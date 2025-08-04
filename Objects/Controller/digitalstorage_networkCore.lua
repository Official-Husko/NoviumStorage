require "/DigitalClasses/DigitalNetwork.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Scripts/AdditionalFunctions.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/DigitalClasses/ItemsDrivesStorage.lua"
require "/DigitalClasses/PatternsStorage.lua"
require "/HLib/Classes/Network/Transmission.lua"

local coreself = {};

StorageInteractions = {};

function SortAsc(t, a, b)
  if t[a].Priority ~= t[b].Priority then
    return t[a].Priority < t[b].Priority;
  elseif t[a].Count ~= t[b].Count then
    return t[a].Count < t[b].Count;
  elseif t[a].Index ~= t[b].Index then
    return t[a].Index > t[b].Index;
  else
    return t[a].Entity < t[b].Entity;
  end
end

function SortDesc(t, a, b)
  if t[a].Priority ~= t[b].Priority then
    return t[a].Priority > t[b].Priority;
  elseif t[a].Count ~= t[b].Count then
    return t[a].Count > t[b].Count;
  elseif t[a].Index ~= t[b].Index then
    return t[a].Index < t[b].Index;
  else
    return t[a].Entity < t[b].Entity;
  end
end

local function GetMutexKey(entity,index)
  local mutexKey = nil;
  while true do
    mutexKey = world.callScriptedEntity(entity,"GetMutex",index);
    --mutexKey = transm:CallScriptedEntity("GetMutex",index);
    if mutexKey == nil then
      coroutine.yield();
    else
      return mutexKey;
    end
  end
end

function StorageInteractions.AddItem(item)
  local itemToPush = ItemWrapper.CopyItem(item);
  -- local tmpitem = ItemWrapper.CopyItem(item);
  local storagesForItem = coreself._networkStorages:GetStoragesForItem(itemToPush);
  for _, storageData in spairs(storagesForItem, SortDesc) do
    local mutexKey = GetMutexKey(storageData.Entity,storageData.Index);
    if mutexKey ~= false then
      local result = world.callScriptedEntity(storageData.Entity,"PushItem",storageData.Index,mutexKey,itemToPush);
      if ItemWrapper.GetItemCount(itemToPush) ~= ItemWrapper.GetItemCount(result) then
        world.callScriptedEntity(storageData.Entity,"SaveChanges",storageData.Index,mutexKey);
        -- ItemWrapper.SetItemCount(tmpitem,ItemWrapper.GetItemCount(itemToPush) - ItemWrapper.GetItemCount(result));
        -- coreself._networkStorages:AddItemToDrive(storageData.Entity, storageData.Index, tmpitem);
      else
        world.callScriptedEntity(storageData.Entity,"CancelChanges",storageData.Index,mutexKey);
      end
      world.callScriptedEntity(storageData.Entity,"FreeMutex",storageData.Index,mutexKey);
      itemToPush = result;
      if ItemWrapper.GetItemCount(itemToPush) == 0 then
        break;
      end
    end
    if self._limiter:Check() then
      coroutine.yield();
    end
  end
  local tmpitem = ItemWrapper.CopyItem(item);
  ItemWrapper.ModifyItemCount(tmpitem,-ItemWrapper.GetItemCount(itemToPush));
  local result = coreself._allItems:Add(tmpitem);
  UpdateBroadcastToListeners(tmpitem,result);
  return itemToPush;
end

function StorageInteractions.RemoveItem(item)
  local itemToPull = ItemWrapper.CopyItem(item);

  local storagesWithItem = coreself._networkStorages:GetStoragesContainingItem(itemToPull);
  for _, storageData in spairs(storagesWithItem, SortAsc) do
    local mutexKey = GetMutexKey(storageData.Entity,storageData.Index);
    if mutexKey ~= false then
      local result = world.callScriptedEntity(storageData.Entity,"PullItem",storageData.Index,mutexKey,itemToPull);
      if ItemWrapper.GetItemCount(result) ~= 0 then
        world.callScriptedEntity(storageData.Entity,"SaveChanges",storageData.Index,mutexKey);
        -- ItemWrapper.SetItemCount(tmpitem,ItemWrapper.GetItemCount(result));
        -- coreself._networkStorages:RemoveItemFromDrive(storageData.Entity, storageData.Index, tmpitem);
      else
        world.callScriptedEntity(storageData.Entity,"CancelChanges",storageData.Index,mutexKey);
      end
      world.callScriptedEntity(storageData.Entity,"FreeMutex",storageData.Index,mutexKey);
      ItemWrapper.ModifyItemCount(itemToPull,-ItemWrapper.GetItemCount(result));
      if ItemWrapper.GetItemCount(itemToPull) == 0 then
        break;
      end
    end
    if self._limiter:Check() then
      coroutine.yield();
    end
  end
  local tmpitem = ItemWrapper.CopyItem(item);             --NOTE this needs to be reworked
  ItemWrapper.ModifyItemCount(tmpitem,-ItemWrapper.GetItemCount(itemToPull));
  local _,result = coreself._allItems:Remove(tmpitem);
  ItemWrapper.SetItemCount(tmpitem,-ItemWrapper.GetItemCount(tmpitem)); --Make item count negative to broadcast
  UpdateBroadcastToListeners(tmpitem,result);
  ItemWrapper.SetItemCount(tmpitem,-ItemWrapper.GetItemCount(tmpitem)); --Make item count positive to return
  return tmpitem;
end
function StorageInteractions.GetItemList()
  return coreself._allItems;
end

function StorageInteractions.GetPatternListIndexed ()
  return coreself._patterns:GetPatternsIndexed();
end
function StorageInteractions.GetPatternListFlattened ()
  return coreself._patterns:GetPatternsFlattened();
end
function DeviceInNetwork(id)
  return coreself._network:DeviceInNetwork(id);
end





function ManagePatterns(patternstorage, patterns)
  if patterns then
    coreself._patterns:AddPatternProvider(patternstorage,patterns);
  else
    coreself._patterns:RemovePatternProvider(patternstorage);
  end
end
function UpdatePatterns(patternstorage, changes)
  local added  = changes.Added;
  for i=1,#added do
    coreself._patterns:AddPatternToProvider(patternstorage,added[i]);
  end
  local remove = changes.Removed;
  for i=1,#remove do
    coreself._patterns:RemovePatternFromProvider(patternstorage,remove[i]);
  end
end



function AddNetworkStorage(storage,index,drivedata)
  coreself._networkStorages:AddDrive(storage,index,drivedata);
  local items = drivedata.Items:GetFlattened();
  for i=1,#items do
    local result = coreself._allItems:Add(items[i]);
    UpdateBroadcastToListeners(items[i],result);
  end
end

function RemoveNetworkStorage(storage,index)
  if not coreself._networkStorages:DriveIsConnected(storage,index) then
    return;
  end
  local driveItems = coreself._networkStorages:GetItemsFromDrive(storage,index):GetFlattened();
  coreself._networkStorages:RemoveDrive(storage,index);
  for i=1,#driveItems do
    local workItem = ItemWrapper.CopyItem(driveItems[i]);
    local _,result = coreself._allItems:Remove(workItem);
    ItemWrapper.SetItemCount(workItem,-ItemWrapper.GetItemCount(workItem));
    UpdateBroadcastToListeners(workItem,result);
  end
end

local function UpdateNetwork()
  coreself._network:RefreshNetwork();
end

function die()
  for id,objectData in pairs(coreself._network:AllDevices()) do
    if id ~= self._entityId then
      if world.entityExists(id) then
        world.callScriptedEntity(id, "DigitalNetworkRemoveController",self._entityId);
      end
    end
  end
end

function NetworkShutdown()
  for id,objectData in pairs(coreself._network:AllDevices()) do
    if id ~= self._entityId then
      world.callScriptedEntity(id, "DigitalNetworkFailsafeShutdown");
    end
  end
  DigitalNetworkFailsafeShutdownDevice();
  DigitalNetworkFailsafeShutdown();
end

local function CheckNetworkRefresh()
  if coreself._networkRefreshCount < 5 then

    if (os.clock() - coreself._lastNetworkLoad) > 3 then
      coreself._networkRefreshCount = coreself._networkRefreshCount + 6;
      coreself._coreTasks:AddTask(Task(coroutine.create(UpdateNetwork),"UpdateNetwork"));
      coreself._lastNetworkLoad = os.clock();
      script.setUpdateDelta(1);
    end
  else
    CheckNetworkRefresh = function () end;
  end
end

--local _oldUpdate = update;
function update()
  self._limiter:Restart();
  self._controllerTasks:Restart();
  CheckNetworkRefresh();
  if self._singleController then
    if self._controllerTasks:HasTasks() then
      animator.setAnimationState("digitalstorage_controllerState", "working");
    else
      animator.setAnimationState("digitalstorage_controllerState", "idle");
      script.setUpdateDelta(60);
      return;
    end
  end
  coreself._coreTasks:Launch();
  if self._limiter:Check() then
    return;
  end
  --_oldUpdate();
  clientUpdate();
  if not self._controllerTasks:LaunchedAnyTask() and not self._controllerTasks:HasTasks() then
    animator.setAnimationState("digitalstorage_controllerState", "idle");
    script.setUpdateDelta(60);
  else
    script.setUpdateDelta(1);
  end
end

function init()
  coreself = {};
  coreself._allItems = ItemsTable(true);

  coreself._networkRefreshCount = 0;
  self._limiter = ClockLimiter();
  self._entityId = entity.id();
  self._singleController = true;
  self._controllerTasks = TaskManager(self._limiter,function() animator.setAnimationState("digitalstorage_controllerState", "failure"); NetworkShutdown(); end);
  coreself._patterns = PatternsStorage();

  clientInit();

  animator.setAnimationState("digitalstorage_controllerState", "working");
  coreself._network = DigitalNetwork();
  self._controllerTasks:AddTaskOperator("CoreTasks", "Table");
  coreself._coreTasks = self._controllerTasks:GetTaskOperator("CoreTasks");

  coreself._networkStorages = ItemsDrivesStorage();

  local forcedDelay = os.clock();
  local tmpUpdate = update;
  script.setUpdateDelta(20);
  update = function ()
    if (os.clock() - forcedDelay) < 3 then
      return;
    end
    update = tmpUpdate;
    coreself._lastNetworkLoad = os.clock();
    coreself._coreTasks:AddTask(Task(coroutine.create(UpdateNetwork),"UpdateNetwork"));
    onNodeConnectionChange = function ()
      coreself._coreTasks:AddTask(Task(coroutine.create(UpdateNetwork),"UpdateNetwork"));
      script.setUpdateDelta(1);
    end
  end
end
