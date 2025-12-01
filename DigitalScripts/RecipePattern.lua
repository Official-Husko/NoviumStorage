require "/HLib/Classes/Item/Item.lua"
require "/scripts/util.lua"
function GenerateRecipePattern(recipe)
  local itemrec = {};
  itemrec.OriginalRecipe = copy(recipe);
  local output = nil
  if type(recipe.output) == "string" then
    output = {name = recipe.output; count = 1; parameters = {}}
  elseif recipe.output.item or recipe.output.name then
    output = {name = recipe.output.item or recipe.output.name; count = recipe.output.count or 1; parameters = recipe.output.parameters or {}}
  else
    output = {name = recipe.output[1]; count = recipe.output[2] or 1; parameters = recipe.output[3] or {}}
  end
  itemrec.Output = Item(output);
  itemrec.Inputs = {};
  itemrec.Groups = {}
  if recipe.groups then
    for _, group in ipairs(recipe.groups) do
      itemrec.Groups[group] = true
    end
  end
  if recipe.currencyInputs then
    for currname, currcount in pairs(recipe.currencyInputs) do
      itemrec.Inputs[#itemrec.Inputs + 1] = Item({name = currname;count = currcount;parameters = {}});
    end
  end
  local inputs = recipe.input;
  for i = 1, #inputs do
    local input = inputs[i]
    local inputRec = nil
    if type(input) == "string" then
      inputRec = {name = input; count = 1; parameters = {}}
    elseif input.item or input.name then
      inputRec = {name = input.item or input.name; count = input.count or 1; parameters = input.parameters or {}}
    else
      output = {name = input[1]; count = input[2] or 1; parameters = input[3] or {}}
    end
    itemrec.Inputs[#itemrec.Inputs + 1] = Item(inputRec);
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
