require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Scripts/AdditionalFunctions.lua"
require "/HLib/Classes/GUIElements/Itemslot.lua"
require "/HLib/Classes/Other/LoadData.lua"
require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/HLib/Classes/Tasks/TaskOperator.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/GUIElements/ListFlat.lua"

local function SaveData()
  Messenger().SendMessageNoResponse(self._parentEntityId, "Save", {Filters = self.FiltersList:GetList();ConfigCard = self.ConfigSlot:GetItem();ImportSpeedCard = self.ImportSpeedUpgrade:GetItem(); ExportSpeedCard = self.ExportSpeedUpgrade:GetItem()});
end

function update()
  if self._responseLoader:Call() then
    local data = self._responseLoader:GetData();
    if not data then
      return;
    end
    self.FiltersList:EmptyList();
    self.FiltersList:AddList(data.Filters or {});
    self.ConfigSlot:SetItem(data.ConfigCard);
    if data.ConfigCard then
      widget.setVisible("tabs.tabs.config.renameCard",true);
      widget.setText("tabs.tabs.config.renameCard",data.ConfigCard.ItemDescriptor.parameters.shortdescription or "");
    end
    self.ImportSpeedUpgrade:SetItem(data.ImportSpeedCard);
    self.ExportSpeedUpgrade:SetItem(data.ExportSpeedCard);
    widget.setVisible("tabs", true);
    script.setUpdateDelta(0);
  end
end

function uninit()
  Messenger().SendMessageNoResponse(self._parentEntityId, "GUIClosed");
end

function init()
  self._parentEntityId = pane.containerEntityId();
  Messenger().SendMessageNoResponse(self._parentEntityId, "GUIOpened");

  self._responseLoader = LoadData(self._parentEntityId, "Load");
  script.setUpdateDelta(1);

  self.SlotList = ListFlat("tabs.tabs.config.basicDetails.slotsArea.slotsList",
  function (listItem, item)
    widget.setText(string.format("%s.slots", listItem), item);
  end);

  self.FiltersList = ListFlat("tabs.tabs.config.filterArea.filterList",
  function (listItem, item)
    widget.setText(string.format("%s.textFilter", listItem), item.DisplayName);
    if item.Mode == "None" then
      widget.setImage(string.format("%s.mode", listItem), "/Objects/TransferNode/digitalstorage_transfernodeFilterNone.png");
    elseif item.Mode == "Import" then
      widget.setImage(string.format("%s.mode", listItem), "/Objects/TransferNode/digitalstorage_transfernodeFilterImport.png");
    else
      widget.setImage(string.format("%s.mode", listItem), "/Objects/TransferNode/digitalstorage_transfernodeFilterExport.png");
    end

  end);

  self.ConfigSlot = Itemslot("tabs.tabs.config.configCard");
  self.ConfigSlot:SetFilterFunction(
  function (item)
    return item.ItemDescriptor.name == "digitalstorage_configcard";
  end);
  self.ConfigSlot:SetItemLimit(1);

  self.ItemSlot = Itemslot("tabs.tabs.config.filterCard", true);

  self.ItemSlot:SetItemLimit(1);

  self.ActivationItem = Itemslot("tabs.tabs.config.basicDetails.item.activationItem", true);

  self.ItemSlot:SetItemLimit(1);



  self.ImportSpeedUpgrade = Itemslot("tabs.tabs.upgrades.importUpgradeSpeedSlot");
  self.ImportSpeedUpgrade:SetFilterFunction(
  function (item)
    return item.ItemDescriptor.name == "digitalstorage_speedcard";
  end);
  self.ExportSpeedUpgrade = Itemslot("tabs.tabs.upgrades.exportUpgradeSpeedSlot");
  self.ExportSpeedUpgrade:SetFilterFunction(
  function (item)
    return item.ItemDescriptor.name == "digitalstorage_speedcard";
  end);
end

function configCard()
  self.ConfigSlot:Click();
  local configCard = self.ConfigSlot:GetItem();
  if configCard then
    widget.setVisible("tabs.tabs.config.renameCard",true);
    widget.setText("tabs.tabs.config.renameCard",configCard.ItemDescriptor.parameters.shortdescription or "");
  else
    widget.setVisible("tabs.tabs.config.renameCard",false);
  end
  SaveData();
end

function saveConfig()
  local configCard = self.ConfigSlot:GetItem();
  if not configCard then
    return;
  end
  local filters = self.FiltersList:GetList();
  configCard.ItemDescriptor.parameters.Type = "Transfer Node data";
  configCard.ItemDescriptor.parameters.Data = filters;
  configCard.ItemDescriptor.parameters.SourceEntity = "TransferNode"
  configCard.ItemDescriptor.parameters.description = "Contains "..#filters.." filter(s)";
  self.ConfigSlot:SetItem(configCard);
  SaveData();
end

function loadConfig()
  local configCard = self.ConfigSlot:GetItem();
  if not configCard then
    return;
  end
  if configCard.ItemDescriptor.parameters.Type == "Transfer Node data" then
    self.FiltersList:EmptyList();
    self.FiltersList:AddList(configCard.ItemDescriptor.parameters.Data);
    SaveData();
  end
end

function renameCard ()
  local configCard = self.ConfigSlot:GetItem();
  if not configCard then
    return;
  end
  local newname = widget.getText("tabs.tabs.config.renameCard");
  if newname == "" then
    newname = nil;
  end
  if configCard.ItemDescriptor.parameters.shortdescription ~= newname then
    configCard.ItemDescriptor.parameters.shortdescription = newname;
    self.ConfigSlot:SetItem(configCard);
    SaveData();
  end
end

function filterCard()
  self.ItemSlot:Click();
end

function TransformIntoFilter(item)
  return Item(
  {
    parameters = {
      Filters = {
        Mode = "Whitelist";
        ItemFilters = {
          item.ItemDescriptor;
        };
        TextFilters = {
        }
      };
      description = "Card designed to store filters.\n(Formatted)";
      shortdescription = item.DisplayName;
    };
    count = 1;
    name = "digitalstorage_filtercard";
  });
end

function addFilterCard()
  local item = self.ItemSlot:GetItem();
  if not item then
    return ;
  end
  local filter = nil;
  if item.ItemDescriptor.name == "digitalstorage_filtercard" then
    filter = item;
  else
    filter = TransformIntoFilter(item);
  end
  local filter2 = {};
  filter2.DisplayName = filter.ItemDescriptor.parameters.shortdescription or filter.DisplayName;
  filter2.Filters = filter.ItemDescriptor.parameters.Filters;
  filter2.Mode = "None";
  filter2.AdditionalData = {};
  filter2.ActivationMode = "Manual";
  filter2.ActivationData = "Off";
  filter2.Uuid = sb.makeUuid();
  filter2.Slots = {};
  filter2.SlotMode = "Not Inverted";
  self.FiltersList:AddListItem(filter2);
  self.ItemSlot:SetItem();
  SaveData();
end

function removeFilterCard()
  local selected = self.FiltersList:GetSelected();
  if selected == nil then
    return;
  end
  self.FiltersList:RemoveListItem(selected);
  SaveData();
end

local function SetActivationDataFromFilter(mode,data)
  self._activation = mode;
  widget.setText("tabs.tabs.config.basicDetails.activationModeChange", mode);
  if mode == "Manual" then
    self._manualStateChange = data;
    widget.setText("tabs.tabs.config.basicDetails.manual.manualStateChange", data);
    widget.setVisible("tabs.tabs.config.basicDetails.manual", true);
    widget.setVisible("tabs.tabs.config.basicDetails.wire", false);
    widget.setVisible("tabs.tabs.config.basicDetails.item", false);
  elseif mode == "Wire" then
    self._wireStateChange = data;
    widget.setText("tabs.tabs.config.basicDetails.wire.wireStateChange", data);
    widget.setVisible("tabs.tabs.config.basicDetails.manual", false);
    widget.setVisible("tabs.tabs.config.basicDetails.wire", true);
    widget.setVisible("tabs.tabs.config.basicDetails.item", false);
  else
    widget.setVisible("tabs.tabs.config.basicDetails.manual", false);
    widget.setVisible("tabs.tabs.config.basicDetails.wire", false);
    widget.setVisible("tabs.tabs.config.basicDetails.item", true);
    self._comapre = data.Compare;
    widget.setText("tabs.tabs.config.basicDetails.item.compare", data.Compare);
    self._count = data.Count;
    widget.setText("tabs.tabs.config.basicDetails.item.how_many", data.Count);
    self.ActivationItem:SetItem(data.Item);
  end
end

local function SetAdditionalSettingsForMode(selected)

  if selected.Mode == "Export" then
    SetUpToCount(selected.AdditionalData.UpToCount);
    SetExportMode(selected.AdditionalData.UpToMode);
    SetMultipleCount(selected.AdditionalData.MultipleCount);
  elseif selected.Mode == "Import" then
    SetLeaveCount(selected.AdditionalData.LeaveCount);
  end
end

local function DisplayAdditionalSettings(mode)
  if mode == "Export" then
    widget.setVisible("tabs.tabs.config.additionalDetails.import", false);
    widget.setVisible("tabs.tabs.config.additionalDetails.export", true);
  elseif mode == "Import" then
    widget.setVisible("tabs.tabs.config.additionalDetails.import", true);
    widget.setVisible("tabs.tabs.config.additionalDetails.export", false);
  else
    widget.setVisible("tabs.tabs.config.additionalDetails.import", false);
    widget.setVisible("tabs.tabs.config.additionalDetails.export", false);
  end
end

function filter()
  local selected = self.FiltersList:GetSelected();
  widget.setVisible("tabs.tabs.config.additionalDetails", false);
  if selected then
    widget.setVisible("tabs.tabs.config.basicDetails", true);
    self._filterModeChange = selected.Mode;
    widget.setText("tabs.tabs.config.basicDetails.filterModeChange", selected.Mode);
    SetActivationDataFromFilter(selected.ActivationMode , selected.ActivationData);
    SetInvert(selected.SlotMode);
    self.SlotList:EmptyList();
    self.SlotList:AddList(selected.Slots);
    DisplayAdditionalSettings(selected.Mode);
    SetAdditionalSettingsForMode(selected);
  else
    widget.setVisible("tabs.tabs.config.basicDetails", false);
  end
end


--#region Additional Settings

function SetLeaveCount(count)
  widget.setText("tabs.tabs.config.additionalDetails.import.leave_count", count);
  local selected = self.FiltersList:GetSelected();
  selected.AdditionalData.LeaveCount = count;
  SaveData();
end
function  leave_count ()
  local number = widget.getText("tabs.tabs.config.additionalDetails.import.leave_count");
  if number and number ~= "" then
    number = tonumber(number);
    if self.FiltersList:GetSelected().AdditionalData.LeaveCount ~= number then
      SetLeaveCount(number);
    end
  end
end
function SetUpToCount(count)
  widget.setText("tabs.tabs.config.additionalDetails.export.upTo_count", count);
  local selected = self.FiltersList:GetSelected();
  selected.AdditionalData.UpToCount = count;
  SaveData();
end
function  upTo_count ()
  local number = widget.getText("tabs.tabs.config.additionalDetails.export.upTo_count");
  if number and number ~= "" then
    number = tonumber(number);
    if self.FiltersList:GetSelected().AdditionalData.UpToCount ~= number then
      SetUpToCount(number);
    end
  end
end

function SetExportMode(stat)

  widget.setText("tabs.tabs.config.additionalDetails.export.exportMode", stat);
  local selected = self.FiltersList:GetSelected();
  selected.AdditionalData.UpToMode = stat;
  SaveData();
end
function  exportMode ()
  if self.FiltersList:GetSelected().AdditionalData.UpToMode == "Container" then
    SetExportMode("Per Slot");
  else
    SetExportMode("Container");
  end
end

function SetMultipleCount(count)
  widget.setText("tabs.tabs.config.additionalDetails.export.multiple_count", count);
  local selected = self.FiltersList:GetSelected();
  selected.AdditionalData.MultipleCount = count;
  SaveData();
end
function  multiple_count()
  local number = widget.getText("tabs.tabs.config.additionalDetails.export.multiple_count");
  if number and number ~= "" then
    number = tonumber(number);
    if self.FiltersList:GetSelected().AdditionalData.MultipleCount ~= number then
      SetMultipleCount(number);
    end
  end
end

--#endregion

--#region Filter Mode

local function SetDefaultAdditionalSettingsForMode(mode)
  local selected = self.FiltersList:GetSelected();
  selected.AdditionalData = {};
  if mode == "Export" then
    selected.AdditionalData.UpToCount = 0;
    selected.AdditionalData.UpToMode = "Container";
    selected.AdditionalData.MultipleCount = 0;
    SetUpToCount(selected.AdditionalData.UpToCount);
    SetExportMode(selected.AdditionalData.UpToMode);
    SetMultipleCount(selected.AdditionalData.MultipleCount);
  elseif mode == "Import" then
    selected.AdditionalData.LeaveCount = 0;
    SetLeaveCount(selected.AdditionalData.LeaveCount);
  end
end

function SetFilterModeChange(stat)
  self._filterModeChange = stat;
  widget.setText("tabs.tabs.config.basicDetails.filterModeChange", stat);
  local selected = self.FiltersList:GetSelected();
  selected.Mode = stat;
  self.FiltersList:UpdateListItem(selected);
  DisplayAdditionalSettings(selected.Mode);
  SetDefaultAdditionalSettingsForMode(selected.Mode);
  SaveData();
end

function filterModeChange()
  if self._filterModeChange == "None" then
    SetFilterModeChange("Import");
  elseif self._filterModeChange == "Import" then
    SetFilterModeChange("Export");
  else
    SetFilterModeChange("None");
  end
end

--#endregion

--#region  activation

function activationItem()
  self.ActivationItem:Click();
  local selected = self.FiltersList:GetSelected();
  local item = self.ActivationItem:GetItem()
  selected.ActivationData.Item = item;
  SaveData();
end

function SetHowMany(num)
  self._count = num;
  widget.setText("tabs.tabs.config.basicDetails.item.how_many",num)
  local selected = self.FiltersList:GetSelected();
  selected.ActivationData.Count = num;
  SaveData();
end

function how_many()
  local number = widget.getText("tabs.tabs.config.basicDetails.item.how_many");
  if number and number ~= "" then
    number = tonumber(number);
    if self._count ~= number then
      SetHowMany(number);
    end
  end
end

function SetCompare(stat)
  self._comapre = stat;
  widget.setText("tabs.tabs.config.basicDetails.item.compare", stat);
  local selected = self.FiltersList:GetSelected();
  selected.ActivationData.Compare = stat;
  SaveData();
end

function compareVal()
  if self._comapre == "<=" then
    SetCompare(">=");
  else
    SetCompare("<=");
  end
end

function SetManualStateChange(stat)
  self._manualStateChange = stat;
  widget.setText("tabs.tabs.config.basicDetails.manual.manualStateChange", stat);
  local selected = self.FiltersList:GetSelected();
  selected.ActivationData = stat;
  SaveData();
end

function manualStateChange ()
  if self._manualStateChange == "Off" then
    SetManualStateChange("On");
  else
    SetManualStateChange("Off");
  end
end

function SetWireStateChange(stat)
  self._wireStateChange = stat;
  widget.setText("tabs.tabs.config.basicDetails.wire.wireStateChange", stat);
  local selected = self.FiltersList:GetSelected();
  selected.ActivationData = stat;
  SaveData();
end

function wireStateChange ()
  if self._wireStateChange == "Normal" then
    SetWireStateChange("Inverted");
  else
    SetWireStateChange("Normal");
  end
end



function SetActivationMode(stat)
  self._activation = stat;
  widget.setText("tabs.tabs.config.basicDetails.activationModeChange", stat);
  local selected = self.FiltersList:GetSelected();
  selected.ActivationMode = stat;
  SaveData();
end

function activationModeChange()
  if self._activation == "Manual" then
    widget.setVisible("tabs.tabs.config.basicDetails.manual", false);
    widget.setVisible("tabs.tabs.config.basicDetails.wire", true);
    widget.setVisible("tabs.tabs.config.basicDetails.item", false);
    SetActivationMode("Wire");
    SetWireStateChange("Normal");
  elseif self._activation == "Wire" then
    widget.setVisible("tabs.tabs.config.basicDetails.manual", false);
    widget.setVisible("tabs.tabs.config.basicDetails.wire", false);
    widget.setVisible("tabs.tabs.config.basicDetails.item", true);
    SetActivationMode("Item");
    local selected = self.FiltersList:GetSelected();
    selected.ActivationData = {};
    SetCompare("<=");
    SetHowMany(0);
    self.ActivationItem:SetItem(nil);
  else
    widget.setVisible("tabs.tabs.config.basicDetails.manual", true);
    widget.setVisible("tabs.tabs.config.basicDetails.wire", false);
    widget.setVisible("tabs.tabs.config.basicDetails.item", false);
    SetActivationMode("Manual");
    SetManualStateChange("Off");
  end
end

--#endregion

--#region  Slots

function SetInvert(stat)
  self._invert = stat;
  widget.setText("tabs.tabs.config.basicDetails.invertMode", stat);
  local selected = self.FiltersList:GetSelected();
  selected.SlotMode = stat;
  SaveData();
end

function invertMode()
  if self._invert == "Not Inverted" then
    SetInvert("Inverted");
  else
    SetInvert("Not Inverted");
  end
end

function removeSlot()
  local selected = self.SlotList:GetSelected();
  if selected == nil then
    return;
  end
  self.SlotList:RemoveListItem(selected);
  local selected = self.FiltersList:GetSelected();
  selected.Slots = self.SlotList:GetList();
  SaveData();
end

function addSlot()
  local slot = widget.getText("tabs.tabs.config.basicDetails.slot");
  if slot == "" or slot == nil then
    return false;
  end
  slot = tonumber(slot);
  widget.setText("tabs.tabs.config.basicDetails.slot", slot + 1);
  local cardSlots = self.SlotList:GetList();
  for k, v in pairs(cardSlots) do
    if v == slot then
      return false;
    end
  end
  cardSlots[#cardSlots + 1] = slot;
  table.sort(cardSlots);
  self.SlotList:EmptyList();
  self.SlotList:AddList(cardSlots);
  self.SlotList:RefreshDisplay();
  local selected = self.FiltersList:GetSelected();
  selected.Slots = cardSlots;
  SaveData();
end

--#endregion



function additionalSettings()
  widget.setVisible("tabs.tabs.config.basicDetails", false);
  widget.setVisible("tabs.tabs.config.additionalDetails", true);

end

function back()
  widget.setVisible("tabs.tabs.config.basicDetails", true);
  widget.setVisible("tabs.tabs.config.additionalDetails", false);
end

function importUpgradeSpeedSlot()
  self.ImportSpeedUpgrade:Click();
  SaveData();
end

function exportUpgradeSpeedSlot()
  self.ExportSpeedUpgrade:Click();
  SaveData();
end
