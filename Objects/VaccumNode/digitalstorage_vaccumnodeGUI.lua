require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Classes/Item/Item.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"
require "/HLib/Classes/GUIElements/Itemslot.lua"
require "/HLib/Classes/Other/LoadData.lua"

function init()
  self._parentEntityId = pane.containerEntityId();
  self._responseLoader = LoadData(self._parentEntityId, "LoadData");
  self._upgradeCard = Itemslot("upgradeCard");
  self._upgradeCard:SetFilterFunction(
  function (item)
    return item.ItemDescriptor.name == "digitalstorage_radiuscard";
  end);
  script.setUpdateDelta(1);
end

function update()
  if self._responseLoader:Call() then
    local responses = self._responseLoader:GetData();
    self._responseLoader:Reset();
    if not responses then
      return;
    end
    self._upgradeCard:SetItem(responses);
    script.setUpdateDelta(0);
  end
end

function upgradeCard()
  self._upgradeCard:Click();
  local it = self._upgradeCard:GetItem();
  Messenger().SendMessageNoResponse(self._parentEntityId, "SaveData",it);
end
