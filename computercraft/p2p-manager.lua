local data
local file = "./p2p.tbl"

local function save()
	local f = fs.open(file, "w")
	f.write(textutils.serialise(data))
	f.close()
end

local function load()
	if fs.exists(file) then
		local f = fs.open(file, "r")
		local x = textutils.unserialise(f.readAll())
		f.close()
		return x
	end
end

local function split(str)
	local t = {}
	for w in str:gmatch("%S+") do table.insert(t, w) end
	return t
end

data = load() or {}

local case_insensitive = {
	__index = function( table, key )
		local value = rawget( table, key )
		if value ~= nil then
			return value
		end
		if type(key) == "string" then
			local value = rawget( table, string.lower(key) )
			if value ~= nil then
				return value
			end                    
		end
		return nil
	end
}

setmetatable(data, case_insensitive)

local function tunnel_info(name)
	local d = data[name]
	return ("%s: %d %s"):format(name, d.channels, d.description)
end

local commands = {
	list = function()
		for t in pairs(data) do print(tunnel_info(t)) end
	end,
	info = function(name)
		print(tunnel_info(name))
	end,
	describe = function(name)
		local t = data[name]
		print("Description:", t.description)
		write "New description: "
		t.description = read()
	end,
	add = function(name)
		data[name] = {
			channels = 0,
			description = "None set."
		}
	end,
	channels = function(name, by)
		local by = tonumber(by)
		if not by then error "Invalid number!" end
		local t = data[name]
		print("Channels:", t.channels)
		print("Increasing by:", by)
		t.channels = t.channels + by
		print("New channels:", t.channels)
	end,
	delete = function(name)
		data[name] = nil
	end
}

setmetatable(commands, case_insensitive)

local hist = {}

while true do
	write "> "
	local text = read(nil, hist)
	table.insert(hist, text)
	local tokens = split(text)
	local command = table.remove(tokens, 1)

	local ok, err = pcall(commands[command], unpack(tokens))
	save()
	if not ok then printError(err) end
end