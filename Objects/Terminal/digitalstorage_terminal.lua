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

local _pageSize = 200;

local function ApplyChangeToTable(tbl, item, action)
  if not tbl then
    return;
  end
  if action == "Added" or action == "Modified" then
    tbl:Add(item);
  elseif action == "Removed" then
    tbl:Remove(item);
  end
end

local function AppendChange(change)
  self._changeLog = self._changeLog or {};
  self._changeLog[#self._changeLog + 1] = change;
  if #self._changeLog > 2000 then
    table.remove(self._changeLog, 1);
  end
end

local function GetNetworkData()
  if not DigitalNetworkHasOneController() then
    return;
  end
  DigitalNetworkRegisterListener(); -- NOTE this has to be here to avoid sync problems
  if not self._cachedItems then
    local resp = DigitalNetworkObtainCraftableList(self._currentChangeId or 0);
    self._currentChangeId = resp.CurrentId or 0;
    self._cachedItems = ItemsTable(true);
    self._changeLog = {};
    if resp.Snapshot then
      for _, item in ipairs(resp.Snapshot) do
        self._cachedItems:Add(Item(item, true));
      end
    end
    if resp.Changes then
      for i=1, #resp.Changes do
        local ch = resp.Changes[i];
        ApplyChangeToTable(self._cachedItems, ch.Item, ch.Action);
        AppendChange(ch);
      end
    end
  end
  local flattened = self._cachedItems:GetFlattened();
  local total = #flattened;
  local idx = 1;
  self._responses = {};
  while idx <= total do
    local chunk = {};
    local limit = math.min(idx + _pageSize - 1, total);
    for i = idx, limit do
      chunk[#chunk + 1] = flattened[i];
    end
    self._responses[#self._responses + 1] = {Task = "LoadNetworkData"; Data = chunk; CurrentId = self._currentChangeId; IsFinal = (limit == total)};
    idx = limit + 1;
  end
  if self._lastClientChangeId then
    local changes = {};
    for i=1, #self._changeLog do
      if self._changeLog[i].ChangeId > self._lastClientChangeId then
        changes[#changes + 1] = self._changeLog[i];
      end
    end
    if #changes > 0 then
      self._responses[#self._responses + 1] = {Task = "ApplyDeltas"; Changes = changes; CurrentId = self._currentChangeId};
    end
  end
end

function update(dt)
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

function DigitalNetworkItemsListener(item,type, changeId)
  self._currentChangeId = changeId or (self._currentChangeId or 0) + 1;
  local change = {Item = item; Action = type; ChangeId = self._currentChangeId};
  ApplyChangeToTable(self._cachedItems, item, type);
  AppendChange(change);
  self._responses[#self._responses + 1] = {Task = "ApplyDeltas"; Changes = {change}; CurrentId = self._currentChangeId};
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

function CraftUpgradeNetworkItem(recipe, amount, upgradeItem)
  local results = DigitalNetworkCraftUpgradeItem(recipe, amount, upgradeItem);
  for i=1, #results do
    local leftover = results[i]
    if ItemWrapper.GetItemCount(leftover) > 0 then
      SpawnItem(leftover);
    end
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
  self._networkFailsafeShutdown = false;
  self._limiter = ClockLimiter();
  self._tasksManager = TaskManager(self._limiter, function() animator.setAnimationState("digitalstorage_terminalState", "off"); uninit(); end);
  self._tasksManager:AddTaskOperator("ItemsNetwork", "Table");

  Messenger().RegisterMessage("GetNetworkData", function (_, _, lastChangeId) self._lastClientChangeId = lastChangeId; self._tasksManager:GetTaskOperator("ItemsNetwork"):AddTask(Task(coroutine.create(GetNetworkData)), nil, "GetNetworkData"); script.setUpdateDelta(1); end);
  -- Messenger().RegisterMessage("GetNetworkPatterns", function () self._tasksManager:GetTaskOperator("ItemsNetwork"):AddTask(Task(coroutine.create(GetNetworkPatterns)), nil, "GetNetworkPatterns"); script.setUpdateDelta(1); end);
  -- Messenger().RegisterMessage("RecieveNetworkItems", function (_, _) return self._networkItems; end);
  Messenger().RegisterMessage("PullNetworkItems", function (_, _, data) self._tasksManager:GetTaskOperator("ItemsNetwork"):AddTask(Task(coroutine.create(PullNetworkItem), data)); script.setUpdateDelta(1); end);
  Messenger().RegisterMessage("CraftUpgradeNetworkItem", function (_, _, data, amount, upgradeItem) self._tasksManager:GetTaskOperator("ItemsNetwork"):AddTask(Task(coroutine.create(CraftUpgradeNetworkItem), data, amount, upgradeItem)); script.setUpdateDelta(1); end);
  -- Messenger().RegisterMessage("IsTerminalWorking", IsTerminalWorking);
  Messenger().RegisterMessage("LoadResponses", function (_, _)
    local tmp = self._responses;
    self._responses = {};
    return tmp;
  end);
  Messenger().RegisterMessage("SetInteractingPlayer", function (_, _, playerId) self._interactingPlayer = playerId; end);
  Messenger().RegisterMessage("IsTerminalActive", IsTerminalWorking);
  self._responses = {};
  self._cachedItems = nil;
  self._changeLog = {};
  self._currentChangeId = 0;
  self._lastClientChangeId = 0;
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
