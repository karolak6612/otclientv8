MapExplorer = {}

local mapExplorerWindow
local explorerPanel
local selectedMapPath = ""
local selectedVersion = 1098
local reloadEvent = nil
local lastModTime = "0"
local updatePanelEvent = nil
local autoSaveEvent = nil
local lastPlayerPos = nil

function init()
  g_logger.info("MapExplorer: init() called")
  g_settings.setNode('mapexplorer', g_settings.getNode('mapexplorer') or {})
  
  -- Load last used settings
  selectedMapPath = g_settings.getString('mapexplorer/lastMapPath', '')
  
  -- Initialize FileBrowser
  FileBrowser.init()
  
  -- Connect to game start to show explorer panel
  connect(g_game, { onGameStart = MapExplorer.onGameStart,
                    onGameEnd = MapExplorer.onGameEnd })
  
  -- Bind floor change keys
  g_keyboard.bindKeyPress('PageUp', MapExplorer.floorUp)
  g_keyboard.bindKeyPress('PageDown', MapExplorer.floorDown)

  -- Hook g_game.changeOutfit for offline mode
  if not g_game.originalChangeOutfit then
    g_game.originalChangeOutfit = g_game.changeOutfit
    g_game.changeOutfit = function(outfit)
      -- Always use offline logic in MapExplorer mode, even if engine thinks it's online
      g_logger.info("MapExplorer: changeOutfit hook called")
      local player = g_game.getLocalPlayer()
      if player then
        -- Ensure outfit has all required fields to prevent C++ crashes
        outfit.type = outfit.type or 0
        outfit.head = outfit.head or 0
        outfit.body = outfit.body or 0
        outfit.legs = outfit.legs or 0
        outfit.feet = outfit.feet or 0
        outfit.addons = outfit.addons or 0
        outfit.mount = outfit.mount or 0
        outfit.wings = outfit.wings or 0
        outfit.aura = outfit.aura or 0
        outfit.shader = outfit.shader or "outfit_default"
        outfit.healthBar = outfit.healthBar or 0
        outfit.manaBar = outfit.manaBar or 0
        
        g_logger.info(string.format("Setting outfit: type=%d head=%d body=%d legs=%d feet=%d addons=%d mount=%d", 
            outfit.type, outfit.head, outfit.body, outfit.legs, outfit.feet, outfit.addons, outfit.mount))
            
        -- Crash protection: Check if outfit type is valid
        if outfit.type >= 1 and outfit.type <= 1000 then
          local status, err = pcall(function() 
            g_logger.info("[CRASH DEBUG] About to call player:setOutfit")
            player:setOutfit(outfit)
            g_logger.info("[CRASH DEBUG] player:setOutfit completed successfully")
          end)
          if not status then
            g_logger.error("[CRASH DEBUG] Failed to set outfit: " .. tostring(err))
            displayInfoBox("Outfit Error", "Failed to change outfit: " .. tostring(err))
          else
            g_logger.info("Outfit set successfully")
          end
        else
          g_logger.error("Invalid outfit type: " .. tostring(outfit.type))
          displayInfoBox("Outfit Error", "Invalid outfit type: " .. tostring(outfit.type))
        end
      end
    end
  end
  
end

function terminate()
  g_logger.info("MapExplorer: terminate() called")
  disconnect(g_game, { onGameStart = MapExplorer.onGameStart,
                       onGameEnd = MapExplorer.onGameEnd })
                       
  if reloadEvent then
    removeEvent(reloadEvent)
    reloadEvent = nil
  end
  
  if updatePanelEvent then
    removeEvent(updatePanelEvent)
    updatePanelEvent = nil
  end

  if autoSaveEvent then
    removeEvent(autoSaveEvent)
    autoSaveEvent = nil
  end
  
  if mapExplorerWindow then
    mapExplorerWindow:destroy()
    mapExplorerWindow = nil
  end
  
  if explorerPanel then
    explorerPanel:destroy()
    explorerPanel = nil
  end
  
  -- Restore original changeOutfit if needed
  if g_game.originalChangeOutfit then
    g_game.changeOutfit = g_game.originalChangeOutfit
    g_game.originalChangeOutfit = nil
  end
  
  FileBrowser.terminate()
  return true
end

function MapExplorer.show(version)
  if mapExplorerWindow then
    mapExplorerWindow:raise()
    mapExplorerWindow:focus()
    return
  end

  selectedVersion = version or 1098
  mapExplorerWindow = g_ui.displayUI('mapexplorer')
  
  -- Setup FileBrowser
  FileBrowser.setPanel(mapExplorerWindow)
  FileBrowser.setOnFileSelect(function(path)
    selectedMapPath = path
    mapExplorerWindow:getChildById('pathEdit'):setText(path)
    mapExplorerWindow:getChildById('loadButton'):setEnabled(true)
  end)
  
  -- Restore last path
  if selectedMapPath ~= '' then
    mapExplorerWindow:getChildById('pathEdit'):setText(selectedMapPath)
    mapExplorerWindow:getChildById('loadButton'):setEnabled(true)
    -- Also try to navigate file browser there
    local dir = selectedMapPath:match("(.*[/\\])")
    if dir then
       FileBrowser.setPath(dir)
    end
  end
  
  mapExplorerWindow:show()
  mapExplorerWindow:raise()
  mapExplorerWindow:focus()
end

function MapExplorer.hide()
  if mapExplorerWindow then
    mapExplorerWindow:destroy()
    mapExplorerWindow = nil
  end
end

function MapExplorer.onLoadMap()
  if not selectedMapPath or selectedMapPath == '' then return end
  
  g_settings.set('mapexplorer/lastMapPath', selectedMapPath)
  g_settings.save()
  
  -- Load dependencies
  g_modules.ensureModuleLoaded('game_things')
  g_modules.ensureModuleLoaded('game_interface')
  g_modules.ensureModuleLoaded('game_outfit')
  
  if g_game.isOnline() then
    g_game.forceLogout()
    g_game.processGameEnd()
  end
  
  g_game.setClientVersion(selectedVersion)
  g_game.setProtocolVersion(g_game.getClientProtocolVersion(selectedVersion))
  
  -- Load Assets
  local dataDir = '/data/things/' .. selectedVersion
  if not g_things.loadDat(dataDir .. '/Tibia') then
    displayErrorBox(tr('Error'), tr('Failed to load DAT file'))
    return
  end
  g_things.loadOtb(dataDir .. '/items.otb')
  if not g_things.isOtbLoaded() then
    displayErrorBox(tr('Error'), tr('Failed to load OTB file'))
    return
  end
  if not g_sprites.loadSpr(dataDir .. '/Tibia') then
    displayErrorBox(tr('Error'), tr('Failed to load SPR file'))
    return
  end
  
  MapExplorer.loadMapInternal(selectedMapPath)
  
  MapExplorer.hide()
  
  -- Hide EnterGame window
  if modules.client_entergame and modules.client_entergame.EnterGame then
    modules.client_entergame.EnterGame.hide()
  end
end

function MapExplorer.loadMapInternal(path)
  g_logger.info("Loading map: " .. path)
  
  local status, err = pcall(function() 
    g_map.loadOtbm(path) 
  end)
  
  if not status then
    g_logger.error("Failed to load OTBM: " .. err)
    displayErrorBox(tr('Error'), tr('Failed to load map file: ' .. err))
    return
  end
  
  -- GENERATE MINIMAP FROM MAP TILES (Fix for minimap staying blank)
  g_minimap.generateFromMap()
  g_logger.info("Minimap generated from map tiles")
  
  local mapSize = g_map.getSize()
  if mapSize.width == 0 then
    displayErrorBox(tr('Error'), tr('Map loaded but size is 0x0'))
    return
  end
  
  -- Setup Player
  local player = LocalPlayer.create()
  player:setOfflineMode(true)
  g_game.setLocalPlayer(player) 
  
  player:setName("Glaszcz Koldre")
  player:setHealth(150, 150)
  player:setMana(90, 90)
  player:setLevel(8, 0)
  player:setSpeed(220)
  player:setBaseSpeed(220)
  -- Fix: Use correct keys for outfit (type, head, body, legs, feet)
  player:setOutfit({type = 159, head = 29, body = 86, legs = 105, feet = 124})
  
  -- Try to load state
  local stateLoaded = MapExplorer.loadMapState()
  
  if not stateLoaded then
    -- Default spawn
    local spawnPos = MapExplorer.findSpawnPosition()
    if not spawnPos then
       -- Fallback to center if no valid tile found
       spawnPos = {x = math.floor(mapSize.width / 2), y = math.floor(mapSize.height / 2), z = 7}
    end
    player:setPosition(spawnPos)
    g_map.addThing(player, spawnPos, -1)
    g_map.setCentralPosition(spawnPos)
  else
     local pos = player:getPosition()
     g_map.addThing(player, pos, -1)
     g_map.setCentralPosition(pos)
  end
  
  g_map.setLight({intensity = 255, color = 215})
  g_game.processGameStart()
  
  -- Start hot-reload watcher
  lastModTime = g_resources.getFileModificationTime(path)
  if reloadEvent then removeEvent(reloadEvent) end
  reloadEvent = scheduleEvent(MapExplorer.checkFileModification, 500)
end

function MapExplorer.checkFileModification()
  if not selectedMapPath or selectedMapPath == "" then return end
  
  local modTime = g_resources.getFileModificationTime(selectedMapPath)
  if modTime ~= "0" and modTime ~= lastModTime then
    if lastModTime ~= "0" then
       g_logger.info("Map file changed, reloading...")
       MapExplorer.reloadMap()
    end
    lastModTime = modTime
  end
  
  reloadEvent = scheduleEvent(MapExplorer.checkFileModification, 500)
end

function MapExplorer.reloadMap()
  local player = g_game.getLocalPlayer()
  if not player then return end
  
  -- Save state temporarily (in memory)
  local pos = player:getPosition()
  local outfit = player:getOutfit()
  local speed = player:getSpeed()
  
  g_map.clean()
  
  local status, err = pcall(function() 
    g_map.loadOtbm(selectedMapPath) 
  end)
  
  if not status then
    g_logger.error("Reload failed: " .. err)
  end
  
  -- Restore player
  player:setPosition(pos)
  player:setOutfit(outfit)
  player:setSpeed(speed)
  player:setBaseSpeed(speed)
  
  g_map.addThing(player, pos, -1)
  g_map.setCentralPosition(pos)
end

function MapExplorer.onGameStart()
  -- Show Explorer Panel
  if not explorerPanel then
    explorerPanel = g_ui.createWidget('ExplorerPanel', modules.game_interface.getRootPanel())
  end
  explorerPanel:show()
  
  -- Start update loop for coords
  MapExplorer.updatePanelLoop()
  
  -- Start auto-save loop
  MapExplorer.autoSaveLoop()
  
  -- Bind keys
  g_keyboard.bindKeyDown('Ctrl+Shift+E', function() 
    if explorerPanel:isVisible() then explorerPanel:hide() else explorerPanel:show() end
  end)
end

function MapExplorer.onGameEnd()
  if explorerPanel then
    explorerPanel:hide()
  end
  if reloadEvent then
    removeEvent(reloadEvent)
    reloadEvent = nil
  end
  if updatePanelEvent then
    removeEvent(updatePanelEvent)
    updatePanelEvent = nil
  end
  if autoSaveEvent then
    removeEvent(autoSaveEvent)
    autoSaveEvent = nil
  end
  
  MapExplorer.saveMapState()
end

function MapExplorer.updatePanelLoop()
  if explorerPanel and explorerPanel:isVisible() then
    local player = g_game.getLocalPlayer()
    if player then
      local pos = player:getPosition()
      
      -- Only update if position changed significantly to avoid fighting user input
      if not lastPlayerPos or lastPlayerPos.x ~= pos.x or lastPlayerPos.y ~= pos.y or lastPlayerPos.z ~= pos.z then
        lastPlayerPos = pos
        
        local posX = explorerPanel:getChildById('posX')
        local posY = explorerPanel:getChildById('posY')
        local posZ = explorerPanel:getChildById('posZ')
        
        -- Check focus to prevent overwriting while typing
        if not posX:isFocused() then posX:setText(pos.x) end
        if not posY:isFocused() then posY:setText(pos.y) end
        if not posZ:isFocused() then posZ:setText(pos.z) end
      end
    end
  end
  updatePanelEvent = scheduleEvent(MapExplorer.updatePanelLoop, 100)
end

function MapExplorer.autoSaveLoop()
  MapExplorer.saveMapState()
  autoSaveEvent = scheduleEvent(MapExplorer.autoSaveLoop, 5000) -- Save every 5 seconds
end

function MapExplorer.onTeleport()
  local x = tonumber(explorerPanel:getChildById('posX'):getText())
  local y = tonumber(explorerPanel:getChildById('posY'):getText())
  local z = tonumber(explorerPanel:getChildById('posZ'):getText())
  
  if x and y and z then
    local player = g_game.getLocalPlayer()
    if player then
      local pos = {x=x, y=y, z=z}
      -- Remove from old tile
      local oldTile = g_map.getTile(player:getPosition())
      if oldTile then oldTile:removeThing(player) end
      
      player:setPosition(pos)
      
      local newTile = g_map.getTile(pos)
      if newTile then 
        newTile:addThing(player, -1)
      else
        -- Create tile if needed? Or just float.
        -- If we want to see void, we need to be on a tile usually?
        -- Actually, if no tile, we can't addThing to it.
        -- But we can setCentralPosition.
      end
      g_map.setCentralPosition(pos)
      lastPlayerPos = pos -- Update last known pos to prevent overwrite
    end
  end
end

local noclipKeys = {
  ['Up'] = {x=0, y=-1, z=0},
  ['Down'] = {x=0, y=1, z=0},
  ['Left'] = {x=-1, y=0, z=0},
  ['Right'] = {x=1, y=0, z=0},
  ['Numpad8'] = {x=0, y=-1, z=0},
  ['Numpad2'] = {x=0, y=1, z=0},
  ['Numpad4'] = {x=-1, y=0, z=0},
  ['Numpad6'] = {x=1, y=0, z=0},
  ['Numpad7'] = {x=-1, y=-1, z=0},
  ['Numpad9'] = {x=1, y=-1, z=0},
  ['Numpad1'] = {x=-1, y=1, z=0},
  ['Numpad3'] = {x=1, y=1, z=0},
}

function MapExplorer.moveNoClip(dir)
  local player = g_game.getLocalPlayer()
  if not player then return end
  
  local pos = player:getPosition()
  pos.x = pos.x + dir.x
  pos.y = pos.y + dir.y
  pos.z = pos.z + dir.z
  
  -- Use new instant position method (handles tiles, camera, and events)
  player:setPositionInstant(pos, true)  -- true = update camera
  
  lastPlayerPos = pos  -- Update panel tracking
end

function MapExplorer.toggleNoClip(enabled)
  g_logger.info("MapExplorer: toggleNoClip " .. tostring(enabled))
  local player = g_game.getLocalPlayer()
  if player then
    player:setNoClipMode(enabled)
  end
  
  -- Don't override movement keys - let the normal walking system handle it
  -- NoClip mode is now properly integrated at the C++ level
  -- The game will automatically bypass collision checks when m_noClipMode is true
end

function MapExplorer.onSpeedChange(value)
  g_logger.info("MapExplorer: onSpeedChange " .. tostring(value))
  local player = g_game.getLocalPlayer()
  if player then
    player:setSpeed(value)
    player:setBaseSpeed(value)
  end
end

function MapExplorer.saveMapState()
  if not selectedMapPath or selectedMapPath == "" then return end
  local player = g_game.getLocalPlayer()
  if not player then return end
  
  local key = 'map_state_' .. g_crypt.md5Encode(selectedMapPath)
  local state = {
    pos = player:getPosition(),
    outfit = player:getOutfit(),
    speed = player:getSpeed()
  }
  g_settings.setNode(key, state)
  g_settings.save()
end

function MapExplorer.loadMapState()
  if not selectedMapPath or selectedMapPath == "" then return false end
  local key = 'map_state_' .. g_crypt.md5Encode(selectedMapPath)
  local state = g_settings.getNode(key)
  
  if state and state.pos then
    local player = g_game.getLocalPlayer()
    if player then
      player:setPosition(state.pos)
      if state.outfit then 
          g_logger.info("Restoring outfit from state (SKIPPED to force hardcoded)")
          -- player:setOutfit(state.outfit) 
      end
      if state.speed then 
         player:setSpeed(state.speed) 
         if explorerPanel then
            explorerPanel:getChildById('speedScroll'):setValue(state.speed)
         end
      end
      return true
    end
  end
  return false
end

function MapExplorer.findSpawnPosition()
  -- Try to find a valid tile near the center of the map
  local mapSize = g_map.getSize()
  local centerX = math.floor(mapSize.width / 2)
  local centerY = math.floor(mapSize.height / 2)
  local centerZ = 7
  
  -- Spiral search for a walkable tile
  local radius = 0
  local maxRadius = 100 -- Limit search
  
  while radius < maxRadius do
    for x = centerX - radius, centerX + radius do
      for y = centerY - radius, centerY + radius do
        local pos = {x=x, y=y, z=centerZ}
        local tile = g_map.getTile(pos)
        if tile and tile:isWalkable() then
          return pos
        end
      end
    end
    radius = radius + 10 -- Skip some tiles for speed
  end
  
  -- Fallback to towns if available
  local towns = g_towns.getTowns()
  if #towns > 0 then
    local townPos = towns[1]:getPos()
    if g_map.getTile(townPos) then return townPos end
  end
  
  return nil
end

function MapExplorer.onLightChange(value)
  g_map.setLight({intensity = value, color = 215})
end

function MapExplorer.floorUp()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition()
  if pos.z > 0 then
    pos.z = pos.z - 1
    player:setPosition(pos)
    g_map.setCentralPosition(pos)
  end
end

function MapExplorer.floorDown()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition()
  if pos.z < 15 then
    pos.z = pos.z + 1
    player:setPosition(pos)
    g_map.setCentralPosition(pos)
  end
end

function MapExplorer.validateOutfitType(typeId)
  if typeId <= 0 then return false end
  
  -- We use pcall to catch any potential crashes, but getThingType might log errors if invalid
  -- There is no way to check validity without triggering the error log in current API
  local status, result = pcall(function() 
    return g_things.getThingType(typeId, ThingCategoryCreature)
  end)
  
  if not status or not result then return false end
  
  -- Check if we got a valid thing type (not the null one)
  -- The null thing type usually has ID 0 or doesn't match the requested ID
  if result:getId() ~= typeId then return false end
  
  return true
end

function MapExplorer.getMaxAddonsForOutfit(typeId)
  -- Addon validation heuristic
  -- Most outfits support 0-3 addons, but server would normally validate
  local thingType = g_things.getThingType(typeId, ThingCategoryCreature)
  if not thingType then return 0 end
  
  -- Conservative: assume all outfits support max addons to avoid limiting user
  -- In production, this would read from .dat metadata
  return 3
end

function MapExplorer.openOutfitWindow()
  g_logger.info("MapExplorer: openOutfitWindow() called")
  local player = g_game.getLocalPlayer()
  if not player then return end
  
  -- Generate validated outfit list
  local outfits = {}
  local validOutfitCount = 0
  
  -- Scan for valid outfits
  -- Stop after 10 consecutive invalid IDs to avoid spamming errors for the rest of the range
  local consecutiveInvalid = 0
  for i = 1, 2000 do
    if MapExplorer.validateOutfitType(i) then
      local maxAddons = MapExplorer.getMaxAddonsForOutfit(i)
      -- Format: {id, name, maxAddons}
      table.insert(outfits, {i, "Outfit " .. i, maxAddons})
      validOutfitCount = validOutfitCount + 1
      consecutiveInvalid = 0
    else
      consecutiveInvalid = consecutiveInvalid + 1
      if consecutiveInvalid >= 10 then
        break
      end
    end
  end
  
  g_logger.info("Found " .. validOutfitCount .. " valid outfits")
  
  -- Generate mount list (if mounts feature enabled)
  local mounts = {}
  if g_game.getFeature(GamePlayerMounts) then
    for i = 1, 200 do
      if MapExplorer.validateOutfitType(i) then
        table.insert(mounts, {i, "Mount " .. i})
      end
    end
  end
  
  -- CRITICAL: Never pass empty lists - always include "None" option
  -- This prevents Lua errors when the outfit window iterates over empty tables
  local wings = {{0, "None"}}
  local auras = {{0, "None"}}
  local healthBars = {{0, "None"}}
  local manaBars = {{0, "None"}}
  
  -- CRITICAL: Shader list must include "outfit_default"
  -- The C++ rendering code expects this shader to exist
  local shaders = {
    {0, "Default", "outfit_default"},  -- Must have outfit_default
    {1, "None", "no_shader"}
  }
  
  -- Get current outfit (ensure all fields exist with defaults)
  local currentOutfit = player:getOutfit()
  currentOutfit.type = currentOutfit.type or 0
  currentOutfit.head = currentOutfit.head or 0
  currentOutfit.body = currentOutfit.body or 0
  currentOutfit.legs = currentOutfit.legs or 0
  currentOutfit.feet = currentOutfit.feet or 0
  currentOutfit.addons = currentOutfit.addons or 0
  currentOutfit.mount = currentOutfit.mount or 0
  currentOutfit.wings = currentOutfit.wings or 0
  currentOutfit.aura = currentOutfit.aura or 0
  currentOutfit.shader = currentOutfit.shader or "outfit_default"  -- Critical default
  currentOutfit.healthBar = currentOutfit.healthBar or 0
  currentOutfit.manaBar = currentOutfit.manaBar or 0
  
  -- Validate addon value against outfit capabilities
  local maxAddons = MapExplorer.getMaxAddonsForOutfit(currentOutfit.type)
  if currentOutfit.addons > maxAddons then
    g_logger.warning(string.format("Outfit %d only supports %d addons, clamping from %d", 
      currentOutfit.type, maxAddons, currentOutfit.addons))
    currentOutfit.addons = maxAddons
  end
  
  -- Call outfit window with error handling
  local status, err = pcall(function()
    if modules.game_outfit then
      modules.game_outfit.create(currentOutfit, outfits, mounts, wings, auras, shaders, healthBars, manaBars)
    end
  end)
  
  if not status then
    g_logger.error("Failed to open outfit window: " .. tostring(err))
    displayErrorBox("Outfit Error", "Failed to open outfit window. Check console for details.")
  end
end

function MapExplorer.onAutoWalk(toPos)
  local player = g_game.getLocalPlayer()
  if not player then return false end
  
  -- Simple teleport for now
  -- TODO: Implement pathfinding if smooth walking is desired
  g_logger.info(string.format("MapExplorer: Teleporting to (%d, %d, %d)", toPos.x, toPos.y, toPos.z))
  
  -- Update position
  player:setPosition(toPos)
  g_map.setCentralPosition(toPos)
  
  -- Update last player pos to prevent rubberbanding if any
  lastPlayerPos = toPos
  
  return true
end
