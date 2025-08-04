require "/DigitalScripts/DigitalStoragePeripheral.lua"
require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Scripts/tableEx.lua"


require "/HLib/Classes/Tasks/Task.lua"
require "/HLib/Classes/Tasks/TaskOperator.lua"

require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Item/Item.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"

require "/HLib/Classes/Data/IndexedTable.lua"



function init ()
  self._limiter = ClockLimiter();
  self._tasks = TaskOperator("Queue",self._limiter,function() end);
end

local function Merge()
  local indexed = self._networkItems:GetIndexed();
  local mergeable = {};
  for _,items in pairs(indexed) do
    local itemcategory = root.itemType(items[1].ItemDescriptor.name);
    if itemcategory == "consumable" and items[1].ItemDescriptor.parameters.timeToRot then
      mergeable[#mergeable + 1] = items;
    end
  end
  if self._limiter:Check() then
    coroutine.yield();
  end
  local toMerge = {};
  for j=1,#mergeable do
    local items = mergeable[j];
    if #items ~= 1 then
      local countMultiples = 0;
      for i=1,#items do
        if ItemWrapper.GetItemCount(items[i]) > 0 then
          countMultiples = countMultiples + 1;
        end
        if countMultiples > 1 then
          toMerge[#toMerge + 1] = items;
          break;
        end
      end
    end
    if self._limiter:Check() then
      coroutine.yield();
    end
  end
  for i=1,#toMerge do
    local tmpItem = ItemWrapper.CopyItem(toMerge[i][1]);
    local itemcount = 0;
    local rotTimes = {};
    local items = toMerge[i];
    for j=1,#items do
      local obtained = DigitalNetworkPullItem(items[j]);
      if obtained then
        local obtainedCount = ItemWrapper.GetItemCount(obtained);
        itemcount = itemcount + obtainedCount;
        local rottime = obtained.ItemDescriptor.parameters.timeToRot;
        for k=1,obtainedCount do
          rotTimes[#rotTimes + 1] = rottime;
        end
      end
      if self._limiter:Check() then
        coroutine.yield();
      end
    end
    if itemcount > 0 then
      local avgRotTime = GetAverage(rotTimes);
      ItemWrapper.SetItemCount(tmpItem,itemcount);
      tmpItem.ItemDescriptor.parameters.timeToRot = avgRotTime;

      DigitalNetworkPushItem(tmpItem);
    end


    if self._limiter:Check() then
      coroutine.yield();
    end


    --NOTE merge stuff
  end
end

function update()
  self._limiter:Restart();
  self._tasks:Restart();
  if not (DigitalNetworkDeviceOperative() and self._networkItems) then
    return;
  end
  if self._tasks:HasTasks() then
    self._tasks:Launch();
    script.setUpdateDelta(1);
  else
    self._tasks:AddTask(Task(coroutine.create(Merge)));
    script.setUpdateDelta(300);
    local tmp_update = update;
    update = function ()
      update = tmp_update;
    end
  end
end

function DigitalNetworkPreUpdateControllers(count, mode)
  if DigitalNetworkDeviceOperative() then
    if count == 1 then
      animator.setAnimationState("digitalstackerState", "off");
      self._networkItems = nil;
      self._tasks:RemoveTasks();
      script.setUpdateDelta(60);
    end
  end
end

function DigitalNetworkPostUpdateControllers(count, mode)
  if DigitalNetworkDeviceOperative() then
    if count == 1 then
      animator.setAnimationState("digitalstackerState", "on");
      self._networkItems = DigitalNetworkObtainNetworkItemList();
    end
  end
end
