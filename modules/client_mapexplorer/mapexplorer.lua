MapExplorer = {}

local mapExplorerWindow
local selectedMapPath = ""
local selectedVersion = 1098

function init()
  g_logger.info("MapExplorer: init() called")
  g_settings.setNode('mapexplorer', g_settings.getNode('mapexplorer') or {})
  
  -- Load last used settings
  selectedMapPath = g_settings.getString('mapexplorer/lastMapPath', '')
  g_logger.info("MapExplorer: module initialized. Last path: " .. selectedMapPath)
  return true
end

function terminate()
  g_logger.info("MapExplorer: terminate() called")
  if mapExplorerWindow then
    mapExplorerWindow:destroy()
  end
  return true
end

function MapExplorer.show(version)
  g_logger.info("MapExplorer: show() called with version: " .. tostring(version))
  if mapExplorerWindow then
    mapExplorerWindow:raise()
    mapExplorerWindow:focus()
    return
  end

  selectedVersion = version or 1098
  mapExplorerWindow = g_ui.displayUI('mapexplorer')
  
  -- Restore last used map path
  if selectedMapPath ~= '' then
    local mapPathEdit = mapExplorerWindow:getChildById('mapPathEdit')
    mapPathEdit:setText(selectedMapPath)
    mapExplorerWindow:getChildById('loadButton'):setEnabled(true)
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

function MapExplorer.onBrowseMap()
  -- g_platform.openFileDialog is not available in this version
  -- Fallback: Focus the text edit and show a message
  local mapPathEdit = mapExplorerWindow:getChildById('mapPathEdit')
  mapPathEdit:setEnabled(true)
  mapPathEdit:focus()
  
  local statusLabel = mapExplorerWindow:getChildById('statusLabel')
  statusLabel:setText(tr('Please type the full path to the .otbm file'))
  statusLabel:setColor('#ffff00')
  
  -- Enable load button if text is not empty
  if mapPathEdit:getText() ~= '' then
     mapExplorerWindow:getChildById('loadButton'):setEnabled(true)
  end
end

function MapExplorer.onLoadMap()
  g_logger.info("MapExplorer: onLoadMap() called")
  if not selectedMapPath or selectedMapPath == '' then
    return
  end
  
  -- Save settings
  g_settings.set('mapexplorer/lastMapPath', selectedMapPath)
  g_settings.save()
  
  local mapPath = selectedMapPath
  local version = selectedVersion
  
  g_logger.info('MapExplorer: Loading map: ' .. mapPath)
  g_logger.info('MapExplorer: Client version: ' .. version)

  -- Ensure dependencies are loaded
  g_logger.info("MapExplorer: Checking dependencies...")
  g_modules.ensureModuleLoaded('game_things')
  g_modules.ensureModuleLoaded('game_interface')
  g_logger.info("MapExplorer: Dependencies loaded.")
  
  -- Disconnect if online
  if g_game.isOnline() then
    g_game.forceLogout()
    g_game.processGameEnd()
  end
  
  -- Set client version
  g_game.setClientVersion(version)
  g_game.setProtocolVersion(g_game.getClientProtocolVersion(version))
  
  -- Load assets (DAT, OTB, SPR)
  g_logger.info('MapExplorer: Loading DAT...')
  local datPath = '/data/things/' .. version .. '/Tibia'
  if not g_things.loadDat(datPath) then
    g_logger.error("MapExplorer: Failed to load DAT: " .. datPath)
    displayErrorBox(tr('Error'), tr('Failed to load DAT file'))
    return false
  end
  
  g_logger.info('MapExplorer: Loading OTB...')
  local otbPath = '/data/things/' .. version .. '/items.otb'
  
  -- Load OTB (void function, handles errors internally via try/catch)
  g_things.loadOtb(otbPath)
  
  -- Verify OTB loaded by checking isOtbLoaded()
  if not g_things.isOtbLoaded() then
    g_logger.error("MapExplorer: OTB did not load successfully")
    displayErrorBox(tr('Error'), tr('Failed to load OTB file'))
    return false
  end
  
  g_logger.info('MapExplorer: OTB loaded successfully')
  
  g_logger.info('MapExplorer: Loading SPR...')
  local sprPath = '/data/things/' .. version .. '/Tibia'
  if not g_sprites.loadSpr(sprPath) then
    g_logger.error("MapExplorer: Failed to load SPR: " .. sprPath)
    displayErrorBox(tr('Error'), tr('Failed to load SPR file'))
    return false
  end
  
  -- Load map
  -- Normalize path separators
  mapPath = mapPath:gsub("\\", "/")
  
  -- Convert absolute path to virtual path if possible
  local dataIndex = mapPath:find("/data/")
  if dataIndex then
    mapPath = mapPath:sub(dataIndex)
  end
  
  local modulesIndex = mapPath:find("/modules/")
  if modulesIndex then
    mapPath = mapPath:sub(modulesIndex)
  end
  
  g_logger.info("================================================")
  g_logger.info("MapExplorer: Starting map load sequence")
  g_logger.info("================================================")
  
  if selectedMapPath == '' then
    g_logger.error("MapExplorer: No map path selected")
    return false
  end
  
  --========================================
  -- STEP 1: Load OTBM File
  --========================================
  -- Note: mapPath already processed at lines 126-138 above
  g_logger.info("STEP 1: Loading OTBM file: " .. mapPath)
  
  -- Load OTBM (void function, handles errors internally via try/catch)
  g_map.loadOtbm(mapPath)
  
  -- Verify map loaded by checking if size is valid
  local mapSize = g_map.getSize()
  if mapSize.width == 0 or mapSize.height == 0 then
    g_logger.error("STEP 1 FAILED: Map did not load (size is 0x0)")
    local statusLabel = mapExplorerWindow:getChildById('statusLabel')
    statusLabel:setText(tr('Failed to load map file'))
    statusLabel:setColor('#ff0000')
    return false
  end
  
  g_logger.info("STEP 1 COMPLETE: OTBM loaded successfully")
  g_logger.info("Map size: " .. mapSize.width .. "x" .. mapSize.height)
  
  -- Save last used path
  g_settings.setValue('mapexplorer/lastMapPath', selectedMapPath)
  
  --========================================
  -- STEP 2: Create Local Player
  --========================================
  g_logger.info("STEP 2: Creating local player for offline mode")
  local player = LocalPlayer.create()
  if not player then
    g_logger.error("STEP 2 FAILED: Could not create LocalPlayer!")
    return false
  end
  
  -- Set player for offline mode (bypasses server walk validation)
  player:setOfflineMode(true)
  g_game.setLocalPlayer(player)
  g_logger.info("STEP 2 COMPLETE: Local player created and set")
  
  -- Set player name for offline mode
  player:setName("Map Explorer")
  
  -- Unlock walk to allow movement (locked by default)
  player:unlockWalk()
  g_logger.info("STEP 2: Player walk unlocked for movement")
  g_logger.info("STEP 2: Offline mode enabled - walks will confirm locally")
  
  --========================================
  -- STEP 3: Find Spawn Position
  --========================================
  g_logger.info("STEP 3: Finding spawn position")
  local spawnPos = findSpawnPosition()
  
  if not spawnPos then
    -- Fallback to map center
    g_logger.warning("STEP 3: No spawn found, using map center")
    spawnPos = {
      x = math.floor(mapSize.width / 2),
      y = math.floor(mapSize.height / 2),
      z = 7
    }
  end
  
  g_logger.info("STEP 3 COMPLETE: Spawn position: " .. spawnPos.x .. "," .. spawnPos.y .. "," .. spawnPos.z)
  
  -- Verify tile exists at spawn
  local spawnTile = g_map.getTile(spawnPos)
  if not spawnTile then
    g_logger.error("STEP 3 FAILED: No tile at spawn position!")
    return false
  end
  debugTileContents(spawnPos, "Spawn Position")
  
  --========================================
  -- STEP 4: Set Player Position
  --========================================
  g_logger.info("STEP 4: Setting player position")
  player:setPosition(spawnPos)
  
  -- NOTE: m_allowAppearWalk defaults to false, which prevents auto-walk on position changes
  -- Creature::onAppear() only calls walk() if m_allowAppearWalk = true
  -- We DON'T call allowAppearWalk() to keep it false
  g_logger.info("STEP 4: Auto-walk disabled (m_allowAppearWalk = false by default)")
  
  g_logger.info("STEP 4 COMPLETE: Player position set")
  
  --========================================
  -- STEP 5: Add Player to Map Tile
  --========================================
  g_logger.info("STEP 5: Adding player to map tile")
  
  -- Add player to tile at spawn position (void function, no return value)
  g_map.addThing(player, spawnPos, -1)
  
  -- Verify player was added by checking creatures on tile
  local tile = g_map.getTile(spawnPos)
  if not tile then
    g_logger.error("STEP 5 FAILED: Tile disappeared after addThing")
    return false
  end
  
  local creatures = tile:getCreatures()
  local playerFound = false
  for _, creature in ipairs(creatures) do
    if creature == player then
      playerFound = true
      break
    end
  end
  
  if not playerFound then
    g_logger.error("STEP 5 FAILED: Player not found in tile creatures list")
    g_logger.error("Creatures on tile: " .. #creatures)
    return false
  end
  
  g_logger.info("STEP 5 COMPLETE: Player added to map tile")
  
  -- Verify player is now in tile
  spawnTile = g_map.getTile(spawnPos)
  local creatures = spawnTile:getCreatures()
  if not creatures or #creatures == 0 then
    g_logger.error("STEP 5 VERIFICATION FAILED: Player not in tile creatures list!")
    return false
  end
  g_logger.info("STEP 5 VERIFIED: Player is in tile (creature count: " .. #creatures .. ")")
  debugTileContents(spawnPos, "After Adding Player")
  
  --========================================
  -- STEP 6: Set Central Position (Awareness)
  --========================================
  g_logger.info("STEP 6: Setting central position (awareness)")
  g_map.setCentralPosition(spawnPos)
  g_logger.info("STEP 6 COMPLETE: Central position set, awareness updated")
  
  -- Verify awareness tiles
  verifyMapState("After Setting Central Position")
  
  --========================================
  -- STEP 7: Set World Light
  --========================================
  g_logger.info("STEP 7: Setting world light")
  g_map.setLight({intensity = 255, color = 215})
  g_logger.info("STEP 7 COMPLETE: World light set to full daylight")
  
  --========================================
  -- STEP 8: Start Game (processGameStart)
  --========================================
  g_logger.info("STEP 8: Starting game state (processGameStart)")
  
  -- Note: processEnterGame is NOT bound to Lua - it's only called by ProtocolGame
  -- In offline mode, we skip directly to processGameStart, which handles:
  -- - Setting g_game online
  -- - Synchronizing fight modes
  -- - Calling onGameStart callback
  -- - Starting ping events (if features enabled)
  g_game.processGameStart()
  
  g_logger.info("STEP 8 COMPLETE: Game state initialized")
  g_logger.info("Game is online: " .. tostring(g_game.isOnline()))
  
  -- Manually ensure game_walking module binds keys for offline mode
  if modules.game_walking and modules.game_walking.onGameStart then
    g_logger.info("STEP 8: Triggering game_walking.onGameStart() for keyboard bindings")
    modules.game_walking.onGameStart()
  else
    g_logger.warning("STEP 8: game_walking module not available!")
  end
  
  --========================================
  -- STEP 9: Bind Camera to Player
  --========================================
  g_logger.info("STEP 9: Binding camera to player")
  if modules.game_interface then
    local mapPanel = modules.game_interface.getMapPanel()
    if mapPanel then
      mapPanel:followCreature(player)
      g_logger.info("STEP 10 COMPLETE: Camera bound to player")
    else
      g_logger.error("STEP 10 FAILED: No map panel found!")
      return false
    end
  else
    g_logger.error("STEP 10 FAILED: game_interface module not loaded!")
    return false
  end
  
  --========================================
  -- STEP 11: Final Verification
  --========================================
  g_logger.info("STEP 11: Final state verification")
  if not verifyMapState("Final State") then
    g_logger.error("STEP 11 FAILED: Final verification failed")
    return false
  end
  g_logger.info("STEP 11 COMPLETE: All verifications passed")
  
  --========================================
  -- SUCCESS!
  --========================================
  g_logger.info("================================================")
  g_logger.info("MAP LOADED SUCCESSFULLY - Rendering should work!")
  g_logger.info("================================================")
  
  -- Update UI
  local statusLabel = mapExplorerWindow:getChildById('statusLabel')
  statusLabel:setText(tr('Map loaded successfully!'))
  statusLabel:setColor('#00ff00')
  
  -- Hide EnterGame window
  if EnterGame then EnterGame.hide() end
  
  -- Close explorer window
  MapExplorer.hide()
  
  return true
end

function findSpawnPosition()
  -- Try to find a town spawn first
  local towns = g_towns.getTowns()
  if #towns > 0 then
    local townPos = towns[1]:getPos()
    if g_map.getTile(townPos) then
      return townPos
    end
    g_logger.warning("Town spawn has no tile, searching nearby...")
  end
  
  -- Fallback to map center
  local mapSize = g_map.getSize()
  local centerX = math.floor(mapSize.width / 2)
  local centerY = math.floor(mapSize.height / 2)
  local centerZ = 7
  
  -- Helper function to find nearest valid tile in spiral pattern
  local function findNearestTile(startX, startY, startZ, maxRadius)
    -- Check center first
    if g_map.getTile({x=startX, y=startY, z=startZ}) then
      return {x=startX, y=startY, z=startZ}
    end
    
    -- Spiral search outward
    for radius = 1, maxRadius do
      for z = startZ, 0, -1 do  -- Try current floor first, then go up
        -- Search in a square pattern around the center
        for dx = -radius, radius do
          for dy = -radius, radius do
            -- Only check the perimeter of the current radius
            if math.abs(dx) == radius or math.abs(dy) == radius then
              local pos = {x=startX + dx, y=startY + dy, z=z}
              local tile = g_map.getTile(pos)
              if tile and tile:isWalkable() then
                g_logger.info("Found valid tile at offset (" .. dx .. "," .. dy .. ") from center")
                return pos
              end
            end
          end
        end
      end
      
      -- Also try lower floors
      for z = startZ + 1, 15 do
        for dx = -radius, radius do
          for dy = -radius, radius do
            if math.abs(dx) == radius or math.abs(dy) == radius then
              local pos = {x=startX + dx, y=startY + dy, z=z}
              local tile = g_map.getTile(pos)
              if tile and tile:isWalkable() then
                g_logger.info("Found valid tile at offset (" .. dx .. "," .. dy .. ") floor " .. z)
                return pos
              end
            end
          end
        end
      end
    end
    
    return nil
  end
  
  -- Search for nearest valid tile within 200 tile radius
  return findNearestTile(centerX, centerY, centerZ, 200)
end
function MapExplorer.onMapPathChange(widget, text)
  selectedMapPath = text
  local loadButton = mapExplorerWindow:getChildById('loadButton')
  loadButton:setEnabled(text ~= '')
end

-- ============================================
-- VERIFICATION & DEBUG HELPER FUNCTIONS
-- ============================================

function verifyMapState(context)
  g_logger.info("=== VERIFYING STATE: " .. context .. " ===")
  
  -- Check player
  local player = g_game.getLocalPlayer()
  if not player then
    g_logger.error("  FAIL: No local player")
    return false
  end
  g_logger.info("  Player exists: " .. (player:getName() or "Offline Player"))
  
  -- Check player position
  local playerPos = player:getPosition()
  if playerPos then
    g_logger.info("  Player position: " .. playerPos.x .. "," .. playerPos.y .. "," .. playerPos.z)
  else
    g_logger.error("  FAIL: Player has no position")
    return false
  end
  
  -- Check if player is on a tile
  local tile = g_map.getTile(playerPos)
  if tile then
    g_logger.info("  Tile exists at player position")
    local creatures = tile:getCreatures()
    if creatures then
      g_logger.info("  Creatures on tile: " .. #creatures)
      if #creatures == 0 then
        g_logger.warning("  WARNING: Tile has no creatures")
      end
    end
  else
    g_logger.error("  FAIL: No tile at player position!")
    return false
  end
  
  -- Check tiles around player
  local tileCount = 0
  for dx = -5, 5 do
    for dy = -5, 5 do
      local checkPos = {x=playerPos.x+dx, y=playerPos.y+dy, z=playerPos.z}
      if g_map.getTile(checkPos) then
        tileCount = tileCount + 1
      end
    end
  end
  g_logger.info("  Tiles in 11x11 area: " .. tileCount .. "/121")
  
  -- Check camera
  if modules.game_interface then
    local mapPanel = modules.game_interface.getMapPanel()
    if mapPanel then
      local following = mapPanel:getFollowingCreature()
      if following then
        g_logger.info("  Camera following: " .. (following:getName() or "Offline Player"))
      else
        g_logger.warning("  WARNING: Camera not following")
      end
    else
      g_logger.warning("  WARNING: No map panel")
    end
  end
  
  g_logger.info("=== VERIFICATION COMPLETE ===")
  return true
end

function debugTileContents(pos, label)
  g_logger.info("=== TILE DEBUG: " .. label .. " ===")
  local tile = g_map.getTile(pos)
  if not tile then
    g_logger.info("  No tile at position")
    return
  end
  
  local ground = tile:getGround()
  if ground then
    g_logger.info("  Ground: ID " .. ground:getId())
  else
    g_logger.info("  No ground")
  end
  
  local items = tile:getItems()
  if items then
    g_logger.info("  Items: " .. #items)
  end
  
  local creatures = tile:getCreatures()
  if creatures then
    g_logger.info("  Creatures: " .. #creatures)
    for i, creature in ipairs(creatures) do
      g_logger.info("    " .. i .. ": " .. (creature:getName() or "Unknown"))
    end
  end
end
