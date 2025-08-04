require "/HLib/Classes/Class.lua"
require "/HLib/Classes/Data/Deque.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Scripts/HelperScripts.lua"
require "/scripts/util.lua"
DriveMutexOrganizer = Class();
function DriveMutexOrganizer:_init()
  self._mutexQueue = Deque();

end

function DriveMutexOrganizer:AddMutexToQueue(mutexRequest)
  self._mutexQueue:PushEnd(mutexRequest);
end

function DriveMutexOrganizer:GetMutexRequest()
  return self._mutexQueue:PeekBegin()
end
function DriveMutexOrganizer:PopMutexRequest()
  self._mutexQueue:PopBegin()
end
function DriveMutexOrganizer:GetAllMutexRequests()
  return self._mutexQueue;
end
