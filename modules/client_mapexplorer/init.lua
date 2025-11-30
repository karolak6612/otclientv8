-- MapExplorer Module Entry Point
-- Orchestrates initialization of all services and UI

MapExplorer = {}

-- Dependencies (Global)
local Config = _G.ExplorerConfig
local EventBus = _G.ExplorerEventBus
local Events = _G.ExplorerEvents
local ExplorerState = _G.ExplorerState

-- Services (Global)
local MapLoaderService = _G.MapLoaderService
local PlayerService = _G.PlayerService
local LightingService = _G.LightingService
local PersistenceService = _G.PersistenceService
local OutfitService = _G.OutfitService
local SpawnService = _G.SpawnService

-- UI (Global)
local MapExplorerUI = _G.MapExplorerUI

function MapExplorer.init()
  g_logger.info("MapExplorer: Initializing...")
  
  -- Initialize Services
  PersistenceService.init()
  MapLoaderService.init()
  PlayerService.init()
  LightingService.init()
  OutfitService.init()
  SpawnService.init()
  
  -- Initialize UI (if not already handled by otmod @onLoad)
  -- Note: MapExplorerUI.init() is usually called separately in otmod
  
  -- Connect to game start/end
  connect(g_game, { onGameStart = MapExplorer.onGameStart,
                    onGameEnd = MapExplorer.onGameEnd })
                    
  -- Hook global g_game.changeOutfit for offline mode
  if not g_game.originalChangeOutfit then
    g_game.originalChangeOutfit = g_game.changeOutfit
    g_game.changeOutfit = function(outfit)
      -- Always use offline logic in MapExplorer mode
      g_logger.info("MapExplorer: changeOutfit hook called")
      local player = g_game.getLocalPlayer()
      if player then
        OutfitService.applyOutfit(player, outfit)
      end
    end
  end
  
  -- Initialize Extended Rendering (7x7 chunks)
  local mapPanel = modules.game_interface.getMapPanel()
  if mapPanel then
    mapPanel:setDrawBuffer({width=Config.DRAW_BUFFER_SIZE, height=Config.DRAW_BUFFER_SIZE})
    
    -- Hook Zoom (Ctrl + Scroll)
    local originalOnMouseWheel = mapPanel.onMouseWheel
    mapPanel.onMouseWheel = function(widget, mousePos, direction)
      if g_keyboard.isCtrlPressed() then
        local speed = ExplorerState.getZoomSpeed()
        for i = 1, speed do
            if direction == MouseWheelUp then
              widget:zoomIn()
            else
              widget:zoomOut()
            end
        end
        return true
      else
        -- Mouse Scroll -> Change Floor (PageUp/Down behavior)
        -- Only if enabled in ExplorerState
        if ExplorerState.isScrollFloorChangeEnabled() then
          if direction == MouseWheelUp then
            PlayerService.floorDown() -- Inverted: Up -> Down (Z+1)
          else
            PlayerService.floorUp()   -- Inverted: Down -> Up (Z-1)
          end
          return true
        end
        -- If disabled, let default behavior happen (or return false)
        return false
      end
    end
    
    -- Hook Map Click (Ctrl + Click Teleport)
    local originalOnMouseRelease = mapPanel.onMouseRelease
    mapPanel.onMouseRelease = function(widget, mousePos, mouseButton)
        if mouseButton == MouseLeftButton then
            if g_keyboard.isCtrlPressed() then
                local tile = widget:getTile(mousePos)
                if tile then
                    local pos = tile:getPosition()
                    PlayerService.teleportTo(pos)
                    return true
                end

                local pos = widget:getPosition(mousePos)
                if pos then
                    PlayerService.teleportTo(pos)
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
             return true
        end
        if originalOnMousePress then
            return originalOnMousePress(widget, mousePos, mouseButton)
        end
        return false
    end
    
    -- Prevent drag interactions
    mapPanel.onDragMove = function() return true end
    mapPanel.onDragEnter = function() return true end
    mapPanel.onDragLeave = function() return true end
    mapPanel.onMouseMove = function() return true end
    mapPanel.onHoverChange = function() return true end
  end
  
  -- Load last used settings
  local globalSettings = PersistenceService.getGlobalSettings()
  local lastPath = globalSettings.lastMapPath or ''
  ExplorerState.setMapPath(lastPath)
  
  local lastVersion = globalSettings.clientVersion or 1098
  ExplorerState.setMapVersion(lastVersion)
end

function MapExplorer.terminate()
  g_logger.info("MapExplorer: Terminating...")
  
  disconnect(g_game, { onGameStart = MapExplorer.onGameStart,
                       onGameEnd = MapExplorer.onGameEnd })
                       
  -- Restore original changeOutfit
  if g_game.originalChangeOutfit then
    g_game.changeOutfit = g_game.originalChangeOutfit
    g_game.originalChangeOutfit = nil
  end
  
  -- Terminate Services
  SpawnService.terminate()
  OutfitService.terminate()
  LightingService.terminate()
  PlayerService.terminate()
  MapLoaderService.terminate()
  PersistenceService.terminate()
  
  _G.MapExplorer = nil
end

function MapExplorer.onGameStart()
  g_logger.info("MapExplorer: onGameStart")
  
  -- Hide EnterGame window
  if modules.client_entergame and modules.client_entergame.EnterGame then
    modules.client_entergame.EnterGame.hide()
  end
  
  -- Disable game_walking module
  if modules.game_walking then
    g_modules.ensureModuleLoaded('game_walking') 
    if modules.game_walking.loaded then
      modules.game_walking.terminate()
    end
  end

  -- Hook Minimap Click
  if modules.game_minimap and modules.game_minimap.minimapWidget then
    modules.game_minimap.minimapWidget.onMouseRelease = function(widget, mousePos, mouseButton)
      if mouseButton == MouseLeftButton and g_keyboard.isCtrlPressed() then
        local pos = widget:getTilePosition(mousePos)
        if pos then
          PlayerService.teleportTo(pos)
          return true
        end
      end
      return false
    end
  end
end

function MapExplorer.onGameEnd()
  g_logger.info("MapExplorer: onGameEnd")
  PersistenceService.saveMapState()
  ExplorerState.setMapLoaded(false)
  
  -- Re-enable game_walking module
  if modules.game_walking then
     modules.game_walking.init()
  end
end

-- Global Compatibility / Facade
-- These functions are called by UI or other modules expecting the old MapExplorer interface

function MapExplorer.show(version)
  if version then
      ExplorerState.setMapVersion(version)
  end
  if MapExplorerUI then
    MapExplorerUI.show()
  end
end

function MapExplorer.hide()
  if MapExplorerUI then
    MapExplorerUI.hide()
  end
end

-- Legacy mappings for OTUI callbacks (if any still use MapExplorer global)
MapExplorer.onTeleport = function()
    -- This should be handled by ToolsPanelController, but keeping for safety
    if MapExplorerUI and MapExplorerUI.explorerPanel then
      local x = tonumber(MapExplorerUI.explorerPanel:recursiveGetChildById('posX'):getText())
      local y = tonumber(MapExplorerUI.explorerPanel:recursiveGetChildById('posY'):getText())
      local z = tonumber(MapExplorerUI.explorerPanel:recursiveGetChildById('posZ'):getText())
      if x and y and z then
        PlayerService.teleportTo({x=x, y=y, z=z})
      end
    end
end

MapExplorer.toggleSpawnSimulator = function() 
    if _G.SpawnSimulatorUI then _G.SpawnSimulatorUI.toggle() end 
end

MapExplorer.onLoadMap = MapLoaderService.loadSelectedMap

MapExplorer.resetView = function()
  local mapPanel = modules.game_interface.getMapPanel()
  if mapPanel then
    mapPanel:setVisibleDimension({width = Config.DEFAULT_VISIBLE_WIDTH, height = Config.DEFAULT_VISIBLE_HEIGHT})
    mapPanel:setZoom(Config.DEFAULT_ZOOM_LEVEL)
    ExplorerState.setZoomSpeed(Config.DEFAULT_ZOOM_SPEED)
    
    local player = g_game.getLocalPlayer()
    if player then
        g_map.setCentralPosition(player:getPosition())
    end
  end
end

-- OTUI Callbacks (Delegate to State/Services)
MapExplorer.toggleNoClip = PlayerService.toggleNoClip
MapExplorer.onLightChange = function(value)
  g_logger.info("MapExplorer.onLightChange called with: " .. tostring(value))
  if LightingService then
    LightingService.setLightIntensity(value)
  else
    g_logger.error("MapExplorer.onLightChange: LightingService is nil!")
  end
end
MapExplorer.onColorChange = LightingService.setLightColor
MapExplorer.onSpeedChange = PlayerService.setSpeed
MapExplorer.onZoomSpeedChange = function(value) ExplorerState.setZoomSpeed(value) end

-- Reset Functions
MapExplorer.resetLight = function() 
  LightingService.setLightIntensity(Config.DEFAULT_LIGHT_INTENSITY) 
end
MapExplorer.resetSpeed = function() 
  PlayerService.setSpeed(Config.DEFAULT_PLAYER_SPEED) 
end
MapExplorer.resetZoom = function() 
  ExplorerState.setZoomSpeed(Config.DEFAULT_ZOOM_SPEED) 
  MapExplorer.resetView()
end

return MapExplorer
