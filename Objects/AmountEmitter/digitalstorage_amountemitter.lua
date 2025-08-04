require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Scripts/AdditionalFunctions.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/DigitalScripts/DigitalStoragePeripheral.lua"

function DigitalNetworkFailsafeShutdown()
  DigitalNetworkFailsafeShutdownDevice();
  animator.setAnimationState("AnimationState", "errored");
  script.setUpdateDelta(0);
  self._workData = nil;
end

local function FindNetworkItem()
  if not self._workData or not self._workData.Item then

    return;
  end
  local netItem = self._networkItems:Find(self._workData.Item);
  if netItem then
    self._workData.WorkItem = netItem;
  else
    local itemcpy = ItemWrapper.CopyItem(self._workData.Item);
    ItemWrapper.SetItemCount(itemcpy,0);
    self._networkItems:Add(itemcpy);
    self._workData.WorkItem = self._networkItems:Find(self._workData.Item);
  end
  if not self._workData.WorkItem then
    DigitalNetworkFailsafeShutdown();
  end
  script.setUpdateDelta(30 + sb.staticRandomI32Range(0, 60, sb.makeUuid()));
end

local function PrepareWorkData ();
  if not DigitalNetworkDeviceOperative() then
    return;
  end
  local data = storage.EmitterData;
  if not self._networkItems or not data.Item then
    return;
  end
  self._workData = {Item = Item(data.Item); Mode = data.Mode;Count = tonumber(data.Count)};
  FindNetworkItem();
end

function SaveData (_,_,data)
  storage.EmitterData = data;
  PrepareWorkData ();
end

function LoadData (_,_)
  return storage.EmitterData;
end

local function SetAmountEmmiterOutput(state)
  if state then
    object.setOutputNodeLevel(0,true);
    animator.setAnimationState("AnimationState", "onact");
  else
    object.setOutputNodeLevel(0,false);
    animator.setAnimationState("AnimationState", "oninac");
  end
end

function update()
  if not DigitalNetworkDeviceOperative() then
    return;
  end
  if not self._workData or not self._workData.WorkItem then
    PrepareWorkData();
    return;
  end
  if self._workData.WorkItem then
    if self._workData.Mode == "<=" then
      SetAmountEmmiterOutput(ItemWrapper.GetItemCount(self._workData.WorkItem) <= self._workData.Count);
    else
      SetAmountEmmiterOutput(ItemWrapper.GetItemCount(self._workData.WorkItem) >= self._workData.Count);
    end
  end

  script.setUpdateDelta(30 + sb.staticRandomI32Range(0, 60, sb.makeUuid()));

end


function init()

  if storage.EmitterData == nil then
    storage.EmitterData = {};
  end
  object.setOutputNodeLevel(0,false);

  Messenger().RegisterMessage("SaveData", SaveData);
  Messenger().RegisterMessage("LoadData", LoadData);
  -- script.setUpdateDelta(0);
end

function DigitalNetworkPreUpdateControllers(count, mode)
  if DigitalNetworkDeviceOperative() then
    if count == 1 then
      animator.setAnimationState("AnimationState", "off");
      self._networkItems = nil;
      self._workData = nil;
      script.setUpdateDelta(0);
    end
  end
end

function DigitalNetworkPostUpdateControllers(count, mode)
  if DigitalNetworkDeviceOperative() then
    if count == 1 then
      animator.setAnimationState("AnimationState", "off");
      self._networkItems = DigitalNetworkObtainNetworkItemList();
      PrepareWorkData ();
      script.setUpdateDelta(30);
    end
  end
end
