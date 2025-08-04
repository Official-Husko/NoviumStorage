require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Scripts/AdditionalFunctions.lua"
require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Classes/Other/LoadData.lua"
require "/HLib/Classes/GUIElements/Itemslot.lua"
require "/HLib/Classes/Item/Item.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"
require "/DigitalClasses/Drive.lua"
local self = {};


function RefreshUI(state)
  widget.setVisible("filter", state);
  widget.setVisible("capT1", state);
  widget.setVisible("capT2", state);
  widget.setVisible("capT3", state);
  widget.setVisible("sizeT1", state);
  widget.setVisible("sizeT2", state);
  widget.setVisible("sizeT3", state);
  widget.setVisible("mk1", state);
  widget.setVisible("mk2", state);
  widget.setVisible("mk3", state);
  widget.setVisible("priority", state);
end

function Save()
  Messenger().SendMessageNoResponse(self._parentEntityId, "Save", {Drive = self.Drive:GetItem()});
end

function FillUI()

  local drive = self.Drive:GetItem();
  RefreshUI(drive ~= nil);
  if drive then
    local filter = drive.ItemDescriptor.parameters.Filters;
    if filter then
      local filterItem = Item({name = "digitalstorage_filtercard";count = 1;parameters = {Filters = filter}});
      if (filter.ItemFilters and next(filter.ItemFilters)) or (filter.TextFilters and next(filter.TextFilters)) then
        filterItem.ItemDescriptor.parameters.description = filterItem.Config.config.description .. "\n(Formatted)";
      end
      self.Filter:SetItem(filterItem);
    end
    local upgrades = drive.ItemDescriptor.parameters.DriveParameters.Upgrades;
    if upgrades.Mk1.Capacity ~= 0 then
      self.CapT1:SetItem(Item({name = "digitalstorage_capacitycard";count = upgrades.Mk1.Capacity;parameters = {}}));
    end
    if upgrades.Mk2.Capacity ~= 0 then
      self.CapT2:SetItem(Item({name = "digitalstorage_capacitycard_mk2";count = upgrades.Mk2.Capacity;parameters = {}}));
      self.SizeT2:SetItemLimit(4 - upgrades.Mk2.Capacity);
    end
    if upgrades.Mk3.Capacity ~= 0 then
      self.CapT3:SetItem(Item({name = "digitalstorage_capacitycard_mk3";count = upgrades.Mk3.Capacity;parameters = {}}));
      self.SizeT3:SetItemLimit(2 - upgrades.Mk3.Capacity);
    end
    if upgrades.Mk1.Types ~= 0 then
      self.SizeT1:SetItem(Item({name = "digitalstorage_typescard";count = upgrades.Mk1.Types;parameters = {}}));
    end
    if upgrades.Mk2.Types ~= 0 then
      self.SizeT2:SetItem(Item({name = "digitalstorage_typescard_mk2";count = upgrades.Mk2.Types;parameters = {}}));
      self.CapT2:SetItemLimit(4 - upgrades.Mk2.Types);
    end
    if upgrades.Mk3.Types ~= 0 then
      self.SizeT3:SetItem(Item({name = "digitalstorage_typescard_mk3";count = upgrades.Mk3.Types;parameters = {}}));
      self.CapT3:SetItemLimit(2 - upgrades.Mk3.Types);
    end

    if drive.ItemDescriptor.parameters.Priority then
      widget.setText("priority", drive.ItemDescriptor.parameters.Priority);
    else
      widget.setText("priority", 0);
    end
  end
end

function update()
  if self._responseLoader:Call() then
    local data = self._responseLoader:GetData();
    if not data then
      return;
    end
    self.Drive:SetItem(data.Drive);
    FillUI();
    Save();
    script.setUpdateDelta(0);
  end
end

function CleanupUI()
  self.CapT1:SetItem();
  self.SizeT1:SetItem();
  self.CapT2:SetItemLimit(4);
  self.CapT2:SetItem();
  self.SizeT2:SetItemLimit(4);
  self.SizeT2:SetItem();
  self.CapT3:SetItemLimit(2);
  self.CapT3:SetItem();
  self.SizeT3:SetItemLimit(2);
  self.SizeT3:SetItem();
  self.Filter:SetItem();
  -- widget.setText("priority",0);
end

function drive()
  self.Drive:Click();
  local drive = self.Drive:GetItem();
  if drive then
    local drivedesc = drive.ItemDescriptor;
    UpdateDriveVersion(drivedesc);
    RecalculateDriveSize(drivedesc);
    self.Drive:SetItem(drive);
  end
  CleanupUI();
  FillUI();
  Save();
end

function filter()
  if self.Drive:GetItem() then
    self.Filter:Click();
    local filter = self.Filter:GetItem();
    if filter then
      self.Drive:GetItem().ItemDescriptor.parameters.Filters = filter.ItemDescriptor.parameters.Filters;
    else
      self.Drive:GetItem().ItemDescriptor.parameters.Filters = nil;
    end
    Save();
  end
end

function priority()
  local drive = self.Drive:GetItem();
  if drive then
    local pri = widget.getText("priority");
    if pri == "" then
      pri = 0;
    end
    pri = tonumber(pri);
    drive.ItemDescriptor.parameters.Priority = pri;
    drive = RecalculateDriveSize(drive.ItemDescriptor);
    self.Drive:SetItem(drive);
    Save();
  end
end

function init()

  self._parentEntityId = pane.containerEntityId();
  self._responseLoader = LoadData(self._parentEntityId, "Load");

  self.Drive = Itemslot("drive", false);
  self.Drive:SetFilterFunction(
  function (item)
    return item.ItemDescriptor.name == "digitalstorage_datadrive";
  end);
  self.Drive:SetItemLimit(1);
  self.Filter = Itemslot("filter", false);
  self.Filter:SetFilterFunction(
  function (item)
    return item.ItemDescriptor.name == "digitalstorage_filtercard" and item.ItemDescriptor.parameters.Filters;
  end);
  self.Filter:SetItemLimit(1);

  self.CapT1 = Itemslot("capT1", false);
  self.CapT1:SetFilterFunction(
  function (item)
    return item.ItemDescriptor.name == "digitalstorage_capacitycard";
  end);
  self.CapT1:SetItemLimit(8);
  self.CapT2 = Itemslot("capT2", false);
  self.CapT2:SetFilterFunction(
  function (item)
    return item.ItemDescriptor.name == "digitalstorage_capacitycard_mk2";
  end);
  self.CapT2:SetItemLimit(4);
  self.CapT3 = Itemslot("capT3", false);
  self.CapT3:SetFilterFunction(
  function (item)
    return item.ItemDescriptor.name == "digitalstorage_capacitycard_mk3";
  end);
  self.CapT3:SetItemLimit(2);
  self.SizeT1 = Itemslot("sizeT1", false);
  self.SizeT1:SetFilterFunction(
  function (item)
    return item.ItemDescriptor.name == "digitalstorage_typescard";
  end);
  self.SizeT1:SetItemLimit(8);
  self.SizeT2 = Itemslot("sizeT2", false);
  self.SizeT2:SetFilterFunction(
  function (item)
    return item.ItemDescriptor.name == "digitalstorage_typescard_mk2";
  end);
  self.SizeT2:SetItemLimit(4);
  self.SizeT3 = Itemslot("sizeT3", false);
  self.SizeT3:SetFilterFunction(
  function (item)
    return item.ItemDescriptor.name == "digitalstorage_typescard_mk3";
  end);
  self.SizeT3:SetItemLimit(2);
  script.setUpdateDelta(1);
end

local function ValidateClick(drive)

  if not drive then
    return false;
  end
  if not player.swapSlotItem() and drive.ItemDescriptor.parameters.ItemCount ~= 0 then
    return false;
  end
  return true;
end

function capT1()
  local drive = self.Drive:GetItem();
  if not ValidateClick(drive) then
    return;
  end
  self.CapT1:Click();
  local item = self.CapT1:GetItem();
  if item then
    drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk1.Capacity = ItemWrapper.GetItemCount(item) ;
  else
    drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk1.Capacity = 0 ;
  end
  drive = RecalculateDriveSize(drive.ItemDescriptor);
  self.Drive:SetItem(drive);
  Save();
end

function sizeT1()
  local drive = self.Drive:GetItem();
  if not ValidateClick(drive) then
    return;
  end
  self.SizeT1:Click();
  local item = self.SizeT1:GetItem();
  if item then
    drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk1.Types = ItemWrapper.GetItemCount(item) ;
  else
    drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk1.Types = 0 ;
  end
  drive = RecalculateDriveSize(drive.ItemDescriptor);
  self.Drive:SetItem(drive);
  Save();
end
function capT2()
  local drive = self.Drive:GetItem();
  if not ValidateClick(drive) then
    return;
  end
  self.CapT2:Click();
  local item = self.CapT2:GetItem();
  if item then
    drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk2.Capacity = ItemWrapper.GetItemCount(item) ;
  else
    drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk2.Capacity = 0 ;
  end
  self.SizeT2:SetItemLimit(4 - drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk2.Capacity);
  drive = RecalculateDriveSize(drive.ItemDescriptor);
  self.Drive:SetItem(drive);
  Save();
end
function sizeT2()
  local drive = self.Drive:GetItem();
  if not ValidateClick(drive) then
    return;
  end
  self.SizeT2:Click();
  local item = self.SizeT2:GetItem();
  if item then
    drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk2.Types = ItemWrapper.GetItemCount(item) ;
  else
    drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk2.Types = 0 ;
  end
  self.CapT2:SetItemLimit(4 - drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk2.Types);
  drive = RecalculateDriveSize(drive.ItemDescriptor);
  self.Drive:SetItem(drive);
  Save();
end
function capT3()
  local drive = self.Drive:GetItem();
  if not ValidateClick(drive) then
    return;
  end
  self.CapT3:Click();
  local item = self.CapT3:GetItem();
  if item then
    drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk3.Capacity = ItemWrapper.GetItemCount(item) ;
  else
    drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk3.Capacity = 0 ;
  end
  self.SizeT3:SetItemLimit(2 - drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk3.Capacity);
  drive = RecalculateDriveSize(drive.ItemDescriptor);
  self.Drive:SetItem(drive);
  Save();
end
function sizeT3()
  local drive = self.Drive:GetItem();
  if not ValidateClick(drive) then
    return;
  end
  self.SizeT3:Click();
  local item = self.SizeT3:GetItem();
  if item then
    drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk3.Types = ItemWrapper.GetItemCount(item) ;
  else
    drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk3.Types = 0 ;
  end
  self.CapT3:SetItemLimit(2 - drive.ItemDescriptor.parameters.DriveParameters.Upgrades.Mk3.Types);
  drive = RecalculateDriveSize(drive.ItemDescriptor);
  self.Drive:SetItem(drive);
  Save();
end
