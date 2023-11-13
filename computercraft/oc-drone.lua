local drone = component.proxy(component.list "drone"())
local net = component.proxy(component.list "internet"())
local wlan = component.proxy(component.list "modem"())
local comp = component.proxy(component.list "computer"())
wlan.setWakeMessage("poweron", true)

local central_point = { x = 297, y = 80, z = 294 }

local statuses = {
	loading = { text = "LOAD", color = 0x000000 },
	moving = { text = "GO", color = 0xFFFF00 },
	idle = { text = "IDLE", color = 0x00FFFF },
	error = { text = "ERROR", color = 0xFF0000 },
	low_battery = { text = "ELOW", 0xFF8800 }
}

local function set_status(status)
	local stat = statuses[status]
	drone.setLightColor(stat.color or 0xFFFFFF)
	drone.setStatusText((stat.text or status) .. (" "):rep(8))
end

set_status "loading"
comp.beep(600, 1)

local function energy()
	return computer.energy() / computer.maxEnergy()
end

local GPS_PING_CHANNEL, GPS_RESPONSE_CHANNEL, TIMEOUT = 2048, 2047, 1

wlan.setStrength(math.huge)

local function fetch(url)
    local res, err = net.request(url)
    if not res then error(url .. " error: " .. err) end
    local out = {}
    while true do
        local chunk, err = res.read()
        if err then error(url .. " error: " .. err) end
        if chunk then table.insert(out, chunk)
        else return table.concat(out) end
    end
end

local function round(v, m)
	m = m or 1.0
	return {
		x = math.floor((v.x+(m*0.5))/m)*m,
		y = math.floor((v.y+(m*0.5))/m)*m,
		z = math.floor((v.z+(m*0.5))/m)*m
	}
end

local function len(v)
	return math.sqrt(v.x^2 + v.y^2 + v.z^2)
end

local function cross(v, b)
	return {x = v.y*b.z-v.z*b.y, y = v.z*b.x-v.x*b.z, z = v.x*b.y-v.y*b.x}
end

local function dot(v, b)
	return v.x*b.x + v.y*b.y + v.z*b.z
end

local function add(v, b)
	return {x = v.x+b.x, y = v.y+b.y, z = v.z+b.z}
end

local function sub(v, b)
	return {x = v.x-b.x, y = v.y-b.y, z = v.z-b.z}
end

local function mul(v, m)
	return {x = v.x*m, y = v.y*m, z = v.z*m}
end

local function norm(v)
	return mul(v, 1/len(v))
end

local function trilaterate(A, B, C)
	local a2b = {x = B.x-A.x, y = B.y-A.y, z = B.z-A.z}
	local a2c = {x = C.x-A.x, y = C.y-A.y, z = C.z-A.z}
	if math.abs(dot(norm(a2b), norm(a2c))) > 0.999 then
		return nil
	end
	local d = len(a2b)
	local ex = norm(a2b)
	local i = dot(ex, a2c)
	local ey = norm(sub(mul(ex, i), a2c))
	local j = dot(ey, a2c)
	local ez = cross(ex, ey)
	local r1 = A.d
	local r2 = B.d
	local r3 = C.d
	local x = (r1^2 - r2^2 + d^2) / (2*d)
	local y = (r1^2 - r3^2 - x^2 + (x-i)^2 + j^2) / (2*j)
	local result = add(A, add(mul(ex, x), mul(ey, y)))
	local zSquared = r1^2 - x^2 - y^2
	if zSquared > 0 then
		local z = math.sqrt(zSquared)
		local result1 = add(result, mul(ez, z))
		local result2 = add(result, mul(ez, z))
		local rounded1, rounded2 = round(result1, 0.01), round(result2, 0.01)
		if rounded1.x ~= rounded2.x or
			 rounded1.y ~= rounded2.y or
			 rounded1.z ~= rounded2.z then
			return rounded1, rounded2
		else
			return rounded1
		end
	end
	return round(result, 0.01)
end

local function narrow(p1, p2, fix)
	local dist1 = math.abs(len(sub(p1, fix)) - fix.d)
	local dist2 = math.abs(len(sub(p2, fix)) - fix.d)
	if math.abs(dist1 - dist2) < 0.01 then
		return p1, p2
	elseif dist1 < dist2 then
		return round(p1, 0.01)
	else
		return round(p2, 0.01)
	end
end

local function locate(timeout)
	local timeout = timeout or TIMEOUT
	wlan.open(GPS_RESPONSE_CHANNEL)
	wlan.broadcast(GPS_PING_CHANNEL, "PING")
	local fixes = {}
	local pos1, pos2 = nil, nil
	local deadline = computer.uptime() + timeout
	local dim
	repeat
		local event, _, from, port, distance, x, y, z, dimension = computer.pullSignal(deadline - computer.uptime())
		if event == "modem_message" and port == GPS_RESPONSE_CHANNEL and x and y and z then
			if type(dim) == "string" then dim = dimension end
			local fix = {x = x, y = y, z = z, d = distance}
			if fix.d == 0 then
				pos1, pos2 = {fix.x, fix.y, fix.z}, nil
			else
				table.insert(fixes, fix)
				if #fixes >= 3 then
					if not pos1 then
						pos1, pos2 = trilaterate(fixes[1], fixes[2], fixes[#fixes])
					else
						pos1, pos2 = narrow(pos1, pos2, fixes[#fixes])
					end
				end				
			end
			if pos1 and not pos2 then
				break
			end
		end
	until computer.uptime() >= deadline
	wlan.close(GPS_RESPONSE_CHANNEL)
	if pos1 and pos2 then
		return nil
	elseif pos1 then
		return pos1, dim
	else
		return nil
	end
end

local a={["\\"]="\\\\",["\""]="\\\"",["\b"]="\\b",["\f"]="\\f",["\n"]="\\n",["\r"]="\\r",["\t"]="\\t"}local b={["\\/"]="/"}for c,d in pairs(a)do b[d]=c end;local e;local function f(...)local g={}for h=1,select("#",...)do g[select(h,...)]=true end;return g end;local i=f(" ","\t","\r","\n")local j=f(" ","\t","\r","\n","]","}",",")local k=f("\\","/",'"',"b","f","n","r","t","u")local l=f("true","false","null")local m={["true"]=true,["false"]=false,["null"]=nil}local function n(o,p,q,r)for h=p,#o do if q[o:sub(h,h)]~=r then return h end end;return#o+1 end;local function s(o,p,t)local u=1;local v=1;for h=1,p-1 do v=v+1;if o:sub(h,h)=="\n"then u=u+1;v=1 end end;error(string.format("%s at line %d col %d",t,u,v))end;local function w(x)local y=math.floor;if x<=0x7f then return string.char(x)elseif x<=0x7ff then return string.char(y(x/64)+192,x%64+128)elseif x<=0xffff then return string.char(y(x/4096)+224,y(x%4096/64)+128,x%64+128)elseif x<=0x10ffff then return string.char(y(x/262144)+240,y(x%262144/4096)+128,y(x%4096/64)+128,x%64+128)end;error(string.format("invalid unicode codepoint '%x'",x))end;local function z(A)local B=tonumber(A:sub(3,6),16)local C=tonumber(A:sub(9,12),16)if C then return w((B-0xd800)*0x400+C-0xdc00+0x10000)else return w(B)end end;local function D(o,h)local E=false;local F=false;local G=false;local H;for I=h+1,#o do local J=o:byte(I)if J<32 then s(o,I,"control character in string")end;if H==92 then if J==117 then local K=o:sub(I+1,I+5)if not K:find("%x%x%x%x")then s(o,I,"invalid unicode escape in string")end;if K:find("^[dD][89aAbB]")then F=true else E=true end else local L=string.char(J)if not k[L]then s(o,I,"invalid escape char '"..L.."' in string")end;G=true end;H=nil elseif J==34 then local A=o:sub(h+1,I-1)if F then A=A:gsub("\\u[dD][89aAbB]..\\u....",z)end;if E then A=A:gsub("\\u....",z)end;if G then A=A:gsub("\\.",b)end;return A,I+1 else H=J end end;s(o,h,"expected closing quote for string")end;local function M(o,h)local J=n(o,h,j)local A=o:sub(h,J-1)local x=tonumber(A)if not x then s(o,h,"invalid number '"..A.."'")end;return x,J end;local function N(o,h)local J=n(o,h,j)local O=o:sub(h,J-1)if not l[O]then s(o,h,"invalid literal '"..O.."'")end;return m[O],J end;local function P(o,h)local g={}local x=1;h=h+1;while 1 do local J;h=n(o,h,i,true)if o:sub(h,h)=="]"then h=h+1;break end;J,h=e(o,h)g[x]=J;x=x+1;h=n(o,h,i,true)local Q=o:sub(h,h)h=h+1;if Q=="]"then break end;if Q~=","then s(o,h,"expected ']' or ','")end end;return g,h end;local function R(o,h)local g={}h=h+1;while 1 do local S,T;h=n(o,h,i,true)if o:sub(h,h)=="}"then h=h+1;break end;if o:sub(h,h)~='"'then s(o,h,"expected string for key")end;S,h=e(o,h)h=n(o,h,i,true)if o:sub(h,h)~=":"then s(o,h,"expected ':' after key")end;h=n(o,h+1,i,true)T,h=e(o,h)g[S]=T;h=n(o,h,i,true)local Q=o:sub(h,h)h=h+1;if Q=="}"then break end;if Q~=","then s(o,h,"expected '}' or ','")end end;return g,h end;local U={['"']=D,["0"]=M,["1"]=M,["2"]=M,["3"]=M,["4"]=M,["5"]=M,["6"]=M,["7"]=M,["8"]=M,["9"]=M,["-"]=M,["t"]=N,["f"]=N,["n"]=N,["["]=P,["{"]=R}e=function(o,p)local Q=o:sub(p,p)local y=U[Q]if y then return y(o,p)end;s(o,p,"unexpected character '"..Q.."'")end;local function json_decode(o)if type(o)~="string"then error("expected argument of type string, got "..type(o))end;local g,p=e(o,n(o,1,i,true))p=n(o,p,i,true)if p<=#o then s(o,p,"trailing garbage")end;return g end

local function sleep(timeout)
	local deadline = computer.uptime() + (timeout or 0)
	repeat
		computer.pullSignal(deadline - computer.uptime())
	until computer.uptime() >= deadline
end

local function moveraw(x, y, z)
	set_status "moving"
	drone.move(x, y, z)
	repeat
		sleep(0.5) 
	until drone.getVelocity() < 0.1
	set_status "idle"
end

local function move(pos)
	moveraw(0, 32, 0)
	moveraw(pos.x, pos.y, pos.z)
	moveraw(0, -32, 0)
end

local function follow(currpos)
	local data = json_decode(fetch "https://dynmap.codersnet.pw/up/world/world/1588704574112")
	local possibles = {}
	for _, p in pairs(data.players) do
		local plrpos = { x = p.x, y = p.y, z = p.z }
		local dist = len(sub(plrpos, central_point))
		if dist < 100 and p.world == "world" then
			table.insert(possibles, plrpos)
		end
	end
	if #possibles == 0 then return false, "TNF" end
	local targpos = possibles[math.random(1, #possibles)]
	local offset = sub(targpos, currpos)
	comp.beep(400, 0.5)
	move(offset)
	return true
end

while true do
	set_status "idle"
	local currpos = locate()
	if currpos then
		wlan.broadcast(1033, drone.name(), "LOC", currpos.x, currpos.y, currpos.z)
		local offset_from_hub = sub(central_point, currpos)
		if len(offset_from_hub) then
			move(offset_from_hub)
		else
			local ok, err = follow(currpos)
			if not ok then set_status "error" drone.setStatusText("E" .. err) sleep(10) end
			sleep(1)
		end
	end
	if energy() < 0.3 then
		wlan.broadcast(1033, drone.name(), "LOW")
		comp.beep(2000, 1.5)
		status "low_battery"
		move(sub(central_point, locate()))
	end
end