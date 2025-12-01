
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

local function TaskCraftUpgradeItem(transmission, recipe, amount, upgradeItem)
  local craftResult = ItemWrapper.CopyItem(recipe.Output)
  local craftAmount = ItemWrapper.GetItemCount(craftResult)
  local allRemoved = true
  local removed = {}
  for i=1,#recipe.Inputs do
    local item = recipe.Inputs[i]
    local neededCount = ItemWrapper.GetItemCount(item) * amount
    ItemWrapper.SetItemCount(item, neededCount)
    if IsCurrency(item.ItemDescriptor) then
      removed[#removed+1] = item
    else
      local removeResult = StorageInteractions.RemoveItem(item, false);
      removed[#removed+1] = ItemWrapper.CopyItem(removeResult)
      local removedCount = ItemWrapper.GetItemCount(removeResult);
      if removedCount ~= neededCount then
        allRemoved = false
        break
      end
    end
  end
  local result = {}
  local addResult = nil
  if allRemoved then
    ItemWrapper.SetItemCount(craftResult, craftAmount * amount)
    addResult = StorageInteractions.AddItem(craftResult)
    if upgradeItem then
      local removeResult = StorageInteractions.RemoveItem(upgradeItem)
      if ItemWrapper.GetItemCount(removeResult) == 0 then
        StorageInteractions.RemoveItem(craftResult)
        allRemoved = false
      end
    end
  end
  if not allRemoved then
    for i=1, #removed do
      local item = removed[i]
      result[#result+1] = StorageInteractions.AddItem(item)
    end
  else
    result[1] = addResult
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


function TaskGetCraftableList(transmission)
  while not self._craftablesInit do
    coroutine.yield()
  end
  local result = StorageInteractions.GetCraftableList();
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

function GetCraftableList(transmission)
  LaunchCoreInteractionCall(TaskGetCraftableList,transmission);
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
function CraftUpgradeItem(transmission, recipe, amount, upgradeItem)
  LaunchCoreInteractionCall(TaskCraftUpgradeItem,transmission, copy(recipe), amount, upgradeItem and ItemWrapper.CopyItem(upgradeItem));
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
