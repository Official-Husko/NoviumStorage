
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
  clientself._networkSaveId = clientself._networkSaveId + 1;
  clientself._networkChangeLog[#clientself._networkChangeLog + 1] = {SaveId = clientself._networkSaveId; Item = itemcpy};
  if #clientself._networkChangeLog > clientself._networkChangeLogMax then
    table.remove(clientself._networkChangeLog, 1);
    clientself._networkChangeLogMin = clientself._networkChangeLogMin + 1;
  end
  for entityId,_ in pairs(clientself._listeners) do
    if world.entityExists(entityId) and DeviceInNetwork(entityId) then
      world.callScriptedEntity(entityId, "DigitalNetworkItemsListener",itemcpy,reason, clientself._networkSaveId);
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

local function TaskGetNetworkState(transmission, sinceSaveId)
  local response = {SaveId = clientself._networkSaveId};
  local deltaAvailable = sinceSaveId and sinceSaveId >= clientself._networkChangeLogMin and sinceSaveId <= clientself._networkSaveId;
  if not deltaAvailable then
    response.Items = StorageInteractions.GetItemList():GetIndexed();
    response.Patterns = StorageInteractions.GetPatternListIndexed();
  else
    local changes = {};
    for i = 1, #clientself._networkChangeLog do
      local entry = clientself._networkChangeLog[i];
      if entry.SaveId > sinceSaveId then
        changes[#changes + 1] = {SaveId = entry.SaveId; Item = ItemWrapper.CopyItem(entry.Item)};
      end
    end
    response.Changes = changes;
  end
  transmission:SendResponse(response);
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

function GetNetworkState(transmission, sinceSaveId)
  LaunchCoreInteractionCall(TaskGetNetworkState, transmission, sinceSaveId);
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
  clientself._networkSaveId = 0;
  clientself._networkChangeLog = {};
  clientself._networkChangeLogMin = 0;
  clientself._networkChangeLogMax = 256;
end

--#endregion
