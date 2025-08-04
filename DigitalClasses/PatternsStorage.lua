require "/HLib/Classes/Class.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Classes/Item/Item.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"
require "/HLib/Classes/Data/IndexedTable.lua"
require "/DigitalScripts/RecipePattern.lua"
require "/scripts/util.lua"

PatternsStorage = Class();

function PatternsStorage:_init()
  self._storage = {};
  self._allPatterns = IndexedTable(
  function (x)
    return x.Output.UniqueIndex;
  end,
  function (x,y)
    return compare(x.OriginalRecipe,y.OriginalRecipe);
  end);
end


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

function PatternsStorage:RemovePatternProvider(entityId)
  local patterns = self._storage[entityId]:GetFlattened();
  self._storage[entityId] = nil;
  for i=1,#patterns do
    self._allPatterns:Remove(patterns[i]);
  end
end

function PatternsStorage:AddPatternToProvider(entityId, pattern)
  self._storage[entityId]:Add(pattern);
  self._allPatterns:Add(pattern);
end
function PatternsStorage:RemovePatternFromProvider(entityId, pattern)
  self._storage[entityId]:Remove(pattern);
  self._allPatterns:Remove(pattern);
end


function PatternsStorage:GetPatternsFlattened()
  return self._allPatterns:GetFlattened();
end
function PatternsStorage:GetPatternsIndexed()
  return self._allPatterns:GetIndexed();
end
function PatternsStorage:CopyGetPatternsFlattened()
  return self._allPatterns:GetCopyFlattened();
end
function PatternsStorage:CopyGetPatternsIndexed()
  return self._allPatterns:GetCopyIndexed();
end
