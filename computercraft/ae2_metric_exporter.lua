local ae2 = peripheral.wrap "right"
local m = peripheral.find "modem"

local items = {
	"minecraft:redstone",
	"minecraft:quartz",
	"minecraft:glowstone_dust",
	"minecraft:iron_ingot",
	"appliedenergistics2:material",
	{ name="minecraft:planks", damage = 5 },
	"minecraft:coal",
	"minecraft:diamond"
}
local dn_cache = {}

local function send_metric(...)
	m.transmit(3054, 3054, {...})
end

while true do
	local cpus = ae2.getCraftingCPUs()
	local cpucount = 0
	for _, cpu in pairs(cpus) do if cpu.busy then cpucount = cpucount + 1 end end
	send_metric("busy_crafting_cpus", "number of crafting CPUs operating", "set", cpucount)
	for _, id in pairs(items) do
		local ok, i = pcall(ae2.findItem, id)
		local count = 0
		if ok and i then
			local meta = i.getMetadata()
			dn_cache[id] = meta.displayName
			count = meta.count
		end
		if dn_cache[id] then
			send_metric("items/" .. dn_cache[id], "stored items in ME network", "set", count)
		end
	end
	sleep(1)
end