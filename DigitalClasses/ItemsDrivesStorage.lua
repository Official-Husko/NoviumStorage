require "/HLib/Classes/Class.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Classes/Item/Item.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"
require "/HLib/Classes/Other/MutexSecure.lua"
require "/HLib/Classes/Filters/FilterGroup.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/scripts/util.lua"

ItemsDrivesStorage = Class();

function ItemsDrivesStorage:_init()
  self._drives = {};
  -- self._allItems = ItemsTable(true);
  self._priorityOrderedDrives = {};
end

function ItemsDrivesStorage:AddDrive(rackId, slotId, drive)
  local tmpDrive = {};
  tmpDrive.Uuid = drive.Uuid;
  tmpDrive.TypesMax = drive.TypesMax;
  tmpDrive.CapacityMax = drive.CapacityMax;
  tmpDrive.Filter = FilterGroup(drive.Filters);
  tmpDrive.Items = drive.Items;
  tmpDrive.Priority = drive.Priority;
  tmpDrive.Location = {Entity = rackId;Index = slotId};
  if not self._drives[rackId] then
    self._drives[rackId] = {};
  end
  if self._drives[rackId][slotId] then
    error(ToStringAnything("Drive already exists on: ",rackId,slotId,self._drives));
  end
  self._drives[rackId][slotId] = tmpDrive;
  if not self._priorityOrderedDrives[tmpDrive.Priority] then
    self._priorityOrderedDrives[tmpDrive.Priority] = {};
  end
  self._priorityOrderedDrives[tmpDrive.Priority][tmpDrive] = tmpDrive;
end

function ItemsDrivesStorage:RemoveDrive(rackId, slotId)
  local drive = self._drives[rackId][slotId];
  if drive then
    self._priorityOrderedDrives[drive.Priority][drive] = nil;
    -- local items = drive.Items:GetFlattened();

    self._drives[rackId][slotId] = nil;

  end
end

function ItemsDrivesStorage:RemoveRack(rackId)
  local drives = self._drives[rackId];
  if drives then
    for slotId,_ in pairs(drives) do
      self:RemoveDrive(rackId, slotId);
    end
    self._drives[rackId] = nil;
  end
end

function ItemsDrivesStorage:DriveIsConnected(rackId,slotId)
  if self._drives[rackId] then
    if self._drives[rackId][slotId] then
      return true;
    end
  end
  return false;
end


function ItemsDrivesStorage:GetItemsFromDrive(rackId,slotId)
  return self._drives[rackId][slotId].Items;
end

function ItemsDrivesStorage:GetStoragesContainingItem(item)
  local storagesWithItem = {};
  for rackId, drives in pairs(self._drives) do
    for slotId, drive in pairs(drives) do
      local index = drive.Items:FindFlattened(item);
      if index then
        storagesWithItem[#storagesWithItem + 1] =
        {
          Index = slotId;
          Entity = rackId;
          Priority = drive.Priority;
          Count = ItemWrapper.GetItemCount(drive.Items:GetFlattened()[index]);
        };
      end
    end
  end
  return storagesWithItem;
end

function ItemsDrivesStorage:GetStoragesForItem(item)
  local storagesForItem = {};
  for priority, storages in pairs(self._priorityOrderedDrives) do
    for id, storage in pairs(storages) do
      if (storage.CapacityMax > storage.Items:GetItemsCount()) and (storage.TypesMax > storage.Items:GetItemsTypes()) and storage.Filter:IsItemAllowed(item) then
        local count = 0;
        if storage.Items[item.UniqueIndex] then
          for _, itemInSt in pairs(storage.Items[item.UniqueIndex]) do
            if ItemWrapper.Compare(item, itemInSt) then
              count = ItemWrapper.GetItemCount(itemInSt);
              break;
            end
          end
        end
        storagesForItem[#storagesForItem + 1] = {Index = storage.Location.Index ; Entity = storage.Location.Entity; Priority = priority; Count = count};
      end
    end
  end
  return storagesForItem;
end
