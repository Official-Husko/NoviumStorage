require "/HLib/Scripts/tableEx.lua"
require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Scripts/AdditionalFunctions.lua"
require "/HLib/Classes/Network/Network.lua"
require "/HLib/Classes/Class.lua"
require "/scripts/util.lua"
DigitalNetwork = Class();

function DigitalNetwork:_init()
  self._entityId = entity.id();
  self._network = Network(function(id)
    return world.getObjectParameter(id, "DigitalStorageNetworkPart");
  end,
  function(id)
    return world.getObjectParameter(id, "DigitalStorageNetworkPart.Router", false);
  end,
  "DigitalStorageNetworkRouter");
  self._previousNetworkObjects = {};
  self._newNetworkObjects = {};
  self._networkObjectsByTags = {};
  self._added = {};
  self._removed = {};
end

function DigitalNetwork:RefreshNetwork()
  self._previousNetworkObjects = self._newNetworkObjects;
  self._newNetworkObjects = self._network:RefreshNetwork();
  local added = {};
  local removed = {};

  for id,data in pairs(self._newNetworkObjects) do
    if not self._previousNetworkObjects[id] then
      added[#added + 1] = {Id = id; Data = data};
    end
  end
  for id,data in pairs(self._previousNetworkObjects) do
    if not self._newNetworkObjects[id] then
      removed[#removed + 1] = {Id = id; Data = data};
    end
  end
  for i=1,#added do
    world.callScriptedEntity(added[i].Id, "DigitalNetworkAddController", self._entityId);
    for tag,_ in pairs(added[i].Data) do
      if not self._networkObjectsByTags[tag] then
        self._networkObjectsByTags[tag] = {};
      end
      self._networkObjectsByTags[tag][added[i].Id] = true;
    end
  end
  for i=1,#removed do
    if world.entityExists(removed[i].Id) then
      world.callScriptedEntity(removed[i].Id, "DigitalNetworkRemoveController", self._entityId);
    end
    for tag,_ in pairs(removed[i].Data) do
      self._networkObjectsByTags[tag][removed[i].Id] = nil;
    end
  end

  self._added = added;
  self._removed = removed;
end

function DigitalNetwork:CountNetworkElementsWithTag(tag)
  return GetTableSize(self._networkObjectsByTags[tag]);
end

function DigitalNetwork:AddedDevices()
  return self._added;
end

function DigitalNetwork:RemovedDevices()
  return self._removed;
end

function DigitalNetwork:AllDevices()
  return self._newNetworkObjects;
end
function DigitalNetwork:DeviceInNetwork(id)
  return self._newNetworkObjects[id] ~= nil;
end
