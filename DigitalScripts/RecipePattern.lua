--[[
  RecipePattern.lua
  ----------------
  Utility functions for generating and validating recipe patterns for Starbound crafting.
  Used to convert raw recipe data into a structured pattern format and to check if a recipe is valid for a given output item.

  Starbound API cross-reference:
    - Item(): Constructs an item object from a descriptor (mod library)
    - copy(): Utility to clone a table (see util.lua)
    - root.recipesForItem(): Returns all recipes for a given item name (see root.md)
    - compare(): Compares two recipes for equality (mod library or util.lua)
]]

require "/HLib/Classes/Item/Item.lua"         -- Item class
require "/scripts/util.lua"                   -- Starbound utility functions

--[[
  GenerateRecipePattern(recipe)
  ----------------------------
  Converts a raw recipe table into a structured recipe pattern object.
  @param recipe (table): The raw recipe data
  @return (table): The structured recipe pattern
]]
function GenerateRecipePattern(recipe)
  local itemrec = {};
  itemrec.OriginalRecipe = copy(recipe); -- Clone the original recipe
  itemrec.Output = Item(recipe.output);  -- Output item
  itemrec.Inputs = {};                   -- List of input items
  for currname, currcount in pairs(recipe.currencyInputs) do
    itemrec.Inputs[#itemrec.Inputs + 1] = Item({name = currname;count = currcount;parameters = {}});
  end
  local inputs = recipe.input;
  for i = 1, #inputs do
    itemrec.Inputs[#itemrec.Inputs + 1] = Item(inputs[i]);
  end
  return itemrec;
end

--[[
  ValidateRecipe(recipe)
  ---------------------
  Checks if the given recipe matches any registered recipe for the output item.
  Uses:
    - root.recipesForItem: Gets all recipes for the output item
    - compare: Compares recipes for equality
  @param recipe (table): The recipe to validate
  @return (bool): True if valid, false otherwise
]]
function ValidateRecipe(recipe)
  local recipes = root.recipesForItem(recipe.output.name);
  for i = 1, #recipes do
    if compare(recipes[i], recipe) then
      return true;
    end
  end
  return false;
end
