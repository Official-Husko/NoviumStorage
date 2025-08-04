--[[
  PatternsStorage.lua
  ------------------
  This class manages a collection of crafting patterns (recipes) for Starbound, organized by provider entity.
  It supports adding/removing pattern providers, and efficiently querying all patterns or by provider.
  Part of NoviumStorage (fork of DigitalStorage by X)

  Starbound API cross-reference:
    - IndexedTable: Table structure for indexed and flattened storage (mod library)
    - compare: Function for comparing recipes (mod library or utility)
    - Class: Lua class system (mod library)
]]

require "/HLib/Classes/Class.lua"            -- Class system
require "/HLib/Scripts/tableEx.lua"           -- Table utility extensions
require "/HLib/Classes/Item/Item.lua"         -- Item class
require "/HLib/Classes/Item/ItemWrapper.lua"  -- Item wrapper utilities
require "/HLib/Classes/Data/IndexedTable.lua" -- Indexed table for pattern storage
require "/DigitalScripts/RecipePattern.lua"    -- Recipe pattern definitions
require "/scripts/util.lua"                   -- Starbound utility functions

-- PatternsStorage: Manages all crafting patterns by provider entity
PatternsStorage = Class();

--[[
  _init()
  -------
  Constructor. Initializes the storage for all patterns and providers.
  Uses:
    - IndexedTable: For efficient indexed and flattened storage of patterns
    - compare: For recipe comparison
]]
function PatternsStorage:_init()
  self._storage = {}; -- [entityId] = provider IndexedTable
  self._allPatterns = IndexedTable(
    function (x)
      return x.Output.UniqueIndex;
    end,
    function (x,y)
      return compare(x.OriginalRecipe,y.OriginalRecipe);
    end);
end

--[[
  AddPatternProvider(entityId, patterns)
  -------------------------------------
  Adds a new pattern provider (entity) and its patterns to storage.
  @param entityId (any): The provider entity's ID
  @param patterns (table): List of pattern objects to add
]]
function PatternsStorage:AddPatternProvider(entityId,patterns)
  local provider = IndexedTable(
    function (x)
      return x.Output.UniqueIndex;
    end,
    function (x,y)
      return compare(x.OriginalRecipe,y.OriginalRecipe);
    end);

  for i=1,#patterns do
    provider:Add(patterns[i]);
    self._allPatterns:Add(patterns[i]);
  end
  self._storage[entityId] = provider;
end

--[[
  RemovePatternProvider(entityId)
  ------------------------------
  Removes a pattern provider and all its patterns from storage.
  @param entityId (any): The provider entity's ID
]]
function PatternsStorage:RemovePatternProvider(entityId)
  local patterns = self._storage[entityId]:GetFlattened();
  self._storage[entityId] = nil;
  for i=1,#patterns do
    self._allPatterns:Remove(patterns[i]);
  end
end

--[[
  AddPatternToProvider(entityId, pattern)
  --------------------------------------
  Adds a single pattern to a provider and to the global pattern list.
  @param entityId (any): The provider entity's ID
  @param pattern (table): The pattern object to add
]]
function PatternsStorage:AddPatternToProvider(entityId, pattern)
  self._storage[entityId]:Add(pattern);
  self._allPatterns:Add(pattern);
end

--[[
  RemovePatternFromProvider(entityId, pattern)
  -------------------------------------------
  Removes a single pattern from a provider and from the global pattern list.
  @param entityId (any): The provider entity's ID
  @param pattern (table): The pattern object to remove
]]
function PatternsStorage:RemovePatternFromProvider(entityId, pattern)
  self._storage[entityId]:Remove(pattern);
  self._allPatterns:Remove(pattern);
end

--[[
  GetPatternsFlattened()
  ---------------------
  Returns a flat list of all patterns from all providers.
  @return (table): List of all pattern objects
]]
function PatternsStorage:GetPatternsFlattened()
  return self._allPatterns:GetFlattened();
end

--[[
  GetPatternsIndexed()
  --------------------
  Returns an indexed table of all patterns (by unique index).
  @return (table): Indexed table of all patterns
]]
function PatternsStorage:GetPatternsIndexed()
  return self._allPatterns:GetIndexed();
end

--[[
  CopyGetPatternsFlattened()
  -------------------------
  Returns a copy of the flat list of all patterns.
  @return (table): Copy of the list of all pattern objects
]]
function PatternsStorage:CopyGetPatternsFlattened()
  return self._allPatterns:GetCopyFlattened();
end

--[[
  CopyGetPatternsIndexed()
  -----------------------
  Returns a copy of the indexed table of all patterns.
  @return (table): Copy of the indexed table of all patterns
]]
function PatternsStorage:CopyGetPatternsIndexed()
  return self._allPatterns:GetCopyIndexed();
end
