require "/HLib/Classes/Other/Messenger.lua"

local self = {};

function init()
  self._parentEntityId = pane.containerEntityId();
  Messenger().SendMessageNoResponse(self._parentEntityId, "ServerRackIsOpen",true);
end
function uninit()
  Messenger().SendMessageNoResponse(self._parentEntityId, "ServerRackIsOpen",false);
end
