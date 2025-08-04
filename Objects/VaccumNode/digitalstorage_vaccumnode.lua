require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"
require "/scripts/vec2.lua"
require "/HLib/Scripts/AdditionalFunctions.lua"
require "/DigitalScripts/DigitalStoragePeripheral.lua"

function DigitalNetworkFailsafeShutdown()
  DigitalNetworkFailsafeShutdownDevice();
  animator.setAnimationState("AnimationState", "off");
  script.setUpdateDelta(0);
  self._workData = nil;

end

function die()
  if storage.Upgrades then
    world.spawnItem(storage.Upgrades.ItemDescriptor, entity.position());
  end
end

local function LoadData(_,_)
  return storage.Upgrades;
end

local function SaveData(_,_,data)
  storage.Upgrades = data;
end

local function GetRange()
  local range = 3;
  if storage.Upgrades then
    range = range + ItemWrapper.GetItemCount(storage.Upgrades);
  end
  return range;
end


local function PushItemsIntoNetwork()
  if DigitalNetworkDeviceActive() then
    local items = world.containerItems(self._entityId);
    for slot, item in pairs(items) do
      item = Item(item);
      local leftover = DigitalNetworkPushItem(item);
      local pushedCount = ItemWrapper.GetItemCount(item) - ItemWrapper.GetItemCount(leftover);
      if pushedCount > 0 then
        world.containerConsumeAt(self._entityId, slot - 1, pushedCount);
      end
      if self._limiter:Check() then
        coroutine.yield();
      end
    end
  end
end

local function PullItemsFromWorld()
  local range = GetRange();
  local items = world.itemDropQuery(vec2.add(self._position,-range),vec2.add(self._position,range));
  if self._limiter:Check() then
    coroutine.yield();
  end
  local itemstab = {};
  for i=1,#items do
    local item =  world.takeItemDrop(items[i]);
    if item then
      local tmptab = {};
      tmptab.Position = world.entityPosition(items[i]);
      tmptab.Item = item;
      itemstab[#itemstab + 1] = tmptab;
    end
    if self._limiter:Check() then
      coroutine.yield();
    end
  end
  for i=1,#itemstab do
    local leftover = world.containerAddItems(self._entityId, itemstab[i].Item);
    if leftover then
      world.spawnItem(leftover, itemstab[i].Position);
    end
    if self._limiter:Check() then
      coroutine.yield();
    end
  end
end

local function DoWork()
  PullItemsFromWorld();
  coroutine.yield();
  PushItemsIntoNetwork();
end

function update()
  if DigitalNetworkDeviceOperative() then
    self._limiter:Restart();
    self._task:Restart();
    if self._task:HasTasks() then
      self._task:Launch();
      script.setUpdateDelta(1);
    else
      self._task:AddTask(Task(coroutine.create(DoWork)));
      script.setUpdateDelta(200 + sb.staticRandomI32Range(0, 120, sb.makeUuid()));
      local tmp_update = update;
      update = function ()
        update = tmp_update;
      end
    end
  end
  -- self._limiter:Restart();
  -- self._tasksManager:Restart();
  -- self._tasksManager:LaunchTaskOperator("Vaccum");
  -- if not self._tasksManager:HasTasks() then
  --   local range = GetRange();
  --   DelayNextUpdate(_ENV,45 + math.ceil((range / 2) + sb.staticRandomI32Range(0, range + 30, sb.makeUuid())),1);
  --   self._tasksManager:GetTaskOperator("Vaccum"):AddTask(Task(coroutine.create(PullItemsFromWorld)));
  --   if DigitalNetworkHasOneController() then
  --     self._tasksManager:GetTaskOperator("Vaccum"):AddTask(Task(coroutine.create(PushItemsIntoNetwork)));
  --   end
  -- end
end

-- function DigitalNetworkUpdateControllerCount(count)
--   if DigitalNetworkGetControllerCount() == 1 then
--     animator.setAnimationState("AnimationState", "onconnected");
--     -- object.setOutputNodeLevel(0,false);
--   --  script.setUpdateDelta(1);
--   else
--     animator.setAnimationState("AnimationState", "on");
--   --  script.setUpdateDelta(0);
--     -- object.setOutputNodeLevel(0,false);
--   end
-- end

-- function DigitalNetworkFailsafeShutdown()
--   self._networkFailsafeShutdown = true;
--   local nofun = function()
--     animator.setAnimationState("AnimationState", "off");
--     -- object.setOutputNodeLevel(0,false);
--     script.setUpdateDelta(0);
--   end
--   DigitalNetworkUpdateControllerCount = nofun;
--   update = nofun;
--   nofun();
-- end
--


function init()
  self._entityId = entity.id();
  self._position = entity.position();
  -- if type(storage) ~= "table" then
  --   storage = {};
  -- end
  self._limiter = ClockLimiter();
  self._task = TaskOperator("Queue",self._limiter,function() DigitalNetworkFailsafeShutdown() end);
  -- self._transmission = Transmission(TransmissionMessageProcess);

  -- self._tasksManager = TaskManager(self._limiter, function() animator.setAnimationState("AnimationState", "off"); DigitalNetworkFailsafeShutdown(); end);
  -- self._tasksManager:AddTaskOperator("Vaccum", "Queue");
  Messenger().RegisterMessage("SaveData", SaveData);
  Messenger().RegisterMessage("LoadData", LoadData);
  animator.setAnimationState("AnimationState", "on");
  script.setUpdateDelta(30 + sb.staticRandomI32Range(0, 60, sb.makeUuid()));
end

function DigitalNetworkPreUpdateControllers(count, mode)
  if DigitalNetworkDeviceOperative() then
    if count == 1 then
      animator.setAnimationState("AnimationState", "on");
    end
  end
end

function DigitalNetworkPostUpdateControllers(count, mode)
  if DigitalNetworkDeviceOperative() then
    if count == 1 then
      animator.setAnimationState("AnimationState", "onconnected");
    end
  end
end
