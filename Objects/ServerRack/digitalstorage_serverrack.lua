require "/DigitalClasses/Drive.lua"
require "/HLib/Classes/Class.lua"
require "/HLib/Classes/Item/Item.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Scripts/AdditionalFunctions.lua"
require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Network/Transmission.lua"
require "/HLib/Classes/Data/BitMap.lua"
require "/DigitalClasses/DriveMutexOrganizer.lua"
require "/DigitalScripts/DigitalStoragePeripheral.lua"

function DigitalNetworkFailsafeShutdown()
  DigitalNetworkFailsafeShutdownDevice();
  animator.setAnimationState("AnimationState", "failure");
end


--#region Network Connections

function DigitalNetworkPreUpdateControllers(count, mode)
  if DigitalNetworkDeviceOperative() then
    if count == 1 then
      animator.setAnimationState("AnimationState", "off");
      for index, drive in pairs(self._drives) do
        DigitalNetworkRemoveNetworkStorage(index);
      end
    end
  end
end

function DigitalNetworkPostUpdateControllers(count, mode)
  if DigitalNetworkDeviceOperative() then
    if count == 1 then
      animator.setAnimationState("AnimationState", "on");
      for index, drive in pairs(self._drives) do
        DigitalNetworkAddNetworkStorage(index,drive.Drive:GetDriveData());
      end
    end
  end
end

--#endregion

local function UnloadDrive(id)
  if DigitalNetworkHasOneController() then
    DigitalNetworkRemoveNetworkStorage(id);
  end
  self._drives[id] = nil;
  self._containsDrives[id] = nil;
  storage[id] = nil;
end

local function LoadDrive(id,drive)
  local loadedDrive = {};
  loadedDrive.Drive = Drive(drive);
  loadedDrive.Id = id;
  self._drives[id] = loadedDrive;
  self._containsDrives[id] = drive.parameters.DriveUuid;
  storage[id] = self._drives[id].Drive:GetDrive();
  if DigitalNetworkHasOneController() then
    DigitalNetworkAddNetworkStorage(id, self._drives[id].Drive:GetDriveData());
  end
end

local function SaveDrive(drive)
  local itematSlot = world.containerItemAt(self._entityId, drive.Id-1);
  if itematSlot.parameters.DriveUuid == drive.Drive:GetDrive().parameters.DriveUuid then
    if itematSlot.parameters.SaveId ~= drive.Drive:GetDrive().parameters.SaveId then
      world.containerSwapItemsNoCombine(self._entityId, drive.Drive:GetDrive(), drive.Id-1);
    end
  else
    error("Drive in memory does not match Uuid with drive in slot");
  end
end

local function SaveAllDrives()
  for index, drive in pairs(self._drives) do
    SaveDrive(drive);
  end
end


--#region API

local function GetMutexInternal(index)
  if self._drives[index] ~= nil and not self._drives[index].Unlocking then
    return self._drives[index].Drive:TryLockMutex();
  else
    return false;
  end
end

function GetMutex(...)
  if not DigitalNetworkDeviceOperative() then
    return false;
  end
  local status,result = pcall(GetMutexInternal,...);
  if status then
    return result;
  else
    DigitalNetworkFailsafeShutdown();
    return false;
  end
end

local function FreeMutexInternal(index,key)
  return self._drives[index].Drive:FreeMutex(key);
end

function FreeMutex(...)
  if not DigitalNetworkDeviceOperative() then
    return;
  end
  local status,result = pcall(FreeMutexInternal,...);
  if status then
    return result;
  else
    DigitalNetworkFailsafeShutdown();
    return false;
  end
end

local function PushItemInternal(index,key,item)
  if not self._drives[index].Drive:ValidateMutex(key) then
    error("Invalid mutex provided");
  end
  local result = self._drives[index].Drive:AddItem(item);
  return result;
end

function PushItem(...)
  if not DigitalNetworkDeviceOperative() then
    return;
  end
  local status,result = pcall(PushItemInternal,...);
  if status then
    return result;
  else
    DigitalNetworkFailsafeShutdown();
    return false;
  end
end

local function PullItemInternal(index,key,item,match)
  if not self._drives[index].Drive:ValidateMutex(key) then
    error("Invalid mutex provided");
  end

  local result = self._drives[index].Drive:RemoveItem(item,match);
  return result;
end

function PullItem(...)
  if not DigitalNetworkDeviceOperative() then
    return;
  end
  local status,result = pcall(PullItemInternal,...);
  if status then
    return result;
  else
    DigitalNetworkFailsafeShutdown();
    return false;
  end
end

local function SaveChangesInternal(index,key)
  if not self._drives[index].Drive:ValidateMutex(key) then
    error("Invalid mutex provided");
  end
  self._drives[index].Drive:SaveChanges();
  if self._guiOpened then
    SaveDrive(self._drives[index]);
  end
end

function SaveChanges(...)
  if not DigitalNetworkDeviceOperative() then
    return;
  end
  local status,result = pcall(SaveChangesInternal,...);
  if status then
    return result;
  else
    DigitalNetworkFailsafeShutdown();
    return false;
  end
end

local function CancelChangesInternal(index,key)
  if not self._drives[index].Drive:ValidateMutex(key) then
    error("Invalid mutex provided");
  end
  self._drives[index].Drive:CancelChanges();
end

function CancelChanges(...)
  if not DigitalNetworkDeviceOperative() then
    return;
  end
  local status,result = pcall(CancelChangesInternal,...);
  if status then
    return result;
  else
    DigitalNetworkFailsafeShutdown();
    return false;
  end
end

--#endregion



local function OpenGUI()
  self._guiOpened = true;
  SaveAllDrives();
end

local function CloseGUI()
  self._guiOpened = false;
end

local function LoadDrivesFromStorage();
  for id,drive in pairs(storage) do
    LoadDrive(id,drive);
  end
end

function containerCallback()
  if not DigitalNetworkDeviceOperative() then
    return;
  end
  local rack_items = world.containerItems(self._entityId);
  local shouldReturn = false;
  for id,drive in pairs(rack_items) do

    local driveItem = Item(drive);
    if not driveItem.Config.config.digitalstorage_drivedata then
      shouldReturn = true;
      world.spawnItem(world.containerTakeAt(self._entityId, id-1),entity.position());
    else
      local driveVersion = drive.parameters.Version;
      local initDrive = UpdateDriveVersion(drive);
      if initDrive.parameters.Version ~= driveVersion then
        world.containerSwapItemsNoCombine(self._entityId,initDrive ,id-1);
        shouldReturn = true;
      end
    end
  end
  if shouldReturn then
    return;
  end
  rack_items = world.containerItems(self._entityId);
  for id,drive in pairs(self._containsDrives) do
    if not rack_items[id] then
      UnloadDrive(id);
    end
  end
  for id,drive in pairs(rack_items) do
    if self._containsDrives[id] ~= drive.parameters.DriveUuid then
      if self._containsDrives[id] then
        UnloadDrive(id);
      end
      LoadDrive(id,drive);
    end
  end
end

function update()

  if next(storage) then
    LoadDrivesFromStorage();
    SaveAllDrives();
  else
    containerCallback();
  end
  script.setUpdateDelta(1800 + sb.staticRandomI32Range(0, 1800, sb.makeUuid()));
  update = SaveAllDrives;

end

function init ()
  self._responses = {};
  self._entityId = entity.id();
  self._drives = {};
  self._guiOpened = false;
  self._containsDrives = {};
  self._limiter = ClockLimiter();
  script.setUpdateDelta(1);
  Messenger().RegisterMessage("ServerRackIsOpen", function (_, _, isopen) if isopen then OpenGUI() else CloseGUI() end end);
end

function uninit()
  if DigitalNetworkHasOneController() then
    if world.entityExists(DigitalNetworkGetFirstController()) then
      for index, drive in pairs(self._drives) do
        DigitalNetworkRemoveNetworkStorage(index);
      end
    end
  end
end

function die()
  if DigitalNetworkHasOneController() then
    if world.entityExists(DigitalNetworkGetFirstController()) then
      for index, drive in pairs(self._drives) do
        DigitalNetworkRemoveNetworkStorage(index);
      end
    end
  end
end
