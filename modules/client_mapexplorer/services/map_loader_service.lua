--- MapLoaderService
-- Handles map loading, version detection, and asset management.
-- @module MapLoaderService
_G.MapLoaderService = {}
local MapLoaderService = _G.MapLoaderService

-- Dependencies (Global)
local Config = _G.ExplorerConfig
local ExplorerState = _G.ExplorerState
local EventBus = _G.ExplorerEventBus
local Events = _G.ExplorerEvents

function MapLoaderService.init()
  g_logger.info("MapLoaderService: init() called")
end

function MapLoaderService.terminate()
  MapLoaderService.stopFileWatcher()
end

function MapLoaderService.setSelectedMap(path)
  ExplorerState.setBrowserPath(path)
  
  -- Auto-detect version from path (handle both / and \ for Windows)
  local versionMatch = path:match("[/\\]things[/\\](%d+)[/\\]")
  if not versionMatch then
     -- Try standard forward slash just in case
     versionMatch = path:match("/things/(%d+)/")
  end

  if versionMatch then
    local version = tonumber(versionMatch)
    g_logger.info("MapLoaderService: Auto-detected version " .. version .. " from path: " .. path)
    ExplorerState.setMapVersion(version)
    ExplorerState.setMapVersion(version)
    -- g_settings.set(Config.SETTINGS_KEYS.CLIENT_VERSION, version) -- Removed: Handled by PersistenceService
    
    -- Emit status update via UI (or EventBus if UI listens)
    if _G.MapExplorerUI then
        _G.MapExplorerUI.setStatus("Detected client version: " .. version)
    end
  else
    g_logger.info("MapLoaderService: Could not detect version from path: " .. path .. ". Keeping current version: " .. ExplorerState.getMapVersion())
  end
end

function MapLoaderService.loadSelectedMap()
  local selectedMapPath = ExplorerState.getBrowserPath()
  if selectedMapPath == "" then
    if _G.MapExplorerUI then _G.MapExplorerUI.setStatus("No map selected") end
    return
  end
  
  if _G.MapExplorerUI then _G.MapExplorerUI.setStatus("Loading map...") end
  
  MapLoaderService.stopFileWatcher()
  
  -- Schedule load to allow UI to update
  scheduleEvent(function()
    -- Load dependencies
    g_modules.ensureModuleLoaded('game_things')
    g_modules.ensureModuleLoaded('game_interface')
    g_modules.ensureModuleLoaded('game_outfit')
    
    if g_game.isOnline() then
      g_logger.info("MapLoaderService: Forcing logout for map reload")
      g_game.forceLogout()
      -- g_game.processGameEnd() -- Invalid function, handled by forceLogout
    end
    
    -- NOW update the map path to the new one (after logout/save of old map)
    -- Use relative path for portability (so hash is consistent across machines)
    local relativePath = _G.FileBrowserUtils.getRelativePath(selectedMapPath)
    ExplorerState.setMapPath(relativePath)
    
    local selectedVersion = ExplorerState.getMapVersion()
    local currentVersion = g_game.getClientVersion()
    
    -- Clear stale 'things' settings to prevent things.lua from using old paths
    g_settings.setNode('things', {})

    -- Temporarily disconnect features callback to prevent premature things.load()
    if modules.game_features then
        disconnect(g_game, { onClientVersionChange = modules.game_features.updateFeatures })
    end

    -- Set version (this would normally trigger features.updateFeatures -> things.load)
    g_game.setClientVersion(selectedVersion)
    g_game.setProtocolVersion(g_game.getClientProtocolVersion(selectedVersion))

    -- Manually update features (without triggering things.load if we can avoid it, or just let it happen now that settings are clear)
    if modules.game_features then
        modules.game_features.updateFeatures(selectedVersion)
        -- Reconnect callback
        connect(g_game, { onClientVersionChange = modules.game_features.updateFeatures })
    end

    -- Load dependencies
    g_modules.ensureModuleLoaded('game_things')
    
    -- Re-set version in case game_things reset it (it does on failure)
    g_game.setClientVersion(selectedVersion)
    g_game.setProtocolVersion(g_game.getClientProtocolVersion(selectedVersion))
    
    -- Only reload assets if version changed or things are not loaded
    if selectedVersion ~= currentVersion or not g_things.isDatLoaded() then
        g_logger.info("MapLoaderService: Loading assets for version " .. selectedVersion)
        
        -- Load Assets
        local dataDir = string.format(Config.DATA_DIR_TEMPLATE, selectedVersion)
        if not g_things.loadDat(dataDir .. '/Tibia') then
          if _G.MapExplorerUI then _G.MapExplorerUI.setStatus("Failed to load DAT file") end
          return
        end
        g_things.loadOtb(dataDir .. '/items.otb')
        if not g_things.isOtbLoaded() then
          if _G.MapExplorerUI then _G.MapExplorerUI.setStatus("Failed to load OTB file") end
          return
        end
        if not g_sprites.loadSpr(dataDir .. '/Tibia') then
          if _G.MapExplorerUI then _G.MapExplorerUI.setStatus("Failed to load SPR file") end
          return
        end
    else
        g_logger.info("MapLoaderService: Version match (" .. selectedVersion .. "), skipping asset reload")
    end
    
    -- Load map
    local mapPath = selectedMapPath
    if not g_resources.fileExists(mapPath) then
      if _G.MapExplorerUI then _G.MapExplorerUI.setStatus("Map file not found: " .. mapPath) end
      return
    end
    
    g_logger.info("Loading map: " .. mapPath)
    
    -- Clear existing map
    g_map.clean()
    
    -- Load OTBM
    local status, err = pcall(function()
      g_map.loadOtbm(mapPath)
    end)
    
    if not status then
      g_logger.error("Failed to load map: " .. tostring(err))
      if _G.MapExplorerUI then _G.MapExplorerUI.setStatus("Failed to load map: " .. tostring(err)) end
      MapLoaderService.startFileWatcher()
      return
    end
    
    if _G.MapExplorerUI then _G.MapExplorerUI.setStatus("Map loaded!") end
    ExplorerState.setMapLoaded(true)
    
    -- Emit MAP_LOADED event
    EventBus.emit(Events.MAP_LOADED, mapPath)
    
    -- Set initial position (center of map or saved pos)
    local player = g_game.getLocalPlayer()
    if not player then
      player = LocalPlayer.create()
      player:setOfflineMode(true)
      player:setName(Config.DEFAULT_PLAYER_NAME)
      g_game.setLocalPlayer(player)
    end
    
    -- Reset light to default before loading state
    ExplorerState.setLightIntensity(Config.DEFAULT_LIGHT_INTENSITY)
    
    -- Try to load state (PersistenceService will handle this later, but keeping logic here for now or delegating)
    -- For now, we'll assume PersistenceService isn't ready and do it inline or call a placeholder
    local stateLoaded = false
    if _G.PersistenceService then
        stateLoaded = _G.PersistenceService.loadMapState()
    elseif _G.MapExplorerGame and _G.MapExplorerGame.loadMapState then
        stateLoaded = _G.MapExplorerGame.loadMapState()
    end

    if not stateLoaded then
      -- Try to find a valid position if no state loaded
      local pos = nil -- MapExplorerGame.findSpawnPosition() -- TODO: Extract this too
      if not pos then
         -- Fallback to center if no valid tile found
         local mapSize = g_map.getSize()
         pos = {x = math.floor(mapSize.width / 2), y = math.floor(mapSize.height / 2), z = Config.DEFAULT_FLOOR}
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
    local light = ExplorerState.getLight()
    g_map.setLight(light)
    
    -- Start game interface
    g_game.processGameStart()
    
    -- Force minimap generation
    if g_minimap then
      g_minimap.clean()
      g_minimap.generateFromMap()
    end
    
    MapLoaderService.startFileWatcher()
  end, 100)
end

function MapLoaderService.refreshMap()
  local path = ExplorerState.getBrowserPath()
  if not path or path == "" then return end
  
  if not g_resources.fileExists(path) then
      g_logger.error("MapLoaderService: Map file not found for refresh: " .. path)
      return
  end

  g_logger.info("MapLoaderService: Refreshing map data from " .. path)

  -- Save player position
  local player = g_game.getLocalPlayer()
  local pos = nil
  if player then
      pos = player:getPosition()
  end

  -- Clean map
  g_map.clean()

  -- Load OTBM
  local status, err = pcall(function()
      g_map.loadOtbm(path)
  end)

  if not status then
      g_logger.error("MapLoaderService: Failed to refresh map: " .. tostring(err))
      if _G.MapExplorerUI then _G.MapExplorerUI.setStatus("Refresh failed: " .. tostring(err)) end
      return
  end

  -- Restore player
  if player and pos then
      player:setPosition(pos)
      g_map.addThing(player, pos, -1)
      g_map.setCentralPosition(pos)
  end
  
  -- Regenerate minimap
  if g_minimap then
      g_minimap.clean()
      g_minimap.generateFromMap()
  end
  
  if _G.MapExplorerUI then _G.MapExplorerUI.setStatus("Map refreshed!") end
end

-- File Watcher
local fileWatcherEvent = nil
local lastModificationTime = ""

function MapLoaderService.startFileWatcher()
  MapLoaderService.stopFileWatcher()
  
  local path = ExplorerState.getBrowserPath()
  if not path or path == "" then return end
  
  -- Initial check
  lastModificationTime = g_resources.getFileModificationTime(path)
  
  fileWatcherEvent = cycleEvent(function()
    local newTime = g_resources.getFileModificationTime(path)
    if newTime ~= "0" and newTime ~= lastModificationTime then
      g_logger.info("MapLoaderService: File changed, reloading...")
      lastModificationTime = newTime
      MapLoaderService.refreshMap()
    end
  end, 1000)
end

function MapLoaderService.stopFileWatcher()
  if fileWatcherEvent then
    removeEvent(fileWatcherEvent)
    fileWatcherEvent = nil
  end
end

return MapLoaderService
