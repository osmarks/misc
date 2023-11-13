local inputs = {"minecraft:ironchest_gold_338"}
local storage = {peripheral.find "minecraft:ironchest_iron"}

local free_space_cache = {}

local function has_free_space(chest)
    if free_space_cache[chest] then return free_space_cache[chest] > 0 end
    local max = chest.size() * 64
    local count = 0
    for slot, content in pairs(chest.list()) do
        count = count + content.count
    end
    free_space_cache[chest] = max - count
    return count < max
end

local function move_stack(source, slot, size)
    local remaining = size
    for _, chest in pairs(storage) do
        if has_free_space(chest) then
            local removed = chest.pullItems(source, slot)
            free_space_cache[chest] = free_space_cache[chest] - removed
            remaining = remaining - removed
        end
        if remaining <= 0 then return true end
    end
    return false
end

while true do
	for _, input in pairs(inputs) do
	    for slot, content in pairs(peripheral.call(input, "list")) do
    	    print(input, slot, content.count)
        	move_stack(input, slot, content.count)
	        sleep(0.5)
    	end
	end
    sleep(10)
end