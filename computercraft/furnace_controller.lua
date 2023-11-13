local inchest = peripheral.wrap "quark:variant_chest_0"
local outchest = peripheral.wrap "quark:variant_chest_1"
local furns = {peripheral.find "mana-and-artifice:runeforge_tile_entity"}

local function find_next()
	for k, v in pairs(inchest.list()) do return k end
end

--[[
local smelt = {
	"minecraft:stone",
	"minecraft:baked_potato"
}
local sset = {}
for k, v in pairs(smelt) do sset[v] = true end
]]

local last_inputs = {}

local function commit()
	local f = fs.open("state", "w")
	f.write(textutils.serialise(last_inputs))
	f.close()
end

if fs.exists "state" then
	local f = fs.open("state", "r")
	last_inputs = textutils.unserialise(f.readAll())
	f.close()
end

while true do
	for _, furn in pairs(furns) do
		local nxt = find_next()
		if nxt then
			local idet = inchest.getItemDetail(nxt)
			if inchest.pushItems(peripheral.getName(furn), nxt, 1, 1) then
				last_inputs[peripheral.getName(furn)] = idet.name
				print("insert", idet.displayName)
				commit()
			end
		end
		local det = furn.getItemDetail(1)
		if det and det.name ~= last_inputs[peripheral.getName(furn)] then
			print("extract", det.displayName)
			outchest.pullItems(peripheral.getName(furn), 1, 1)
		end
	end
	sleep(1)
end