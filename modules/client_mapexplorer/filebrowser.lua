FileBrowser = {}

local fileList = nil
local currentPath = "/"
local onFileSelectCallback = nil

function FileBrowser.init()
  -- UI is defined in mapexplorer.otui
end

function FileBrowser.terminate()
  fileList = nil
end

function FileBrowser.setPanel(panel)
  fileList = panel:getChildById('fileList')
  
  -- Initial load
  local lastPath = g_settings.getString('mapexplorer/lastPath', '/data/things/')
  if not g_resources.directoryExists(lastPath) then
    lastPath = '/'
  end
  FileBrowser.setPath(lastPath)
end

function FileBrowser.setPath(path)
  if not g_resources.directoryExists(path) then
    return
  end
  
  -- Normalize path
  if not path:ends("/") then
    path = path .. "/"
  end
  
  currentPath = path
  g_settings.set('mapexplorer/lastPath', currentPath)
  
  FileBrowser.refresh()
end

function FileBrowser.refresh()
  if not fileList then return end
  
  fileList:destroyChildren()
  
  -- Add ".." if not root
  if currentPath ~= "/" and currentPath ~= "" then
    local widget = g_ui.createWidget('FileBrowserItem', fileList)
    widget:setText("..")
    widget.isDir = true
    widget.fullPath = currentPath .. "/.." -- Simplified, logic needs to handle parent resolution
    widget:setId("parent_dir")
    widget.onDoubleClick = function() FileBrowser.goUp() end
  end
  
  local files = g_resources.listDirectoryFiles(currentPath, false, false)
  
  -- Sort: Directories first, then files
  table.sort(files, function(a, b)
    local aIsDir = g_resources.directoryExists(currentPath .. a)
    local bIsDir = g_resources.directoryExists(currentPath .. b)
    if aIsDir and not bIsDir then return true end
    if not aIsDir and bIsDir then return false end
    return a < b
  end)
  
  for _, file in ipairs(files) do
    local fullPath = currentPath .. file
    local isDir = g_resources.directoryExists(fullPath)
    local isOtbm = file:ends(".otbm")
    
    if isDir or isOtbm then
      local widget = g_ui.createWidget('FileBrowserItem', fileList)
      widget:setText(file)
      widget.fullPath = fullPath
      widget.isDir = isDir
      
      if isDir then
        widget:setText("[DIR] " .. file)
        widget.onDoubleClick = function() FileBrowser.setPath(fullPath) end
      else
        widget.onDoubleClick = function() 
          if onFileSelectCallback then
            onFileSelectCallback(fullPath)
          end
        end
      end
    end
  end
end

function FileBrowser.goUp()
  -- Simple string manipulation to go up
  local parts = currentPath:split("/")
  local newPath = "/"
  -- Remove last empty part if exists (due to trailing slash)
  if parts[#parts] == "" then table.remove(parts) end
  -- Remove current dir
  table.remove(parts)
  
  if #parts > 0 then
    newPath = table.concat(parts, "/")
    if not newPath:starts("/") then newPath = "/" .. newPath end
    if not newPath:ends("/") then newPath = newPath .. "/" end
  end
  
  FileBrowser.setPath(newPath)
end

function FileBrowser.setOnFileSelect(callback)
  onFileSelectCallback = callback
end
