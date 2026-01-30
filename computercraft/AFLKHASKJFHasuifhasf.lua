local config = dofile "config.lua"
local modems = {}
local defaults = {[gps.CHANNEL_GPS] = true, [999] = true}
for name, location in pairs(config.modems) do
	modems[name] = peripheral.wrap(name)
	modems[name].location = location
	modems[name].closeAll()
	for def in pairs(defaults) do
		modems[name].open(def)
	end
end
local has_open = {}
local has_open_map = {}

local vla_modem = peripheral.wrap(config.vla_modem or "bottom")
vla_modem.open(31415)

local function timestamp()
    return os.date "!%X"
end

-- Trilateration code from GPS and modified slightly

local function trilaterate( A, B, C )
    local a2b = B.position - A.position
    local a2c = C.position - A.position
       
    if math.abs( a2b:normalize():dot( a2c:normalize() ) ) > 0.999 then
        return nil
    end
   
    local d = a2b:length()
    local ex = a2b:normalize( )
    local i = ex:dot( a2c )
    local ey = (a2c - (ex * i)):normalize()
    local j = ey:dot( a2c )
    local ez = ex:cross( ey )
 
    local r1 = A.distance
    local r2 = B.distance
    local r3 = C.distance
       
    local x = (r1*r1 - r2*r2 + d*d) / (2*d)
    local y = (r1*r1 - r3*r3 - x*x + (x-i)*(x-i) + j*j) / (2*j)
       
    local result = A.position + (ex * x) + (ey * y)
 
    local zSquared = r1*r1 - x*x - y*y
    if zSquared > 0 then
        local z = math.sqrt( zSquared )
        local result1 = result + (ez * z)
        local result2 = result - (ez * z)
       
        local rounded1, rounded2 = result1:round( 0.01 ), result2:round( 0.01 )
        if rounded1.x ~= rounded2.x or rounded1.y ~= rounded2.y or rounded1.z ~= rounded2.z then
            return rounded1, rounded2
        else
            return rounded1
        end
    end
    return result:round( 0.01 )
end
 
local function narrow( p1, p2, fix )
    local dist1 = math.abs( (p1 - fix.position):length() - fix.distance )
    local dist2 = math.abs( (p2 - fix.position):length() - fix.distance )
   
    if math.abs(dist1 - dist2) < 0.01 then
        return p1, p2
    elseif dist1 < dist2 then
        return p1:round( 0.01 )
    else
        return p2:round( 0.01 )
    end
end

local function compact_serialize(x, hist)
    local t = type(x)
    if t == "string" then
        return ("%q"):format(x)
    elseif t == "table" then
		if hist[x] then return "[recursion]" end
		hist[x] = true
        local out = "{ "
        for k, v in pairs(x) do
            out = out .. string.format("[%s]=%s, ", compact_serialize(k, hist), compact_serialize(v, hist))
        end
        return out .. "}"
    else
        return tostring(x)
    end
end

local monitors = {}
for name, monitor in pairs(config.monitors) do
	monitors[name] = peripheral.wrap(monitor)
	monitors[name].setTextScale(0.5)
end

local function write_to(mon, ...)
	term.redirect(monitors[mon])
	print(...)
end

for name in pairs(monitors) do
	write_to(name, timestamp(), "Initialized")
end

local fixes = {}

while true do
	local _, modem, channel, reply_channel, message, distance = os.pullEvent "modem_message"
	if channel == 31415 and type(message) == "table" and modem == peripheral.getName(vla_modem) and message.origin == "VLA by Anavrins" and message.dimension == "Nether/End" and type(message.replyChannel) == "number" and type(message.senderChannel) == "number" and not defaults[message.senderChannel] then
		write_to("vla", timestamp(), ("%d->%d %s"):format(message.senderChannel, message.replyChannel, compact_serialize(message.message, {})))
		local newchan = message.senderChannel
		if not has_open_map[newchan] then
			write_to("vla", "Opening", newchan)
			if #has_open == 126 then
				local oldchan = table.remove(has_open, 1)
				write_to("vla", "Closing", oldchan)
				for name, modem in pairs(modems) do
					modem.close(oldchan)
				end
			end
			for name, modem in pairs(modems) do
				modem.open(newchan)
			end
			table.insert(has_open, newchan)
			has_open_map[newchan] = true
		end
	elseif distance and (has_open_map[channel] or defaults[channel]) then
		local reply_modem = modems[modem]
		if message == "PING" and channel == gps.CHANNEL_GPS then
			reply_modem.transmit(reply_channel, gps.CHANNEL_GPS, { reply_modem.location[1], reply_modem.location[2], reply_modem.location[3], dimension = config.dimension, server = config.server })
		end
		table.insert(fixes, { position = vector.new(unpack(reply_modem.location)), distance = distance })
		if #fixes == 4 then
			local p1, p2 = trilaterate(fixes[1], fixes[2], fixes[3])
			if p1 and p2 then
				local pos = narrow(p1, p2, fixes[4])
				if channel == gps.CHANNEL_GPS then
					if message == "PING" then write_to("gps", timestamp(), ("%d: %.0f %.0f %.0f"):format(reply_channel, pos.x, pos.y, pos.z)) end
				elseif channel == 999 then
					local status, label = "?", "?"
					if type(message) == "table" then status = tostring(message.status) label = tostring(message.label) end
					write_to("opus", timestamp(), ("%05d %s (%.0f %.0f %.0f) %s"):format(reply_channel, label, pos.x, pos.y, pos.z, status))
				else
					write_to("vla", timestamp(), ("-> %.0f %.0f %.0f"):format(pos.x, pos.y, pos.z))
				end
			end
			fixes = {}
		end
	end

end


