require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Classes/Other/LoadData.lua"
require "/HLib/Scripts/tableEx.lua"

require "/HLib/Classes/Item/Item.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/HLib/Classes/Tasks/TaskOperator.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Classes/Filters/TextFilter.lua"
require "/HLib/Classes/Data/BitMap.lua"
require "/HLib/Classes/GUIElements/ListIndexed.lua"
require "/HLib/Classes/GUIElements/ListDoubleClick.lua"
require "/HLib/Classes/GUIElements/Filter.lua"
require "/DigitalScripts/BlueprintScanner.lua"
require "/HLib/Classes/Item/ItemsTable.lua"

require "/scripts/util.lua"

--#region populate network Item list;

local function FindMatchingItemInTable(tab,item)
  for i=1,#tab do
    if ItemWrapper.Compare(tab[i].Item,item) then
      return i;
    end
  end
  return nil;
end


local function SortByName(a,b)
  return a.DisplayNameLower < b.DisplayNameLower;
end

local function ProcessData(items,patterns)
  for uniqueId,itemsTable in pairs(items) do
    for i=1,#itemsTable do
      self._networkItems:Add(copy(itemsTable[i]));
      if self._limiter:Check() then
        coroutine.yield();
      end
    end
  end

  for uniqueId,patternsTable in pairs(patterns) do
    for i=1,#patternsTable do
      local tmpitem = copy(patternsTable[i].Output);
      ItemWrapper.SetItemCount(tmpitem,0);
      self._networkItems:Add(tmpitem);
      self._networkItems:Find(tmpitem).HasPatterns = true;
      self._networkPatterns:Add(copy(patternsTable[i]));
      if self._limiter:Check() then
        coroutine.yield();
      end
    end
  end
end

local function ProcessNetworkItemsPatterns(items,patterns)

  ProcessData(items,patterns);
  local flatData = copy(self._networkItems:GetFlattened());
  table.sort(flatData,SortByName);
  for i=1,#flatData do
    self._networkList:AddListItem(flatData[i]);
    if self._limiter:Check() then
      coroutine.yield();
    end
  end
  local flatPatterns = copy(self._networkPatterns:GetFlattened());
  for i=1,#flatPatterns do
    self._patternList:AddListItem(flatPatterns[i]);
    if self._limiter:Check() then
      coroutine.yield();
    end
  end
  self._networkDataDisplayed = true;
end
--#endregion

--#region ItemPulling

function getSelectedItem(count, item)
  if not item then
    item = self._networkList:GetSelected();
  end
  if not item then
    return;
  end

  local tmpitem = ItemWrapper.CopyItem(item);
  ItemWrapper.SetItemCount(tmpitem,count);
  Messenger().SendMessageNoResponse(self._parentEntityId, "PullNetworkItems", tmpitem);
end

function get1()
  getSelectedItem(1);
end
function get10()
  getSelectedItem(10);
end
function get100()
  getSelectedItem(100);
end
function get1000()
  getSelectedItem(1000);
end
function getCount()
  local how_many_val = widget.getText("network.how_many") or "";
  if how_many_val == "" then
    return;
  end
  local numval = tonumber(how_many_val);
  getSelectedItem(numval);
end

function sort()
  self._networkList:QueueSort();
  self._networkList:RefreshDisplay();
end

function filterEnt()
  self._filter:SaveFilter();
  UpdateFilter(self._filter:GetFilter() or "");
end
function filter()
  self._filter:UpdateFilter();
end
function UpdateFilter(text)
  self._textFilter = TextFilter(text);
  self._networkList:RefreshDisplay();
end
function FilterNetworkItems(it) --NOTE Remove comments
  if ItemWrapper.GetItemCount(it) > 0 or it.HasPatterns then
    return self._textFilter:ItemMatch(it);
  end
end
function doubleclick()
  local item = self._networkList:GetSelected();
  if not item then
    error("DoubleClick on null item error");
  end
  local count = 0;
  if ItemWrapper.GetItemCount(item) > 1000 then
    count = 1000;
  else
    count = ItemWrapper.GetItemCount(item);
  end
  if count > item.MaxStack then
    count = item.MaxStack;
  end
  getSelectedItem(count, item);
end


--#endregion

local function UpdateItemCount(data,type)
  if not self._networkDataDisplayed then
    error("Network data is not displayed. Invalid order of displaying items");
  end
  if not self._networkList:UpdateListItem(data) then
    self._networkItems:Add(data);
    self._networkList:AddListItem(data);

  end
end

function ScanForNewBlueprints()
  widget.setVisible("network.scan", false);
  widget.setVisible("network.scanning", true);
  local items = self._networkItems:GetFlattened();
  for itemId, item in pairs(items) do
    if not LearnBlueprintForItem(item) then
      widget.setVisible("network.scan", false);
      widget.setVisible("network.scanning", false);
      widget.setVisible("network.scanfailed", true);
      return;
    end
    if self._limiter:Check() then
      coroutine.yield();
    end
  end
  widget.setVisible("network.scan", true);
  widget.setVisible("network.scanning", false);
end

function scan()
  self._listTasks:AddTask(Task(coroutine.create(ScanForNewBlueprints)));
end

local function GetResponses()
  local addedInitTable = false;
  if self._responseLoader:Call() then
    local responses = self._responseLoader:GetData();
    self._responseLoader:Reset();
    if not responses then
      return;
    end
    script.setUpdateDelta(1);
    for _, response in pairs(responses) do
      if response.Task == "LoadNetworkData" then
        self._ProcessNetworkItemsPatternsQueued = true;
        addedInitTable = true;
        self._listTasks:AddTask(Task(coroutine.create(ProcessNetworkItemsPatterns), response.Data.Items, response.Data.Patterns));
      elseif response.Task == "UpdateItemCount" then
        if self._ProcessNetworkItemsPatternsQueued and not addedInitTable then
          self._listTasks:AddTask(Task(coroutine.create(UpdateItemCount), response.Data, response.Type));
        end
      elseif response.Task == "TerminalActive" then
        if response.Data then
          if not self._terminalInitalized then
            self._terminalInitalized = true;
            Messenger().SendMessageNoResponse(self._parentEntityId, "SetInteractingPlayer", pane.playerEntityId());
            Messenger().SendMessageNoResponse(self._parentEntityId, "GetNetworkData");
          else
            --NOTE terminal initalized and Active
          end
        else
          --NOTE terminal Should Shutdown
        end
      else
        error(ToStringAnything("Invalid Code:", bitmap, response));
      end
    end
    responses = nil;
  end
end

function craftClick()
  self._patternList:ClearList();
  widget.setVisible("network", false);
  widget.setVisible("crafting", true);
  self._patternList:RefreshDisplay();
end
function back()
  widget.setVisible("network", true);
  widget.setVisible("crafting", false);
end

function FilterPatterns(it)
  local selected = self._networkList:GetSelected();
  if selected then
    if selected.UniqueIndex == it.Output.UniqueIndex then
      return ItemWrapper.Compare(it.Output,selected);
    end
  end
  return false;
end

function craftingDoubleclick()
end

function init()

  self._limiter = ClockLimiter(1/100);
  self._filter = Filter("network.filter");
  self._textFilter = TextFilter("");

  --  self._networkData = IndexedTable(function(x) return x.Item.UniqueIndex; end, CompareItemPatternToItem);
  self._networkItems = ItemsTable(true);
  self._networkPatterns = IndexedTable(function(x) return x.Output.UniqueIndex; end);
  self._networkList = ListIndexed("network.scrollArea.itemList",
  function(listItem, item)
    widget.setText(string.format("%s.itemName", listItem), item.DisplayName);
    widget.setText(string.format("%s.countLabel", listItem), ItemWrapper.GetItemCount(item));
    widget.setItemSlotItem(string.format("%s.itemIcon", listItem), item.ItemDescriptor);
    if not item.HasPatterns then
      widget.setVisible(string.format("%s.craft", listItem),false);
    end
  end
  , SortByName,FilterNetworkItems,function (x,y) ItemWrapper.ModifyItemCount(x,ItemWrapper.GetItemCount(y)); end,function(x) return x.UniqueIndex; end,ItemWrapper.Compare);

  self._patternList = ListIndexed("crafting.scrollArea.itemList",
  function(listItem, item)
    widget.setVisible(string.format("%s.noMachine", listItem), not item.HasCraftingMachine);
    widget.setText(string.format("%s.itemName", listItem), item.Output.DisplayName);
    widget.setText(string.format("%s.countLabel", listItem), ItemWrapper.GetItemCount(item.Output));
    widget.setItemSlotItem(string.format("%s.itemIcon", listItem), item.Output.ItemDescriptor);
  end
  , SortByName,FilterPatterns,nil,function(x) return x.Output.UniqueIndex; end,compare);
  widget.registerMemberCallback("network.scrollArea.itemList","craft",craftClick);



  self._listTasks = TaskOperator("Queue",self._limiter,function() end);
  self._parentEntityId = pane.containerEntityId();

  ListDoubleClick("network.scrollArea.itemList", "doubleclick", doubleclick);
  ListDoubleClick("crafting.scrollArea.itemList", "doubleclick", craftingDoubleclick);

  self._responseLoader = LoadData(self._parentEntityId, "LoadResponses");
  Messenger().SendMessageNoResponse(self._parentEntityId, "IsTerminalActive");
  script.setUpdateDelta(1);
end

function uninit()
  Messenger().SendMessageNoResponse(self._parentEntityId, "SetInteractingPlayer", nil);
end

function update()
  self._limiter:Restart();
  self._listTasks:Restart();
  self._listTasks:Launch();
  if self._filter:UpdateFilterTimeout() then
    self._filter:SaveFilter();
    UpdateFilter(self._filter:GetFilter() or "");
  end
  GetResponses();
end
