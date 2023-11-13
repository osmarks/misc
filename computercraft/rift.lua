local channel = 31415

local m = peripheral.find("modem", function(_, o) return o.isWireless() end)
if not m then error "Modem required!" end

local tele = peripheral.find "Teleporter"
if not tele then error "Teleporter (see Mekanism wiki) required!" end

local sign = peripheral.find "minecraft:sign"

local rift_ID = os.getComputerLabel():match "Rift:([A-Za-z0-9_-]+)"

if not rift_ID then error "Please relabel this computer `Rift:[unique rift identifier]`." end

m.open(channel)

local function display_status(...)
	if sign then sign.setSignText(rift_ID, ...) end
end

local function split_at_spaces(s)
    local t = {}
    for i in string.gmatch(s, "%S+") do
       table.insert(t, i)
    end
    return t
end

local function first_letter(s)
    return string.sub(s, 1, 1)
end

local function update_self()
	print "Downloading update."
	local h = http.get "https://pastebin.com/raw/jta5puZL"
	local t = h.readAll()
	h.close()

	local fn, err = load(t, "@rift")
	if not fn then printError("Not updating: syntax error:\n" .. err) end

	local f = fs.open("startup", "w")
	f.write(t)
	f.close()
	os.reboot()
end

local teleporter_errors = {
	[2] = "Frame invalid.",
	[3] = "Pairing error.",
	[4] = "Insufficient energy."
}

local function send_message(...)
	m.transmit(channel, channel, { ... })
end

local function disconnect(remote)
	display_status "Idle"
	if not remote then send_message("command", "handle_disconnect", rift_ID) end
	tele.setFrequency(("rift-%s-null"):format(rift_ID), true)
end

local connected_to = nil

local remote_commands = {
	ping = function()
		return { rift_ID }
	end,
	update = function()
		update_self()
	end,
	dial = function(from, to)
		if to ~= rift_ID then return end
		if type(from) ~= "string" then error("Invalid or no originator specified!") end
		local freq = ("rift-%s-%s"):format(from, to)
		tele.setFrequency(freq, true)
		local status = tele.canTeleport()
		if status == 1 then
			print(("Connection established from %s."):format(from))
			display_status("Dialed from:", from)
			connected_to = from
			return { true }
		else
			local e = teleporter_errors[status] or "Unknown error."
			display_status("Error:", e)
			printError(("Error receiving connection from %s: %s"):format(from, e))
			return { false, e }
		end
	end,
	handle_disconnect = function(other_end)
		if other_end == connected_to then disconnect(true) end
	end
}

local function timeout(fn, time)
	local timer = os.startTimer(time)
	local co = coroutine.create(fn)
	local filter
	while true do
		local ev = { os.pullEvent() }
		if coroutine.status(co) == "dead" or ev[1] == "timer" and ev[2] == timer then return end
		if not filter or filter == ev[1] then
			local ok, res = coroutine.resume(co, unpack(ev))
			if not ok then error(res)
			else filter = res end
		end
	end
end

local usage = 
[[Welcome to Rift. All listed commands are accessible by single-letter shortcuts.
dial [destination] - Open a connection to rift [destination].
scan - Scan for available rifts.
scan [filter] - Scan for available rifts whose names contain [filter].
help - Print this.
update - Update this.
disconnect - Disconnect from current paired rift.
id - Get the ID of the current rift.]]

local CLI_commands = {
	help = function() textutils.pagedPrint(usage) end,
	dial = function(dest)
		if not dest then error "No destination rift specified." end
		local freq = ("rift-%s-%s"):format(rift_ID, dest)
		print(("Setting frequency to %s."):format(freq))
		tele.setFrequency(freq, true)
		print(("Sending dial request to %s."):format(dest))
		send_message("command", "dial", rift_ID, dest)

		local result
		timeout(function()
			while true do
				local _, response_to, success, error_type = os.pullEvent "remote_result"
				if response_to == "dial" then
					if not success then
						print(dest, "reports error:", error_type)
						result = "remote_error"
					else
						print(dest, "reports success.")
						local status = tele.canTeleport()
						if status == 1 then
							result = "success"
							print "Link established."
							display_status("Dialed to:", dest)
							connected_to = dest
						else
							result = "local_error"
							local e = teleporter_errors[status] or "Unknown error."
							display_status("Error:", e)
							print(e)
						end
					end
					break
				end
			end
		end, 1)

		if result == nil then error(dest .. " is unreachable or nonexistent.", 0) end
	end,
	update = function(what)
		if what == "all" then
			send_message("command", "update")
			print "Update command broadcast"
		end
		update_self()
	end,
	scan = function(filter)
		send_message("command", "ping")
		print "Scanning..."
		timeout(function()
			while true do
				local _, resp_to, from = os.pullEvent "remote_result"
				if resp_to == "ping" and from and (not filter or from:match(filter)) then
					print("Found:", from)
				end
			end
		end, 1)
	end,
	disconnect = disconnect,
	id = function()
		print("Rift ID:", rift_ID)
	end
}

local function command_prompt()
	print "Welcome to Rift!"
	local history = {}
	while true do
		write "|> "
		local text = read(nil, history)

		if text ~= "" then table.insert(history, text) end

		local tokens = split_at_spaces(text)
		local command = table.remove(tokens, 1)
		local args = tokens
		local fn = CLI_commands[command]

		if not fn then
			for command_name, func in pairs(CLI_commands) do
				if command and first_letter(command_name) == first_letter(command) then fn = func end
			end
		end
		if not fn then
			print("Command", command, "not found.")
		else
			local ok, err = pcall(fn, table.unpack(args))
			if not ok then printError(err) end
		end
	end
end

local function message_handler()
	while true do
		local _, _, _, _, message = os.pullEvent "modem_message"
		if type(message) == "table" then
			local mtype = table.remove(message, 1)
			if mtype == "command" then
				local cmd = table.remove(message, 1)
				local cmd_fn = remote_commands[cmd]
				if cmd_fn then
					local ok, res = pcall(cmd_fn, unpack(message))
					if ok then
						if type(res) == "table" then
							send_message("result", cmd, unpack(res))
						end
					else
						printError(res)
						send_message("error", res)
					end
				end
			elseif mtype == "result" then os.queueEvent("remote_result", unpack(message))
			elseif mtype == "error" then os.queueEvent("remote_error", unpack(message)) end
		end
	end
end

if ... == "update" then update_self() end

disconnect()

parallel.waitForAny(message_handler, command_prompt)