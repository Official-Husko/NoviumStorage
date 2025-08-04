require "/DigitalScripts/Node.lua"
require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Classes/Item/Item.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Scripts/AdditionalFunctions.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/HLib/Classes/Filters/FilterGroup.lua"
require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Classes/Monitor/Monitor.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/HLib/Classes/Item/ContainerItemStorage.lua"

require "/DigitalScripts/DigitalStoragePeripheral.lua"


function die()

  if storage.Data.ImportSpeedCard then
    world.spawnItem(storage.Data.ImportSpeedCard.ItemDescriptor, entity.position());
  end
  if storage.Data.ExportSpeedCard then
    world.spawnItem(storage.Data.ExportSpeedCard.ItemDescriptor, entity.position());
  end
  if storage.Data.ConfigCard then
    world.spawnItem(storage.Data.ConfigCard.ItemDescriptor, entity.position());
  end
end

function ConnectedContainerItemsUpdate()
  if #self._containerItems:UpdateContainer() ~= 0 then
    self._containerUpdated = true;
  end
end


local function GetActiveSlots(slots, isinvert)
  local maxId = self._containerItems:GetContainerSize();
  local workSlots = {};
  local tmpslotIndex = {}
  for i=1,#slots do
    tmpslotIndex[slots[i]] = true;
  end
  for i=1,maxId do
    workSlots[i] = xor(tmpslotIndex[i] or false,isinvert);
  end
  return workSlots;
end

function TransformIntoFilter(item)
  return {
    Mode = "Whitelist";
    ItemFilters = {
      item.ItemDescriptor;
    };
    TextFilters = {
    }
  };
end

local function FindAllItemMatches(itemsTable,filter)
  local newItemTable = IndexedTable(function(x) return x.UniqueIndex; end,ItemWrapper.Compare);
  for i=1,#itemsTable do
    local item = itemsTable[i];
    if filter:IsItemAllowed(item) then
      if not newItemTable:Exists(item) then
        newItemTable:Add(item);
      end
    end
  end
  return newItemTable;
end

local function GenerateWorkData()
  local data = {};
  data.Import = {};
  data.Export = {};
  data.Import.Filters = {};
  data.Export.Filters = {};
  data.Import.Actions = 1;
  data.Export.Actions = 1;
  if storage.Data.ImportSpeedCard then
    data.Import.Actions = data.Import.Actions + ItemWrapper.GetItemCount(storage.Data.ImportSpeedCard);
  end
  if storage.Data.ExportSpeedCard then
    data.Export.Actions = data.Export.Actions + ItemWrapper.GetItemCount(storage.Data.ExportSpeedCard);
  end
  local items = self._networkItems:GetFlattened();
  if storage.Data.Filters then
    for id,filter in pairs(storage.Data.Filters) do

      if filter.Mode ~= "None" then
        local thisModeFilters = data[filter.Mode].Filters;
        local processed = {};
        processed.Activation = {};
        processed.Activation.Mode = filter.ActivationMode;
        processed.Activation.Data = copy(filter.ActivationData);
        if processed.Activation.Mode == "Item" then
          local activationitem = processed.Activation.Data.Item;
          if activationitem then
            local activationFilter = nil;
            if activationitem.ItemDescriptor.name == "digitalstorage_filtercard" then
              activationFilter = FilterGroup(activationitem.ItemDescriptor.parameters.Filters);
            else
              activationFilter = FilterGroup(TransformIntoFilter(activationitem));
            end
            processed.Activation.Data.Item = activationitem;
            processed.Activation.Data.Filter = activationFilter;
            processed.Activation.Data.Items = FindAllItemMatches(items,activationFilter);
          else
            processed.Activation.Data.Items = IndexedTable(function(x) return x.UniqueIndex; end,ItemWrapper.Compare);
          end
        end

        processed.AdditionalSettings = copy(filter.AdditionalData);
        processed.Slots = GetActiveSlots(filter.Slots,filter.SlotMode == "Inverted");
        processed.Filter = FilterGroup(filter.Filters);
        thisModeFilters[#thisModeFilters + 1] = processed;
      end
      if self._limiter:Check() then
        coroutine.yield();
      end
    end
    local export = data.Export.Filters;
    for i=1,#export do
      local exportFilter = export[i];
      local filter = exportFilter.Filter;
      exportFilter.Items = FindAllItemMatches(items,filter);
      if self._limiter:Check() then
        coroutine.yield();
      end
    end
    if self._limiter:Check() then
      coroutine.yield();
    end
  end
  self._workData = data;
end


function update()
  self._limiter:Restart();
  self._tasks:Restart();
  if not self._containerId then
    local container = FindContainer(2);
    if not container then
      script.setUpdateDelta(60 + sb.staticRandomI32Range(0, 120, sb.makeUuid()));
    else
      self._containerId = container;
      self._containerItems = ContainerItemStorage(container);
      self._containerItems:UpdateContainer();
      EntityMonitor(container,"die","ConnectedContainerDied");
      EntityMonitor(container,"containerCallback","ConnectedContainerItemsUpdate");
    end
    return;
  end
  if DigitalNetworkHasOneController() and self._containerId then
    if animator.animationState("digitalstorage_transfernodeState") ~= "on" then
      animator.setAnimationState("digitalstorage_transfernodeState", "on");
    end
    if self._tasks:HasTasks() then
      self._tasks:Launch();
      script.setUpdateDelta(1);
    else
      if not self._guiOpened and not self._savedFilters and self._workData then
        self._tasks:AddTask(Task(coroutine.create(DoImportExport)));
        if self._containerUpdated then
          self._containerUpdated = false;
          script.setUpdateDelta(45 + sb.staticRandomI32Range(0, 60, sb.makeUuid()));
        else
          script.setUpdateDelta(240 + sb.staticRandomI32Range(0, 120, sb.makeUuid()));
        end
        --- NOTE This shit is needed because delta isnt applied instantly.
        local tmp_update = update;
        update = function ()
          update = tmp_update;
        end
      else
        script.setUpdateDelta(240 + sb.staticRandomI32Range(0, 120, sb.makeUuid()));
        if (self._savedFilters and not self._guiOpened) or (not self._workData and not self._guiOpened) then
          self._savedFilters = false;
          self._tasks:AddTask(Task(coroutine.create(GenerateWorkData)));
        end
      end
    end
  end
end



function init()

  self._containerId = nil;
  self._workData = nil;
  self._containerItems = nil;
  self._networkItems = nil;
  self._limiter = ClockLimiter();
  self._containerUpdated = false;
  self._guiOpened = false;



  self._tasks = TaskOperator("Queue",self._limiter,function() DigitalNetworkFailsafeShutdown(); end);
  storage.Data = storage.Data or {};
  Messenger().RegisterMessage("GUIOpened", function(_, _) self._guiOpened = true;  end);
  Messenger().RegisterMessage("GUIClosed", function(_, _) self._guiOpened = false; script.setUpdateDelta(1) end);
  Messenger().RegisterMessage("Load", function(_, _) return storage.Data; end);
  Messenger().RegisterMessage("Save", function(_, _, data) storage.Data = data; self._savedFilters = true; self._tasks:RemoveTasks(); end);
  script.setUpdateDelta(0);
end


function DigitalNetworkPreUpdateControllers(count, mode)
  if count == 1 then
    animator.setAnimationState("digitalstorage_transfernodeState", "off");
    self._networkItems = nil;
    self._workData = nil;
    self._tasks:RemoveTasks();
    DigitalNetworkUnregisterListener();
  end
end

function DigitalNetworkPostUpdateControllers(count, mode)
  if count == 1 then
    animator.setAnimationState("digitalstorage_transfernodeState", "idle");
    self._networkItems = DigitalNetworkObtainNetworkItemList();
    DigitalNetworkRegisterListener();
    script.setUpdateDelta(1);
  end
end

function DigitalNetworkItemsListener(item,type)
  if type == "Added" then
    if self._workData then
      local exportFilters = self._workData.Export.Filters;
      for i=1,#exportFilters do
        filteredItems = exportFilters[i].Items;
        if exportFilters[i].Filter:IsItemAllowed(item) then
          if not filteredItems:Exists(item) then
            filteredItems:Add(self._networkItems:Find(item));
          end
        end
      end
      for _,operation in pairs(self._workData) do
        for i=1,#operation.Filters do
          local filter = operation.Filters[i];
          if filter.Activation.Mode == "Item" then
            if filter.Activation.Data.Filter then
              if filter.Activation.Data.Filter:IsItemAllowed(item) then
                if not filter.Activation.Data.Items:Exists(item) then
                  filter.Activation.Data.Items:Add(self._networkItems:Find(item));
                end
              end
            end
          end
        end
      end
    end
  end
end

function DigitalNetworkFailsafeShutdown()
  DigitalNetworkFailsafeShutdownDevice();
end
