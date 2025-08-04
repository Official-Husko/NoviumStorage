--[[
  ItemsDrivesStorage.lua
  ---------------------
  This class manages a collection of digital storage drives, organized by racks and slots, for Starbound.
  It provides methods to add/remove drives, query for drives containing or able to accept specific items, and manage drive priorities and filters.
  Part of NoviumStorage (fork of DigitalStorage by X)

  Starbound API cross-reference:
    - ItemWrapper: Utility for item comparison and manipulation (mod library)
    - FilterGroup: Filtering logic for items (mod library)
    - ItemsTable: Table structure for item storage (mod library)
    - Class: Lua class system (mod library)
]]

require "/HLib/Classes/Class.lua"            -- Class system
require "/HLib/Scripts/tableEx.lua"           -- Table utility extensions
require "/HLib/Classes/Item/Item.lua"         -- Item class
require "/HLib/Classes/Item/ItemWrapper.lua"  -- Item wrapper utilities
require "/HLib/Classes/Other/MutexSecure.lua" -- Mutex/locking for concurrency
require "/HLib/Classes/Filters/FilterGroup.lua" -- Filtering logic
require "/HLib/Classes/Item/ItemsTable.lua"   -- Table for storing items
require "/scripts/util.lua"                   -- Starbound utility functions

-- ItemsDrivesStorage: Manages all drives and their organization by rack/slot
ItemsDrivesStorage = Class();

--[[
  _init()
  -------
  Constructor. Initializes the drives and priority-ordered drives tables.
]]
function ItemsDrivesStorage:_init()
  self._drives = {};                    -- [rackId][slotId] = drive
  -- self._allItems = ItemsTable(true); -- (optional) all items table
  self._priorityOrderedDrives = {};     -- [priority][drive] = drive
end

--[[
  AddDrive(rackId, slotId, drive)
  -------------------------------
  Adds a drive to the specified rack and slot, and updates priority ordering.
  Uses:
    - FilterGroup: For drive filtering
    - Error handling if drive already exists at location
  @param rackId (any): The rack identifier
  @param slotId (any): The slot identifier
  @param drive (table): The drive data (see Drive:GetDriveData)
]]
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

--[[
  RemoveDrive(rackId, slotId)
  --------------------------
  Removes a drive from the specified rack and slot, and updates priority ordering.
  @param rackId (any): The rack identifier
  @param slotId (any): The slot identifier
]]
function ItemsDrivesStorage:RemoveDrive(rackId, slotId)
  local drive = self._drives[rackId][slotId];
  if drive then
    self._priorityOrderedDrives[drive.Priority][drive] = nil;
    -- local items = drive.Items:GetFlattened();
    self._drives[rackId][slotId] = nil;
  end
end

--[[
  RemoveRack(rackId)
  ------------------
  Removes all drives from the specified rack.
  @param rackId (any): The rack identifier
]]
function ItemsDrivesStorage:RemoveRack(rackId)
  local drives = self._drives[rackId];
  if drives then
    for slotId,_ in pairs(drives) do
      self:RemoveDrive(rackId, slotId);
    end
    self._drives[rackId] = nil;
  end
end

--[[
  DriveIsConnected(rackId, slotId)
  --------------------------------
  Checks if a drive is connected at the given rack and slot.
  @param rackId (any): The rack identifier
  @param slotId (any): The slot identifier
  @return (bool): True if connected, false otherwise
]]
function ItemsDrivesStorage:DriveIsConnected(rackId,slotId)
  if self._drives[rackId] then
    if self._drives[rackId][slotId] then
      return true;
    end
  end
  return false;
end

--[[
  GetItemsFromDrive(rackId, slotId)
  ---------------------------------
  Returns the ItemsTable for the drive at the given rack and slot.
  @param rackId (any): The rack identifier
  @param slotId (any): The slot identifier
  @return (ItemsTable): The items table for the drive
]]
function ItemsDrivesStorage:GetItemsFromDrive(rackId,slotId)
  return self._drives[rackId][slotId].Items;
end

--[[
  GetStoragesContainingItem(item)
  ------------------------------
  Returns a list of all drives that contain the specified item.
  Uses:
    - ItemsTable:FindFlattened: Finds item index
    - ItemWrapper.GetItemCount: Gets item count
  @param item (table): The item to search for
  @return (table): List of {Index, Entity, Priority, Count}
]]
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

--[[
  GetStoragesForItem(item)
  -----------------------
  Returns a list of all drives that can accept the specified item (have space, type slots, and allow via filter).
  Uses:
    - ItemsTable:GetItemsCount/GetItemsTypes: Checks space and type limits
    - FilterGroup:IsItemAllowed: Checks filter rules
    - ItemWrapper.Compare/GetItemCount: Compares and counts items
  @param item (table): The item to check
  @return (table): List of {Index, Entity, Priority, Count}
]]
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
