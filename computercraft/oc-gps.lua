local eeprom = component.proxy(component.list "eeprom"())
local wlan = component.proxy(component.list "modem"())
local comp = component.proxy(component.list "computer"())

local function serialize(a)local b=type(a)if b=="number"then return tostring(a)elseif b=="string"then return ("%q"):format(a)elseif b=="table"then local c="{"for d,e in pairs(a)do c=c..string.format("[%s]=%s,",serialize(d),serialize(e))end;return c.."}"elseif b=="boolean"then return tostring(a)else return("%q"):format(tostring(a))end end
local function unserialize(a) local fn, e = load("return "..a:gsub("functio".."n", ""), "@deser", "t", {}) if not fn then return false, e end return fn() end
local a=string.byte;local function crc32(c)local d,e,f;e=0xffffffff;for g=1,#c do d=a(c,g)e=e~d;for h=1,8 do f=-(e&1);e=(e>>1)~(0xedb88320&f)end end;return(~e)&0xffffffff end
local conf, e = unserialize(eeprom.getData())
if e then error("Config parse error: " .. e) end

wlan.open(2048)
wlan.open(2049)

local function respond(main, auth)
	local data, e = unserialize(main)
	if not data then error("unserialization: " .. e) end
	if type(data) ~= "table" then error "command format invalid" end
	local authed = false
	if data.time and auth then
		local timediff = math.abs(os.time() - data.time)
		if timediff > 1000 then error "tdiff too high" end
		local vauth = crc32(main .. conf.psk)
		if auth ~= vauth then error "auth invalid" end
		authed = true
	end
	local ctype = data[1]
	if ctype == "ping" then return conf.uid end
	if authed then
		if ctype == "reflash" and data[2] then
			eeprom.set(data[2])
			for i = 1, 5 do
				comp.beep(800, 0.2)
				comp.beep(1200, 0.2)
			end
			return #data[2]
		elseif ctype == "setpos" and data[2] and data[3] then
			if data[2] == conf.uid then
				conf.pos = data[3]
				eeprom.setData(serialize(conf))
				eeprom.setLabel("GPS"..conf.uid)
				return true
			end
			return "ignoring"
		end
	end
	error("invalid command (auth: " .. tostring(authed) .. ")")
end

while true do
	local ev, _, from, port, distance, m1, m2 = computer.pullSignal()
	if ev == "modem_message" then
		if port == 2048 and m1 == "PING" then
			if conf.pos then
				wlan.broadcast(2047, table.unpack(conf.pos))
			else
				comp.beep(400, 2)
			end
		elseif port == 2049 and distance < 8 then
			comp.beep(1000, 0.5)
			local ok, res = pcall(respond, m1, m2)
			wlan.broadcast(2050, conf.uid, ok, serialize(res))
			if not ok then comp.beep(1500, 2) end
		end
	end
end