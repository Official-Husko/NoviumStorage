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
require "/HLib/Classes/GUIElements/ListFlat.lua"
require "/HLib/Classes/GUIElements/ListDoubleClick.lua"
require "/HLib/Classes/GUIElements/Filter.lua"
require "/DigitalScripts/BlueprintScanner.lua"
require "/DigitalScripts/RecipePattern.lua"
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

local function updateAvailableStations(it)
  local filters = nil
  local count = ItemWrapper.GetItemCount(it)
  if count == 0 then return false end
  if it.Config.config.interactAction ~= "OpenCraftingInterface" and not it.Config.config.upgradeStages then return false end
  local interactConfig = nil
  local stage = 1
  local maxStage = 1
  if it.ItemDescriptor.name == "mechcraftingtable" then
    filters = {"craftingmech"}
    interactConfig = it.Config.config.interactData.config
  elseif it.Config.config.interactData then
    filters = it.Config.config.interactData.filter
    interactConfig = it.Config.config.interactData.config
  elseif it.Config.config.upgradeStages then
    stage = it.Config.parameters.startingUpgradeStage or it.Config.config.startingUpgradeStage
    maxStage = it.Config.config.maxUpgradeStage
    if it.Config.config.upgradeStages[stage].interactData then
      filters = it.Config.config.upgradeStages[stage].interactData.filter
      interactConfig = it.Config.config.upgradeStages[stage].interactData.config
    end
  end
  local needBlueprint = (interactConfig and root.assetJson(interactConfig).requiresBlueprint) ~= false
  if filters ~= nil then
    local station = copy(it)
    station.Filters = copy(filters)
    station.Stage = stage
    station.MaxStage = maxStage
    local existingStation = self._stationItems[station.ItemDescriptor.name]
    if not existingStation then
      existingStation = {current = 0}
      existingStation[stage] = station
      self._stationItems[station.ItemDescriptor.name] = existingStation
    else
      local stageStation = existingStation[stage]
      if not stageStation then
        existingStation[stage] = station
      else
        ItemWrapper.ModifyItemCount(stageStation, count)
      end
    end
    local previousStage = existingStation.current
    existingStation.current = 0
    for i=maxStage, 1, -1 do
      if existingStation[i] and ItemWrapper.GetItemCount(existingStation[i]) > 0 then
        existingStation.current = i
        break
      end
    end
    for _, filter in ipairs(filters) do
      if self._stations[filter] then
        self._stations[filter].count = math.max(0, self._stations[filter].count + count)
      else
        self._stations[filter] = {needBlueprint = needBlueprint; count = math.max(0, count)}
      end
    end
    if self._selectedStation and ItemWrapper.Compare(existingStation[stage], self._selectedStation, false)
       and previousStage ~= existingStation.current then
      self._nextSelectedStation = existingStation[existingStation.current] or self._defaultStations[1]
    end
    return true
  end
  return false
end

local function refreshStationList()
  self._stationList:EmptyList()
  local stationItems = {}
  for _,v in pairs(self._stationItems) do
    if v[v.current] then
      stationItems[#stationItems+1] = v[v.current]
    end
    if self._limiter:Check() then
      coroutine.yield();
    end
  end
  table.sort(stationItems, SortByName)
  table.insert(stationItems, 1, self._defaultStations[1])
  table.insert(stationItems, 2, self._defaultStations[2])
  for _, station in ipairs(stationItems) do
    self._stationList:AddListItem(copy(station));
    if self._limiter:Check() then
      coroutine.yield();
    end
  end
  self._stationList:SetSelected(self._nextSelectedStation or self._selectedStation)
  self._nextSelectedStation = nil
end

local function ProcessItems(items)
  for _,item in ipairs(items) do
    self._networkItems:Add(item);
    updateAvailableStations(item)
    if self._limiter:Check() then
      coroutine.yield();
    end
  end
end

local function ProcessNetworkItems(items)
  self._limiter:SetLimit(1/50)
  ProcessItems(items);
  self._limiter:SetLimit()
  refreshStationList()
  local flatData = self._networkItems:GetFlattened()
  for _, index in ipairs(self._networkItems:GetSortedIndex()) do
    self._networkList:AddListItem(copy(flatData[index]));
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
function clearFilter()
  widget.setText("network.filter", "");
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
function checkStationFilter(it, filters)
  if not filters then return true end
  if not it.Groups then return false end
  for _, filter in ipairs(filters) do
    if it.Groups[filter] then return true end
  end
  return false
end
function FilterNetworkItems(it) --NOTE Remove comments
  local filters = self._selectedStation and self._selectedStation.Filters
  if (not filters and ItemWrapper.GetItemCount(it) > 0) or ((filters or self._filter:HasFilter()) and checkPattern(it)) then
    return self._textFilter:ItemMatch(it) and checkStationFilter(it, filters)
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
  local flatData = self._networkItems:GetFlattened();
  local _, index, isNew = self._networkItems:Add(data);
  if updateAvailableStations(data) then
    refreshStationList()
  end
  if not self._networkList:UpdateListItem(data) then
    self._networkList:AddListItem(data);
  end
  self._ingredientList:RefreshDisplay()
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
        --self._listTasks:AddTask(Task(coroutine.create(ProcessNetworkItemsPatterns), response.Data.Items, response.Data.Craftables));
        self._listTasks:AddTask(Task(coroutine.create(ProcessNetworkItems), response.Data.Craftables)) --, response.Data.Craftables));
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
  self._selected = copy(self._networkList:GetSelected())
  if not self._selected then return end
  refreshPatternList()
  self._craftLevel[1] = {}
  widget.setVisible("crafting.upgradeButtons", false);
  widget.setVisible("crafting.craftingButtons", true);
  widget.setVisible("network", false);
  widget.setVisible("crafting", true);
end

function refreshPatternList()
  if self._upgradePattern then
    self._patternList:EmptyList();
    self._patternList:AddListItem(self._upgradePattern)
    widget.setVisible("crafting.craftingButtons", false);
    widget.setVisible("crafting.upgradeButtons", true);
  else
    local recipes = root.recipesForItem(self._selected.ItemDescriptor.name)
    if not recipes then return end
    self._patternList:EmptyList();
    for _, recipe in ipairs(recipes) do
      local pattern = GenerateRecipePattern(recipe)
      if hasStationFor(pattern) ~= nil then
        self._patternList:AddListItem(pattern)
      end
    end
    widget.setVisible("crafting.upgradeButtons", false);
    widget.setVisible("crafting.craftingButtons", true);
  end
end

function back()
  local selected = table.remove(self._craftLevel) or {}
  if selected.upgrade then
    self._upgradePattern = selected.item
  else
    self._selected = selected.item
    self._upgradePattern = nil
  end
  if not self._selected then
    widget.setVisible("crafting", false);
    widget.setVisible("network", true);
    self._lastPattern = {}
  else
    refreshPatternList();
    self._patternList:SetSelected(table.remove(self._lastPattern))
  end
end

function hasStationFor(it)
  if it ~= nil and it.Groups then
    for group,config in pairs(self._stations) do
      if config.count > 0 and it.Groups[group] then return config.needBlueprint end
    end
  end
  return nil
end

function checkPattern(it)
  local needBlueprint = hasStationFor(it)
  return needBlueprint ~= nil and (not needBlueprint or player.blueprintKnown(it.ItemDescriptor))
end

function init()

  self._limiter = ClockLimiter(1/50);
  self._filter = Filter("network.filter");
  self._textFilter = TextFilter("");
  self._craftLevel = {}
  self._selected = nil
  self._lastPattern = {}
  self._stations = {["plain"] = {needBlueprint = true; count = 1}}
  self._defaultStations = {
    {DisplayName = "No filter"; ItemDescriptor = {name="all"; count = 1; parameters = {}}; Filters = nil; Stage = 1; MaxStage = 1 },
    {DisplayName = "Handcrafting"; ItemDescriptor = {name = "hands", count = 1, pasrameters = {}}; Filters = {"plain"}; Stage = 1; MaxStage = 1}
  }

  self._selectedStation = self._defaultStations[1]
  self._nextSelectedStation = nil

  self._upgradePattern = nil

  self._networkItems = ItemsTable(true);
  self._networkIndexes = {}
  self._networkList = ListIndexed("network.itemsArea.itemList",
  function(listItem, item)
    widget.setText(string.format("%s.itemName", listItem), item.DisplayName);
    widget.setText(string.format("%s.countLabel", listItem), IfZero(ItemWrapper.GetItemCount(item), ""));
    widget.setItemSlotItem(string.format("%s.itemIcon", listItem), item.ItemDescriptor);
    if not checkPattern(item) then
      widget.setVisible(string.format("%s.craft", listItem),false);
    end
  end
  , SortByName,FilterNetworkItems,function (x,y) ItemWrapper.ModifyItemCount(x,ItemWrapper.GetItemCount(y)); end,function(x) return x.UniqueIndex; end,ItemWrapper.Compare);

  self._patternList = ListIndexed("crafting.patternsArea.itemList",
  function(listItem, item)
    widget.setText(string.format("%s.itemName", listItem), item.Output.DisplayName);
    widget.setText(string.format("%s.countLabel", listItem), ItemWrapper.GetItemCount(item.Output));
    widget.setItemSlotItem(string.format("%s.itemIcon", listItem), item.Output.ItemDescriptor);
  end
  , nil,nil,nil,function(x) return x.Output.UniqueIndex; end,compare);
  widget.registerMemberCallback("network.itemsArea.itemList","craft",craftClick);

  self._ingredientList = ListIndexed("crafting.ingredientsArea.itemList",
  function(listItem, item)
    widget.setText(string.format("%s.itemName", listItem), item.DisplayName);
    local availCount = 0
    if IsCurrency(item.ItemDescriptor) then
      availCount = player.currency(item.ItemDescriptor.name)
    else
      availCount =  self._networkItems:Count(item, false)
    end
    local needCount = ItemWrapper.GetItemCount(item)
    if availCount >= needCount then
      widget.setFontColor(string.format("%s.countLabel", listItem), "green");
    else
      widget.setFontColor(string.format("%s.countLabel", listItem), "red");
    end
    widget.setText(string.format("%s.countLabel", listItem), string.format("%s / %s", availCount, needCount));
    widget.setItemSlotItem(string.format("%s.itemIcon", listItem), item.ItemDescriptor);
    if not checkPattern(self._networkItems:Find(item, function(x,y) return ItemWrapper.Compare(x,y,false) end)) then
      widget.setVisible(string.format("%s.craft", listItem),false);
    end
  end
  , SortByName,nil,nil,function(x) return x.UniqueIndex end, function(x,y) return ItemWrapper.Compare(x,y,false) end);
  widget.registerMemberCallback("crafting.ingredientsArea.itemList","craft",craftIngredient);

  self._stationItems = {}
  self._stationList = ListFlat("stations.stationsArea.itemList",
  function(listItem, item)
    widget.setText(string.format("%s.stationName", listItem), item.DisplayName);
    if item.ItemDescriptor.name ~= "hands" and item.ItemDescriptor.name ~= "all" then
      widget.setItemSlotItem(string.format("%s.stationIcon", listItem), item.ItemDescriptor);
    end
    if item.Stage < item.MaxStage then
      widget.setVisible(string.format("%s.stage", listItem),false);
      widget.setVisible(string.format("%s.upgrade", listItem),true);
    end
  end, nil, nil, nil, nil)
  widget.registerMemberCallback("stations.stationsArea.itemList","upgrade",upgrade);
  self._listTasks = TaskOperator("Queue",self._limiter,function() end);

  self._parentEntityId = pane.containerEntityId();

  ListDoubleClick("network.itemsArea.itemList", "doubleclick", doubleclick);
  ListDoubleClick("crafting.patternsArea.itemList", "doubleclick", craftingDoubleclick);
  ListDoubleClick("stations.stationsArea.itemList", "doubleclick", stationDoubleclick);

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

function recipeClick()
  widget.setVisible("crafting.ingredientsArea", false);
  local selected = self._patternList:GetSelected()
  if selected then
    self._ingredientList:EmptyList()
    local inputs = copy(selected.Inputs)
    table.sort(inputs, SortByName)
    for _,input in ipairs(inputs) do
      self._ingredientList:AddListItem(input);
    end
    self._ingredientList:RefreshDisplay();
    widget.setVisible("crafting.ingredientsArea", true);
  end
end

function craft(amount, pattern, upgradeItem)
  local selected = pattern or self._patternList:GetSelected();
  if selected then
    local maxAmount = amount
    local currency = {}
    for i=1,#selected.Inputs do
      local item = selected.Inputs[i]
      local count = 0
      local needCount = ItemWrapper.GetItemCount(item)
      if IsCurrency(item.ItemDescriptor) then
        count = player.currency(item.ItemDescriptor.name)
        currency[#currency+1] = {name = item.ItemDescriptor.name, count = needCount}
      else
        count = self._networkItems:Count(item, false)
      end
      if needCount == 0 then return end
      local availAmount = count // needCount
      if availAmount < maxAmount then
        maxAmount = availAmount
      end
    end
    if maxAmount == 0 then return end
    local removed = {}
    local failed = false
    for _, curr in ipairs(currency) do
      curr.count = curr.count * maxAmount
      if player.consumeCurrency(curr.name, curr.count) then
        removed[#removed+1] = curr
      else
        failed = true
        break
      end
    end
    if failed then
      for _,curr in ipairs(removed) do
        player.addCurrency(curr.name, curr.count)
      end
    else
      local tmprecipe = copy(selected)
      Messenger().SendMessageNoResponse(self._parentEntityId, "CraftUpgradeNetworkItem", tmprecipe, maxAmount, upgradeItem);
    end
  end
end

function craft1()
  craft(1)
end

function craft10()
  craft(10)
end

function craft100()
  craft(100)
end

function craft1000()
  craft(1000)
end

function craftCount()
  local how_many_val = widget.getText("crafting.craftingButtons.how_many") or "";
  if how_many_val == "" then
    return;
  end
  local numval = tonumber(how_many_val);
  craft(numval);
end

function craftingDoubleclick()
  craft(9999)
end

function craftIngredient()
  local selected = self._ingredientList:GetSelected()
  if selected then
    self._lastPattern[#self._lastPattern+1] = self._patternList:GetSelected()
    local levelItem = {item = self._upgradePattern or self._selected}
    self._craftLevel[#self._craftLevel+1] = levelItem
    if self._upgradePattern then
      levelItem.upgrade = true
      self._upgradePattern = nil
    end
    self._selected = copy(selected)
    refreshPatternList()
  end
end

function stationClick()
  local selected = self._stationList:GetSelected()
  if selected and not (self._selectedStation and ItemWrapper.Compare(selected, self._selectedStation)) then
    self._selectedStation = selected
    self._networkList:RefreshDisplay()
  end
end

function stationDoubleclick()
  local selected = self._stationList:GetSelected()
  if selected.ItemDescriptor.name == "all" or selected.ItemDescriptor.name == "hands" then return end
  getSelectedItem(1, selected)
end

function upgrade()
  local selected = copy(self._stationList:GetSelected())
  if selected.Stage == selected.MaxStage then return end
  local nextStageLevel = selected.Stage + 1
  local nextStage = selected.Config.config.upgradeStages[nextStageLevel]
  local currentStage = selected.Config.config.upgradeStages[selected.Stage]
  local upgradedParameters = nextStage.itemSpawnParameters
  upgradedParameters.startingUpgradeStage = nextStageLevel
  local upgraded = Item({name = selected.ItemDescriptor.name, count = 1; parameters = upgradedParameters})
  local inputs = {}
  for _,resource in ipairs(currentStage.interactData.upgradeMaterials) do
    inputs[#inputs+1] = Item({name = resource.item; count = resource.count; parameters = {}})
  end
  self._upgradePattern = {Output = upgraded; Inputs = inputs}
  widget.setVisible("network", false);
  widget.setVisible("crafting", true);
  refreshPatternList()
end

function upgradeStation()
  local selected = copy(self._stationList:GetSelected())
  ItemWrapper.SetItemCount(selected, 1)
  craft(1, self._upgradePattern, selected)
end
