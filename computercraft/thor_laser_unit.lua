local laser = peripheral.find "plethora:laser" or peripheral.find "neuralInterface"
local run_lasers = true

local function compact_serialize(x)
    local t = type(x)
    if t == "number" then
        return tostring(x)
    elseif t == "string" then
        return textutils.serialise(x)
    elseif t == "table" then
        local out = "{"
        for k, v in pairs(x) do
            out = out .. string.format(" [%s] = %s,", compact_serialize(k), compact_serialize(v))
        end
        return out .. " }"
    else
        return tostring(x)
    end
end

local function log(...)
	print(os.date "!%X", ...)
end

local function fire(yaw, pitch, power)
	if not run_lasers then error "Lasing capability has been temporarily disabled." end
	if not yaw or not pitch then error "yaw and pitch required" end
	laser.fire(yaw, pitch, power or 0.5)
	log("FIRE", yaw, pitch, power)
	return true
end

-- for cost most lasers are installed on turtles anyway, so just detect neural interfaces
local is_stationary = peripheral.getType "back" ~= "neuralInterface"
local x, y, z
local function locate()
	if x and is_stationary then return x, y, z end
	x, y, z = gps.locate()
	if not x then error "GPS fix unavailable." end
	return x, y, z
end

local function calc_yaw_pitch(x, y, z)
	local pitch = -math.atan2(y, math.sqrt(x * x + z * z))
	local yaw = math.atan2(-x, z)
	return math.deg(yaw), math.deg(pitch)
end

-- from shell

local function tokenise(line)
    local words = {}
    local quoted = false
    for match in string.gmatch(line .. "\"", "(.-)\"") do
        if quoted then
            table.insert(words, match)
        else
            for m in string.gmatch(match, "[^ \t]+") do
                table.insert(words, m)
            end
        end
        quoted = not quoted
    end
    return words
end

local laser_id = os.getComputerLabel()

local raw_exec_prefix = "!RAWEXEC "

local function handle_command(cmd_text)
	if cmd_text:match("^" .. raw_exec_prefix) then
		local code = cmd_text:sub(#raw_exec_prefix + 1)
		local fn, err = load(code, "@<code>")
		if err then error(err) end
		return fn()
	end
	local tokens = tokenise(cmd_text)
	local command = table.remove(tokens, 1)
	if command == "update" then
		local h = http.get("https://pastebin.com/raw/iL1CXJkQ?" .. tostring(math.random(0, 100000)))
		local code = h.readAll()
		h.close()
		local ok, err = load(code, "@<code>")
		if err then error("syntax error: " .. err) end
		local f = fs.open("startup", "w")
		f.write(code)
		f.close()
		os.reboot()
	elseif command == "fire_direction" then
		local id = tokens[1]
		local yaw = tonumber(tokens[2])
		local pitch = tonumber(tokens[3])
		if not id or not yaw or not pitch then
			error "format: fire_direction [laser ID] [yaw] [pitch] <power>"
		end
		local power = tonumber(tokens[4])
		if id == laser_id then
			fire(yaw, pitch, power)
			return true
		end
	elseif command == "fire_position" then
		local tx = tonumber(tokens[1])
		local ty = tonumber(tokens[2])
		local tz = tonumber(tokens[3])
		local power = tonumber(tokens[4])
		if not tx or not ty or not tz then
			error "format: fire_position [target x] [target y] [target z] <power>"
		end
		local x, y, z = locate()
		local yaw, pitch = calc_yaw_pitch(tx - x, ty - y, tz - z)
		fire(yaw, pitch, power)
		return { yaw = yaw, pitch = pitch }
	elseif command == "ping" then
		local x, y, z = locate()
		return ("%s %f %f %f"):format(laser_id, x, y, z)
	else
		error "no such command"
	end
end

local ws

local function run()
	ws = http.websocket "wss://osmarks.tk/wsthing/lasers"
	ws.send("CONN " .. laser_id)

    while true do
        -- Receive and run code from backdoor's admin end
        local command_text = ws.receive()
		log("Executing", command_text)
		local ok, err = pcall(handle_command, command_text)
		if not ok then log(err) end
		local result_type = "OK  "
		if not ok then result_type = "FAIL" end
		ws.send(result_type .. " " .. compact_serialize(err))
    end
end

while true do
	local ok, err = pcall(run)
	pcall(ws.close)
	if not ok then printError(err)
	else
		sleep(0.5)
	end
end