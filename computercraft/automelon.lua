local storage = peripheral.find "minecraft:ender chest"
local monitor = peripheral.find "monitor"
local button = settings.get "melon.button" or "right"
local dispense_count = 16
local dispense_direction = settings.get "melon.dispense" or "west"
local display_name = "Melon"
local to_store = "minecraft:melon"

local function mon_write(...)
	monitor.setTextScale(1)
	local oldterm = term.redirect(monitor)
	term.clear()
	term.setCursorPos(1, 1)
	print "GTech AutoMelon"
	write(...)
	term.redirect(oldterm)
end

local function fill_chest()
	while true do
		local count = 0
		for slot, stack in pairs(storage.list()) do
			if stack.name == to_store then
				count = count + stack.count
			end
		end
		mon_write(("%dx %s stored\nPress button for %dx %s"):format(count, display_name, dispense_count, display_name))
		local timer = os.startTimer(5)
		while true do
			local ev, param = os.pullEvent()
			if (ev == "timer" and param == timer) or ev == "refresh_storage" then break end
		end
	end
end

local function handle_button()
	while true do
		os.pullEvent "redstone"
		if redstone.getInput(button) then
			local contents = storage.list()
			for slot, stack in pairs(contents) do
				if stack.count > dispense_count then
					print("Dispensing", dispense_count, "from", slot, "to", dispense_direction)
					storage.drop(slot, dispense_count, dispense_direction)
					os.queueEvent("refresh_storage")
					break		
				end
			end
		end
	end
end

parallel.waitForAll(handle_button, fill_chest)