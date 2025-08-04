require "/DigitalScripts/DigitalStoragePeripheral.lua"
require "/HLib/Classes/Filters/FilterGroup.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"
require "/HLib/Classes/Item/Item.lua"
require "/HLib/Scripts/AdditionalFunctions.lua"



local blockedSlots = {};

local function IsActive(activation)
  if activation.Mode == "Manual" then
    if activation.Data == "On" then
      return true;
    end
  elseif activation.Mode == "Wire" then
    return (activation.Data == "Normal") == object.getInputNodeLevel(0);
  elseif activation.Mode == "Item" then

    local count = 0;
    if activation.Data.Items then
      local items = activation.Data.Items:GetFlattened();
      for i=1,#items do
        count = count + ItemWrapper.GetItemCount(items[i]);
      end
    end
    if activation.Data.Compare == "<=" then
      return count <= activation.Data.Count;
    else
      return count >= activation.Data.Count;
    end
  end
  return false;
end

local function Import(filters)
  local currentoperations = 0;
  for i=1,#filters.Filters do
    local filter = filters.Filters[i];
    if IsActive(filter.Activation) then
      local containerItems = self._containerItems:GetContainerData();
      local allowedSlots = filter.Slots;
      for j=1,#allowedSlots do
        if allowedSlots[j] then
          if not blockedSlots[j] then
            local item = containerItems[j];
            if item then
              if filter.Filter:IsItemAllowed(item) then
                local itemCountToImport = ItemWrapper.GetItemCount(item) - filter.AdditionalSettings.LeaveCount;
                if itemCountToImport > 0 then
                  blockedSlots[j] = true;
                  local consumedItemDesc = world.containerTakeNumItemsAt(self._containerId, j - 1, itemCountToImport);
                  if consumedItemDesc then
                    currentoperations = currentoperations + 1;
                    local leftover = DigitalNetworkPushItem(Item(consumedItemDesc));
                    if ItemWrapper.GetItemCount(leftover) ~= 0 then
                      local result = world.containerPutItemsAt(self._containerId, leftover.ItemDescriptor, j - 1);
                      if result then
                        world.spawnItem(result, entity.position());
                      end
                    end
                    if currentoperations >= filters.Actions then
                      return;
                    end
                  end
                end
              end
            end
          end
        end
        if self._limiter:Check() then
          coroutine.yield();
        end
      end
    end
  end
end

local function Export(filters)
  local actions = filters.Actions;
  local currentoperations = 0;
  for i=1,#filters.Filters do
    local filter = filters.Filters[i];
    if IsActive(filter.Activation) then
      local containerItems = self._containerItems:GetContainerData();
      local containerAllItems = self._containerItems:GetContainerAllItems();
      local allowedSlots = filter.Slots;
      local itemsAllowed = filter.Items;
      local additionalSettings = filter.AdditionalSettings;
      for i=1,#allowedSlots do
        if allowedSlots[i] then
          local itemToExport = nil;
          local item = containerItems[i];
          if item then
            if ItemWrapper.GetItemCount(item) ~= item.MaxStack then
              local tmpitm = itemsAllowed:Find(item);
              if tmpitm and ItemWrapper.GetItemCount(tmpitm) > 0 then

                local notMoreThan = 0;
                if additionalSettings.UpToCount == 0 or additionalSettings.UpToMode == "Per Slot" then
                  if additionalSettings.UpToCount == 0 then
                    notMoreThan = item.MaxStack;
                  else
                    notMoreThan = additionalSettings.UpToCount;
                  end
                else
                  local cntItem = containerAllItems:Find(item);
                  if cntItem then
                    notMoreThan = additionalSettings.UpToCount - ItemWrapper.GetItemCount(cntItem);
                  else
                    notMoreThan = additionalSettings.UpToCount;
                  end
                end
                if notMoreThan > 0 then
                  notMoreThan =  notMoreThan - ItemWrapper.GetItemCount(item);

                  local countToExport = item.MaxStack - ItemWrapper.GetItemCount(item);
                  if notMoreThan < countToExport then
                    countToExport = notMoreThan;
                  end

                  if ItemWrapper.GetItemCount(tmpitm) < countToExport then
                    countToExport = ItemWrapper.GetItemCount(tmpitm);
                  end

                  if additionalSettings.MultipleCount > 1 then
                    countToExport = math.floor(countToExport / additionalSettings.MultipleCount) * additionalSettings.MultipleCount;
                  end
                  if countToExport > 0 then
                    itemToExport = ItemWrapper.CopyItem(item);
                    ItemWrapper.SetItemCount(itemToExport,countToExport);
                  end
                end

              end
            end
          else
            local itemsAllowedFlat = itemsAllowed:GetFlattened();
            for k=1,#itemsAllowedFlat do
              local item = itemsAllowedFlat[k];
              if ItemWrapper.GetItemCount(item) > 0 then
                local notMoreThan = 0;
                if additionalSettings.UpToCount == 0 or additionalSettings.UpToMode == "Per Slot" then
                  if additionalSettings.UpToCount == 0 then
                    notMoreThan = item.MaxStack;
                  else
                    notMoreThan = additionalSettings.UpToCount;
                  end
                else
                  local cntItem = containerAllItems:Find(item);
                  if cntItem then
                    notMoreThan = additionalSettings.UpToCount - ItemWrapper.GetItemCount(cntItem);
                  else
                    notMoreThan = additionalSettings.UpToCount;
                  end
                end
                if notMoreThan > 0 then
                  local countToExport = ItemWrapper.GetItemCount(item);
                  if notMoreThan < countToExport then
                    countToExport = notMoreThan;
                  end
                  if item.MaxStack < countToExport then
                    countToExport = item.MaxStack;
                  end
                  if additionalSettings.MultipleCount > 1 then
                    countToExport = math.floor(countToExport / additionalSettings.MultipleCount) * additionalSettings.MultipleCount;
                  end
                  if countToExport > 0 then
                    itemToExport = ItemWrapper.CopyItem(item);
                    ItemWrapper.SetItemCount(itemToExport,countToExport);
                    break;
                  end

                end
              end
              if self._limiter:Check() then
                coroutine.yield();
              end
            end
          end


          -- NOTE actual exporting
          if itemToExport then
            currentoperations = currentoperations + 1;
            local result = DigitalNetworkPullItem(itemToExport);
            local leftover = world.containerPutItemsAt(self._containerId, result.ItemDescriptor, i - 1);
            if leftover then
              local leftover2 = DigitalNetworkPushItem(Item(leftover));
              if leftover2 and ItemWrapper.GetItemCount(leftover2) then
                world.spawnItem(leftover2.ItemDescriptor, entity.position());
              end
            end
          end
          if currentoperations >= filters.Actions then
            return;
          end
          if self._limiter:Check() then
            coroutine.yield();
          end
        end
      end
    end
  end
end



function DoImportExport()
  blockedSlots = {};
  if self._workData ~= nil then
    Import(self._workData.Import);
    if self._limiter:Check() then
      coroutine.yield();
    end

    Export(self._workData.Export);

  end
end
