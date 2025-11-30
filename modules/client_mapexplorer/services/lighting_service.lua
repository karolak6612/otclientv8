--- LightingService
-- Controls ambient lighting intensity and color filters.
-- @module LightingService
_G.LightingService = {}
local LightingService = _G.LightingService

-- Dependencies (Global)
local Config = _G.ExplorerConfig
local ExplorerState = _G.ExplorerState
local EventBus = _G.ExplorerEventBus
local Events = _G.ExplorerEvents

function LightingService.init()
  g_logger.info("LightingService: init() called")
  EventBus.on(Events.LIGHT_CHANGE, LightingService.onLightChangeEvent)
end

function LightingService.terminate()
  EventBus.off(Events.LIGHT_CHANGE, LightingService.onLightChangeEvent)
end

function LightingService.setLightIntensity(value)
  g_logger.info("LightingService: setLightIntensity called with: " .. tostring(value))
  ExplorerState.setLightIntensity(value)
end

function LightingService.setLightColor(value)
  g_logger.info("LightingService: setLightColor called with: " .. tostring(value))
  ExplorerState.setLightColor(value)
end

function LightingService.onLightChangeEvent(intensity, color)
  g_logger.info("LightingService: onLightChangeEvent - Intensity: " .. tostring(intensity) .. ", Color: " .. tostring(color))
  if g_map then
      g_map.setLight({intensity=intensity, color=color})
  else
      g_logger.error("LightingService: g_map is nil!")
  end
end

return LightingService
