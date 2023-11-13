local config = dofile "config.lua"
local modems = {}
for name, location in pairs(config.modems) do
	modems[name] = peripheral.wrap(name)
	modems[name].location = location
	modems[name].open(21592)
end

local key = config.spudnet_key
if not key then error "SPUDNET key not found." end
local ws
 
local function connect()
	while true do
		ws, err = http.websocket("wss://osmarks.tk/wsthing/SGNS/admin", { authorization = "Key " .. key })
		if err then
			printError(err)
			sleep(1)
		else
			break
		end
	end
end

connect()

local function send(msg)
	local ok, err = pcall(ws.send, json.encode(msg))
	if not ok then
		connect()
	end
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

local fixes = {}

while true do
	local _, modem, channel, reply_channel, message, distance = os.pullEvent "modem_message"
	if distance and (type(message) == "string" or type(message) == "number") then
		local reply_modem = modems[modem]
		reply_modem.transmit(reply_channel, gps.CHANNEL_GPS, reply_modem.location)
		table.insert(fixes, { position = vector.new(unpack(reply_modem.location)), distance = distance })
		if #fixes == 4 then
			local p1, p2 = trilaterate(fixes[1], fixes[2], fixes[3])
			if p1 and p2 then
				local pos = narrow(p1, p2, fixes[4])
				send { type = "position_fix", dimension = config.dimension, x = pos.x, y = pos.y, z = pos.z, ID = message }
			else
				send { type = "error", error = "position fix failed", ID = message }
			end
			fixes = {}
		end
	end
end