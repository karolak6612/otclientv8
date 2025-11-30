--- PersistenceService
-- Handles saving and restoring of application state (map position, settings).
-- @module PersistenceService
PersistenceService = {}

-- Dependencies (Global)
local Config = _G.ExplorerConfig
local ExplorerState = _G.ExplorerState

local STATE_FILE = Config.STATE_FILE or "explorer_state.json"

function PersistenceService.init()
  g_logger.info("PersistenceService: init() called")
  -- Start auto-save loop
  PersistenceService.autoSaveLoop()
end

function PersistenceService.terminate()
  -- Save on exit
  PersistenceService.saveMapState()
end

function PersistenceService.saveMapState()
  local selectedMapPath = ExplorerState.getMapPath()
  if not selectedMapPath or selectedMapPath == "" then return end
  local player = g_game.getLocalPlayer()
  if not player then return end
  
  -- Load existing state first to preserve other maps
  local allStates = PersistenceService.loadAllStates()
  
  local mapHash = g_crypt.md5Encode(selectedMapPath)
  
  allStates[mapHash] = {
    pos = {x = player:getPosition().x, y = player:getPosition().y, z = player:getPosition().z},
    outfit = player:getOutfit(), -- getOutfit returns table, safe to save
    speed = player:getSpeed(),
    light = ExplorerState.getLightIntensity(),
    color = ExplorerState.getLightColor(),
    zoomSpeed = ExplorerState.getZoomSpeed()
  }
  
  -- Save global settings
  allStates._global = {
    lastMapPath = selectedMapPath,
    clientVersion = ExplorerState.getMapVersion()
  }
  
  local status, err = pcall(function()
    local f = io.open(STATE_FILE, "w")
    if f then
      f:write(json.encode(allStates, 2))
      f:close()
    else
      g_logger.error("PersistenceService: Could not open state file for writing")
    end
  end)
  
  if not status then
    g_logger.error("PersistenceService: Failed to save state: " .. tostring(err))
  end
end

function PersistenceService.getGlobalSettings()
  local allStates = PersistenceService.loadAllStates()
  return allStates._global or {}
end

function PersistenceService.loadAllStates()
  local f = io.open(STATE_FILE, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local status, result = pcall(function() return json.decode(content) end)
    if status then return result end
  end
  return {}
end

function PersistenceService.loadMapState()
  local selectedMapPath = ExplorerState.getMapPath()
  if not selectedMapPath or selectedMapPath == "" then return false end
  
  local allStates = PersistenceService.loadAllStates()
  local mapHash = g_crypt.md5Encode(selectedMapPath)
  local state = allStates[mapHash]
  
  if state and state.pos then
    local player = g_game.getLocalPlayer()
    if player then
      -- Reconstruct position object
      local pos = {x = state.pos.x, y = state.pos.y, z = state.pos.z}
      player:setPosition(pos)
      ExplorerState.setPlayerPosition(pos)
      
      if state.outfit then 
          player:setOutfit(state.outfit) 
          ExplorerState.setPlayerOutfit(state.outfit)
      end
      if state.speed then 
         player:setSpeed(state.speed) 
         ExplorerState.setPlayerSpeed(state.speed)
      end
      
      if state.zoomSpeed then 
         ExplorerState.setZoomSpeed(state.zoomSpeed)
      end
      
      if state.light then
         ExplorerState.setLightIntensity(state.light)
      end
      
      if state.color then
         ExplorerState.setLightColor(state.color)
      end
      
      -- Force update map light
      g_map.setLight(ExplorerState.getLight())
      return true
    end
  end
  return false
end

function PersistenceService.autoSaveLoop()
  PersistenceService.saveMapState()
  scheduleEvent(PersistenceService.autoSaveLoop, Config.AUTO_SAVE_INTERVAL_MS)
end

return PersistenceService
