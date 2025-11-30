SpawnSimulator = {}

-- Constants
local SPAWN_CONFIG_FILE = "/settings/spawn_config.json"
local SIMULATION_INTERVAL = 1000 -- Check movement every 1 second

-- State
SpawnSimulator.monsters = {} -- List of all monsters found in current spawn file
SpawnSimulator.spawnPoints = {} -- List of {name, pos, radius, creatureUid}
SpawnSimulator.globalConfig = {} -- Loaded from spawn_config.json
SpawnSimulator.isSimulating = false
SpawnSimulator.simulationEvent = nil

function SpawnSimulator.init()
  g_logger.info("SpawnSimulator: Initializing...")
  SpawnSimulator.loadGlobalConfig()
end

function SpawnSimulator.terminate()
  SpawnSimulator.stopSimulation()
  SpawnSimulator.monsters = {}
  SpawnSimulator.spawnPoints = {}
end

-- Config Management
function SpawnSimulator.loadGlobalConfig()
  if g_resources.fileExists(SPAWN_CONFIG_FILE) then
    local status, result = pcall(function() 
      return json.decode(g_resources.readFileContents(SPAWN_CONFIG_FILE)) 
    end)
    if status then
      -- Normalize keys to lowercase
      SpawnSimulator.globalConfig = {}
      for k, v in pairs(result) do
        SpawnSimulator.globalConfig[k:lower()] = v
      end
    else
      g_logger.error("SpawnSimulator: Failed to load config: " .. tostring(result))
      SpawnSimulator.globalConfig = {}
    end
  else
    SpawnSimulator.globalConfig = {}
  end
end

function SpawnSimulator.saveGlobalConfig()
  local status, err = pcall(function()
    g_resources.writeFileContents(SPAWN_CONFIG_FILE, json.encode(SpawnSimulator.globalConfig))
  end)
  if not status then
    g_logger.error("SpawnSimulator: Failed to save config: " .. tostring(err))
  end
end

function SpawnSimulator.getMonsterOutfit(name)
  return SpawnSimulator.globalConfig[name:lower()]
end

function SpawnSimulator.setMonsterOutfit(name, outfit)
  SpawnSimulator.globalConfig[name:lower()] = outfit
  SpawnSimulator.saveGlobalConfig()
end

-- XML Parsing
function SpawnSimulator.loadSpawns(filename)
  g_logger.info("SpawnSimulator: Loading spawns from " .. filename)
  
  if not g_resources.fileExists(filename) then
    g_logger.error("SpawnSimulator: File not found: " .. filename)
    return false
  end

  local content = g_resources.readFileContents(filename)
  local xml = nil
  
  -- Simple XML parser since we don't have a full DOM parser exposed easily
  -- We'll use regex patterns to extract spawn data
  -- <spawn centerx="2000" centery="1982" centerz="7" radius="1">
  -- <monster name="demon skeleton" x="0" y="0" z="7" spawntime="0" direction="2" />
  
  SpawnSimulator.monsters = {}
  SpawnSimulator.spawnPoints = {}
  
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
          
          table.insert(SpawnSimulator.spawnPoints, {
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
    table.insert(SpawnSimulator.monsters, name)
  end
  table.sort(SpawnSimulator.monsters)
  
  g_logger.info("SpawnSimulator: Loaded " .. #SpawnSimulator.spawnPoints .. " spawn points and " .. #SpawnSimulator.monsters .. " unique monsters.")
  return true
end

-- Simulation
function SpawnSimulator.startSimulation()
  if SpawnSimulator.isSimulating then return end
  
  g_logger.info("SpawnSimulator: Starting simulation")
  SpawnSimulator.isSimulating = true
  SpawnSimulator.spawnCreatures()
  SpawnSimulator.simulationEvent = cycleEvent(SpawnSimulator.updateMovement, SIMULATION_INTERVAL)
end

function SpawnSimulator.stopSimulation()
  if not SpawnSimulator.isSimulating then return end
  
  g_logger.info("SpawnSimulator: Stopping simulation")
  SpawnSimulator.isSimulating = false
  if SpawnSimulator.simulationEvent then
    removeEvent(SpawnSimulator.simulationEvent)
    SpawnSimulator.simulationEvent = nil
  end
  SpawnSimulator.removeCreatures()
end

function SpawnSimulator.spawnCreatures()
  for _, point in ipairs(SpawnSimulator.spawnPoints) do
    local outfit = SpawnSimulator.getMonsterOutfit(point.name)
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
      point.creature = creature -- Keep reference
    end
  end
end

function SpawnSimulator.removeCreatures()
  for _, point in ipairs(SpawnSimulator.spawnPoints) do
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

function SpawnSimulator.updateMovement()
  if not SpawnSimulator.isSimulating then return end
  
  for _, point in ipairs(SpawnSimulator.spawnPoints) do
    local creature = point.creature
    if creature then
      -- Random chance to move
      if math.random(1, 3) == 1 then
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
