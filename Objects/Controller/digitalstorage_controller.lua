
require "/HLib/Classes/Network/Network.lua"
require "/HLib/Classes/Network/Transmission.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Scripts/AdditionalFunctions.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"
require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/DigitalClasses/ItemsDrivesStorage.lua"

local clientself = {};

function UpdateBroadcastToListeners(item,reason)
  local itemcpy = ItemWrapper.CopyItem(item);
  for entityId,_ in pairs(clientself._listeners) do
    if world.entityExists(entityId) and DeviceInNetwork(entityId) then
      world.callScriptedEntity(entityId, "DigitalNetworkItemsListener",itemcpy,reason);
    else
      clientself._listeners[entityId] = false;
    end
  end
end

local function TaskPushItem(transmission,item)
  local result = StorageInteractions.AddItem(item);
  local countToBroadcast = ItemWrapper.GetItemCount(item) - ItemWrapper.GetItemCount(result);
  if countToBroadcast ~= 0 then
    local itemToBroadcast = ItemWrapper.CopyItem(item);
    ItemWrapper.SetItemCount(itemToBroadcast,countToBroadcast);
    -- clientself._clientTasks:AddTask(Task(UpdateBroadcastToListeners,{itemToBroadcast}));
  end
  transmission:SendResponse(result);
end

local function TaskPullItem(transmission,item)
  local result = StorageInteractions.RemoveItem(item);
  local countToBroadcast = ItemWrapper.GetItemCount(result);
  if countToBroadcast ~= 0 then
    local itemToBroadcast = ItemWrapper.CopyItem(item);
    ItemWrapper.SetItemCount(itemToBroadcast,-countToBroadcast);
    -- clientself._clientTasks:AddTask(Task(UpdateBroadcastToListeners,{itemToBroadcast}));
  end
  transmission:SendResponse(result);
end




local function TaskGetPatternsIndexed(transmission)
  local result = StorageInteractions.GetPatternListIndexed();
  transmission:SendResponse(result);
end

local function TaskGetPatternsFlattened(transmission)
  local result = StorageInteractions.GetPatternListFlattened();
  transmission:SendResponse(result);
end


function LaunchCoreInteractionCall(func,transmission,...)
  local cor = coroutine.create(func);
  if not self._limiter:Check() then
    local s, r = coroutine.resume(cor,transmission,...);
    if not s then
      LogError(ToStringAnything("LaunchCoreInteractionCall failed", func,transmission,...,r));
      NetworkShutdown();
    end

    if coroutine.status(cor) == "dead" then
      return r;
    else
      clientself._clientTasks:AddTask(Task(cor));
      script.setUpdateDelta(1);
    end
  else
    clientself._clientTasks:AddTask(Task(cor,transmission,...));
    script.setUpdateDelta(1);
  end
end

function GetNetworkItems(transmission)
  local result = StorageInteractions.GetItemList();
  return result;
end

function GetPatternsFlattened(transmission)
  LaunchCoreInteractionCall(TaskGetPatternsFlattened,transmission);
end

function GetPatternsIndexed(transmission)
  LaunchCoreInteractionCall(TaskGetPatternsIndexed,transmission);
end


function PushItem(transmission,item)
  LaunchCoreInteractionCall(TaskPushItem,transmission, ItemWrapper.CopyItem(item));
end
function PullItem(transmission,item)
  LaunchCoreInteractionCall(TaskPullItem,transmission, ItemWrapper.CopyItem(item));
end

function RegisterItemsListener(entityId)
  clientself._listeners[entityId] = true;
end

function UnregisterItemsListener(entityId)
  clientself._listeners[entityId] = nil;
end


--#region  Uninteresting stuff

function clientUpdate()
  clientself._clientTasks:Launch();
end

function clientInit()
  self._controllerTasks:AddTaskOperator("ClientTasks", "Table");
  clientself._clientTasks = self._controllerTasks:GetTaskOperator("ClientTasks");
  clientself._listeners = {};
end

--#endregion
