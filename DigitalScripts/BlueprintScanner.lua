function LearnBlueprintForItem(item)

  local  tmpItem  = copy(item.ItemDescriptor);
  tmpItem.count = 1;
  if player.hasItem(tmpItem)  then
    return false;
  end
  player.giveItem(tmpItem);
  if player.hasItem(tmpItem) then
    player.consumeItem(tmpItem);
  end
  player.cleanupItems();
  return true;
end
