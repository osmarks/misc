local chest = "back"
local chest_to_turtle = "east"
local turtle_to_chest = "west"

local function sum_inv(i)
  local out = {}
  for _, v in pairs(i) do
    out[v.name] = (out[v.name] or 0) + v.count
  end
  return out
end

local function clear_inv()
  for i = 1, 16 do
    peripheral.call(chest, "pullItems", turtle_to_chest, i)
  end
end

local recipe = {
  {"minecraft:sand",   "minecraft:sand",   "minecraft:sand"},
  {"minecraft:sand",   "minecraft:gravel", "minecraft:gravel"},
  {"minecraft:gravel", "minecraft:gravel", "minecraft:dye"},
}
local reqs = {}
for y, row in pairs(recipe) do
  for x, item in pairs(row) do
    reqs[item] = (reqs[item] or 0) + 1
  end
end

local function satisfied(reqs, by)
  for req, qty in pairs(reqs) do
    if qty > (by[req] or 0) then return false end
  end
  return true
end

local function move(what, to)
  for slot, stack in pairs(peripheral.call(chest, "list")) do
    if stack.name == what then peripheral.call(chest, "pushItems", chest_to_turtle, slot, 1, to) return end
  end
end

while true do
  local contents = peripheral.call(chest, "list")
  local items = sum_inv(contents)
  if satisfied(reqs, items) then
    print "Requirements satisfied; crafting."
    for y, row in pairs(recipe) do
      for x, item in pairs(row) do
        local tslot = ((y - 1) * 4) + x
        move(item, tslot)
        sleep()
      end
    end
    turtle.select(1)
    turtle.craft()
    --turtle.dropDown()
    repeat turtle.place() sleep()
    until turtle.getItemCount() == 0
  else
    print "Not crafting; requirements not satisfied."
  end
  sleep(1)
end