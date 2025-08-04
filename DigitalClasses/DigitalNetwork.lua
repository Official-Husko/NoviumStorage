--[[
  DigitalNetwork.lua
  ------------------
  This class manages a digital storage network for Starbound, allowing dynamic addition and removal of devices (such as drives, controllers, etc.)
  Devices are tracked by unique IDs and organized by tags. The network state is refreshed regularly, and devices are notified when they join or leave the network.
  
  Part of NoviumStorage (fork of DigitalStorage by X)
  
  Starbound API cross-reference:
    - entity.id(): Returns the unique ID of the current entity (see entity.md)
    - world.getObjectParameter(): Reads config parameters from an object entity (see world.md)
    - world.callScriptedEntity(): Calls a function on another scripted entity (see world.md)
    - world.entityExists(): Checks if an entity exists (see world.md)
    - Class(), Network(): Provided by mod libraries
]]

require "/HLib/Scripts/tableEx.lua"         -- Table utility extensions
require "/HLib/Scripts/HelperScripts.lua"    -- Helper functions
require "/HLib/Scripts/AdditionalFunctions.lua" -- Additional utility functions
require "/HLib/Classes/Network/Network.lua" -- Core network logic
require "/HLib/Classes/Class.lua"            -- Class system
require "/scripts/util.lua"                  -- Starbound utility functions

-- DigitalNetwork: Main class for managing a digital storage network
DigitalNetwork = Class();

--[[]
  _init()
  -------
  Constructor. Initializes the network and tracking tables.
  Uses:
    - entity.id(): To get the controller/owner entity ID.
    - Network(): To create the network object, passing in Starbound API-based device checks.
  Fields:
    - _entityId: The entity ID of the controller/owner.
    - _network: The Network object for device management.
    - _previousNetworkObjects: Devices in the previous network state.
    - _newNetworkObjects: Devices in the current network state.
    - _networkObjectsByTags: Devices indexed by tag.
    - _added: Devices added since last refresh.
    - _removed: Devices removed since last refresh.
]]
function DigitalNetwork:_init()
  self._entityId = entity.id(); -- The entity ID of the controller/owner (see entity.md)
  self._network = Network(
    function(id)
      -- Returns true if the object is a DigitalStorageNetworkPart (see world.getObjectParameter in world.md)
      return world.getObjectParameter(id, "DigitalStorageNetworkPart");
    end,
    function(id)
      -- Returns true if the object is a Router (optional, defaults to false)
      return world.getObjectParameter(id, "DigitalStorageNetworkPart.Router", false);
    end,
    "DigitalStorageNetworkRouter" -- Router tag
  );
  self._previousNetworkObjects = {};    -- Devices in the previous network state
  self._newNetworkObjects = {};         -- Devices in the current network state
  self._networkObjectsByTags = {};      -- Devices indexed by tag
  self._added = {};                     -- Devices added since last refresh
  self._removed = {};                   -- Devices removed since last refresh
end

--[[
  RefreshNetwork()
  ----------------
  Updates the digital storage network state by:
    - Querying all connected devices using the Network class.
    - Detecting which devices have been added or removed since the last update.
    - Notifying devices of their addition/removal using world.callScriptedEntity.
    - Maintaining a tag-based index for fast lookup.
  Uses:
    - world.getObjectParameter: To identify network parts and routers.
    - world.callScriptedEntity: To notify devices (see world.md).
    - world.entityExists: To check device existence before removal (see world.md).
]]
function DigitalNetwork:RefreshNetwork()
  self._previousNetworkObjects = self._newNetworkObjects;
  self._newNetworkObjects = self._network:RefreshNetwork();
  local added = {};
  local removed = {};

  -- Find newly added devices
  for id, data in pairs(self._newNetworkObjects) do
    if not self._previousNetworkObjects[id] then
      added[#added + 1] = {Id = id; Data = data};
    end
  end
  -- Find removed devices
  for id, data in pairs(self._previousNetworkObjects) do
    if not self._newNetworkObjects[id] then
      removed[#removed + 1] = {Id = id; Data = data};
    end
  end
  -- Notify and index added devices
  for i = 1, #added do
    -- Notifies the device it has joined the network (see world.callScriptedEntity in world.md)
    world.callScriptedEntity(added[i].Id, "DigitalNetworkAddController", self._entityId);
    for tag, _ in pairs(added[i].Data) do
      if not self._networkObjectsByTags[tag] then
        self._networkObjectsByTags[tag] = {};
      end
      self._networkObjectsByTags[tag][added[i].Id] = true;
    end
  end
  -- Notify and de-index removed devices
  for i = 1, #removed do
    -- Only notify if the entity still exists (see world.entityExists in world.md)
    if world.entityExists(removed[i].Id) then
      world.callScriptedEntity(removed[i].Id, "DigitalNetworkRemoveController", self._entityId);
    end
    for tag, _ in pairs(removed[i].Data) do
      self._networkObjectsByTags[tag][removed[i].Id] = nil;
    end
  end

  self._added = added;
  self._removed = removed;
end

--[[
  CountNetworkElementsWithTag(tag)
  -------------------------------
  Returns the number of devices in the network with the specified tag.
  @param tag (string): The tag to count devices for (e.g., "Drive", "Controller").
  @return (number): Number of devices with the tag.
  Uses: Lua utility GetTableSize (from your mod or Starbound util).
]]
function DigitalNetwork:CountNetworkElementsWithTag(tag)
  return GetTableSize(self._networkObjectsByTags[tag]);
end

--[[
  AddedDevices()
  --------------
  Returns a list of devices added since the last network refresh.
  @return (table): List of added device tables {Id, Data}
  Devices are detected by comparing previous and current network state.
]]
function DigitalNetwork:AddedDevices()
  return self._added;
end

--[[
  RemovedDevices()
  ----------------
  Returns a list of devices removed since the last network refresh.
  @return (table): List of removed device tables {Id, Data}
  Devices are detected by comparing previous and current network state.
]]
function DigitalNetwork:RemovedDevices()
  return self._removed;
end

--[[
  AllDevices()
  ------------
  Returns a table of all devices currently in the network.
  @return (table): Table of devices indexed by ID
  Uses the most recent network state.
]]
function DigitalNetwork:AllDevices()
  return self._newNetworkObjects;
end

--[[
  DeviceInNetwork(id)
  -------------------
  Checks if a device with the given ID is currently in the network.
  @param id (number): The entity ID to check
  @return (boolean): True if the device is in the network, false otherwise
  Uses the most recent network state.
]]
function DigitalNetwork:DeviceInNetwork(id)
  return self._newNetworkObjects[id] ~= nil;
end
