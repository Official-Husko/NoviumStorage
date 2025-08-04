require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Scripts/AdditionalFunctions.lua"
require "/HLib/Classes/Other/Messenger.lua"




function init()
  if type(storage) ~= "table" then
    storage = {};
  end
  Messenger().RegisterMessage("Load", function(_, _) return storage.Data; end);
  Messenger().RegisterMessage("Save", function(_, _, data) storage.Data = data; end);
  script.setUpdateDelta(0);
end
