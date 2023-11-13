local mods = peripheral.find "manipulator"
local buffer = "up"
local inventory = mods.getInventory()
local ender = mods.getEnder()
mods.clearCaptures()

local item_name_cache = {}

local function stack_type_id(stack)
	return stack.name .. ":" .. tostring(stack.damage or 0) .. "#" .. (stack.nbtHash or "")
end

local function display_name(stack, inv, slot)
	local type_id = stack_type_id(stack)
	if item_name_cache[type_id] then return item_name_cache[type_id] end
	item_name_cache[type_id] = inv.getItemMeta(slot).displayName
	return item_name_cache[type_id]
end

local function scan(inventory)
	local inv = {}
	for slot, stack in pairs(inventory.list()) do
		inv[slot] = display_name(stack, inventory, slot)
	end
	return inv
end

local function strip_section_codes(str)
	return str:gsub("\167[0-9a-z]", "")
end

local function normalize(str)
	return strip_section_codes(str):gsub(" ", ""):lower()
end

local function find_items(inventory, search)
	local candidates = {}
	local search = normalize(search)
	for slot, name in pairs(scan(inventory)) do
		if normalize(name):match(search) then table.insert(candidates, { slot, strip_section_codes(name) }) end
	end
	return candidates
end

local function string_to_list(str)
	local list = {}
	for i = 1, #str do
		table.insert(list, str:sub(i, i))
	end
	return list
end

local function contains(l, x)
	for k, v in pairs(l) do
		if v == x then return true end
	end
	return false
end

local max_tell_length

local function split_tell(msg)
	local remaining = msg
	repeat
		local fst = remaining:sub(1, 100)
		remaining = remaining:sub(101)
		mods.tell(fst)
	until remaining == ""
end

local function run(flags, args)
	local source, destination, source_name, destination_name = inventory, ender, "inventory", "enderchest"
	if contains(flags, ">") and not contains(flags, "<") then -- if set to pull FROM enderchest
		source, destination, source_name, destination_name = ender, inventory, "enderchest", "inventory"
	end
	local query_only_mode = contains(flags, "?")
	local items = find_items(source, args == "any" and "" or args)
	if query_only_mode then
		local item_names = {}
		for _, v in pairs(items) do
			table.insert(item_names, v[2])
		end
		split_tell(("Items matching query %s in %s: %s."):format(args, source_name, table.concat(item_names, ", ")))
	else
		local fst = items[1]
		if not fst then mods.tell(("No item matching query %s found in %s."):format(args, source_name)) return end
		mods.tell(("Moving %s from %s to %s."):format(fst[2], source_name, destination_name))
		source.pushItems(buffer, fst[1])
		local moved = destination.pullItems(buffer, 1)
		mods.tell(("Moved %d item(s)."):format(moved))
	end
end

mods.capture "^!e"
local owner = mods.getName()

while true do
	local _, msg, _, user = os.pullEvent "chat_capture"
	if user == owner then
		print(msg)
		local flags, args = msg:match "^!e ([<?>\^]+) ([A-Za-z0-9_ -]+)"
		if not flags then mods.tell "!e command parse error."
		else 
			local ok, err = pcall(run, string_to_list(flags), args)
			if not ok then printError(err) mods.tell(err:sub(1, 100)) end
		end
	end
end