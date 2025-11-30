SpawnSimulatorUI = {}

local window = nil
local monsterList = nil
local statusLabel = nil

function SpawnSimulatorUI.init()
  -- UI will be created on demand
end

function SpawnSimulatorUI.terminate()
  if window then
    window:destroy()
    window = nil
  end
end

function SpawnSimulatorUI.toggle()
  if window then
    SpawnSimulatorUI.close()
  else
    SpawnSimulatorUI.open()
  end
end

function SpawnSimulatorUI.open()
  if window then return end
  
  window = g_ui.displayUI('spawn_simulator')
  monsterList = window:getChildById('monsterList')
  statusLabel = window:getChildById('statusLabel')
  
  SpawnSimulatorUI.refreshList()
end

function SpawnSimulatorUI.close()
  if window then
    window:destroy()
    window = nil
    monsterList = nil
    statusLabel = nil
  end
end

function SpawnSimulatorUI.refreshList()
  if not window then return end
  
  monsterList:destroyChildren()
  
  local monsters = SpawnSimulator.monsters
  local mappedCount = 0
  
  for _, name in ipairs(monsters) do
    local widget = g_ui.createWidget('MonsterListLabel', monsterList)
    widget:setText(name)
    widget:setId(name)
    
    local outfit = SpawnSimulator.getMonsterOutfit(name)
    if outfit then
      widget:setColor('#00ff00') -- Green for mapped
      widget:setTooltip("Mapped")
      mappedCount = mappedCount + 1
    else
      widget:setColor('#ff0000') -- Red for missing
      widget:setTooltip("Missing Mapping - Click to Set")
    end
    
    widget.onClick = function()
      g_logger.info("Clicked monster: " .. name)
      SpawnSimulatorUI.openOutfitPicker(name)
    end
  end
  
  statusLabel:setText(string.format("Mapped: %d / %d", mappedCount, #monsters))
end

function SpawnSimulatorUI.openOutfitPicker(monsterName)
  local currentOutfit = SpawnSimulator.getMonsterOutfit(monsterName)
  if not currentOutfit then
    currentOutfit = {type = 1, head = 0, body = 0, legs = 0, feet = 0, addons = 0} -- Default
  end
  
  -- Open outfit window with callback
  MapExplorerOutfit.openWindowWithCallback(currentOutfit, function(outfit)
    SpawnSimulator.setMonsterOutfit(monsterName, outfit)
    SpawnSimulatorUI.refreshList()
  end)
end

function SpawnSimulatorUI.onLoadSpawns()
  local picker = g_ui.createWidget('SpawnFilePicker', modules.game_interface.getRootPanel())
  local fileList = picker:getChildById('fileList')
  
  local version = MapExplorerGame.getSelectedVersion()
  local path = "/data/things/" .. version .. "/"
  
  if not g_resources.directoryExists(path) then
    path = "/data/things/" -- Fallback
  end
  
  local files = g_resources.listDirectoryFiles(path, false, false)
  
  for _, file in ipairs(files) do
    if file:ends("-spawn.xml") then
      local widget = g_ui.createWidget('MonsterListLabel', fileList)
      widget:setText(file)
      widget.onDoubleClick = function()
        if SpawnSimulator.loadSpawns(path .. file) then
           SpawnSimulatorUI.refreshList()
           SpawnSimulator.stopSimulation()
           picker:destroy()
        end
      end
    end
  end
end

function SpawnSimulatorUI.onStartSimulation()
  SpawnSimulator.startSimulation()
end

function SpawnSimulatorUI.onStopSimulation()
  SpawnSimulator.stopSimulation()
end
