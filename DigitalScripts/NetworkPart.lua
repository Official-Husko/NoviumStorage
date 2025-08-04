require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Scripts/AdditionalFunctions.lua"


local _connectedControllers = {};

function DigitalNetworkPreUpdateControllers(count, mode)
  error("Function 'DigitalNetworkPreUpdateControllers(count, mode)' has to be overriden.");
end

function DigitalNetworkPostUpdateControllers(count, mode)
  error("Function 'DigitalNetworkPostUpdateControllers(count, mode)' has to be overriden.");
end

function DigitalNetworkFailsafeShutdown()
  error("Function 'DigitalNetworkFailsafeShutdown()' has to be overriden.");
end

function DigitalNetworkRemoveController(id)
  DigitalNetworkPreUpdateControllers(#_connectedControllers, "Remove");
  RemoveTableValue(_connectedControllers, id);
  DigitalNetworkPostUpdateControllers(#_connectedControllers, "Removed");
end

function DigitalNetworkAddController(id)
  DigitalNetworkPreUpdateControllers(#_connectedControllers, "Add");
  _connectedControllers[#_connectedControllers + 1] = id;
  DigitalNetworkPostUpdateControllers(#_connectedControllers, "Added");
end

function DigitalNetworkGetFirstController()
  return _connectedControllers[1];
end

function DigitalNetworkHasOneController()
  return #_connectedControllers == 1;
end

function DigitalNetworkHasController()
  return _connectedControllers[1] ~= nil;
end

function DigitalNetworkGetAllControllers()
  return _connectedControllers;
end

function DigitalNetworkGetControllerCount()
  return #_connectedControllers;
end
