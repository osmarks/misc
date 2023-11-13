local mon = peripheral.find "monitor"
local chat = peripheral.find "chat_box"
local port_side = settings.get "spatial.port"
local ae_needed = settings.get "spatial.energy_needed"
local admins_raw = settings.get "spatial.admins"
local prefix = settings.get "spatial.prefix" or "spatial"
local name = settings.get "spatial.name" or "Spatial Control System"
local warn_lamp = settings.get "spatial.lamp"

local admins = {}
for admin in admins_raw:gmatch "([^,]+)" do
    admins[admin] = true
end

mon.setTextScale(0.5)
mon.clear()
mon.setCursorPos(1, 1)

local function get_energy()
	return peripheral.call(port_side, "getNetworkEnergyStored") / ae_needed
end

local function display(text)
	local t = term.redirect(mon)
	print(text)
	term.redirect(t)
end

local function tell(usr, msg)
	chat.tell(usr, msg, ("\167b\167o%s\167r"):format(name))
end

local function percentage(f)
	return ("%.1f"):format(f * 100) .. "%"
end

display(("SCS online. Chat prefix is %s."):format(prefix))

local command_descriptions = {
	help = "Sends this help text.",
	energy = "View the amount of stored energy in system buffers.",
	swap = "Executes a spatial IO swap - swaps the volume of space in the cell with the volume in the spatial containment structure."
}

local commands = {
	energy = function(player)
		local energy = get_energy()
		local val = percentage(energy)
		display(("%s of needed energy available."):format(val))
		local msg = "\167c\167lcannot\167r"
		if energy >= 1 then
			msg = "\167a\167lcan\167r"
		end
		tell(player, ("Buffers contain \1676\167l%s\167r of needed energy. Spatial IO %s run."):format(val, msg))
	end,
	swap = function(player, args)
		local e = get_energy()
		if e < 1 then
			error(("Insufficient energy to swap (%s)"):format(percentage(e)), 0)
		end

		rs.setOutput(warn_lamp, true)

		if args[1] == "immediate" and admins[player] then
			display "Valid user; executing immediate swap."
		else
			for i = 5, 1, -1 do
				display(("Swapping in %d seconds."):format(i))
				tell(player, ("Swapping in \167l%d\167r seconds."):format(i))
				sleep(1)
			end
		end
		display "Swapping!"
		tell(player, "Swapping \167lnow\167r.")
		rs.setOutput(port_side, true)
		sleep(0.1)
		rs.setOutput(port_side, false)
		sleep(0.1)

		rs.setOutput(warn_lamp, false)

		display "Done!"
		tell(player, "Done!")
	end,
	help = function(player)
		local text = "Available commands:"
		for command, desc in pairs(command_descriptions) do
			text = text .. "\n\167o" .. command .. "\167r - " .. desc
		end
		tell(player, text)
	end
}

while true do
	local e, p1, p2, p3 = os.pullEvent()
	if e == "command" then
		if p2 == prefix then
			local subcommand = table.remove(p3, 1)
			if commands[subcommand] then
				local ok, err = pcall(commands[subcommand], p1, p3)
				if not ok then
					display(("Error running %s: %s."):format(subcommand, err))
					tell(p1, ("\167c\167lError:\167r %s."):format(err))
				end
			else
				display(("Invalid command '%s' from %s."):format(tostring(subcommand), p1))
				tell(p1, ("Command '%s' not recognized. Confused? Try \167n\\%s help\167r."):format(tostring(subcommand), prefix))
			end
		end
	end
end