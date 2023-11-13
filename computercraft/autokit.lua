local box_side = "down"
local box = peripheral.find "thermalexpansion:storage_strongbox"
local interface = peripheral.find "appliedenergistics2:interface"

local kitfile = ...
if not kitfile then error "provide a kit file" end
local kit = dofile(kitfile)

for slot, stack in pairs(box.list()) do
	local name = stack.name .. "@" .. tostring(stack.damage)
	print(stack.count, name, "already present")
	for i, it in pairs(kit) do
		if it[1] == stack.name or it[1] == name then
			it[2] = it[2] - stack.count
			if it[2] <= 0 then table.remove(kit, i) end
			break
		end
	end
end

local function free_crafting_CPUs()
	local count = 0
	for _, CPU in pairs(interface.getCraftingCPUs()) do
		if not CPU.busy then count = count + 1 end
	end
	return count
end

local max_concurrency = math.max(free_crafting_CPUs() / 2, 1)
print("Using max", max_concurrency, "crafting CPUs")

local function display_kit_item(i)
	return ("%s x%d"):format(i[1], i[2])
end

local function export(item, count)
	local total = 0
	while total < count do
		local new = item.export(box_side, count - total)
		if new == 0 then error "no items available or storage full" end
		total = total + new
	end
end

local tasks = {}

while true do
	if #tasks < max_concurrency and #kit > 0 then
		-- pop off next item
		local nexti = table.remove(kit, 1)
		local item = interface.findItem(nexti[1])
		if not item then error(display_kit_item(nexti) .. " not found?") end
		local desired = nexti[2]
		local existing = item.getMetadata().count
		if existing < desired then
			local crafting_job = item.craft(desired - existing)
			print("Queueing", display_kit_item(nexti))
			table.insert(tasks, { job = crafting_job, itemtype = nexti, item = item })
		end
		if existing > 0 then
			export(item, math.min(existing, desired))
			print("Exporting existing", display_kit_item { nexti[1], math.min(existing, desired) })
		end
	else
		for i, task in pairs(tasks) do
			local status = task.job.status()
			if status == "canceled" then
				error("Job for " .. display_kit_item(task.itemtype) .. " cancelled by user")
				table.remove(tasks, i)
			elseif status == "missing" then
				error("Job for " .. display_kit_item(task.itemtype) .. " missing items")
				table.remove(tasks, i)
			elseif status == "finished" then
				print("Exporting", display_kit_item(task.itemtype))
				export(task.item, task.itemtype[2])
				table.remove(tasks, i)
			end
		end
		sleep(1)
	end
	if #tasks == 0 and #kit == 0 then print "Done!" break end
end