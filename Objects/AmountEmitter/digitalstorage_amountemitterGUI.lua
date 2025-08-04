require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Classes/Item/Item.lua"
require "/HLib/Classes/Item/ItemWrapper.lua"
require "/HLib/Classes/GUIElements/Itemslot.lua"
require "/HLib/Classes/Other/LoadData.lua"


local self = {};

function SaveChanges ()
  local dataToSave = {};
  local item = self._itemSlot:GetItem();
  if item then
    dataToSave.Item = item.ItemDescriptor;
  end
  dataToSave.Count = widget.getText("how_many");
  dataToSave.Mode = self._mode;
  Messenger().SendMessageNoResponse(self._parentEntityId, "SaveData",dataToSave);
end

function SetMode(mode)
  self._mode = mode;
  widget.setText("mode",mode );
end

function itemSlot()
  self._itemSlot:Click();
  local it = self._itemSlot:GetItem();
  if it then
    if ItemWrapper.GetItemCount(it) ~= 1 then
      ItemWrapper.SetItemCount(it,1);
      self._itemSlot:SetItem(it);
    end
  end
  SaveChanges ();
end

function mode ()

  if self._mode == "<=" then
    SetMode(">=");
  else
    SetMode("<=");
  end
  SaveChanges ();
end

function how_many ()
  local text = widget.getText("how_many");
  if text == "" then
    widget.setText("how_many", "0");
    return;
  else
    local numstr = tostring(tonumber(text));
    if text ~= numstr then
      widget.setText("how_many", numstr);
      return;
    end
  end
  SaveChanges ();
end

function init()
  self._parentEntityId = pane.containerEntityId();
  self._responseLoader = LoadData(self._parentEntityId, "LoadData");
  self._itemSlot = Itemslot("itemSlot",true);
  script.setUpdateDelta(1);
end

function update ()
  if self._responseLoader:Call() then
    local responses = self._responseLoader:GetData();
    self._responseLoader:Reset();
    if not responses then
      return;
    end
    if responses.Item then
    self._itemSlot:SetItem(Item(responses.Item));
    end
    widget.setText("how_many",responses.Count or "0");
    if (responses.Mode) then
      SetMode(responses.Mode);
    else
      SetMode("<=");
    end
    widget.setText("mode",responses.Mode or "<=" );
    script.setUpdateDelta(0);
    responses = nil;
    SaveChanges ();
  end
end
