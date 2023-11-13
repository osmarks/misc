local key = settings.get "gicr.key"
if not key then error "No SPUDNET key provided" end
local c = peripheral.find "chat_box"

local prefix = "\167bgollark (via GICR)\167r"

local ws
local function connect()
	if ws then pcall(ws.close) end
	local error_count = 0
	while true do
		print "Connecting to SPUDNET..."
		ws, err = http.websocket("wss://osmarks.tk/wsthing/GICR/comm", { authorization = "Key " .. key })
		if not ws then
			printError("Connection Error: " .. tostring(err))
			error_count = error_count + 1
			delay = math.pow(2, error_count)
			print(("Exponential backoff: waiting %d seconds."):format(delay))
			sleep(delay)
			print "Attempting reconnection..."
		else
			return
		end
	end
end

local function receive_ws()
	local ok, result = pcall(ws.receive)
	if not ok then
		printError "Receive Failure"
		printError(result)
		connect()
		return ws.receive()
	end
	return result
end

local function send_ws(message)
	local ok, result = pcall(ws.send, message)
	if not ok then
		printError "Send Failure"
		printError(result)
		connect()
		ws.send(message)
	end
	return result
end

local function chat_listener()
	send_ws "Connected."
	while true do
		local ev, p1, p2, p3 = os.pullEvent()
		if ev == "chat" then
			print("Chat message:", p1, p2)
			send_ws(("%s: %s"):format(p1, p2))
		elseif ev == "death" then
			print("Death:", p1, p2, p3)
			send_ws(("%s died due to entity %s cause %s"):format(p1, p2 or "[none]", p3 or "[none]"))
		elseif ev == "join" then
			print("Join:", p1)
			send_ws("+ " .. p1)
		elseif ev == "leave" then
			print("leave:", p1)
			send_ws("- " .. p1)
		end
	end
end

local function splitspace(str)
	local tokens = {}
	for token in string.gmatch(str, "[^%s]+") do
		table.insert(tokens, token)
	end
	return tokens
end

local function handle_command(tokens)
	local t = tokens[1]
	if t == "update" then
		local h = http.get("https://pastebin.com/raw/70w12805?" .. tostring(math.random(0, 100000)))
		local code = h.readAll()
		h.close()
		local ok, err = load(code, "@<code>")
		if err then error("syntax error in update: " .. err) end
		local f = fs.open("startup", "w")
		f.write(code)
		f.close()
		os.reboot()
	elseif t == "tell" then
		table.remove(tokens, 1)
		local user = table.remove(tokens, 1)
		local message = table.concat(tokens, " ")
		c.tell(user, message, prefix)
	elseif t == "prefix" then
		table.remove(tokens, 1)
		local prefix = table.remove(tokens, 1)
		local message = table.concat(tokens, " ")
		c.say(message, prefix)
	elseif t == "list" then
		local list = c.getPlayerList()
		send_ws(("Player list: %s"):format(table.concat(list, " ")))
	end
end

local function ws_listener()
	while true do
		local message = receive_ws()
		print("Received", message)
		local fst = message:sub(1, 1)
		if fst == "/" then
			local rest = message:sub(2)
			print("Executing", rest)
			local tokens = splitspace(rest)
			local ok, err = pcall(handle_command, tokens)
			if not ok then printError(err) end
		else
			c.say(message, prefix)
		end
	end
end

connect()

parallel.waitForAll(chat_listener, ws_listener)