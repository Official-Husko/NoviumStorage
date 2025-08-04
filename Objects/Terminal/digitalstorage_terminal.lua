require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Classes/Network/Transmission.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Data/BitMap.lua"
require "/HLib/Classes/Item/Item.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"

require "/DigitalScripts/DigitalStoragePeripheral.lua"

local function GetNetworkData()
  local data = {};
  if DigitalNetworkHasOneController() then
    data.Items = DigitalNetworkObtainNetworkItemList():GetIndexed() or {};
    data.Patterns = DigitalNetworkObtainNetworkPatternListIndexed() or {};
  end
  self._responses = {};
  self._responses[1] = {Task = "LoadNetworkData"; Data = data};
  DigitalNetworkRegisterListener(); -- NOTE this has to be here to avoid sync problems
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

function DigitalNetworkItemsListener(item,type)
  self._responses[#self._responses + 1] = {Task = "UpdateItemCount"; Data = item,Type = type};
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
  Messenger().RegisterMessage("SetInteractingPlayer", function (_, _, playerId) self._interactingPlayer = playerId; if not playerId then DigitalNetworkUnregisterListener(); end end);
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
