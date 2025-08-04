require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Scripts/tableEx.lua"


function SaveItem(_, _, item)
  storage.FilterCard = item;
end
function LoadItem(_, _)
  return storage.FilterCard;
end
function die()
  if storage.FilterCard and storage.FilterCard.ItemDescriptor then
    world.spawnItem(storage.FilterCard.ItemDescriptor, entity.position());
  end
end

function init()

  if storage == nil then
    storage = {};
  end
  Messenger().RegisterMessage("SaveItem", SaveItem);
  Messenger().RegisterMessage("LoadItem", LoadItem);
end
