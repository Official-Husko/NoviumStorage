--[[
  Drive.lua
  ---------
  This class represents a digital storage drive for Starbound, handling item storage, upgrades, filters, and change tracking.
  Part of NoviumStorage (fork of DigitalStorage by X)

  Starbound API cross-reference:
    - sb.makeUuid(): Generates a unique identifier (see Starbound Lua API)
    - os.clock(), os.time(): Standard Lua functions for time/entropy
    - root.itemConfig(): Reads item configuration (see world.md/root.md)
    - See also: ItemWrapper, ItemsTable, MutexSecure (mod libraries)
]]

require "/HLib/Classes/Class.lua"            -- Class system
require "/HLib/Scripts/tableEx.lua"           -- Table utility extensions
require "/HLib/Classes/Item/Item.lua"         -- Item class
require "/HLib/Classes/Item/ItemWrapper.lua"  -- Item wrapper utilities
require "/HLib/Classes/Other/MutexSecure.lua" -- Mutex/locking for concurrency
require "/HLib/Classes/Filters/FilterGroup.lua" -- Filtering logic
require "/HLib/Classes/Item/ItemsTable.lua"   -- Table for storing items
require "/scripts/util.lua"                   -- Starbound utility functions

-- Drive: Main class for managing a digital storage drive
Drive = Class(MutexSecure);

--[[
  _init(item)
  ------------
  Constructor. Initializes the drive with the given item descriptor.
  Sets up item storage, change tracking, and loads items from parameters.
  Uses:
    - UpdateDriveVersion: Ensures drive parameters are up-to-date.
    - self:LoadItems(): Loads items from the drive's parameters.
  @param item (table): The item descriptor for this drive (see Starbound item format)
]]
function Drive:_init(item)
  MutexSecure._init(self);
  self._drive = item;
  self._driveStoredItems = ItemsTable();      -- Persistent storage of items
  self._driveChanges = {};                    -- Pending changes (add/remove)
  self._driveLastChanges = {};                -- Last committed changes
  self._driveItemsWorktable = ItemsTable();   -- Working table for item operations
  self._driveItemsLoaded = false;             -- Whether items are loaded
  self._changes = {};                        -- General change tracking
  self._driveFilters = nil;                   -- FilterGroup for item filtering
  UpdateDriveVersion(self._drive);            -- Ensure drive parameters are up-to-date
  self:LoadItems();                           -- Load items from parameters
end

--[[
  GetDrive()
  ----------
  Returns the underlying item descriptor for this drive.
  @return (table): The item descriptor (see Starbound item format)
]]
function Drive:GetDrive()
  return self._drive;
end

--[[
  LoadItems()
  -----------
  Loads items from the drive's parameters into storage and work tables.
  Handles both flat and grouped data formats.
  Updates the drive's Data parameter to a flattened format.
  Uses:
    - Item(): Constructs item objects from stored data.
    - ItemsTable:Add(): Adds items to storage/work tables.
    - next(): Standard Lua function for table iteration.
]]
function Drive:LoadItems()
  local firstindex, _ = next(self._drive.parameters.Data or {});
  if firstindex == nil then
    -- No items to load
  elseif type(firstindex) == "number" then
    -- Flat array of items
    for i, v in pairs(self._drive.parameters.Data) do
      self._driveStoredItems:Add(Item(v,true));
      self._driveItemsWorktable:Add(Item(v,true));
    end
  else
    -- Grouped items (by type/group)
    for groupName, group in pairs(self._drive.parameters.Data) do
      for itemStoredIndex, itemStored in pairs(group) do
        self._driveStoredItems:Add(Item(itemStored,true));
        self._driveItemsWorktable:Add(Item(itemStored,true));
      end
    end
  end
  self._driveItemsLoaded = true;
  self._drive.parameters.Data = self._driveStoredItems:GetFlattened();
end

--[[
  AddItem(item)
  -------------
  Attempts to add an item to the drive, respecting capacity and type limits.
  Uses:
    - ItemWrapper.GetItemCount: Gets item count (see ItemWrapper)
    - ItemsTable:GetItemsCount/Types: Gets current usage
    - ItemsTable:FindFlattened: Finds matching item slot
    - ItemWrapper.CopyItem/SetItemCount: Clones and modifies item descriptors
  @param item (table): The item to add
  @return (table): The leftover item (if not all could be added)
]]
function Drive:AddItem(item)
  local itemsToAddTotal = ItemWrapper.GetItemCount(item);
  local freespace = self._drive.parameters.DriveParameters.Capacity - self._driveItemsWorktable:GetItemsCount();
  if freespace <= 0 then
    return item;
  end

  local slot = self._driveItemsWorktable:FindFlattened(item);
  if not slot and self._driveItemsWorktable:GetItemsTypes() >= self._drive.parameters.DriveParameters.Types then
    return item;
  end

  local itemsToAdd = 0;
  local itemsToReturn = 0;
  if freespace < itemsToAddTotal then
    itemsToAdd = freespace;
    itemsToReturn = itemsToAddTotal - itemsToAdd;
  else
    itemsToAdd = itemsToAddTotal;
  end
  local changeItem = ItemWrapper.CopyItem(item);
  ItemWrapper.SetItemCount(changeItem, itemsToAdd);
  local returnItem = ItemWrapper.CopyItem(item);
  ItemWrapper.SetItemCount(returnItem, itemsToReturn);
  self._driveItemsWorktable:Add(changeItem);
  self._driveChanges[#self._driveChanges + 1] = {Mode = 1; Item = changeItem};
  return returnItem;
end

--[[
  RemoveItem(item)
  ----------------
  Attempts to remove an item from the drive.
  Uses:
    - ItemWrapper.CopyItem/SetItemCount: Clones and modifies item descriptors
    - ItemsTable:FindFlattened/Remove: Finds and removes item
  @param item (table): The item to remove
  @return (table): The removed item (with correct count), or zero-count if not found
]]
function Drive:RemoveItem(item)
  local result = ItemWrapper.CopyItem(item);
  ItemWrapper.SetItemCount(result,0)
  local slot = self._driveItemsWorktable:FindFlattened(item);
  if not slot then
    return result;
  end
  result = self._driveItemsWorktable:Remove(item);
  local tmpitem = ItemWrapper.CopyItem(item);
  if result then
    ItemWrapper.SetItemCount(tmpitem,  ItemWrapper.GetItemCount(result));
  end
  self._driveChanges[#self._driveChanges + 1] = {Mode = 2; Item = tmpitem};
  return result;
end

--[[
  LoadFilters()
  -------------
  Loads the drive's filter group from parameters.
  Uses:
    - FilterGroup: Constructs a filter group for item filtering.
]]
function Drive:LoadFilters()
  self._driveFilters = FilterGroup(self._drive.parameters.Filters or {});
end

--[[
  FiltersAllow(item)
  -----------------
  Checks if the given item is allowed by the drive's filters.
  Uses:
    - FilterGroup:IsItemAllowed: Checks filter rules.
  @param item (table): The item to check
  @return (bool): True if allowed, false otherwise
]]
function Drive:FiltersAllow(item)
  return self._driveFilters:IsItemAllowed(item);
end

--[[
  GetDriveData()
  --------------
  Returns a summary table of the drive's configuration and state.
  @return (table): Table with filters, capacity, types, priority, items, and UUID
]]
function Drive:GetDriveData()
  local driveData = {};
  driveData.Filters = self._drive.parameters.Filters;
  driveData.CapacityMax = self._drive.parameters.DriveParameters.Capacity;
  driveData.TypesMax = self._drive.parameters.DriveParameters.Types;
  driveData.Priority = self._drive.parameters.Priority;
  driveData.Items = self._driveStoredItems;
  driveData.Uuid = self:GetDriveUuid();
  return driveData;
end

--[[
  SaveChanges()
  -------------
  Commits all pending changes to the drive's stored items and updates parameters.
  Updates item counts, types, and description for UI.
  Increments SaveId for versioning.
]]
function Drive:SaveChanges()
  for i=1,#self._driveChanges do
    if self._driveChanges[i].Mode == 1 then
      self._driveStoredItems:Add(self._driveChanges[i].Item);
    else -- Mode == 2
      self._driveStoredItems:Remove(self._driveChanges[i].Item);
    end
  end
  self._drive.parameters.ItemCount = self._driveStoredItems:GetItemsCount();
  self._drive.parameters.ItemTypes = self._driveStoredItems:GetItemsTypes();
  self._drive.parameters.description = "Items stored: ".. self._driveStoredItems:GetItemsCount() .." / " .. self._drive.parameters.DriveParameters.Capacity .. "\nItem types: ".. self._driveStoredItems:GetItemsTypes() .." / ".. self._drive.parameters.DriveParameters.Types .. "\nPriority: " .. self._drive.parameters.Priority ;

  self._drive.parameters.SaveId = self._drive.parameters.SaveId + 1;
  if self._drive.parameters.SaveId > 1000000 then
    self._drive.parameters.SaveId = 0;
  end

  self._driveLastChanges = self._driveChanges;
  self._driveChanges = {};
end

--[[
  CancelChanges()
  ---------------
  Rolls back all pending changes, restoring the worktable to the previous state.
]]
function Drive:CancelChanges()
  for i=1,#self._driveChanges do
    if self._driveChanges[i].Mode == 1 then
      self._driveItemsWorktable:Remove(self._driveChanges[i].Item);
    else
      self._driveItemsWorktable:Add(self._driveChanges[i].Item);
    end
  end
  self._driveChanges = {};
end

--[[
  GetCurrentChanges()
  -------------------
  Returns the list of currently pending changes (not yet saved).
  @return (table): List of change tables {Mode, Item}
]]
function Drive:GetCurrentChanges()
  return self._driveChanges;
end

--[[
  GetLastChanges()
  ----------------
  Returns the list of changes from the last save operation.
  @return (table): List of change tables {Mode, Item}
]]
function Drive:GetLastChanges()
  return self._driveLastChanges;
end

--[[
  GetDriveUuid()
  --------------
  Returns the unique identifier for this drive.
  Uses:
    - sb.makeUuid(): Starbound API for UUIDs
  @return (string): The drive's UUID
]]
function Drive:GetDriveUuid()
  return self._drive.parameters.DriveUuid;
end

--[[
  UpdateDriveStatsByVal(driveParams, stat, times, value)
  -----------------------------------------------------
  Helper function to increment a drive stat by a value, multiple times.
  @param driveParams (table): Drive parameters
  @param stat (string): Stat name ("Capacity" or "Types")
  @param times (number): How many times to increment
  @param value (number): Value to add each time
]]
local function UpdateDriveStatsByVal(driveParams, stat, times, value)
  if times ~= 0 then
    for i = 1, times do
      driveParams[stat] = driveParams[stat] + value;
    end
  end
end

--[[
  RecalculateDriveSize(drive)
  --------------------------
  Recalculates the drive's capacity and type limits based on upgrades and base stats.
  Uses:
    - root.itemConfig: Reads item config (see world.md/root.md)
  @param drive (table): The drive item descriptor
  @return (table): The updated drive descriptor
]]
function RecalculateDriveSize(drive)
  local driveParams = drive.parameters.DriveParameters;
  if not driveParams.BaseStats then
    local config = root.itemConfig(drive.name);;
    driveParams.BaseStats = {};
    driveParams.BaseStats.Types = config.config.digitalstorage_drivedata.types;
    driveParams.BaseStats.Capacity = config.config.digitalstorage_drivedata.capacity;
  end

  driveParams.Types = driveParams.BaseStats.Types;
  driveParams.Capacity = driveParams.BaseStats.Capacity;
  local capMk1 = math.floor((driveParams.BaseStats.Capacity * 2) - (driveParams.BaseStats.Capacity / 8));
  local typMk1 = math.floor(driveParams.BaseStats.Types / 8);
  local capMk2 = math.floor((driveParams.BaseStats.Capacity + (capMk1 * 8)) - ((driveParams.BaseStats.Capacity + (capMk1 * 8)) / 4));
  local typMk2 = math.floor((driveParams.BaseStats.Types + typMk1 * 8) / 4);
  UpdateDriveStatsByVal(driveParams, "Capacity", driveParams.Upgrades.Mk1.Capacity, capMk1);
  UpdateDriveStatsByVal(driveParams, "Types", driveParams.Upgrades.Mk1.Types, typMk1);
  UpdateDriveStatsByVal(driveParams, "Capacity", driveParams.Upgrades.Mk2.Capacity, capMk2);
  UpdateDriveStatsByVal(driveParams, "Types", driveParams.Upgrades.Mk2.Types, typMk2);
  for i = 1, driveParams.Upgrades.Mk3.Capacity do
    driveParams.Capacity = driveParams.Capacity * 4;
  end
  for i = 1, driveParams.Upgrades.Mk3.Types do
    if driveParams.Types ~= 1 then
      driveParams.Types = driveParams.Types * 2;
    end
  end
  drive.parameters.DriveParameters = driveParams;
  drive.parameters.description = "Items stored: ".. drive.parameters.ItemCount .." / " .. driveParams.Capacity .. "\nItem types: ".. drive.parameters.ItemTypes .." / ".. driveParams.Types .. "\nPriority: " .. drive.parameters.Priority ;
  return drive;
end

--[[
  UpdateDriveVersion(drive)
  ------------------------
  Ensures the drive's parameters are up-to-date and formatted for the current version.
  Handles migration from older versions and initializes missing fields.
  Uses:
    - sb.makeUuid(): For unique IDs (see Starbound API)
    - os.clock(), os.time(): For entropy
    - RecalculateDriveSize: For stat recalculation
  @param drive (table): The drive item descriptor
  @return (table): The updated drive descriptor
]]
function UpdateDriveVersion(drive)
  local driveVersion = drive.parameters.Version or 0;
  if driveVersion < 1 then
    if not drive.parameters.DriveFormatted then
      drive.parameters.ItemCount = 0;
      drive.parameters.ItemTypes = 0;
      drive.parameters.DriveFormatted = true;
      drive.parameters.Data = {};
      drive.parameters.DriveUuid = sb.makeUuid() .. tostring(os.clock()) .. tostring(os.time());
      drive.parameters.description = "Items stored: ".. 0 .." / " .. 8192 .. "\nItem types: ".. 0 .." / ".. 64 .. "\nPriority: " .. 0 ;
    end
    if not drive.parameters.DriveParameters then
      drive.parameters.DriveParameters = {};
    end
    if not drive.parameters.DriveParameters.Upgrades then
      drive.parameters.DriveParameters.Upgrades = {};
      drive.parameters.DriveParameters.Upgrades.Mk1 = {Capacity = 0, Types = 0};
      drive.parameters.DriveParameters.Upgrades.Mk2 = {Capacity = 0, Types = 0};
      drive.parameters.DriveParameters.Upgrades.Mk3 = {Capacity = 0, Types = 0};
    end
    if not drive.parameters.Priority then
      drive.parameters.Priority = 0;
    end
    driveVersion = 1;
  end
  if driveVersion < 2 then
    drive.parameters.SaveId = 0;
    drive = RecalculateDriveSize(drive);
    driveVersion = 2;
  end
  if driveVersion < 3 then
    driveVersion = 3;
  end
  drive.parameters.Version = driveVersion;
  return drive;
end
