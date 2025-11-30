SpawnSimulatorController = {}

-- Dependencies (Global)
local EventBus = _G.ExplorerEventBus
local Events = _G.ExplorerEvents
local ExplorerState = _G.ExplorerState
local Config = _G.ExplorerConfig
local FileBrowserUtils = _G.FileBrowserUtils
local SpawnService = _G.SpawnService

local spawnPanel = nil
local monsterList = nil
local startButton = nil
local stopButton = nil

function SpawnSimulatorController.init()
  g_logger.info("SpawnSimulatorController: init()")
  
  -- Don't create panel on init - wait for user to toggle it
  EventBus.on(Events.SPAWN_LIST_CHANGE, SpawnSimulatorController.onSpawnListChange)
  EventBus.on(Events.SPAWN_SIMULATION_START, SpawnSimulatorController.onSimulationStart)
  EventBus.on(Events.SPAWN_SIMULATION_STOP, SpawnSimulatorController.onSimulationStop)
end

function SpawnSimulatorController.terminate()
  EventBus.off(Events.SPAWN_LIST_CHANGE, SpawnSimulatorController.onSpawnListChange)
  EventBus.off(Events.SPAWN_SIMULATION_START, SpawnSimulatorController.onSimulationStart)
  EventBus.off(Events.SPAWN_SIMULATION_STOP, SpawnSimulatorController.onSimulationStop)
  
  if spawnPanel then
    spawnPanel:destroy()
    spawnPanel = nil
  end
end

function SpawnSimulatorController.toggle()
  if not spawnPanel then
    SpawnSimulatorController.show()
  elseif spawnPanel:isVisible() then
    spawnPanel:close()
  else
    spawnPanel:open()
  end
end

function SpawnSimulatorController.show()
  g_logger.info("SpawnSimulatorController: show() - Creating dockable panel")
  
  local gameInterface = modules.game_interface
  
  if not spawnPanel then
    -- Find first available left panel slot (Explorer Tools should be in slot 1)
    local targetPanel = gameInterface.getLeftPanel(2)
    if not targetPanel then
      -- Create second left panel if it doesn't exist
      gameInterface.addLeftPanel()
      targetPanel = gameInterface.getLeftPanel(2)
    end
    
    g_logger.info("SpawnSimulatorController: Loading UI from OTUI file")
    -- Load MiniWindow into panel
    spawnPanel = g_ui.loadUI('/modules/client_mapexplorer/ui/views/spawn_simulator_dockable', targetPanel)
    
    if not spawnPanel then
      g_logger.error("SpawnSimulatorController: Failed to load UI!")
      return
    end
    
    g_logger.info("SpawnSimulatorController: UI loaded, getting child widgets")
    -- Get widget references (use recursiveGetChildById for nested widgets)
    monsterList = spawnPanel:recursiveGetChildById('monsterList')
    startButton = spawnPanel:recursiveGetChildById('startButton')
    stopButton = spawnPanel:recursiveGetChildById('stopButton')
    
    -- Setup button callbacks
    if startButton then
      startButton.onClick = function() SpawnService.startSimulation() end
      g_logger.info("SpawnSimulatorController: Start button callback set")
    end
    
    if stopButton then
      stopButton.onClick = function() SpawnService.stopSimulation() end
      g_logger.info("SpawnSimulatorController: Stop button callback set")
    end
    
    -- Setup and open the panel
    g_logger.info("SpawnSimulatorController: Calling setup()")
    spawnPanel:setup()
    
    g_logger.info("SpawnSimulatorController: Calling open()")
    spawnPanel:open()
    
    g_logger.info("SpawnSimulatorController: Panel should now be visible")
  else
    -- Panel already exists, just show it
    g_logger.info("SpawnSimulatorController: Panel already exists, opening it")
    spawnPanel:open()
  end
end

function SpawnSimulatorController.onSpawnListChange(monsters, points)
  if not monsterList then return end
  monsterList:destroyChildren()
  
  for _, name in ipairs(monsters) do
    local label = g_ui.createWidget('MonsterListLabel', monsterList)
    label:setText(name)
    
    if SpawnService.getMonsterOutfit(name) then
      label:setColor('green')
    else
      label:setColor('red')
    end
    
    label.onDoubleClick = function()
      local currentOutfit = SpawnService.getMonsterOutfit(name)
      if not currentOutfit then
        -- Default to player's outfit or a basic one if none set
        local player = g_game.getLocalPlayer()
        if player then
           currentOutfit = player:getOutfit()
        else
           currentOutfit = {type=128, head=0, body=0, legs=0, feet=0, addons=0}
        end
      end
      
      -- Open outfit window with callback
      _G.OutfitService.openWindowWithCallback(currentOutfit, function(newOutfit)
         SpawnService.setMonsterOutfit(name, newOutfit)
         -- Refresh list to show green status
         SpawnSimulatorController.onSpawnListChange(monsters, points)
      end)
    end
  end
end

function SpawnSimulatorController.onLoadSpawns()
  local root = modules.game_interface.getRootPanel()
  local picker = g_ui.createWidget('SpawnFilePicker', root)
  local fileList = picker:getChildById('fileList')
  
  -- List .xml files in current map directory or root
  local currentPath = ExplorerState.getMapPath()
  local dir = "/"
  if currentPath and currentPath ~= "" then
     dir = FileBrowserUtils.getParentPath(currentPath)
  end
  
  local files = g_resources.listDirectoryFiles(dir, false, false)
  
  for _, file in ipairs(files) do
    if file:ends("-spawn.xml") then
      local widget = g_ui.createWidget('FileBrowserItem', fileList)
      widget:setText(file)
      widget.onDoubleClick = function() 
        SpawnService.loadSpawns(dir .. file)
        picker:destroy()
      end
    end
  end
end

function SpawnSimulatorController.onStartSimulation()
  SpawnService.startSimulation()
end

function SpawnSimulatorController.onStopSimulation()
  SpawnService.stopSimulation()
end

function SpawnSimulatorController.onSimulationStart()
  if startButton then startButton:setEnabled(false) end
  if stopButton then stopButton:setEnabled(true) end
end

function SpawnSimulatorController.onSimulationStop()
  if startButton then startButton:setEnabled(true) end
  if stopButton then stopButton:setEnabled(false) end
end

function SpawnSimulatorController.onClose()
  -- Called when user closes panel via close button
  g_logger.info("SpawnSimulatorController: Panel closed by user")
end

return SpawnSimulatorController
