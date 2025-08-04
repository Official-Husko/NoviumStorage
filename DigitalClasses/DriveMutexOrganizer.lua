--[[
  DriveMutexOrganizer.lua
  ----------------------
  This class manages a queue of mutex (mutual exclusion) requests for digital storage drives in Starbound.
  It ensures that drive operations are performed in a thread-safe, ordered manner by serializing access requests.
  Part of NoviumStorage (fork of DigitalStorage by X)

  Starbound API cross-reference:
    - Deque: Double-ended queue for efficient FIFO/LIFO operations (provided by mod library)
    - Class: Lua class system (provided by mod library)
]]

require "/HLib/Classes/Class.lua"            -- Class system
require "/HLib/Classes/Data/Deque.lua"        -- Double-ended queue implementation
require "/HLib/Scripts/tableEx.lua"           -- Table utility extensions
require "/HLib/Scripts/HelperScripts.lua"     -- Helper functions
require "/scripts/util.lua"                   -- Starbound utility functions

-- DriveMutexOrganizer: Manages a queue of mutex requests for drive operations
DriveMutexOrganizer = Class();

--[[
  _init()
  -------
  Constructor. Initializes the mutex request queue.
  Uses:
    - Deque(): Provides efficient queue operations (see mod library)
]]
function DriveMutexOrganizer:_init()
  self._mutexQueue = Deque(); -- Queue of mutex requests
end

--[[
  AddMutexToQueue(mutexRequest)
  -----------------------------
  Adds a mutex request to the end of the queue.
  @param mutexRequest (any): The mutex request object to enqueue
]]
function DriveMutexOrganizer:AddMutexToQueue(mutexRequest)
  self._mutexQueue:PushEnd(mutexRequest);
end

--[[
  GetMutexRequest()
  -----------------
  Returns the mutex request at the front of the queue without removing it.
  @return (any): The first mutex request, or nil if the queue is empty
]]
function DriveMutexOrganizer:GetMutexRequest()
  return self._mutexQueue:PeekBegin()
end

--[[
  PopMutexRequest()
  -----------------
  Removes the mutex request at the front of the queue.
]]
function DriveMutexOrganizer:PopMutexRequest()
  self._mutexQueue:PopBegin()
end

--[[
  GetAllMutexRequests()
  ---------------------
  Returns the entire mutex request queue (as a Deque object).
  @return (Deque): The queue of all mutex requests
]]
function DriveMutexOrganizer:GetAllMutexRequests()
  return self._mutexQueue;
end
