local lamp = peripheral.find "colorful_lamp"
lamp.setLampColor(32767)
local sensor = peripheral.find "plethora:sensor"
local label = os.getComputerLabel()
local switch_config = dofile "config.lua"

local function spudnet()
	if not http or not http.websocket then return "Websockets do not actually exist on this platform" end
	
	local ws

	local function send_packet(msg)
		local ok, err = pcall(ws.send, textutils.serialiseJSON(msg))
		if not ok then printError(err) try_connect_loop() end
	end

	local function send(data)
		send_packet { type = "send", channel = "comm:arr", data = data }
	end

	local function connect()
		if ws then ws.close() end
		ws, err = http.websocket "wss://spudnet.osmarks.net/v4?enc=json"
		if not ws then print("websocket failure %s", err) return false end
		ws.url = "wss://spudnet.osmarks.net/v4?enc=json"

		send_packet { type = "identify", implementation = "ARR switching unit", key = settings.get "spudnet_key" }
		send_packet { type = "set_channels", channels = { "comm:arr" } }

		print("websocket connected")

		return true
	end
	
	local function try_connect_loop()
		while not connect() do
			sleep(0.5)
		end
	end
	
	try_connect_loop()

	local function recv()
		while true do
			local e, u, x = os.pullEvent "websocket_message"
			if u == ws.url then return textutils.unserialiseJSON(x) end
		end
	end
	
	local ping_timeout_timer = nil

	local function ping_timer()
		while true do
			local _, t = os.pullEvent "timer"
			if t == ping_timeout_timer and ping_timeout_timer then
				-- 15 seconds since last ping, we probably got disconnected
				print "SPUDNET timed out, attempting reconnect"
				try_connect_loop()
			end
		end
	end
	
	local function main()
		while true do
			local packet = recv()
			if packet.type == "ping" then
				send_packet { type = "pong", seq = packet.seq }
				if ping_timeout_timer then os.cancelTimer(ping_timeout_timer) end
				ping_timeout_timer = os.startTimer(15)
			elseif packet.type == "error" then
				print("SPUDNET error", packet["for"], packet.error, packet.detail, textutils.serialise(packet))
			elseif packet.type == "message" then
				os.queueEvent("spudnet_message", packet.data)
			end
		end
	end

	return send, function() parallel.waitForAll(ping_timer, main) end
end

local spudnet_send, spudnet_handler = spudnet()

local directions = {
	["+ "] = "east",
	[" +"] = "south",
	["- "] = "west",
	[" -"] = "north"
}

local function direction_name(vec)
	local function symbol(v)
		if math.abs(v) < 0.1 then return " "
		elseif v < 0 then return "-"
		else return "+" end
	end
	return directions[symbol(vec.x) .. symbol(vec.z)]
end

local function main()
	while true do
		local entities = sensor.sense()
		for _, entity in pairs(entities) do
			entity.position = vector.new(entity.x, entity.y, entity.z) + switch_config.offset
			entity.velocity = vector.new(entity.motionX, entity.motionY, entity.motionZ)
		end
		table.sort(entities, function(a, b) return a.position:length() < b.position:length() end)
		local carts = {}
		for _, entity in pairs(entities) do
			if entity.displayName == "entity.MinecartRideable.name" then
				entity.riders = {}
				table.insert(carts, entity)
				break
			end
		end
		local new_carts = {}
		local relevant_carts = 0
		for _, cart in pairs(carts) do
			local new = {
				pos = direction_name(cart.position), dir = direction_name(cart.velocity),
				distance = cart.position:length(),
				riders = {},
				id = cart.id
			}
			for _, entity in pairs(entities) do
				if entity.displayName ~= "entity.MinecartRideable.name" and entity ~= cart and (cart.position - entity.position):length() < 1 then
						table.insert(new.riders, entity.displayName)
					break
				end
			end
			if new.dir and #new.riders > 0 then
				relevant_carts = relevant_carts + 1
			end
			table.insert(new_carts, new)
		end
		spudnet_send { id = label, type = "sw_ping", carts = new_carts }
		if relevant_carts == 0 then sleep(0.5) elseif relevant_carts == 1 then sleep(0.25) else sleep(0.1) end
	end
end

local function spudnet_listen()
	while true do
		local _, data = os.pullEvent "spudnet_message"
		if type(data) == "table" and data.type == "sw_cmd" and (data.id == label or data.id == nil) then
			--print(data.type, data.cmd)
			if data.cmd == "set" then
				print("set")
				if data.lamp then lamp.setLampColor(data.lamp) end
				if data.switch ~= nil then rs.setOutput(switch_config.side, data.switch == 1) end
				spudnet_send { type = "sw_ack", cid = data.cid }
			elseif data.cmd == "update" then
				local h, e = http.get "https://pastebin.com/raw/g9gfxwsb"
				if not h then printError(e)
				else
					lamp.setLampColor(1023)
					local t = h.readAll()
					h.close()
					local f, e = load(t)
					if f then
						local f = fs.open("startup", "w")
						f.write(t)
						f.close()
						print "reboot"
						sleep(1)
						os.reboot()
					else printError(e) end
					
				end
			end
		end
	end
end

parallel.waitForAll(spudnet_handler, main, spudnet_listen)