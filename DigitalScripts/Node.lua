function FindContainer(distance)
  distance = distance or 1;
  pos = entity.position();
  for i = 1, distance do
    pos[2] = pos[2] - 1;
    local obj = world.objectAt(pos);
    if obj then
      local slots = world.containerSize(obj);
      if slots ~= nil and slots ~= 0 then
        return obj, pos;
      end
    end
  end
  return nil;
end
