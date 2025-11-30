-- Centralized state management for MapExplorer
-- Single source of truth for all module state
-- Phase 2: Centralize State Management
-- Phase 3: Event Bus Integration

local Config = _G.ExplorerConfig
local EventBus = _G.ExplorerEventBus
local Events = _G.ExplorerEvents

if _G.ExplorerState then
  return _G.ExplorerState
end

_G.ExplorerState = {
  -- Private state (use getters/setters!)
  _map = {
    path = "",
    version = 1098,
    isLoaded = false,
    size = nil,  -- {width, height}
  },
  
  _player = {
    position = nil,  -- {x, y, z}
    outfit = nil,
    speed = Config.DEFAULT_PLAYER_SPEED,
    noClipEnabled = false,
  },
  
  _camera = {
    light = {
      intensity = Config.DEFAULT_LIGHT_INTENSITY,
      color = Config.DEFAULT_LIGHT_COLOR,
    },
    zoom = {
      level = Config.DEFAULT_ZOOM_LEVEL,
      speed = Config.DEFAULT_ZOOM_SPEED,
    },
  },
  
  _spawn = {
    monsters = {},      -- Array of monster names
    points = {},        -- Array of spawn point configs
    isSimulating = false,
    simulationEvent = nil,
    config = {},        -- Monster outfit mappings
  },
  
  _ui = {
    browserPath = "",
    browserVisible = false,
    toolsVisible = false,
    scrollFloorChange = true,
  },
}

local ExplorerState = _G.ExplorerState


-- ============================================
-- Map State
-- ============================================

function ExplorerState.getMapPath()
  return ExplorerState._map.path
end

function ExplorerState.setMapPath(path)
  assert(type(path) == "string", "Map path must be a string")
  ExplorerState._map.path = path
end

function ExplorerState.getMapVersion()
  return ExplorerState._map.version
end

function ExplorerState.setMapVersion(version)
  assert(type(version) == "number" and version > 0, "Invalid version number")
  ExplorerState._map.version = version
end

function ExplorerState.isMapLoaded()
  return ExplorerState._map.isLoaded
end

function ExplorerState.setMapLoaded(loaded)
  ExplorerState._map.isLoaded = loaded
  EventBus.emit(Events.MAP_LOAD_STATE_CHANGE, loaded)
end

function ExplorerState.getMapSize()
  return ExplorerState._map.size
end

function ExplorerState.setMapSize(width, height)
  ExplorerState._map.size = {width = width, height = height}
end

-- ============================================
-- Player State
-- ============================================

function ExplorerState.getPlayerPosition()
  return ExplorerState._player.position
end

function ExplorerState.setPlayerPosition(pos)
  ExplorerState._player.position = pos
  EventBus.emit(Events.PLAYER_POSITION_CHANGE, pos)
end

function ExplorerState.getPlayerOutfit()
  return ExplorerState._player.outfit
end

function ExplorerState.setPlayerOutfit(outfit)
  ExplorerState._player.outfit = outfit
  EventBus.emit(Events.PLAYER_OUTFIT_CHANGE, outfit)
end

function ExplorerState.getPlayerSpeed()
  return ExplorerState._player.speed
end

function ExplorerState.setPlayerSpeed(speed)
  ExplorerState._player.speed = speed
  EventBus.emit(Events.PLAYER_SPEED_CHANGE, speed)
end

function ExplorerState.isNoClipEnabled()
  return ExplorerState._player.noClipEnabled
end

function ExplorerState.setNoClipEnabled(enabled)
  ExplorerState._player.noClipEnabled = enabled
  EventBus.emit(Events.PLAYER_NOCLIP_CHANGE, enabled)
end

-- ============================================
-- Camera/Light State
-- ============================================

function ExplorerState.getLight()
  return ExplorerState._camera.light
end

function ExplorerState.getLightIntensity()
  return ExplorerState._camera.light.intensity
end

function ExplorerState.setLightIntensity(intensity)
  ExplorerState._camera.light.intensity = intensity
  EventBus.emit(Events.LIGHT_CHANGE, intensity, ExplorerState._camera.light.color)
end

function ExplorerState.getLightColor()
  return ExplorerState._camera.light.color
end

function ExplorerState.setLightColor(color)
  ExplorerState._camera.light.color = color
  EventBus.emit(Events.LIGHT_CHANGE, ExplorerState._camera.light.intensity, color)
end

function ExplorerState.getZoomLevel()
  return ExplorerState._camera.zoom.level
end

function ExplorerState.setZoomLevel(level)
  ExplorerState._camera.zoom.level = level
  EventBus.emit(Events.ZOOM_CHANGE, level)
end

function ExplorerState.getZoomSpeed()
  return ExplorerState._camera.zoom.speed
end

function ExplorerState.setZoomSpeed(speed)
  ExplorerState._camera.zoom.speed = speed
end

-- ============================================
-- Spawn State
-- ============================================

function ExplorerState.getMonsters()
  return ExplorerState._spawn.monsters
end

function ExplorerState.setMonsters(monsters)
  assert(type(monsters) == "table", "Monsters must be an array")
  ExplorerState._spawn.monsters = monsters
  EventBus.emit(Events.SPAWN_LIST_CHANGE, monsters, ExplorerState._spawn.points)
end

function ExplorerState.getSpawnPoints()
  return ExplorerState._spawn.points
end

function ExplorerState.setSpawnPoints(points)
  assert(type(points) == "table", "Spawn points must be an array")
  ExplorerState._spawn.points = points
  EventBus.emit(Events.SPAWN_LIST_CHANGE, ExplorerState._spawn.monsters, points)
end

function ExplorerState.isSpawnSimulating()
  return ExplorerState._spawn.isSimulating
end

function ExplorerState.setSpawnSimulating(simulating)
  ExplorerState._spawn.isSimulating = simulating
  if simulating then
    EventBus.emit(Events.SPAWN_SIMULATION_START)
  else
    EventBus.emit(Events.SPAWN_SIMULATION_STOP)
  end
end

function ExplorerState.getSimulationEvent()
  return ExplorerState._spawn.simulationEvent
end

function ExplorerState.setSimulationEvent(event)
  ExplorerState._spawn.simulationEvent = event
end

function ExplorerState.getSpawnConfig()
  return ExplorerState._spawn.config
end

function ExplorerState.setSpawnConfig(config)
  ExplorerState._spawn.config = config
end

-- ============================================
-- UI State
-- ============================================

function ExplorerState.getBrowserPath()
  return ExplorerState._ui.browserPath
end

function ExplorerState.setBrowserPath(path)
  ExplorerState._ui.browserPath = path
  EventBus.emit(Events.BROWSER_PATH_CHANGE, path)
end

function ExplorerState.isScrollFloorChangeEnabled()
  return ExplorerState._ui.scrollFloorChange
end

function ExplorerState.setScrollFloorChangeEnabled(enabled)
  ExplorerState._ui.scrollFloorChange = enabled
  -- No event needed for now, just state check
end

return ExplorerState
