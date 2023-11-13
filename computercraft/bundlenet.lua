-- Minified CRC32 blob - MIT license - from here: https://raw.githubusercontent.com/davidm/lua-digest-crc32lua/master/lmod/digest/crc32lua.lua
do
	local type=type;local require=require;local setmetatable=setmetatable;local a=bit.bxor;local b=bit.bnot;local c=bit.band;local d=bit.brshift;local e=0xEDB88320;local function f(g)local h={}local i=setmetatable({},h)function h:__index(j)local k=g(j)i[j]=k;return k end;return i end;local l=f(function(m)local n=m;for o=1,8 do local p=c(n,1)n=d(n,1)if p==1 then n=a(n,e)end end;return n end)local function q(r,n)n=b(n or 0)local s=d(n,8)local t=l[a(n%256,r)]return b(a(s,t))end;local function u(v,n)n=n or 0;for m=1,#v do n=q(v:byte(m),n)end;return n end;function crc32(v,n)if type(v)=='string'then return u(v,n)else return q(v,n)end end
end

local function get_byte(num, byte)
    return bit.band(bit.brshift(num, byte * 8), 0xFF)
end
 
local function from_bytes(b)
    local n = 0
    for ix, byte in pairs(b) do
        n = bit.bor(n, bit.blshift(byte, (ix - 1) * 8))
    end
    return n
end

local side = settings.get "bundlenet.side" or "back"

local function send_raw(str)
	local i = 1
	for i = 1, math.ceil(#str / 2) do
		local first = str:byte(i * 2 - 1)
		local second = str:byte(i * 2) or 0
		local u16 = first * 256 + second
		rs.setBundledOutput(side, u16)
		sleep(0.1)
	end
	rs.setBundledOutput(side, 0)
end

local function receive_raw(length)
	local str = ""
	local count = 0
	os.pullEvent "redstone"
	while true do
		local u16 = rs.getBundledInput(side)
		local first = string.char(math.floor(u16 / 256))
		if not length and first == "\0" then break
		else
			count = count + 1
			str = str .. first
			if count == length then break end
			local second = string.char(u16 % 256)
			if not length and second == "\0" then break
			else
				count = count + 1
				str = str .. second
				if count == length then break end
			end
		end
		sleep(0.1)
	end
	return str
end

local function u32_to_string(u32)
	return string.char(get_byte(u32, 0), get_byte(u32, 1), get_byte(u32, 2), get_byte(u32, 3))
end

local function string_to_u32(str)
	return from_bytes{str:byte(1), str:byte(2), str:byte(3), str:byte(4)}
end

local function send(data)
	local length = u32_to_string(#data)
	local checksum = u32_to_string(crc32(data))
	print("len", length, "checksum", checksum)
	send_raw(length)
	send_raw(checksum)
	send_raw(data)
end

local function receive()
	local length = receive_raw(4)
	sleep(0.1)
	local checksum = receive_raw(4)
	print("len", length, "checksum", checksum, "l", string_to_u32(length), "c", string_to_u32(checksum))
	sleep(0.1)
	local data = receive_raw(string_to_u32(length))
	if crc32(data) ~= string_to_u32(checksum) then return false, "checksum mismatch", data end
	return true, data
end

local option = ...

if option == "send" then
	write "Send: "
	local text = read()
	send(text)
elseif option == "raw_receive" then
	print(receive_raw())
elseif option == "receive" then
	print(receive())
end

return { send = send, receive = receive }