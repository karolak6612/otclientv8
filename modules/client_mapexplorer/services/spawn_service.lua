--- SpawnService
-- Manages spawn simulation, XML parsing, and creature lifecycle.
-- @module SpawnService
_G.SpawnService = {}
local SpawnService = _G.SpawnService

-- Dependencies (Global)
local Config = _G.ExplorerConfig
local ExplorerState = _G.ExplorerState
local EventBus = _G.ExplorerEventBus
local Events = _G.ExplorerEvents

-- Constants
local SPAWN_CONFIG_FILE = Config.SPAWN_CONFIG_FILE
local SIMULATION_INTERVAL = Config.SIMULATION_TICK_MS

function SpawnService.init()
  g_logger.info("SpawnService: init() called")
  SpawnService.loadGlobalConfig()
end

function SpawnService.terminate()
  SpawnService.stopSimulation()
  ExplorerState.setMonsters({})
  ExplorerState.setSpawnPoints({})
end

-- Config Management
function SpawnService.loadGlobalConfig()
  local f = io.open(SPAWN_CONFIG_FILE, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local status, result = pcall(function() 
      return json.decode(content) 
    end)
    if status then
      -- Normalize keys to lowercase
      local config = {}
      for k, v in pairs(result) do
        config[k:lower()] = v
      end
      ExplorerState.setSpawnConfig(config)
    else
      g_logger.error("SpawnService: Failed to parse config: " .. tostring(result))
      ExplorerState.setSpawnConfig({})
    end
  else
    -- File doesn't exist, use empty config
    ExplorerState.setSpawnConfig({})
  end
end

function SpawnService.saveGlobalConfig()
  local config = ExplorerState.getSpawnConfig()
  local status, err = pcall(function()
    local f = io.open(SPAWN_CONFIG_FILE, "w")
    if f then
      f:write(json.encode(config, 2))
      f:close()
    else
      error("Could not open file for writing")
    end
  end)
  if not status then
    g_logger.error("SpawnService: Failed to save config: " .. tostring(err))
  end
end

function SpawnService.getMonsterOutfit(name)
  local config = ExplorerState.getSpawnConfig()
  return config[name:lower()]
end

function SpawnService.setMonsterOutfit(name, outfit)
  local config = ExplorerState.getSpawnConfig()
  config[name:lower()] = outfit
  ExplorerState.setSpawnConfig(config)
  SpawnService.saveGlobalConfig()
end

-- XML Parsing
function SpawnService.loadSpawns(filename)
  g_logger.info("SpawnService: Loading spawns from " .. filename)
  
  if not g_resources.fileExists(filename) then
    g_logger.error("SpawnService: File not found: " .. filename)
    return false
  end

  local content = g_resources.readFileContents(filename)
  
  local monsters = {}
  local spawnPoints = {}
  local uniqueMonsters = {}
  
  -- Iterate through <spawn> blocks using split
  local parts = content:split("<spawn ")
  for i = 2, #parts do -- Skip first part (before first spawn)
    local block = parts[i]
    local header, body = block:match('^([^>]+)>(.*)')
    
    if header and body then
      local cx = tonumber(header:match('centerx="(%d+)"'))
      local cy = tonumber(header:match('centery="(%d+)"'))
      local cz = tonumber(header:match('centerz="(%d+)"'))
      local r = tonumber(header:match('radius="(%d+)"'))
      
      -- Find monsters in body (up to </spawn>)
      local spawnBody = body:match('(.-)</spawn>')
      if spawnBody then
        for mName, mX, mY in spawnBody:gmatch('<monster name="([^"]+)" x="(%-?%d+)" y="(%-?%d+)"') do
          local name = mName:lower()
          uniqueMonsters[name] = true
          
          table.insert(spawnPoints, {
            name = name,
            pos = {x = cx + tonumber(mX), y = cy + tonumber(mY), z = cz},
            radius = r,
            creatureUid = nil
          })
        end

        -- Find NPCs in body
        for mName, mX, mY in spawnBody:gmatch('<npc name="([^"]+)" x="(%-?%d+)" y="(%-?%d+)"') do
          local name = mName:lower()
          uniqueMonsters[name] = true
          
          table.insert(spawnPoints, {
            name = name,
            pos = {x = cx + tonumber(mX), y = cy + tonumber(mY), z = cz},
            radius = r,
            creatureUid = nil
          })
        end
      end
    end
  end
  
  -- Convert set to list
  for name, _ in pairs(uniqueMonsters) do
    table.insert(monsters, name)
  end
  table.sort(monsters)
  
  ExplorerState.setMonsters(monsters)
  ExplorerState.setSpawnPoints(spawnPoints)
  
  g_logger.info("SpawnService: Loaded " .. #spawnPoints .. " spawn points and " .. #monsters .. " unique monsters.")
  
  -- Emit event
  EventBus.emit(Events.SPAWN_LIST_CHANGE, monsters, spawnPoints)
  
  return true
end

-- Simulation
function SpawnService.startSimulation()
  if ExplorerState.isSpawnSimulating() then return end
  
  g_logger.info("SpawnService: Starting simulation")
  ExplorerState.setSpawnSimulating(true)
  SpawnService.spawnCreatures()
  
  local event = cycleEvent(SpawnService.updateMovement, SIMULATION_INTERVAL)
  ExplorerState.setSimulationEvent(event)
  
  EventBus.emit(Events.SPAWN_SIMULATION_START)
end

function SpawnService.stopSimulation()
  if not ExplorerState.isSpawnSimulating() then return end
  
  g_logger.info("SpawnService: Stopping simulation")
  ExplorerState.setSpawnSimulating(false)
  
  local event = ExplorerState.getSimulationEvent()
  if event then
    removeEvent(event)
    ExplorerState.setSimulationEvent(nil)
  end
  SpawnService.removeCreatures()
  
  EventBus.emit(Events.SPAWN_SIMULATION_STOP)
end

function SpawnService.spawnCreatures()
  local spawnPoints = ExplorerState.getSpawnPoints()
  for _, point in ipairs(spawnPoints) do
    local outfit = SpawnService.getMonsterOutfit(point.name)
    if outfit then
      local creature = Creature.create()
      creature:setName(point.name)
      creature:setOutfit(outfit)
      
      -- Set initial position
      local pos = {x = point.pos.x, y = point.pos.y, z = point.pos.z}
      creature:setPosition(pos)
      creature:setDirection(Directions.South)
      
      -- Add to map
      local tile = g_map.getTile(pos)
      if not tile then
        tile = g_map.createTile(pos)
      end
      tile:addThing(creature, -1)
      
      point.creatureUid = creature:getId()
      point.creature = creature -- Keep reference (Note: point is inside the state table, so this modifies state)
    end
  end
  -- We modified the points in place, so no need to setSpawnPoints again unless we want to trigger events (Phase 3)
end

function SpawnService.removeCreatures()
  local spawnPoints = ExplorerState.getSpawnPoints()
  for _, point in ipairs(spawnPoints) do
    if point.creature then
      local tile = point.creature:getTile()
      if tile then
        tile:removeThing(point.creature)
      end
      point.creature = nil
      point.creatureUid = nil
    end
  end
end

function SpawnService.updateMovement()
  if not ExplorerState.isSpawnSimulating() then return end
  
  local spawnPoints = ExplorerState.getSpawnPoints()
  for _, point in ipairs(spawnPoints) do
    local creature = point.creature
    if creature then
      -- Random chance to move
      if math.random() < Config.CREATURE_MOVE_CHANCE then
        local currentPos = creature:getPosition()
        local dirs = {
          {x=0, y=-1}, -- North
          {x=1, y=0},  -- East
          {x=0, y=1},  -- South
          {x=-1, y=0}  -- West
        }
        
        local dir = dirs[math.random(1, 4)]
        local newPos = {x = currentPos.x + dir.x, y = currentPos.y + dir.y, z = currentPos.z}
        
        -- Check radius constraint
        local dx = math.abs(newPos.x - point.pos.x)
        local dy = math.abs(newPos.y - point.pos.y)
        
        if dx <= point.radius and dy <= point.radius then
          -- Check walkability (simplified)
          local tile = g_map.getTile(newPos)
          if tile and tile:isWalkable() then
            -- Simulate walk
            local oldTile = creature:getTile()
            if oldTile then
              oldTile:removeThing(creature)
            end
            
            if not tile then
               tile = g_map.createTile(newPos)
            end
            tile:addThing(creature, -1)
            
            -- Update direction and walk
            if dir.x == 1 then creature:setDirection(Directions.East)
            elseif dir.x == -1 then creature:setDirection(Directions.West)
            elseif dir.y == 1 then creature:setDirection(Directions.South)
            elseif dir.y == -1 then creature:setDirection(Directions.North)
            end
            
            creature:setPosition(newPos)
            creature:walk(currentPos, newPos)
          end
        end
      end
    end
  end
end

return SpawnService
