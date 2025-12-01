require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Classes/Network/Transmission.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Data/BitMap.lua"
require "/HLib/Classes/Item/Item.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"
require "/HLib/Classes/Item/ItemsTable.lua"

require "/DigitalScripts/DigitalStoragePeripheral.lua"

local function EnsureListener()
  if not self._listenerRegistered and DigitalNetworkHasOneController() then
    DigitalNetworkRegisterListener();
    self._listenerRegistered = true;
  end
end

local function ApplyPendingDeltas()
  if not self._cachedItems or not self._pendingDeltas then
    return;
  end
  for i=1,#self._pendingDeltas do
    self._cachedItems:Add(ItemWrapper.CopyItem(self._pendingDeltas[i].Item));
    self._cacheSaveId = (self._pendingDeltas[i].SaveId or (self._cacheSaveId + 1));
  end
  self._pendingDeltas = {};
end

local function RebuildLocalCaches()
  if not self._cachedItems then
    return;
  end
  self._cachedIndexed = self._cachedItems:GetIndexed();
  local flat = self._cachedItems:GetFlattened();
  table.sort(flat, function(a,b) return (a.DisplayNameLower or string.lower(a.DisplayName)) < (b.DisplayNameLower or string.lower(b.DisplayName)); end);
  self._cachedFlat = flat;
end

local function QueueLocalCacheRebuild()
  if self._cacheRebuildScheduled then
    return;
  end
  self._cacheRebuildScheduled = true;
  self._tasksManager:GetTaskOperator("ItemsNetwork"):AddTask(Task(coroutine.create(function ()
    RebuildLocalCaches();
    self._cacheRebuildScheduled = false;
  end)));
end

local function BuildCache()
  local state = DigitalNetworkObtainNetworkState(self._cacheSaveId);
  if not state then
    return;
  end
  if state.Pending then
    self._tasksManager:GetTaskOperator("ItemsNetwork"):AddTask(Task(coroutine.create(BuildCache)), nil, "BuildCacheRetry");
    script.setUpdateDelta(1);
    return;
  end

  if not self._cachedItems then
    self._cachedItems = ItemsTable(true);
  end

  if state.Items then
    self._cachedItems = ItemsTable(true);
    for _, itemsTable in pairs(state.Items) do
      for i = 1, #itemsTable do
        self._cachedItems:Add(ItemWrapper.CopyItem(itemsTable[i]));
      end
    end
    self._cachedPatterns = state.Patterns or {};
    self._cachedIndexed = state.Items;
    self._cachedFlat = state.FlatItems;
  end

  if state.Changes then
    for i = 1, #state.Changes do
      self._cachedItems:Add(ItemWrapper.CopyItem(state.Changes[i].Item));
    end
  end

  self._cacheSaveId = state.SaveId or self._cacheSaveId;
  self._cacheBuilt = true;
  ApplyPendingDeltas();
  if not self._cachedFlat or not self._cachedIndexed then
    QueueLocalCacheRebuild();
  end
end

local function GetNetworkData()
  local data = {};
  EnsureListener();
  if not self._cacheBuilt then
    BuildCache();
  end

  if DigitalNetworkHasOneController() then
    data.Items = self._cachedIndexed or (self._cachedItems and self._cachedItems:GetIndexed()) or {};
    data.FlatItems = self._cachedFlat;
    data.Patterns = self._cachedPatterns;
    data.SaveId = self._cacheSaveId;
    data.Cached = true;
  end
  self._responses = {};
  self._responses[1] = {Task = "LoadNetworkData"; Data = data};
end

function update(dt)
  EnsureListener();
  if not DigitalNetworkHasOneController() then
    script.setUpdateDelta(0);
    return;
  end
  self._limiter:Restart();
  self._tasksManager:Restart();
  self._tasksManager:LaunchTaskOperator("ItemsNetwork");
  if not self._tasksManager:HasTasks() then
    script.setUpdateDelta(0);
  end
end

function SpawnItem(item)
  local spawnpos;
  if self._interactingPlayer then
    spawnpos = world.entityPosition(self._interactingPlayer);
    spawnpos[2] = spawnpos[2] + 1;
  else
    spawnpos = self._itemSpawnPosition;
  end
  while ItemWrapper.GetItemCount(item) ~= 0 do
    world.spawnItem(item.ItemDescriptor, spawnpos);
    if ItemWrapper.GetItemCount(item) > item.MaxStack then
      ItemWrapper.ModifyItemCount(item, item.MaxStack * - 1);
    else
      return;
    end
  end
end

function DigitalNetworkItemsListener(item,type,saveId)
  local deltaSaveId = saveId or (self._cacheSaveId + 1);
  if not self._cachedItems then
    self._pendingDeltas[#self._pendingDeltas + 1] = {Item = item, Type = type, SaveId = deltaSaveId};
    self._cacheSaveId = deltaSaveId;
  else
    self._cachedItems:Add(ItemWrapper.CopyItem(item));
    self._cacheSaveId = deltaSaveId;
    self._cachedIndexed = nil;
    self._cachedFlat = nil;
    QueueLocalCacheRebuild();
  end
  if self._interactingPlayer then
    self._responses[#self._responses + 1] = {Task = "UpdateItemCount"; Data = item,Type = type, SaveId = deltaSaveId};
  end
end

function PullNetworkItem(data)
  local itemPulled = DigitalNetworkPullItem(data);
  if ItemWrapper.GetItemCount(itemPulled) > 0 then
    SpawnItem(itemPulled);
  end
end

function PushNetworkItem(item)
  local leftover = DigitalNetworkPushItem(item);
  if ItemWrapper.GetItemCount(leftover) > 0 then
    SpawnItem(leftover);
  end
end

function PushNetworkItems()
  local itemsObj = {};
  local items = world.containerTakeAll(self._entityId);
  for slot, item in pairs(items) do
    self._tasksManager:GetTaskOperator("ItemsNetwork"):AddTask(Task(coroutine.create(PushNetworkItem), Item(item)));
  end
end

function IsTerminalWorking()
  self._responses[#self._responses + 1] = {Task = "TerminalActive"; Data = (DigitalNetworkGetControllerCount() == 1 and not self._networkFailsafeShutdown)};
end

function init()
  self._cacheBuilt = false;
  self._cachedItems = nil;
  self._cachedPatterns = {};
  self._pendingDeltas = {};
  self._cacheSaveId = storage._cacheSaveId or 0;
  self._cachedIndexed = nil;
  self._cachedFlat = nil;
  self._cacheRebuildScheduled = false;
  self._listenerRegistered = false;
  self._networkFailsafeShutdown = false;
  self._limiter = ClockLimiter();
  self._tasksManager = TaskManager(self._limiter, function() animator.setAnimationState("digitalstorage_terminalState", "off"); uninit(); end);
  self._tasksManager:AddTaskOperator("ItemsNetwork", "Table");

  Messenger().RegisterMessage("GetNetworkData", function () self._tasksManager:GetTaskOperator("ItemsNetwork"):AddTask(Task(coroutine.create(GetNetworkData)), nil, "GetNetworkData"); script.setUpdateDelta(1); end);
  -- Messenger().RegisterMessage("GetNetworkPatterns", function () self._tasksManager:GetTaskOperator("ItemsNetwork"):AddTask(Task(coroutine.create(GetNetworkPatterns)), nil, "GetNetworkPatterns"); script.setUpdateDelta(1); end);
  -- Messenger().RegisterMessage("RecieveNetworkItems", function (_, _) return self._networkItems; end);
  Messenger().RegisterMessage("PullNetworkItems", function (_, _, data) self._tasksManager:GetTaskOperator("ItemsNetwork"):AddTask(Task(coroutine.create(PullNetworkItem), data)); script.setUpdateDelta(1); end);
  -- Messenger().RegisterMessage("CraftNetworkItem", function (_, _, data) self._tasksManager:GetTaskOperator("ItemsNetwork"):AddTask(Task(coroutine.create(CraftNetworkItem), data)); script.setUpdateDelta(1); end);
  -- Messenger().RegisterMessage("IsTerminalWorking", IsTerminalWorking);
  Messenger().RegisterMessage("LoadResponses", function (_, _)
    local tmp = self._responses;
    self._responses = {};
    return tmp;
  end);
  Messenger().RegisterMessage("SetInteractingPlayer", function (_, _, playerId) self._interactingPlayer = playerId; end);
  Messenger().RegisterMessage("IsTerminalActive", IsTerminalWorking);
  self._responses = {};
  -- self._transmission = Transmission(TransmissionMessageProcess,"DigitalStoragePeripheralTransmission");
  self._interactingPlayer = nil;
  self._entityId = entity.id();
  local pos = entity.position();
  pos[2] = pos[2] + 1;
  self._itemSpawnPosition = pos;
  script.setUpdateDelta(1);
end

function containerCallback()
  if next(world.containerItems(self._entityId)) then
    self._tasksManager:GetTaskOperator("ItemsNetwork"):AddTask(Task(coroutine.create(PushNetworkItems)));
    script.setUpdateDelta(1);
  end
end

function DigitalNetworkPreUpdateControllers(count, mode)
  if count == 1 then
    animator.setAnimationState("digitalstorage_terminalState", "off");
  end
end

function DigitalNetworkPostUpdateControllers(count, mode)
  if count == 1 then
    animator.setAnimationState("digitalstorage_terminalState", "on");
  end
end

function DigitalNetworkFailsafeShutdown()
  DigitalNetworkFailsafeShutdownDevice();
end

function uninit()
  storage._cacheSaveId = self._cacheSaveId;
  DigitalNetworkUnregisterListener();
end
