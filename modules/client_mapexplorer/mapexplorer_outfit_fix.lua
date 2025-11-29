function MapExplorer.openOutfitWindow()
  g_logger.info("[OUTFIT DEBUG] openOutfitWindow called")
  local player = g_game.getLocalPlayer()
  if not player then 
    g_logger.error("[OUTFIT DEBUG] No player found")
    return 
  end
  
  -- BYPASS game_outfit module completely - it crashes in offline mode
  local currentOutfit = player:getOutfit()
  g_logger.info(string.format("[OUTFIT DEBUG] Current outfit type: %d", currentOutfit.type))
  
  local newTypeStr = displayTextInputBox('Change Outfit', 'Enter outfit type ID (128-200 recommended):', tostring(currentOutfit.type))
  if newTypeStr and newTypeStr ~= '' then
    local newType = tonumber(newTypeStr)
    if newType and newType >= 1 and newType <= 1000 then
      local newOutfit = {
        type = newType,
        head = currentOutfit.head or 0,
        body = currentOutfit.body or 0,
        legs = currentOutfit.legs or 0,
        feet = currentOutfit.feet or 0,
        addons = currentOutfit.addons or 0,
        mount = 0,
        wings = 0,
        aura = 0,
        shader = "outfit_default",
        healthBar = 0,
        manaBar = 0
      }
      g_logger.info(string.format("[OUTFIT DEBUG] Setting outfit type to: %d", newType))
      
      local status, err = pcall(function()
        player:setOutfit(newOutfit)
      end)
      
      if not status then
        g_logger.error("[OUTFIT DEBUG] Crash during setOutfit: " .. tostring(err))
        displayErrorBox("Outfit Error", "Failed to change outfit: " .. tostring(err))
      else
        g_logger.info("[OUTFIT DEBUG] Outfit changed successfully")
      end
    else
      displayErrorBox("Invalid Input", "Please enter a number between 1-1000")
    end
  end
end
