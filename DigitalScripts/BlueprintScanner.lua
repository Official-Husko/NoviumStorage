--[[
  BlueprintScanner.lua
  -------------------
  Utility function for learning a blueprint for a given item in Starbound.
  This function gives the player a single instance of the item, checks if it was added, and then consumes it to unlock the blueprint (if not already known).

  Starbound API cross-reference:
    - player.hasItem(): Checks if the player has the item (see player.md)
    - player.giveItem(): Gives the item to the player (see player.md)
    - player.consumeItem(): Consumes the item from the player's inventory (see player.md)
    - player.cleanupItems(): Cleans up temporary items (see player.md)
    - copy(): Utility to clone a table (see util.lua)
]]

function LearnBlueprintForItem(item)
  local tmpItem = copy(item.ItemDescriptor); -- Clone the item descriptor
  tmpItem.count = 1;                        -- Only need one for blueprint unlock
  if player.hasItem(tmpItem) then           -- If player already has it, blueprint is known
    return false;
  end
  player.giveItem(tmpItem);                 -- Give the item to the player
  if player.hasItem(tmpItem) then           -- If now present, consume it to unlock blueprint
    player.consumeItem(tmpItem);
  end
  player.cleanupItems();                    -- Clean up any temporary items
  return true;                              -- Blueprint learned
end
