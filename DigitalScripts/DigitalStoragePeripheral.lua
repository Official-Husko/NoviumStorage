--[[
  DigitalStoragePeripheral.lua
  ---------------------------
  Utility functions for interacting with a digital storage network peripheral in Starbound.
  Provides device registration, item transfer, network shutdown, and listener management.
  Part of NoviumStorage (fork of DigitalStorage by X)

  Starbound API cross-reference:
    - world.callScriptedEntity(): Calls a function on another scripted entity (see world.md)
    - entity.id(): Returns the unique ID of the current entity (see entity.md)
    - error(): Standard Lua error handling
    - See also: Transmission, ItemWrapper, FilterGroup (mod libraries)
]]

require "/HLib/Scripts/HelperScripts.lua"      -- Helper functions
require "/HLib/Scripts/tableEx.lua"           -- Table utility extensions
require "/HLib/Classes/Item/Item.lua"         -- Item class
require "/HLib/Classes/Item/ItemWrapper.lua"  -- Item wrapper utilities
require "/HLib/Classes/Network/Transmission.lua" -- Transmission utilities
require "/DigitalScripts/NetworkPart.lua"      -- Network part logic
local _listener = nil;
local _deviceFailsafeShutdown = false;

--[[
  DigitalNetworkGetSingleController()
  -----------------------------------
  Returns the single connected network controller's entity ID, or errors if not exactly one is present.
  Uses:
    - DigitalNetworkHasOneController(), DigitalNetworkGetFirstController(): Mod utility functions
  @return (EntityId): The controller's entity ID
]]
local function DigitalNetworkGetSingleController()
  if DigitalNetworkHasOneController() then
    return DigitalNetworkGetFirstController();
  else
    error("Either not a single controller or more than one is connected");
  end
end

--[[
  DigitalNetworkAddNetworkStorage(id, data)
  -----------------------------------------
  Registers a storage device with the network controller.
  @param id (any): The storage device ID
  @param data (table): Storage data to register
]]
function DigitalNetworkAddNetworkStorage(id, data)
  world.callScriptedEntity(DigitalNetworkGetSingleController(),"AddNetworkStorage",entity.id(),id,data);
end

--[[
  DigitalNetworkRemoveNetworkStorage(id)
  --------------------------------------
  Unregisters a storage device from the network controller.
  @param id (any): The storage device ID
]]
function DigitalNetworkRemoveNetworkStorage(id)
  world.callScriptedEntity(DigitalNetworkGetSingleController(),"RemoveNetworkStorage",entity.id(),id);
end

--[[
  DigitalNetworkFailsafeShutdownDevice()
  --------------------------------------
  Activates a failsafe shutdown for this device (disables operations).
]]
function DigitalNetworkFailsafeShutdownDevice()
  _deviceFailsafeShutdown = true;
end

--[[
  DigitalNetworkShutdownEntireNetwork()
  -------------------------------------
  Shuts down all controllers in the network by sending a shutdown command.
]]
function DigitalNetworkShutdownEntireNetwork()
  local cntrls = DigitalNetworkGetAllControllers();
  for i=1,#cntrls do
    world.callScriptedEntity(cntrls[i],"NetworkShutdown");
  end
end

--[[
  DigitalNetworkDeviceOperative()
  ------------------------------
  Returns true if the device is not in failsafe shutdown mode.
  @return (bool): True if operative, false otherwise
]]
function DigitalNetworkDeviceOperative()
  return not _deviceFailsafeShutdown;
end

--[[
  DigitalNetworkDeviceActive()
  ---------------------------
  Returns true if the device is operative and exactly one controller is present.
  @return (bool): True if active, false otherwise
]]
function DigitalNetworkDeviceActive()
  return DigitalNetworkHasOneController() and not _deviceFailsafeShutdown;
end

--[[
  CallControllerAndWaitForResponse(name, ...)
  -------------------------------------------
  Calls a function on the controller and waits for a response using a Transmission object.
  Uses:
    - OpenTransmission: Opens a transmission to the controller
    - Transmission:CallScriptedEntity/WaitForResponse/Close/GetResponse
  @param name (string): Function name to call
  @param ... (any): Arguments to pass
  @return (any): The response from the controller
]]
local function CallControllerAndWaitForResponse(name,...)
  local transm = OpenTransmission(DigitalNetworkGetSingleController());
  transm:CallScriptedEntity(name,...);
  transm:WaitForResponse();
  transm:Close();
  return transm:GetResponse(true);
end

--[[
  DigitalNetworkObtainNetworkItemList()
  -------------------------------------
  Returns the list of all items in the network from the controller.
  @return (table): List of item objects
]]
function DigitalNetworkObtainNetworkItemList()
  return world.callScriptedEntity(DigitalNetworkGetSingleController(), "GetNetworkItems");
end

--[[
  DigitalNetworkObtainNetworkPatternListIndexed()
  -----------------------------------------------
  Returns the indexed list of all patterns in the network from the controller.
  @return (table): Indexed table of pattern objects
]]
function DigitalNetworkObtainNetworkPatternListIndexed()
  return CallControllerAndWaitForResponse("GetPatternsIndexed");
end

--[[
  DigitalNetworkItemInteractions(call, item)
  -----------------------------------------
  Helper for item push/pull operations via the controller.
  @param call (string): Function name ("PushItem" or "PullItem")
  @param item (table): The item to push/pull
  @return (any): The result of the operation
]]
local function DigitalNetworkItemInteractions(call,item)
  local itemproc = CallControllerAndWaitForResponse(call,item);
  return itemproc;
end

--[[
  DigitalNetworkPushItem(item)
  ---------------------------
  Pushes an item into the network via the controller.
  @param item (table): The item to push
  @return (any): The result of the push operation
]]
function DigitalNetworkPushItem(item)
  return DigitalNetworkItemInteractions("PushItem", item);
end

--[[
  DigitalNetworkPullItem(item)
  ---------------------------
  Pulls an item from the network via the controller.
  @param item (table): The item to pull
  @return (any): The result of the pull operation
]]
function DigitalNetworkPullItem(item)
  return DigitalNetworkItemInteractions("PullItem", item);
end

--[[
  DigitalNetworkObtainNetworkItemListFiltered(transmission, controllerId, filter)
  ------------------------------------------------------------------------------
  Returns a filtered list of items from the network, using the provided filter object.
  Uses:
    - filter:ItemMatch(item): Checks if item matches filter
  @param transmission (Transmission): Transmission object (optional, for advanced use)
  @param controllerId (EntityId): Controller entity ID (optional, for advanced use)
  @param filter (object): Filter object with ItemMatch method
  @return (table): List of filtered item objects
]]
function DigitalNetworkObtainNetworkItemListFiltered(transmission, controllerId, filter)
  local netItems = DigitalNetworkObtainNetworkItemList(transmission, controllerId);
  local filteredItems = {};
  for _, item in pairs(netItems) do
    if filter:ItemMatch(item) then
      filteredItems[#filteredItems + 1] = item;
    end
  end
  return filteredItems;
end

--[[
  DigitalNetworkUnregisterListener()
  ----------------------------------
  Unregisters this device as an items listener from the controller.
  Uses:
    - world.callScriptedEntity: Calls UnregisterItemsListener on the controller
    - entity.id(): Gets this device's entity ID
]]
function DigitalNetworkUnregisterListener()
  if _listener then
    world.callScriptedEntity(_listener, "UnregisterItemsListener",entity.id());
    _listener = nil;
  end
end

--[[
  DigitalNetworkRegisterListener()
  --------------------------------
  Registers this device as an items listener with the controller.
  Uses:
    - DigitalNetworkUnregisterListener: Ensures no duplicate registration
    - world.callScriptedEntity: Calls RegisterItemsListener on the controller
    - entity.id(): Gets this device's entity ID
]]
function DigitalNetworkRegisterListener()
  if _listener then
    DigitalNetworkUnregisterListener();
  end
  _listener = DigitalNetworkGetSingleController();
  world.callScriptedEntity(_listener, "RegisterItemsListener",entity.id());
end

--[[
  DigitalNetworkItemsListener(items)
  ---------------------------------
  Abstract callback for receiving item updates from the network. Should be overridden by the device implementation.
  @param items (table): List of item objects
  @error Throws if not overridden
]]
function DigitalNetworkItemsListener(items)
  error("Function 'DigitalNetworkItemsListener(items)' has to be overriden.");
end
