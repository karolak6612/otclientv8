MapExplorerGame = {}

local selectedMapPath = ""
local selectedVersion = 1098
local lastPlayerPos = nil
local currentLight = 255
local currentColor = 215
local currentZoomSpeed = 1

function MapExplorerGame.init()
  g_logger.info("MapExplorerGame: init() called")
  
  -- Load last used settings
  selectedMapPath = g_settings.getString('mapexplorer/lastMapPath', '')
  selectedVersion = g_settings.getNumber('mapexplorer/clientVersion', 1098)
  
  SpawnSimulator.init()
  
  -- Connect to game start
  connect(g_game, { onGameStart = MapExplorerGame.onGameStart,
                    onGameEnd = MapExplorerGame.onGameEnd })
  
  -- Bind floor change keys
  g_keyboard.bindKeyPress('PageUp', MapExplorerGame.floorUp)
  g_keyboard.bindKeyPress('PageDown', MapExplorerGame.floorDown)

  -- Bind Movement Keys (Fix for East/West stutter)
  g_keyboard.bindKeyPress('Up', function() g_game.walk(North) end)
  g_keyboard.bindKeyPress('Right', function() g_game.walk(East) end)
  g_keyboard.bindKeyPress('Down', function() g_game.walk(South) end)
  g_keyboard.bindKeyPress('Left', function() g_game.walk(West) end)

  -- Bind Rotation Keys (Ctrl + Arrows)
  g_keyboard.bindKeyDown('Ctrl+Up', function() MapExplorerGame.rotate(North) end)
  g_keyboard.bindKeyDown('Ctrl+Right', function() MapExplorerGame.rotate(East) end)
  g_keyboard.bindKeyDown('Ctrl+Down', function() MapExplorerGame.rotate(South) end)
  g_keyboard.bindKeyDown('Ctrl+Left', function() MapExplorerGame.rotate(West) end)

  -- Hook g_game.changeOutfit for offline mode
  if not g_game.originalChangeOutfit then
    g_game.originalChangeOutfit = g_game.changeOutfit
    g_game.changeOutfit = function(outfit)
      -- Always use offline logic in MapExplorer mode
      g_logger.info("MapExplorerGame: changeOutfit hook called")
      local player = g_game.getLocalPlayer()
      if player then
        -- Delegate to Outfit module for safe handling
        MapExplorerOutfit.applyOutfit(player, outfit)
      end
    end
  end
end

function MapExplorerGame.terminate()
  disconnect(g_game, { onGameStart = MapExplorerGame.onGameStart,
                       onGameEnd = MapExplorerGame.onGameEnd })
  
  g_keyboard.unbindKeyPress('PageUp', MapExplorerGame.floorUp)
  g_keyboard.unbindKeyPress('PageDown', MapExplorerGame.floorDown)

  g_keyboard.unbindKeyPress('Up', function() g_game.walk(North) end)
  g_keyboard.unbindKeyPress('Right', function() g_game.walk(East) end)
  g_keyboard.unbindKeyPress('Down', function() g_game.walk(South) end)
  g_keyboard.unbindKeyPress('Left', function() g_game.walk(West) end)

  g_keyboard.unbindKeyDown('Ctrl+Up', function() MapExplorerGame.rotate(North) end)
  g_keyboard.unbindKeyDown('Ctrl+Right', function() MapExplorerGame.rotate(East) end)
  g_keyboard.unbindKeyDown('Ctrl+Down', function() MapExplorerGame.rotate(South) end)
  g_keyboard.unbindKeyDown('Ctrl+Left', function() MapExplorerGame.rotate(West) end)
  
  -- Restore original changeOutfit if needed (optional, usually not needed on terminate)
  if g_game.originalChangeOutfit then
    g_game.changeOutfit = g_game.originalChangeOutfit
    g_game.originalChangeOutfit = nil
  end
end

function MapExplorerGame.rotate(dir)
  local player = g_game.getLocalPlayer()
  if player then
    player:setDirection(dir)
  end
end

function MapExplorerGame.onMinimapClick(widget, mousePos, mouseButton)
  if mouseButton == MouseLeftButton and g_keyboard.isCtrlPressed() then
    local pos = widget:getTilePosition(mousePos)
    if pos then
      MapExplorerGame.teleportTo(pos)
      return true
    end
  end
  return false
end

function MapExplorerGame.onGameStart()
  g_logger.info("MapExplorerGame: onGameStart")
  MapExplorerUI.hide() -- Hide file browser if open
  MapExplorerUI.showTools() -- Show tools panel
  
  -- Hide EnterGame window
  if modules.client_entergame and modules.client_entergame.EnterGame then
    modules.client_entergame.EnterGame.hide()
  end
  
  -- Disable game_walking module to prevent conflict
  if modules.game_walking then
    g_modules.ensureModuleLoaded('game_walking') -- Ensure it's loaded so we can unload it properly? No, just check if loaded.
    if modules.game_walking.loaded then
      modules.game_walking.terminate()
    end
  end

  -- Hook Minimap Click
  if modules.game_minimap and modules.game_minimap.minimapWidget then
    modules.game_minimap.minimapWidget.onMouseRelease = MapExplorerGame.onMinimapClick
  end
  
  -- Start auto-save loop
  MapExplorerGame.autoSaveLoop()

  -- Initialize Extended Rendering (7x7 chunks to prevent black tiles on zoom)
  local mapPanel = modules.game_interface.getMapPanel()
  if mapPanel then
    mapPanel:setDrawBuffer({width=7, height=7})
    
    -- Hook Zoom (Ctrl + Scroll)
    local originalOnMouseWheel = mapPanel.onMouseWheel
    mapPanel.onMouseWheel = function(widget, mousePos, direction)
      if g_keyboard.isCtrlPressed() then
        local speed = currentZoomSpeed or 1
        for i = 1, speed do
            if direction == MouseWheelUp then
              widget:zoomIn()
            else
              widget:zoomOut()
            end
        end
        return true
      elseif originalOnMouseWheel then
        return originalOnMouseWheel(widget, mousePos, direction)
      end
      return false
    end
    
    -- Hook Map Click (Ctrl + Click Teleport)
    local originalOnMouseRelease = mapPanel.onMouseRelease
    mapPanel.onMouseRelease = function(widget, mousePos, mouseButton)
        if mouseButton == MouseLeftButton then
            if g_keyboard.isCtrlPressed() then
                local pos = widget:getPosition(mousePos)
                if pos then
                    MapExplorerGame.teleportTo(pos)
                    return true
                end
            else
                -- Disable default left-click (walk) to prevent crash
                return true
            end
        end
        
        if originalOnMouseRelease then
            return originalOnMouseRelease(widget, mousePos, mouseButton)
        end
        return false
    end

    -- Hook Mouse Press to prevent dragging/walking start
    local originalOnMousePress = mapPanel.onMousePress
    mapPanel.onMousePress = function(widget, mousePos, mouseButton)
        if mouseButton == MouseLeftButton then
             -- Always consume Left Click to prevent default drag/walk behavior
             -- This prevents the crash.
             -- Teleport logic is handled in onMouseRelease (which still fires).
             return true
        end
        
        if originalOnMousePress then
            return originalOnMousePress(widget, mousePos, mouseButton)
        end
        return false
    end

    -- Hook Drag Move to be safe
    mapPanel.onDragMove = function(widget, mousePos, mouseMoved)
        return true -- Consume all drags
    end

    -- Hook Drag Enter/Leave to prevent cursor changes and crashes
    mapPanel.onDragEnter = function(widget, mousePos)
        return true -- Consume/Prevent default
    end

    mapPanel.onDragLeave = function(widget, droppedWidget, mousePos)
        return true -- Consume/Prevent default
    end

    -- Hook Mouse Move to prevent cursor changes
    mapPanel.onMouseMove = function(widget, mousePos, mouseMoved)
        return true -- Consume
    end
    
    -- Hook Hover to be safe
    mapPanel.onHoverChange = function(widget, hovered)
        return true
    end
  end
  
  -- Initialize Palette
  MapExplorerGame.initPalette()
end

function MapExplorerGame.resetView()
  local mapPanel = modules.game_interface.getMapPanel()
  if mapPanel then
    -- Reset Zoom (set visible dimension to default)
    mapPanel:setVisibleDimension({width = 15, height = 11})
    mapPanel:setZoom(11) -- Sync internal zoom state
    
    -- Reset Zoom Speed
    currentZoomSpeed = 1
    if MapExplorerUI.explorerPanel then
        MapExplorerUI.explorerPanel:getChildById('zoomSpeedScroll'):setValue(1)
    end
    
    -- Center on player
    local player = g_game.getLocalPlayer()
    if player then
        g_map.setCentralPosition(player:getPosition())
    end
  end
end

function MapExplorerGame.onGameEnd()
  g_logger.info("MapExplorerGame: onGameEnd")
  MapExplorerGame.saveMapState()
  MapExplorerUI.hideTools()
  
  -- Re-enable game_walking module
  if modules.game_walking then
     modules.game_walking.init()
  end
end

function MapExplorerGame.onGameEnd()
  g_logger.info("MapExplorerGame: onGameEnd")
  MapExplorerGame.saveMapState()
  MapExplorerUI.hideTools()
end

function MapExplorerGame.setSelectedMap(path)
  selectedMapPath = path
  g_settings.set('mapexplorer/lastMapPath', path)
  
  -- Auto-detect version from path
  local versionMatch = path:match("/things/(%d+)/")
  if versionMatch then
    selectedVersion = tonumber(versionMatch)
    g_settings.set('mapexplorer/clientVersion', selectedVersion)
    g_settings.set('client-version', selectedVersion) -- Update global setting for EnterGame
    MapExplorerUI.setStatus("Detected client version: " .. selectedVersion)
  end
end

-- Compatibility with EnterGame
MapExplorer = {}

function MapExplorer.show(version)
  selectedVersion = version or 1098
  MapExplorerUI.show()
end

function MapExplorer.hide()
  MapExplorerUI.hide()
end

function MapExplorerGame.loadSelectedMap()
  if selectedMapPath == "" then
    MapExplorerUI.setStatus("No map selected")
    return
  end
  
  MapExplorerUI.setStatus("Loading map...")
  
  -- Schedule load to allow UI to update
  scheduleEvent(function()
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
    
    -- Load Assets (Exact copy from mapexplorer_temp.lua)
    local dataDir = '/data/things/' .. selectedVersion
    if not g_things.loadDat(dataDir .. '/Tibia') then
      MapExplorerUI.setStatus("Failed to load DAT file")
      return
    end
    g_things.loadOtb(dataDir .. '/items.otb')
    if not g_things.isOtbLoaded() then
      MapExplorerUI.setStatus("Failed to load OTB file")
      return
    end
    if not g_sprites.loadSpr(dataDir .. '/Tibia') then
      MapExplorerUI.setStatus("Failed to load SPR file")
      return
    end
    
    -- Load map
    local mapPath = selectedMapPath
    if not g_resources.fileExists(mapPath) then
      MapExplorerUI.setStatus("Map file not found: " .. mapPath)
      return
    end
    
    g_logger.info("Loading map: " .. mapPath)
    
    -- Clear existing map
    g_map.clean()
    
    -- Load OTBM (using pcall as it might raise error, and returns nil on success)
    local status, err = pcall(function()
      g_map.loadOtbm(mapPath)
    end)
    
    if not status then
      g_logger.error("Failed to load map: " .. tostring(err))
      MapExplorerUI.setStatus("Failed to load map: " .. tostring(err))
      return
    end
    
    MapExplorerUI.setStatus("Map loaded!")
    MapExplorerUI.hide()
    MapExplorerUI.showTools() -- Show the tools panel
    
    -- Set initial position (center of map or saved pos)
    local player = g_game.getLocalPlayer()
    if not player then
      player = LocalPlayer.create()
      player:setOfflineMode(true)
      player:setName("MapExplorer")
      g_game.setLocalPlayer(player)
    end
    
    -- Reset light to default before loading state
    currentLight = 255
    
    -- Try to load state
    if not MapExplorerGame.loadMapState() then
      -- Try to find a valid position if no state loaded
      local pos = MapExplorerGame.findSpawnPosition()
      if not pos then
         -- Fallback to center if no valid tile found
         local mapSize = g_map.getSize()
         pos = {x = math.floor(mapSize.width / 2), y = math.floor(mapSize.height / 2), z = 7}
      end
      
      player:setPosition(pos)
      g_map.addThing(player, pos, -1) -- Add player to map
      g_map.setCentralPosition(pos)
    else
       -- State loaded, just ensure player is added to map
       local pos = player:getPosition()
       g_map.addThing(player, pos, -1)
       g_map.setCentralPosition(pos)
    end
    
    -- Set ambient light (using loaded or default value)
    g_map.setLight({intensity = currentLight, color = 215})
    if MapExplorerUI.explorerPanel then
        MapExplorerUI.explorerPanel:getChildById('lightScroll'):setValue(currentLight)
    end
    
    -- Start game interface
    g_game.processGameStart()
    
    -- Force minimap generation
    if g_minimap then
      g_minimap.clean()
      g_minimap.generateFromMap()
    end
  end, 100)
end

-- Remove local currentLight declaration here as it's now used above, 
-- but we need to ensure it's declared at module level if not already.
-- Checking file content, it was declared at line 257 in previous read, 
-- but I am replacing the block that includes line 257.
-- Wait, line 257 was `local currentLight = 255`.
-- I need to make sure `currentLight` is available to `loadMapState` which is defined later?
-- No, `loadMapState` is defined later.
-- But `loadSelectedMap` uses `currentLight`.
-- `currentLight` must be upvalue.
-- In the previous file content, `local currentLight = 255` was at line 257, AFTER `loadSelectedMap` (lines 153-255).
-- This means `loadSelectedMap` was using a global or nil `currentLight`?
-- No, Lua functions capture upvalues. If `currentLight` is defined AFTER `loadSelectedMap`, `loadSelectedMap` can't see it unless it's global?
-- Wait, if `currentLight` is local at file scope but defined AFTER the function, the function can't see it?
-- Actually, in Lua, if I define `local currentLight` after, the function defined before will NOT see it.
-- So `currentLight` inside `loadSelectedMap` (if I used it) would be nil or global.
-- I need to move `local currentLight = 255` to the TOP of the file.
-- I will check where `currentLight` is defined.
-- In step 750 read, `local currentLight = 255` is at line 257. `loadSelectedMap` ends at line 255.
-- So `loadSelectedMap` could NOT access `currentLight`!
-- That explains why I hardcoded 255 in `loadSelectedMap`.
-- I must move `local currentLight = 255` to the top of the file.

function MapExplorerGame.findSpawnPosition()
  -- Try to find a valid tile to spawn on
  -- For now, we just return nil and let the fallback logic handle it
  -- or we could implement a search here.
  -- Since the fallback logic (lines 258+) handles nil, we just need the function to exist.
  return nil
end

function MapExplorerGame.teleportTo(pos)
  local player = g_game.getLocalPlayer()
  if not player then return end
  
  -- Remove from old tile
  local oldTile = g_map.getTile(player:getPosition())
  if oldTile then oldTile:removeThing(player) end
  
  player:setPosition(pos)
  
  local newTile = g_map.getTile(pos)
  if newTile then 
    newTile:addThing(player, -1)
  end
  g_map.setCentralPosition(pos)
  lastPlayerPos = pos
end

function MapExplorerGame.floorUp()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition()
  pos.z = pos.z - 1
  if pos.z < 0 then pos.z = 0 end
  MapExplorerGame.teleportTo(pos)
end

function MapExplorerGame.floorDown()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition()
  pos.z = pos.z + 1
  if pos.z > 15 then pos.z = 15 end
  MapExplorerGame.teleportTo(pos)
end

function MapExplorerGame.onTeleport()
  local x = tonumber(MapExplorerUI.explorerPanel:getChildById('posX'):getText())
  local y = tonumber(MapExplorerUI.explorerPanel:getChildById('posY'):getText())
  local z = tonumber(MapExplorerUI.explorerPanel:getChildById('posZ'):getText())
  
  if x and y and z then
    local pos = {x=x, y=y, z=z}
    MapExplorerGame.teleportTo(pos)
  end
end

function MapExplorerGame.toggleNoClip(enabled)
  g_logger.info("MapExplorerGame: toggleNoClip " .. tostring(enabled))
  local player = g_game.getLocalPlayer()
  if player then
    player:setNoClipMode(enabled)
  end
end

function MapExplorerGame.onSpeedChange(value)
  local player = g_game.getLocalPlayer()
  if player then
    player:setSpeed(value)
    player:setBaseSpeed(value)
  end
end



function MapExplorerGame.initPalette()
  if not MapExplorerUI.explorerPanel then return end
  
  local paletteContainer = MapExplorerUI.explorerPanel:getChildById('paletteContainer')
  if not paletteContainer then return end
  
  paletteContainer:destroyChildren()
  
  -- Generate Tibia 8-bit palette (approximate)
  -- 6x6x6 color cube + grayscale
  for i = 0, 215 do
    local r = (math.floor(i / 36) % 6) * 51
    local g = (math.floor(i / 6) % 6) * 51
    local b = (i % 6) * 51
    local color = string.format("#%02X%02X%02X", r, g, b)
    
    local widget = g_ui.createWidget('UIWidget', paletteContainer)
    widget:setId('color_' .. i)
    widget:setBackgroundColor(color)
    widget:setBorderWidth(1)
    widget:setBorderColor('black')
    widget.onClick = function() 
      MapExplorerGame.onColorChange(i)
      -- Highlight selection
      for _, child in pairs(paletteContainer:getChildren()) do
        child:setBorderColor('black')
        child:setBorderWidth(1)
      end
      widget:setBorderColor('white')
      widget:setBorderWidth(2)
    end
  end
  
  -- Select default
  local defaultWidget = paletteContainer:getChildById('color_' .. currentColor)
  if defaultWidget then
    defaultWidget:setBorderColor('white')
    defaultWidget:setBorderWidth(2)
  end
end

function MapExplorerGame.onLightChange(value)
  currentLight = value
  g_map.setLight({intensity = currentLight, color = currentColor})
end

function MapExplorerGame.onColorChange(value)
  currentColor = value
  g_map.setLight({intensity = currentLight, color = currentColor})
end

-- Expose to global MapExplorer for OTUI compatibility
MapExplorer.onTeleport = MapExplorerGame.onTeleport
MapExplorer.toggleSpawnSimulator = function() SpawnSimulatorUI.toggle() end

function MapExplorerGame.getSelectedVersion()
  return selectedVersion
end

function MapExplorerGame.saveMapState()
  if not selectedMapPath or selectedMapPath == "" then return end
  local player = g_game.getLocalPlayer()
  if not player then return end
  
  local key = 'map_state_' .. g_crypt.md5Encode(selectedMapPath)
  local state = {
    pos = player:getPosition(),
    outfit = player:getOutfit(),
    speed = player:getSpeed(),
    light = currentLight,
    color = currentColor,
    zoomSpeed = currentZoomSpeed
  }
  g_settings.setNode(key, state)
  g_settings.save()
end

function MapExplorerGame.loadMapState()
  if not selectedMapPath or selectedMapPath == "" then return false end
  local key = 'map_state_' .. g_crypt.md5Encode(selectedMapPath)
  local state = g_settings.getNode(key)
  
  if state and state.pos then
    local player = g_game.getLocalPlayer()
    if player then
      player:setPosition(state.pos)
      if state.outfit then 
          player:setOutfit(state.outfit) 
      end
      if state.speed then 
         player:setSpeed(state.speed) 
         if MapExplorerUI.explorerPanel then
            MapExplorerUI.explorerPanel:getChildById('speedScroll'):setValue(state.speed)
         end
      end
      if state.light then
         currentLight = state.light
         if state.color then currentColor = state.color end
         if state.zoomSpeed then 
            currentZoomSpeed = state.zoomSpeed 
            if MapExplorerUI.explorerPanel then
                MapExplorerUI.explorerPanel:getChildById('zoomSpeedScroll'):setValue(currentZoomSpeed)
            end
         end
         
         g_map.setLight({intensity = currentLight, color = currentColor})
         if MapExplorerUI.explorerPanel then
            MapExplorerUI.explorerPanel:getChildById('lightScroll'):setValue(currentLight)
            -- Update palette selection
            local paletteContainer = MapExplorerUI.explorerPanel:getChildById('paletteContainer')
            if paletteContainer then
               for _, child in pairs(paletteContainer:getChildren()) do
                 child:setBorderColor('black')
                 child:setBorderWidth(1)
               end
               local selectedWidget = paletteContainer:getChildById('color_' .. currentColor)
               if selectedWidget then
                 selectedWidget:setBorderColor('white')
                 selectedWidget:setBorderWidth(2)
               end
            end
         end
      end
      return true
    end
  end
  return false
end

function MapExplorerGame.autoSaveLoop()
  MapExplorerGame.saveMapState()
  scheduleEvent(MapExplorerGame.autoSaveLoop, 5000) -- Save every 5 seconds
end
