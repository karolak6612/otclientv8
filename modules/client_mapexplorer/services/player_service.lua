--- PlayerService
-- Manages the local player entity, movement, teleportation, and modes.
-- @module PlayerService
_G.PlayerService = {}
local PlayerService = _G.PlayerService

-- Dependencies (Global)
local Config = _G.ExplorerConfig
local ExplorerState = _G.ExplorerState
local EventBus = _G.ExplorerEventBus
local Events = _G.ExplorerEvents

function PlayerService.init()
  g_logger.info("PlayerService: init() called")
  
  -- Ensure no-clip is disabled by default
  local player = g_game.getLocalPlayer()
  if player then
    player:setNoClipMode(false)
  end
  
  -- Bind keys
  g_keyboard.bindKeyPress('PageUp', PlayerService.floorUp)
  g_keyboard.bindKeyPress('PageDown', PlayerService.floorDown)

  -- Bind Movement Keys (Fix for East/West stutter)
  g_keyboard.bindKeyPress('Up', function() g_game.walk(North) end)
  g_keyboard.bindKeyPress('Right', function() g_game.walk(East) end)
  g_keyboard.bindKeyPress('Down', function() g_game.walk(South) end)
  g_keyboard.bindKeyPress('Left', function() g_game.walk(West) end)

  -- Bind Rotation Keys (Ctrl + Arrows)
  g_keyboard.bindKeyDown('Ctrl+Up', function() PlayerService.rotate(North) end)
  g_keyboard.bindKeyDown('Ctrl+Right', function() PlayerService.rotate(East) end)
  g_keyboard.bindKeyDown('Ctrl+Down', function() PlayerService.rotate(South) end)
  g_keyboard.bindKeyDown('Ctrl+Left', function() PlayerService.rotate(West) end)
  
  -- Subscribe to events
  EventBus.on(Events.PLAYER_SPEED_CHANGE, PlayerService.onSpeedChangeEvent)
  EventBus.on(Events.NOCLIP_CHANGE, PlayerService.onNoClipChangeEvent)
end

function PlayerService.terminate()
  g_keyboard.unbindKeyPress('PageUp', PlayerService.floorUp)
  g_keyboard.unbindKeyPress('PageDown', PlayerService.floorDown)

  g_keyboard.unbindKeyPress('Up', function() g_game.walk(North) end)
  g_keyboard.unbindKeyPress('Right', function() g_game.walk(East) end)
  g_keyboard.unbindKeyPress('Down', function() g_game.walk(South) end)
  g_keyboard.unbindKeyPress('Left', function() g_game.walk(West) end)

  g_keyboard.unbindKeyDown('Ctrl+Up', function() PlayerService.rotate(North) end)
  g_keyboard.unbindKeyDown('Ctrl+Right', function() PlayerService.rotate(East) end)
  g_keyboard.unbindKeyDown('Ctrl+Down', function() PlayerService.rotate(South) end)
  g_keyboard.unbindKeyDown('Ctrl+Left', function() PlayerService.rotate(West) end)
  
  EventBus.off(Events.PLAYER_SPEED_CHANGE, PlayerService.onSpeedChangeEvent)
  EventBus.off(Events.NOCLIP_CHANGE, PlayerService.onNoClipChangeEvent)
end

function PlayerService.teleportTo(pos)
  local player = g_game.getLocalPlayer()
  if not player then return end
  
  -- Remove from old tile
  local oldTile = g_map.getTile(player:getPosition())
  if oldTile then oldTile:removeThing(player) end
  
  player:setPosition(pos)
  ExplorerState.setPlayerPosition(pos)
  
  local newTile = g_map.getTile(pos)
  if newTile then 
    newTile:addThing(player, -1)
  end
  g_map.setCentralPosition(pos)
end

function PlayerService.floorUp()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition()
  pos.z = pos.z - 1
  if pos.z < Config.MIN_FLOOR then pos.z = Config.MIN_FLOOR end
  PlayerService.teleportTo(pos)
end

function PlayerService.floorDown()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition()
  pos.z = pos.z + 1
  if pos.z > Config.MAX_FLOOR then pos.z = Config.MAX_FLOOR end
  PlayerService.teleportTo(pos)
end

function PlayerService.rotate(dir)
  local player = g_game.getLocalPlayer()
  if player then
    player:setDirection(dir)
  end
end

function PlayerService.toggleNoClip(enabled)
  g_logger.info("PlayerService: toggleNoClip " .. tostring(enabled))
  local player = g_game.getLocalPlayer()
  if player then
    player:setNoClipMode(enabled)
    ExplorerState.setNoClipEnabled(enabled)
  end
end

function PlayerService.setSpeed(value)
  g_logger.info("PlayerService: Speed changed to: " .. tostring(value))
  local player = g_game.getLocalPlayer()
  if player then
    player:setSpeed(value)
    player:setBaseSpeed(value)
    ExplorerState.setPlayerSpeed(value)
  end
end

-- Event Handlers
function PlayerService.onSpeedChangeEvent(speed)
  local player = g_game.getLocalPlayer()
  if player then
    player:setSpeed(speed)
    player:setBaseSpeed(speed)
  end
end

function PlayerService.onNoClipChangeEvent(enabled)
  local player = g_game.getLocalPlayer()
  if player then
    player:setNoClipMode(enabled)
  end
end

return PlayerService
