require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Scripts/AdditionalFunctions.lua"
require "/HLib/Classes/GUIElements/ListFlat.lua"
require "/HLib/Classes/GUIElements/Itemslot.lua"
require "/HLib/Classes/GUIElements/ListDoubleClick.lua"
require "/HLib/Classes/Other/LoadData.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"

local self = {};

function clear()

  SetMode("Blacklist");
  self._itemList:EmptyList();
  self._textList:EmptyList();
  widget.setText("rename","");
end

function UpdateUIVisibility(state)
  -- widget.setVisible("save", state);
  widget.setVisible("changeMode", state);
  widget.setVisible("clear", state);
  widget.setVisible("rename", state);
  widget.setVisible("tabs", state);
  widget.setVisible("modeLabel", state);
end

function GUIUpdate()
  local card = self._filtercardSlot:GetItem();
  if card then
    local params = card.ItemDescriptor.parameters;
    local name = params.shortdescription;
    if params.Filters ~= nil and next(params.Filters) then
      clear();
      SetMode(params.Filters.Mode);
      for _, item in pairs(params.Filters.ItemFilters) do
        self._itemList:AddListItem(Item(item));
      end
      for _, text in pairs(params.Filters.TextFilters) do
        self._textList:AddListItem(text);
      end
    end
    widget.setText("rename",name or "");
    UpdateUIVisibility(true);
  else
    UpdateUIVisibility(false);
    clear();
  end
end

function reset()
  self._tasksManager:GetTaskOperator("GUIUpdates"):AddTask(Task(coroutine.create(GUIUpdate)));
  script.setUpdateDelta(2)
end

function SaveCard()
  Messenger().SendMessageNoResponse(self._parentEntityId, "SaveItem", self._filtercardSlot:GetItem());
end

function filterCardCallback()
  self._filtercardSlot:Click();
  reset();
  SaveCard();
end

function update()
  self._limiter:Restart();
  self._tasksManager:Restart();
  if self._dataLoader:Call() then
    local data = self._dataLoader:GetData();
    if not data then
      return;
    end
    if next(data) ~= nil then
      self._filtercardSlot:SetItem(data);
    end
    self._tasksManager:GetTaskOperator("GUIUpdates"):AddTask(Task(coroutine.create(GUIUpdate)));
  end
  self._tasksManager:LaunchTaskOperator("GUIUpdates");
  if not self._tasksManager.LaunchedAnyTask and self._dataLoader:DataLoaded() then
    script.setUpdateDelta(0);
  end
end

function changeMode()
  if self._currentMode == "Blacklist" then
    SetMode("Whitelist");
  else
    SetMode("Blacklist");
  end
  save()
end
function SetMode(mode)
  widget.setText("changeMode", mode);
  self._currentMode = mode;
end


function save()
  local cardslot = self._filtercardSlot:GetItem();
  if not cardslot then
    return;
  end
  if #self._itemList:GetList() == 0 and #self._textList:GetList() == 0 and widget.getText("changeMode") == "Blacklist" then
    cardslot.ItemDescriptor.parameters.Filters = nil;
    cardslot.ItemDescriptor.parameters.description = nil;
  else
    cardslot.ItemDescriptor.parameters.Filters = {};
    cardslot.ItemDescriptor.parameters.Filters.Mode = self._currentMode;
    cardslot.ItemDescriptor.parameters.Filters.ItemFilters = {};
    cardslot.ItemDescriptor.parameters.Filters.TextFilters = {};
    if #self._itemList:GetList() ~= 0 then
      for itemId, item in pairs(self._itemList:GetList()) do
        --GenerateChildTables(cardslot.ItemDescriptor.parameters.Filters.ItemFilters, item.ItemIndex);
        table.insert(cardslot.ItemDescriptor.parameters.Filters.ItemFilters, ItemWrapper.CopyItemDescriptor(item));
      end
    end
    if #self._textList:GetList() ~= 0 then
      for textId, text in pairs(self._textList:GetList()) do
        table.insert(cardslot.ItemDescriptor.parameters.Filters.TextFilters, text);
      end
    end
    cardslot.ItemDescriptor.parameters.description = cardslot.Config.config.description .. "\n(Formatted)";
  end

  local newName = nil;
  local tmptext = widget.getText("rename") or "";
  if tmptext ~= "" then
    newName = tmptext;
  end
  cardslot.ItemDescriptor.parameters.shortdescription = newName;

  self._filtercardSlot:SetItem(cardslot);
  SaveCard();
end

function newItemFilterCallback()
  widget.setItemSlotItem("tabs.tabs.item.newItemFilter", player.swapSlotItem());
end

function rename()
  save()
end
function removeItemFilter()
  -- local index = self._itemList:GetSelectedIndex();
  -- if index then
  --   self._itemList:RemoveItem(index);
  -- end

  self._itemList:RemoveListItem(self._itemList:GetSelected());
  save()
end

function removeTextFilter()
  -- local index = self._textList:GetSelectedIndex();
  -- if index then
  --   self._textList:RemoveItem(index);
  -- end

  self._textList:RemoveListItem(self._textList:GetSelected());
  save()
end

function addTextFilter()
  local filter = widget.getText("tabs.tabs.text.newTextFilter") or "";
  if filter ~= "" then

    local listitems = self._textList:GetList();
    local wasthere = false;
    for i=1,#listitems do
      if filter == listitems[i] then
        wasthere = true;
        break;
      end
    end
    if not wasthere then
      self._textList:AddListItem(filter);
    end

    widget.setText("tabs.tabs.text.newTextFilter", "");
    save()
  end
end

function addItemFilter()
  local item = widget.itemSlotItem("tabs.tabs.item.newItemFilter");
  if item ~= nil then
    item = Item(item);
    local wasthere = false;
    local listitems = self._itemList:GetList();
    for i=1,#listitems do
      if ItemWrapper.Compare(item, listitems[i]) then
        wasthere = true;
        break;
      end
    end
    if not wasthere then
      self._itemList:AddListItem(item);
    end
    widget.setItemSlotItem("tabs.tabs.item.newItemFilter", nil);
    save()
  end
end

function textDoubleclick()
  local item = self._textList:GetSelected();
  if not item then
    error("DoubleClick on null item error");
  end
  widget.setText("tabs.tabs.text.newTextFilter", item);
  self._textList:RemoveListItem(item)
  save()
end

function init()
  UpdateUIVisibility(false);
  self._limiter = ClockLimiter();
  self._parentEntityId = pane.containerEntityId();
  self._dataLoader = LoadData(self._parentEntityId, "LoadItem");
  self._tasksManager = TaskManager(self._limiter, function() end);
  self._tasksManager:AddTaskOperator("GUIUpdates", "Queue");
  self._currentMode = "Blacklist";
  self._itemList = ListFlat("tabs.tabs.item.scrollArea.itemList",
    function (listItem, item)
      widget.setText(string.format("%s.itemName", listItem), item.DisplayName);
      widget.setItemSlotItem(string.format("%s.itemIcon", listItem), item.ItemDescriptor);
    end
  );
  self._textList = ListFlat("tabs.tabs.text.scrollArea.textList",
    function (listItem, item)
      widget.setText(string.format("%s.filterText", listItem), item);
    end
  );
  ListDoubleClick("tabs.tabs.text.scrollArea.textList", "doubleclick", textDoubleclick);
  self._filtercardSlot = Itemslot("filterCard");
  self._filtercardSlot:SetFilterFunction(function(item)
    return item.ItemDescriptor.name == "digitalstorage_filtercard";
  end);
  self._filtercardSlot:SetItemLimit(1);
  script.setUpdateDelta(2);
end
