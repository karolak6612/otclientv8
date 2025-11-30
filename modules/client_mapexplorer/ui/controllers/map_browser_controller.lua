MapBrowserController = {}

-- Dependencies (Global)
local EventBus = _G.ExplorerEventBus
local Events = _G.ExplorerEvents
local ExplorerState = _G.ExplorerState
local FileBrowserWidget = _G.FileBrowserWidget

local MapLoaderService = _G.MapLoaderService

local window = nil
local loadButton = nil

function MapBrowserController.init()
  -- Note: We assume OTUI is loaded or will be loaded. 
  -- If moved to ui/views, we might need to load it explicitly if not in .otmod
  window = g_ui.displayUI('/modules/client_mapexplorer/ui/views/mapexplorer') 
  window:hide()
  
  local fileList = window:getChildById('fileList')
  loadButton = window:getChildById('loadButton')
  
  if loadButton then
    loadButton.onClick = MapLoaderService.loadSelectedMap
  end
  
  if fileList then
    FileBrowserWidget.init(fileList)
    FileBrowserWidget.setOnFileSelect(MapBrowserController.onFileSelected)
  end
  
  EventBus.on(Events.MAP_LOADED, MapBrowserController.onMapLoaded)
  EventBus.on(Events.MAP_CLEARED, MapBrowserController.onMapCleared)
end

function MapBrowserController.terminate()
  EventBus.off(Events.MAP_LOADED, MapBrowserController.onMapLoaded)
  EventBus.off(Events.MAP_CLEARED, MapBrowserController.onMapCleared)
  
  if window then
    window:destroy()
    window = nil
  end
end

function MapBrowserController.onFileSelected(file)
  if file:ends(".otbm") then
    if loadButton then loadButton:setEnabled(true) end
    ExplorerState.setBrowserPath(file)
    MapLoaderService.setSelectedMap(file) 
    g_logger.info("MapBrowserController: Selected " .. file)
  else
    if loadButton then loadButton:setEnabled(false) end
  end
end

function MapBrowserController.onMapLoaded()
  if window then window:hide() end
end

function MapBrowserController.onMapCleared()
  if window then
    window:show()
    window:raise()
    window:focus()
  end
end

function MapBrowserController.toggle()
  if window:isVisible() then
    window:hide()
  else
    window:show()
    window:raise()
    window:focus()
  end
end

function MapBrowserController.show()
  if window then 
    window:show() 
    window:raise()
    window:focus()
  end
end

function MapBrowserController.hide()
  if window then window:hide() end
end

return MapBrowserController
