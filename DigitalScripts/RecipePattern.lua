require "/HLib/Classes/Item/Item.lua"
require "/scripts/util.lua"
function GenerateRecipePattern(recipe)
  local itemrec = {};
  itemrec.OriginalRecipe = copy(recipe);
  itemrec.Output = Item(recipe.output);
  itemrec.Inputs = {};
  for currname, currcount in pairs(recipe.currencyInputs) do
    itemrec.Inputs[#itemrec.Inputs + 1] = Item({name = currname;count = currcount;parameters = {}});
  end
  local inputs = recipe.input;
  for i = 1, #inputs do
    itemrec.Inputs[#itemrec.Inputs + 1] = Item(inputs[i]);
  end
  return itemrec;
end

function ValidateRecipe(recipe)
  local recipes = root.recipesForItem(recipe.output.name);
  for i = 1, #recipes do
    if compare(recipes[i], recipe) then
      return true;
    end
  end
  return false;
end
