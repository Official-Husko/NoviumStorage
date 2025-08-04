require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Classes/Network/Connections.lua"
require "/HLib/Scripts/tableEx.lua"
require "/DigitalScripts/DigitalStoragePeripheral.lua"
local conns = nil;


function DigitalNetworkFailsafeShutdown()
  DigitalNetworkFailsafeShutdownDevice();
end

function DigitalNetworkPreUpdateControllers(count, mode)
end

function DigitalNetworkPostUpdateControllers(count, mode)
  if count == 0 then
    animator.setAnimationState("digitalstorage_routerState", "off");
  else
    animator.setAnimationState("digitalstorage_routerState", "on");
  end
end


function DigitalStorageNetworkRouter()
  return GetConnections(storage.TwoWay);
end

function onNodeConnectionChange()
  for i, v in pairs(DigitalNetworkGetAllControllers()) do
    world.callScriptedEntity(v, "onNodeConnectionChange");
  end
end
function init()
  if not storage.TwoWay then
    storage.TwoWay = true;
  end
end
