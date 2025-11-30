if _G.FileBrowserUtils then
  return _G.FileBrowserUtils
end

_G.FileBrowserUtils = {}

function _G.FileBrowserUtils.normalizePath(path)
  if not path:ends("/") then
    path = path .. "/"
  end
  return path
end

function _G.FileBrowserUtils.getParentPath(path)
  local parts = path:split("/")
  -- Remove last empty part if exists (due to trailing slash)
  if parts[#parts] == "" then table.remove(parts) end
  -- Remove current dir
  table.remove(parts)
  
  if #parts == 0 then return "/" end
  
  local newPath = table.concat(parts, "/")
  if not newPath:starts("/") then newPath = "/" .. newPath end
  if not newPath:ends("/") then newPath = newPath .. "/" end
  return newPath
end

function _G.FileBrowserUtils.getRelativePath(path)
  local workDir = g_resources.getWorkDir()
  -- Normalize slashes to match (Lua string patterns don't like backslashes much, use gsub)
  local normalizedPath = path:gsub("\\", "/")
  local normalizedWorkDir = workDir:gsub("\\", "/")
  
  -- Ensure workDir ends with slash for clean removal
  if not normalizedWorkDir:ends("/") then
    normalizedWorkDir = normalizedWorkDir .. "/"
  end
  
  -- Remove workDir from path if it starts with it
  -- We use plain string find to avoid pattern magic characters issues
  local startIdx, endIdx = normalizedPath:find(normalizedWorkDir, 1, true)
  
  if startIdx == 1 then
    local relative = normalizedPath:sub(endIdx + 1)
    -- Ensure no leading slash (though logic above should handle it)
    if relative:starts("/") then relative = relative:sub(2) end
    return relative
  end
  
  return path
end

function _G.FileBrowserUtils.sortFiles(files, currentPath)
  table.sort(files, function(a, b)
    local aIsDir = g_resources.directoryExists(currentPath .. a)
    local bIsDir = g_resources.directoryExists(currentPath .. b)
    if aIsDir and not bIsDir then return true end
    if not aIsDir and bIsDir then return false end
    return a < b
  end)
  return files
end

return _G.FileBrowserUtils
