local m = peripheral.find("modem", function(_, o) return o.isWireless() end)
local ec_oc = peripheral.find "ender_chest"
local ec_cc = peripheral.find "minecraft:ender chest"
local spatial = "back"
local spatialp = peripheral.wrap(spatial)
local name = os.getComputerLabel()
local channel = 236
local spatial_ec_loc = settings.get "spatial_ec_loc" or "east"
local busy = false
local needed_energy = 34000

local function send(x)
	print("->", unpack(x))
	m.transmit(channel, channel, x)
end

local function recv_filter(fn)
	while true do
		local _, _, c, rc, msg = os.pullEvent "modem_message"
		print("<-", unpack(msg))
		if type(msg) == "table" and fn(msg) then return msg end
	end
end

local function pick_channel()
	return math.random(0xA00, 0xC00)
end

local function run_spatial()
	rs.setOutput(spatial, true)
	sleep(0.1)
	rs.setOutput(spatial, false)
	sleep(0.1)
	print "Run spatial"
end

local function run_transfer(trg)
	busy = true
	local function run_transfer_internal()
		if spatialp.getNetworkEnergyStored() < needed_energy then print "Insufficient energy" return end
		print "Pinging"
		send { "ping", trg }
		if (recv_filter(function(m) return m[1] == "pong" and m[2] == trg end))[3] then print "Remote busy" return end
		print "Destination available"
		local ec_channel = pick_channel()
		ec_oc.setFrequency(ec_channel)
		send { "transfer", trg, ec_channel }
		if not (recv_filter(function(m) return m[1] == "transfer_ack" and m[2] == trg end))[3] then print "Remote denied transfer" return end
		print "Ack received"
		run_spatial()
		spatialp.pushItems(spatial_ec_loc, 2, 1, 1)
		print "Sent item to remote"
		repeat
			sleep(0.1)
		until ec_cc.getItemMeta(27) ~= nil
		print("Remote sent item")
		spatialp.pullItems(spatial_ec_loc, 27, 1, 1)
		run_spatial()
		spatialp.pullItems("self", 2, 1, 1)
		print "Done"
	end
	parallel.waitForAny(run_transfer_internal, function() sleep(5) print "Transfer timed out" end)
	busy = false
end

local pings_timer = nil
local function list_all()
	pings_timer = os.startTimer(1)
	send { "ping" }
end

local function inbound()
	local function run_transfer_recv(msg)
		print("Transfer request from", msg[2])
		if spatialp.getNetworkEnergyStored() < needed_energy then print "Insufficient energy" send { "transfer_ack", msg[2], false } return end
		if busy then print "Already busy, cannot accept transfer" send { "transfer_ack", msg[2], false } return end
		busy = true
		send { "transfer_ack", msg[2], true }
		print("Accepting transfer from", msg[2])
		ec_oc.setFrequency(msg[3])
		repeat
			sleep(0.1)
		until ec_cc.getItemMeta(1) ~= nil
		print "Remote sent item"
		run_spatial()
		spatialp.pullItems(spatial_ec_loc, 1, 1, 1)
		spatialp.pushItems(spatial_ec_loc, 2, 1, 27)
		print "Sent item to remote"
		run_spatial()
		spatialp.pullItems("self", 2, 1, 1)
		print "Done"
	end

	local function process(msg)
		local cmd = msg[1]
		if cmd == "ping" and (msg[2] == nil or msg[2] == name) then
			send { "pong", name, busy }
		elseif pings_timer and cmd == "pong" then
			print(msg[2])
		elseif cmd == "transfer" and msg[2] == name and type(msg[3]) == "number" then
			parallel.waitForAny(function() run_transfer_recv(msg) end, function() sleep(5) print "Inbound transfer timed out" end)
			busy = false
		end
	end

	m.open(channel)
	while true do
		local ev, timer, c, rc, msg = os.pullEvent()
		if ev == "modem_message" and c == channel and rc == channel and type(msg) == "table" then
			local ok, err = pcall(process, msg)
			if not ok then printError(err) end
		elseif ev == "timer" and timer == pings_timer then
			pings_timer = nil
		end
	end
end

local function split_at_spaces(s)
    local t = {}
    for i in string.gmatch(s, "%S+") do
       table.insert(t, i)
    end
    return t
end

local function update_self()
	print "Downloading update."
	local h = http.get "https://pastebin.com/raw/R4HrijSg"
	local t = h.readAll()
	h.close()
	local fn, err = load(t, "@program")
	if not fn then printError("Not updating: syntax error in new version:\n" .. err) return end
	local f = fs.open("startup", "w")
	f.write(t)
	f.close()
	os.reboot()
end

local function ui()
	local history = {}
	while true do
		write "|> "
		local input = read(nil, history)
		table.insert(history, input)
		local tokens = split_at_spaces(input)
		if tokens[1] == "list" then
			list_all()
			sleep(1)
		elseif tokens[1] == "update" then
			update_self()
		elseif tokens[1] == "tp" then
			table.remove(tokens, 1)
			run_transfer(table.concat(tokens, " "))
		else
			printError "Not found"
		end
	end
end

parallel.waitForAll(ui, inbound)