require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Classes/Item/Item.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"
require "/HLib/Classes/Network/Transmission.lua"
require "/DigitalScripts/NetworkPart.lua"
local _listener = nil;
local _deviceFailsafeShutdown = false;


local function DigitalNetworkGetSingleController()
  if DigitalNetworkHasOneController() then
    return DigitalNetworkGetFirstController();
  else
    error("Either not a single controller or more than one is connected");
  end
end


function DigitalNetworkAddNetworkStorage(id, data)
  world.callScriptedEntity(DigitalNetworkGetSingleController(),"AddNetworkStorage",entity.id(),id,data);
end

function DigitalNetworkRemoveNetworkStorage(id)
  world.callScriptedEntity(DigitalNetworkGetSingleController(),"RemoveNetworkStorage",entity.id(),id);
end

function DigitalNetworkFailsafeShutdownDevice()
  _deviceFailsafeShutdown = true;
end

function DigitalNetworkShutdownEntireNetwork()
  local cntrls = DigitalNetworkGetAllControllers();
  for i=1,#cntrls do
    world.callScriptedEntity(cntrls[i],"NetworkShutdown");
  end
end

function DigitalNetworkDeviceOperative()
  return not _deviceFailsafeShutdown;
end

function DigitalNetworkDeviceActive()
  return DigitalNetworkHasOneController() and not _deviceFailsafeShutdown;
end

local function CallControllerAndWaitForResponse(name,...)
  local transm = OpenTransmission(DigitalNetworkGetSingleController());
  transm:CallScriptedEntity(name,...);
  transm:WaitForResponse();
  transm:Close();
  return transm:GetResponse(true);
end

function DigitalNetworkObtainNetworkItemList()
  return world.callScriptedEntity(DigitalNetworkGetSingleController(), "GetNetworkItems");
end



function DigitalNetworkObtainNetworkPatternListIndexed()
  return CallControllerAndWaitForResponse("GetPatternsIndexed");
end

local function DigitalNetworkItemInteractions(call,item)
  local itemproc = CallControllerAndWaitForResponse(call,item);
  return itemproc;
end
function DigitalNetworkPushItem(item)
  return DigitalNetworkItemInteractions("PushItem", item);
end

function DigitalNetworkPullItem(item)
  return DigitalNetworkItemInteractions("PullItem", item);
end

function DigitalNetworkObtainNetworkItemListFiltered(transmission, controllerId, filter)
  local netItems = DigitalNetworkObtainNetworkItemList(transmission, controllerId);
  local filteredItems = {};
  for _, item in pairs(netItems) do
    if filter:ItemMatch(item) then
      filteredItems[#filteredItems + 1] = item;
    end
  end
  return filteredItems;
end

function DigitalNetworkUnregisterListener()
  if _listener then
    world.callScriptedEntity(_listener, "UnregisterItemsListener",entity.id());
    _listener = nil;
  end
end

function DigitalNetworkRegisterListener()
  if _listener then
    DigitalNetworkUnregisterListener();
  end
  _listener = DigitalNetworkGetSingleController();
  world.callScriptedEntity(_listener, "RegisterItemsListener",entity.id());
end

function DigitalNetworkItemsListener(items)
  error("Function 'DigitalNetworkItemsListener(items)' has to be overriden.");
end
