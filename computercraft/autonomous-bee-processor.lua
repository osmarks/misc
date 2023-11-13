local input_chest = "actuallyadditions:giantchestlarge_0"
--local princess_chest = "actuallyadditions:giantchestlarge_2"
local bee_products_chest = "actuallyadditions:giantchestlarge_1"
local bee_overflow_chest = "actuallyadditions:giantchestlarge_7"
local apiaries = {peripheral.find "forestry:apiary"}
local index = {}
local bee_list = {}
local storage = {peripheral.find("actuallyadditions:giantchestlarge", function(n) return n ~= input_chest and n ~= bee_products_chest and n ~= bee_overflow_chest end)}
print("Got", #storage, "storage chests")

local function find_free_space()
	for _, inv in pairs(storage) do
		if not inv.cached_size then inv.cached_size = inv.size() end
		local name = peripheral.getName(inv)
		if not index[name] then
			return name, 1
		end
		for slot = 1, inv.cached_size do
			if not index[name][slot] then return name, slot end
		end
	end
end

local function run_cleanup()
	for i = 1, peripheral.call(bee_overflow_chest, "size") do
		local bee = bee_list[1]
		local moved = peripheral.call(bee_overflow_chest, "pullItems", bee[1], bee[2])
		index[bee[1]][bee[2]].count = index[bee[1]][bee[2]].count - moved
		if index[bee[1]][bee[2]].count == 0 then
			index[bee[1]][bee[2]] = nil
			table.remove(bee_list, 1)
		end
		print("Eliminated", moved, "bees")
	end
end

local tol_table = {
	none = 0,
	both_1 = 3,
	both_2 = 4,
	both_3 = 6,
	up_1 = 1.5,
	down_1 = 1.5,
	up_2 = 2,
	down_2 = 2,
	up_3 = 3,
	down_3 = 3
}

local function score_genome_slot(g)
	local score = g.speed * 8 + (20 / g.lifespan) + g.fertility
	if g.never_sleeps then score = score + 5 end
	if g.tolerates_rain then score = score + 2 end
	if g.cave_dwelling then score = score + 5 end
	score = score + tol_table[g.humidity_tolerance]
	score = score + tol_table[g.temperature_tolerance]
	return score
end

local function score_bee(individual)
	return score_genome_slot(individual.genome.active) + 0.5 * score_genome_slot(individual.genome.inactive)
end

local function insert_into_list(bee, inv, slot)
	local score = score_bee(bee.bee_data)
	local lo, hi = 1, #bee_list + 1
	while lo < hi do
		local mid = math.floor((lo + hi) / 2)
		local compr_score = bee_list[mid][3]
		if score < compr_score then
			hi = mid
		else
			lo = mid + 1
		end
	end
	table.insert(bee_list, lo, { inv, slot, score })
end

local indexed_count = 0
print "Bee indexing initiating"
for _, chest in pairs(storage) do
	local name = peripheral.getName(chest)
	if not index[name] then index[name] = {} end
	for slot, item in pairs(chest.list()) do
		local meta = chest.getItemMeta(slot)
		index[name][slot] = { count = item.count, name = meta.displayName, bee_data = meta.individual }
		indexed_count = indexed_count + 1
		if indexed_count % 100 == 0 then sleep() print(indexed_count, "bees indexed") end
	end
end
print(indexed_count, "bees indexed")

print "Bee list preload initiating"
for inv, contents in pairs(index) do
	for slot, bee in pairs(contents) do
		insert_into_list(bee, inv, slot)
	end
end

while true do
	local modified_count = 0
	for slot, info in pairs(peripheral.call(input_chest, "list")) do
		if string.find(info.name, "drone") then
			local meta = peripheral.call(input_chest, "getItemMeta", slot)
			local invname, targslot = find_free_space()
			if not invname then
				printError "Bee store at capacity - initiating cleanup."
				run_cleanup()
				sleep(1)
			else
				local moved = peripheral.call(input_chest, "pushItems", invname, slot, 64, targslot)
				if not moved then
					printError "Bees nonmotile"
					sleep(1)
				else
					data = { count = moved, name = meta.displayName, bee_data = meta.individual }
					index[invname] = index[invname] or {}
					index[invname][targslot] = data
					modified_count = modified_count + 1
					insert_into_list(data, invname, targslot)
				end
			end
		elseif not string.find(info.name, "princess") then
			peripheral.call(input_chest, "pushItems", bee_products_chest, slot)
		end		
	end
	print("Loaded", modified_count, "unique bees into stores")
	modified_count = 0
	for _, apiary in pairs(apiaries) do
		local content = apiary.list()
		if not content[1] then -- need princess
			print "Loading princess"
			local success = false
			for slot, ccontent in pairs(peripheral.call(input_chest, "list")) do
				if ccontent and string.find(ccontent.name, "princess") then
					peripheral.call(input_chest, "pushItems", peripheral.getName(apiary), slot)
					success = true
					break
				end
			end
			if not success then
				printError "Insufficient princesses"
				sleep(1)
			end
		end
		if not content[2] then
			print "Loading drone"
			local bee = table.remove(bee_list)
			if not bee then
				printError "Drone not found"
				sleep(1)
			else
				local moved = peripheral.call(bee[1], "pushItems", peripheral.getName(apiary), bee[2])
				index[bee[1]][bee[2]].count = index[bee[1]][bee[2]].count - moved
				if index[bee[1]][bee[2]].count == 0 then
					index[bee[1]][bee[2]] = nil
				end
				modified_count = modified_count + 1
			end
		end
		sleep(0.05)
	end
	print("Moved", modified_count, "drones")
end