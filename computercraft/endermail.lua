package.path = "/?;/?.lua;" .. package.path
local chest = settings.get "mail.chest" or error "please set mail.chest to the network name of the (non-ender) chest to use"
local ender_chest = peripheral.find "ender_chest" or error "ender chest connected through adapter + relay required"
local ender_chest_inv = peripheral.find "minecraft:ender chest" or error "ender chest directly connected required"
local modem = peripheral.find("modem", function(_, x) return x.isWireless() end) or error "wireless modem required"
local ok, ecnet = pcall(require, "ecnet")
if not ok then
	print "Downloading ECNet library (https://forums.computercraft.cc/index.php?topic=181.0)"
	shell.run "wget https://gist.githubusercontent.com/migeyel/278f77628248ea991719f0376979b525/raw/ecnet.min.lua ecnet.lua"
end
ecnet = require "ecnet"
local label = os.getComputerLabel() or error "Please set a label to use as a device name"
print("Address is", ecnet.address)
local ecnet_modem = ecnet.wrap(modem)
local maildata_path = "maildata"

local acceptable_mailbox_name_pattern = "^[A-Za-z0-9_]+$"
if not label:match(acceptable_mailbox_name_pattern) then error("label must match: " .. acceptable_mailbox_name_pattern) end

local function find_channel()
	for i = 0, 10 do
		local new = math.random(0, 0xFFF)
		ender_chest.setFrequency(new)
		local count = 0
		for _, stack in pairs(ender_chest_inv.list()) do
			count = count + stack.count
		end
		if count == 0 then
			return new
		end
	end
	error "Available channel scan failed after 10 tries - has someone flooded ender chests with random stuff?"
end

local function writef(n, c)
	local f = fs.open(n, "w")
	f.write(c)
	f.close()
end

local function readf(n)
	local f = fs.open(n, "r")
	local out = f.readAll()
	f.close()
	return out
end

local data = {}
if fs.exists(maildata_path) then data = textutils.unserialise(readf(maildata_path)) end
if type(data.paired) ~= "table" then data.paired = {} end

local function save_data() writef(maildata_path, textutils.serialise(data)) end

local function split_at_spaces(s)
    local t = {}
    for i in string.gmatch(s, "%S+") do
       table.insert(t, i)
    end
    return t
end

local function update_self()
	print "Downloading update."
	local h = http.get "https://pastebin.com/raw/86Kjhq32"
	local t = h.readAll()
	h.close()
	local fn, err = load(t, "@mail")
	if not fn then printError("Not updating: syntax error in new version:\n" .. err) return end
	local f = fs.open("startup", "w")
	f.write(t)
	f.close()
	os.reboot()
end

local function first_letter(s)
    return string.sub(s, 1, 1)
end

local function send_stack(slot, addr)
	local channel = find_channel()
	print("[OUT] Channel:", channel)
	ecnet_modem.send(addr, { "stack_request", channel = channel })
	local _, result = os.pullEvent "stack_request_response"
	if result == true then
		ender_chest_inv.pullItems(chest, slot)
		print("[OUT] Sent stack", slot)
		local _, result, x = os.pullEvent "stack_result"
		if result == false then
			printError("[OUT] Destination error: " .. tostring(x))
			for eslot in pairs(ender_chest_inv.list()) do
				ender_chest_inv.pushItems(chest, eslot)
			end
		end
		return result
	else return false end
end

local function get_name(address)
	for name, addr in pairs(data.paired) do
		if addr == address then return name end
	end
	return address
end

local last_pair_request = nil

local CLI_commands = {
	address = function()
		print(ecnet.address)
	end,
	update = update_self,
	pair = function(addr)
		local ok = ecnet_modem.connect(addr, 2)
		if not ok then error("Could not contact " .. addr) end
		ecnet_modem.send(addr, { "pair", label = label })
	end,
	accept_pair = function()
		if not last_pair_request then error "no pair request to accept" end
		ecnet_modem.send(last_pair_request.address, { "pair_accept", label = label })
		data.paired[last_pair_request.label] = last_pair_request.address
		save_data()
		last_pair_request = nil
	end,
	reject_pair = function()
		if not last_pair_request then error "no pair request to reject" end
		ecnet_modem.send(last_pair_request.address, { "pair_reject", label = label })
		last_pair_request = nil
	end,
	paired = function()
		print "Paired:"
		for label, addr in pairs(data.paired) do
			print(label, addr)
		end
	end,
	unpair = function(name)
		data.paired[name] = nil
		save_data()
	end,
	send = function(name)
		local addr = data.paired[name]
		if not addr then error(name .. " not found") end
		if not ecnet_modem.connect(addr, 3) then error("Connection to " .. name .. " failed") end
		print "Connected"
		for slot, contents in pairs(peripheral.call(chest, "list")) do
			print("[OUT] Sending stack", slot)
			local timed_out, result = false, nil
			parallel.waitForAny(function() result = send_stack(slot, addr) end, function() sleep(5) timed_out = true end)
			if not timed_out then print("[OUT] Destination success") else printError "[OUT] Timed out." end
		end
	end,
	help = function()
		write([[EnderMail UI commands:
address - print address
update - update the code
pair [address] - send a pairing request to the specified address
accept_pair - accept the latest pairing request
deny_pair - reject the latest pairing request
paired - list all paired mailboxes
unpair [name] - remove the named mailbox from your paired list
send [name] - send contents of chest to specified paired mailbox
]])
	end
}

local function handle_commands()
	print "Mailbox UI"
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

local function handle_message(addr, msg)
	if type(msg) == "table" then
		if msg[1] == "pair" then
			if not msg.label or not msg.label:match(acceptable_mailbox_name_pattern) then return end
			print(("Pair request from %s (%s)"):format(addr, msg.label))
			print "`accept_pair` to accept, `reject_pair` to deny"
			last_pair_request = { address = addr, label = msg.label }
		elseif msg[1] == "pair_accept" then
			if not msg.label or not msg.label:match(acceptable_mailbox_name_pattern) then return end
			print(("%s (%s) accepted pairing"):format(addr, msg.label))
			data.paired[msg.label] = addr
			save_data()
		elseif msg[1] == "pair_reject" then
			if not msg.label or not msg.label:match(acceptable_mailbox_name_pattern) then return end
			print(("%s (%s) rejected pairing"):format(addr, msg.label))
		elseif msg[1] == "stack_request" then
			if not msg.channel or msg.channel < 0 or msg.channel > 0xFFF then ecnet_modem.send(addr, { "stack_request_response", false, "channel missing/invalid" }) end
			ender_chest.setFrequency(msg.channel)
			ecnet_modem.send(addr, { "stack_request_response", true })
			local start = os.clock()
			-- constantly attempt to move items until done
			while os.clock() - start <= 5 do
				for slot, stack in pairs(ender_chest_inv.list()) do
					local moved = ender_chest_inv.pushItems(chest, slot)
					print("[IN]", get_name(addr), stack.name, moved)
					if moved > 0 then
						ecnet_modem.send(addr, { "stack_result", true, channel = msg.channel })
						return
					else
						ecnet_modem.send(addr, { "stack_result", false, "out of space", channel = msg.channel })
						return
					end
				end
			end
			ecnet_modem.send(addr, { "stack_result", false, channel = msg.channel })
		elseif msg[1] == "stack_request_response" then
			os.queueEvent("stack_request_response", msg[2])
		elseif msg[1] == "stack_result" then
			os.queueEvent("stack_result", msg[2], msg[3])
		end
	end
end

local function handle_messages()
	while true do
		handle_message(ecnet_modem.receive())
	end
end

parallel.waitForAll(handle_commands, handle_messages)