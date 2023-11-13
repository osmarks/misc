--[[
ARC: AR Client
Uses Plethora overlay glasses and modems to display 3D signage transmitted from local "beacons"
]]

local m = peripheral.find "modem"
local mods = peripheral.wrap "back"

if not m then error "Modem required." end
if not mods then error "Is this even on a neural interface?" end
if not mods.canvas3d then error "Overlay glasses required." end

local canv = mods.canvas3d()

local object_channel = 666

m.open(object_channel)

local x, y, z

-- convert position to string for use as table key
local function serialize_position(p)
	return string.format("%f,%f,%f", p[1], p[2], p[3])
end

-- Generate a string representation of a table, for easy comparison. Not really hashing, I guess.
local function hash_table(x)
	if type(x) == "table" then
		local out = ""
		for k, v in pairs(x) do
			if type(k) ~= "string" or not k:match "^_" then -- ignore keys beginning with _
				out = out .. hash_table(k) .. ":" .. hash_table(v) .. ";"
			end
		end
		return out
	else
		return tostring(x)
	end
end

-- honestly not that elegant, but it works
-- TODO: do this more efficiently/nicely somehow?
local function tables_match(x, y)
	return hash_table(x) == hash_table(y)
end

local objects = {}
local timers = {}

local function redraw(object)
	local frame = object._frame
	frame.clear()
end

local function process_object(object)
	local pos = serialize_position(object.position)
	if objects[pos] then
		if not tables_match(object, objects[pos]) then
			print("redrawing", pos)
			objects[pos] = object
			redraw(objects[pos])
		end
		local t = os.startTimer(20)
		timers[t] = pos
	else
		print("new object at", pos)
		if x then
			local frame = 
		else
			print("GPS error, cannot create object")
		end
	end
end

local function main_loop()
	while true do
		local event, timer, channel, reply_channel, message, distance = os.pullEvent()
		if event == "modem_message" and channel == object_channel and distance and type(message) == "table" then -- ensure message is from this dimension and otherwise valid
			for _, object in pairs(msg) do
				local ok, err = pcall(process_object, object)
				if not ok then printError(err) end
			end
		elseif event == "timer" then
			local objpos = timers[timer]
			if objpos then
				local obj = objects[objpos]
				if obj then
					print(objpos, "timed out")
					obj._frame.remove()
					objects[objpos] = nil
				end
			end
		end
	end
end

-- Request location every second
local function GPS_loop()
	while true do
		x, y, z = gps.locate()
		sleep(1)
	end
end

parallel.waitForAll(GPS_loop, main_loop)