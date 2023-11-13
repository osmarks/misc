local sign = peripheral.find "minecraft:sign"
local sensor = peripheral.find "plethora:sensor"
local label = os.getComputerLabel()
local chest = peripheral.wrap "bottom"

sign.setSignText "Rotating"

local powered_rail_side = "right"

while true do
	local presence, meta = turtle.inspect()
	if presence and meta.name == "minecraft:activator_rail" then
		break
	end
	turtle.turnRight()
end

turtle.turnLeft()
local presence, meta = turtle.inspect()
if presence and meta.name == "minecraft:golden_rail" then
	powered_rail_side = "left"
end
turtle.turnRight()

local function sign_display(player)
	local l2, l3 = "", ""
	if player then
		l2 = "Welcome, "
		l3 = player
	end
	sign.setSignText(label, l2, l3, "\\arr goto [dest]")
end
sign_display()

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

		send_packet { type = "identify", implementation = "ARR station unit", key = settings.get "spudnet_key" }
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

local function main()
	while true do
		local entities = sensor.sense()
		local players = {}
		for _, entity in pairs(entities) do
			entity.position = vector.new(entity.x, entity.y, entity.z)
			if entity.position:length() < 5 and entity.displayName == entity.name then
				table.insert(players, entity.displayName)
			end
		end
		if #players > 0 then
			sign_display(players[1])
			spudnet_send { id = label, type = "st_ping", players = players }
		end
		if turtle.suck() then
			turtle.select(1)
			chest.pullItems("up", 1)
		end
		sleep(1)
	end
end

local busy
local function spudnet_listen()
	while true do
		local _, data = os.pullEvent "spudnet_message"
		if type(data) == "table" and data.type == "st_cmd" and (data.id == label or data.id == nil) then
			--print(data.type, data.cmd)
			if data.cmd == "place_cart" then
				if busy then
					spudnet_send { id = label, cid = data.cid, type = "st_ack", status = "busy" }
				else
					busy = true
					chest.pullItems("up", 1)
					local items = chest.list()
					local cart_slot
					for slot, content in pairs(items) do
						cart_slot = slot
					end
					if not cart_slot then
						spudnet_send { id = label, cid = data.cid, type = "st_ack", status = "no_cart" }
					else
						chest.pushItems("up", cart_slot, 1, 1)
						if powered_rail_side == "left" then turtle.turnLeft() else turtle.turnRight() end
						turtle.place()
						if powered_rail_side == "left" then turtle.turnRight() else turtle.turnLeft() end
						spudnet_send { id = label, cid = data.cid, type = "st_ack", status = "done" }
					end
					busy = false
				end
			elseif data.cmd == "update" then
				local h, e = http.get "https://pastebin.com/raw/JxauVSec"
				if not h then printError(e)
				else
					sign.setSignText("Update", "in progress")
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