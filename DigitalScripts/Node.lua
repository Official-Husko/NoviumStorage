--[[
  Node.lua
  --------
  Utility function for finding a container object below the current entity in Starbound.
  Iterates downward from the entity's position, checking for objects with container slots.

  Starbound API cross-reference:
    - entity.position(): Returns the current entity's world position (see entity.md)
    - world.objectAt(): Returns the object entity ID at a given position (see world.md)
    - world.containerSize(): Returns the number of slots in a container (see world.md)
]]

function FindContainer(distance)
  distance = distance or 1;
  pos = entity.position(); -- Get current entity position
  for i = 1, distance do
    pos[2] = pos[2] - 1; -- Move one block down
    local obj = world.objectAt(pos); -- Check for object at position
    if obj then
      local slots = world.containerSize(obj); -- Check if object is a container
      if slots ~= nil and slots ~= 0 then
        return obj, pos; -- Return container entity ID and position
      end
    end
  end
  return nil;
end
