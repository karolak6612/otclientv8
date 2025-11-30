MapExplorerOutfit = {}

function MapExplorerOutfit.openWindow()
  g_logger.info("MapExplorerOutfit: openWindow called")
  local player = g_game.getLocalPlayer()
  if not player then return end
  
  -- Prepare lists for outfit window
  local outfits = MapExplorerOutfit.getValidOutfits()
  local mounts = {{0, "None"}} -- TODO: Populate mounts if needed
  local wings = {{0, "None"}}
  local auras = {{0, "None"}}
  local healthBars = {{0, "None"}}
  local manaBars = {{0, "None"}}
  
  -- CRITICAL: Shader list must include "outfit_default"
  local shaders = {
    {0, "Default", "outfit_default"},
    {1, "None", "no_shader"}
  }
  
  -- Get current outfit
  local currentOutfit = player:getOutfit()
  MapExplorerOutfit.ensureOutfitDefaults(currentOutfit)
  
  -- Validate addon value
  local maxAddons = MapExplorerOutfit.getMaxAddonsForOutfit(currentOutfit.type)
  if currentOutfit.addons > maxAddons then
    currentOutfit.addons = maxAddons
  end
  
  -- Call outfit window
  local status, err = pcall(function()
    if modules.game_outfit then
      modules.game_outfit.create(currentOutfit, outfits, mounts, wings, auras, shaders, healthBars, manaBars)
    end
  end)
  
  if not status then
    displayErrorBox("Outfit Error", "Failed to open outfit window.")
  end
end

function MapExplorerOutfit.openWindowWithCallback(currentOutfit, callback)
  g_logger.info("MapExplorerOutfit: openWindowWithCallback called")
  
  -- Prepare lists for outfit window
  local outfits = MapExplorerOutfit.getValidOutfits()
  local mounts = {{0, "None"}}
  local wings = {{0, "None"}}
  local auras = {{0, "None"}}
  local healthBars = {{0, "None"}}
  local manaBars = {{0, "None"}}
  
  local shaders = {
    {0, "Default", "outfit_default"},
    {1, "None", "no_shader"}
  }
  
  MapExplorerOutfit.ensureOutfitDefaults(currentOutfit)
  
  local maxAddons = MapExplorerOutfit.getMaxAddonsForOutfit(currentOutfit.type)
  if currentOutfit.addons > maxAddons then
    currentOutfit.addons = maxAddons
  end
  
  local status, err = pcall(function()
    if modules.game_outfit then
      modules.game_outfit.create(currentOutfit, outfits, mounts, wings, auras, shaders, healthBars, manaBars, callback)
    end
  end)
  
  if not status then
    g_logger.error("Failed to open outfit window: " .. tostring(err))
  end
end

function MapExplorerOutfit.applyOutfit(player, outfit)
  MapExplorerOutfit.ensureOutfitDefaults(outfit)
  
  g_logger.info(string.format("Setting outfit: type=%d", outfit.type))
  
  -- Check validity
  if not MapExplorerOutfit.isValidOutfit(outfit.type) then
    g_logger.error("Invalid outfit type: " .. tostring(outfit.type))
    displayInfoBox("Outfit Error", "Invalid outfit type selected.")
    return
  end
  
  local status, err = pcall(function() 
    player:setOutfit(outfit)
  end)
  
  if not status then
    g_logger.error("Failed to set outfit: " .. tostring(err))
    displayInfoBox("Outfit Error", "Failed to change outfit.")
  end
end

function MapExplorerOutfit.ensureOutfitDefaults(outfit)
  outfit.type = outfit.type or 0
  outfit.head = outfit.head or 0
  outfit.body = outfit.body or 0
  outfit.legs = outfit.legs or 0
  outfit.feet = outfit.feet or 0
  outfit.addons = outfit.addons or 0
  outfit.mount = outfit.mount or 0
  outfit.wings = outfit.wings or 0
  outfit.aura = outfit.aura or 0
  outfit.shader = outfit.shader or "outfit_default"
  outfit.healthBar = outfit.healthBar or 0
  outfit.manaBar = outfit.manaBar or 0
end

function MapExplorerOutfit.getValidOutfits()
  local outfits = {}
  local consecutiveInvalid = 0
  
  -- Scan for valid outfits
  -- Limit to 2000 or until 10 consecutive failures
  for i = 1, 2000 do
    if MapExplorerOutfit.isValidOutfit(i) then
      table.insert(outfits, {i, "Outfit " .. i})
      consecutiveInvalid = 0
    else
      consecutiveInvalid = consecutiveInvalid + 1
    end
    
    if consecutiveInvalid >= 10 then
      break
    end
  end
  
  return outfits
end

function MapExplorerOutfit.isValidOutfit(typeId)
  local status, result = pcall(function()
    return g_things.getThingType(typeId, ThingCategoryCreature)
  end)
  
  if not status or not result then return false end
  
  -- Check if we got a valid thing type (not the null one)
  if result:getId() ~= typeId then return false end
  
  return true
end

function MapExplorerOutfit.getMaxAddonsForOutfit(typeId)
  -- Simplified: assume 3 addons (0, 1, 2, 3)
  return 3
end
