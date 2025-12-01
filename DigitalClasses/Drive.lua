require "/HLib/Classes/Class.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Classes/Item/Item.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"
require "/HLib/Classes/Other/MutexSecure.lua"
require "/HLib/Classes/Filters/FilterGroup.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/scripts/util.lua"
Drive = Class(MutexSecure);

function Drive:_init(item)
  MutexSecure._init(self);
  self._drive = item;
  self._driveStoredItems = ItemsTable();
  self._driveChanges = {};
  self._driveLastChanges = {};
  self._driveItemsWorktable = ItemsTable();
  self._driveItemsLoaded = false;
  self._changes = {};
  self._driveFilters = nil;
  UpdateDriveVersion(self._drive);
  self:LoadItems();

end

function Drive:GetDrive()
  return self._drive;
end

function Drive:LoadItems()
  local firstindex, _ = next(self._drive.parameters.Data or {});
  if firstindex == nil then
  elseif type(firstindex) == "number" then
    for i, v in pairs(self._drive.parameters.Data) do

      self._driveStoredItems:Add(Item(v,true));
      self._driveItemsWorktable:Add(Item(v,true));
    end
  else
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

function Drive:RemoveItem(item, match)
  local comparer = nil
  if match ~= nil and not match then
    comparer = function(x,y) return ItemWrapper.Compare(x,y,false) end
  end
  local result = ItemWrapper.CopyItem(item);
  ItemWrapper.SetItemCount(result,0)
  local slot = self._driveItemsWorktable:FindFlattened(item, comparer);
  if not slot then
    return result;
  end
  result = self._driveItemsWorktable:Remove(item, comparer);
  local tmpitem = ItemWrapper.CopyItem(item);
  if result then
    tmpitem = ItemWrapper.CopyItem(result);
  end
  self._driveChanges[#self._driveChanges + 1] = {Mode = 2; Item = tmpitem};
  return result;
end

function Drive:LoadFilters()
  self._driveFilters = FilterGroup(self._drive.parameters.Filters or {});
end

function Drive:FiltersAllow(item)
  return self._driveFilters:IsItemAllowed(item);
end

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

function Drive:GetCurrentChanges()
  return self._driveChanges;
end
function Drive:GetLastChanges()
  return self._driveLastChanges;
end

function Drive:GetDriveUuid()
  return self._drive.parameters.DriveUuid;
end

local function UpdateDriveStatsByVal(driveParams, stat, times, value)
  if times ~= 0 then
    for i = 1, times do
      driveParams[stat] = driveParams[stat] + value;
    end
  end
end

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
