--[[
  NetworkPart.lua
  ---------------
  Utility functions for managing network controllers in a digital storage network for Starbound.
  Handles adding/removing controllers, querying controller state, and provides hooks for pre/post update logic.
  Part of NoviumStorage (fork of DigitalStorage by X)

  Starbound API cross-reference:
    - RemoveTableValue: Utility to remove a value from a table (mod library or util.lua)
    - error(): Standard Lua error handling
]]

require "/HLib/Scripts/HelperScripts.lua"         -- Helper functions
require "/HLib/Scripts/tableEx.lua"               -- Table utility extensions
require "/HLib/Scripts/AdditionalFunctions.lua"   -- Additional utility functions

local _connectedControllers = {}; -- List of connected controller entity IDs

--[[
  DigitalNetworkPreUpdateControllers(count, mode)
  ----------------------------------------------
  Abstract hook called before controllers are added/removed.
  Should be overridden by the implementation.
  @param count (number): Current number of controllers
  @param mode (string): Operation mode ("Add" or "Remove")
  @error Throws if not overridden
]]
function DigitalNetworkPreUpdateControllers(count, mode)
  error("Function 'DigitalNetworkPreUpdateControllers(count, mode)' has to be overriden.");
end

--[[
  DigitalNetworkPostUpdateControllers(count, mode)
  -----------------------------------------------
  Abstract hook called after controllers are added/removed.
  Should be overridden by the implementation.
  @param count (number): New number of controllers
  @param mode (string): Operation mode ("Added" or "Removed")
  @error Throws if not overridden
]]
function DigitalNetworkPostUpdateControllers(count, mode)
  error("Function 'DigitalNetworkPostUpdateControllers(count, mode)' has to be overriden.");
end

--[[
  DigitalNetworkFailsafeShutdown()
  -------------------------------
  Abstract hook for failsafe shutdown logic. Should be overridden.
  @error Throws if not overridden
]]
function DigitalNetworkFailsafeShutdown()
  error("Function 'DigitalNetworkFailsafeShutdown()' has to be overriden.");
end

--[[
  DigitalNetworkRemoveController(id)
  ----------------------------------
  Removes a controller from the network.
  Uses:
    - RemoveTableValue: Removes the controller ID from the list
    - DigitalNetworkPreUpdateControllers/DigitalNetworkPostUpdateControllers: Hooks for custom logic
  @param id (any): The controller entity ID to remove
]]
function DigitalNetworkRemoveController(id)
  DigitalNetworkPreUpdateControllers(#_connectedControllers, "Remove");
  RemoveTableValue(_connectedControllers, id);
  DigitalNetworkPostUpdateControllers(#_connectedControllers, "Removed");
end

--[[
  DigitalNetworkAddController(id)
  -------------------------------
  Adds a controller to the network.
  Uses:
    - DigitalNetworkPreUpdateControllers/DigitalNetworkPostUpdateControllers: Hooks for custom logic
  @param id (any): The controller entity ID to add
]]
function DigitalNetworkAddController(id)
  DigitalNetworkPreUpdateControllers(#_connectedControllers, "Add");
  _connectedControllers[#_connectedControllers + 1] = id;
  DigitalNetworkPostUpdateControllers(#_connectedControllers, "Added");
end

--[[
  DigitalNetworkGetFirstController()
  ----------------------------------
  Returns the first connected controller's entity ID.
  @return (any): The first controller entity ID, or nil if none
]]
function DigitalNetworkGetFirstController()
  return _connectedControllers[1];
end

--[[
  DigitalNetworkHasOneController()
  --------------------------------
  Returns true if exactly one controller is connected.
  @return (bool): True if one controller, false otherwise
]]
function DigitalNetworkHasOneController()
  return #_connectedControllers == 1;
end

--[[
  DigitalNetworkHasController()
  ----------------------------
  Returns true if at least one controller is connected.
  @return (bool): True if any controller is connected, false otherwise
]]
function DigitalNetworkHasController()
  return _connectedControllers[1] ~= nil;
end

--[[
  DigitalNetworkGetAllControllers()
  ---------------------------------
  Returns the list of all connected controller entity IDs.
  @return (table): List of controller entity IDs
]]
function DigitalNetworkGetAllControllers()
  return _connectedControllers;
end

--[[
  DigitalNetworkGetControllerCount()
  ----------------------------------
  Returns the number of connected controllers.
  @return (number): The count of controllers
]]
function DigitalNetworkGetControllerCount()
  return #_connectedControllers;
end
