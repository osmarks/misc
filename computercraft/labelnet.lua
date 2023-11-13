-- https://github.com/SquidDev-CC/CC-Tweaked/blob/1c9110b9277bd7a2bf0b2ddd9d517656a72da906/src/main/java/dan200/computercraft/shared/util/StringUtil.java#L11-L31 is the code restricting the contents of labels.
-- Basically, they can contain chars (I think in Extended ASCII for some reason, and inclusive) 32 to 126, 161 to 172, and 174 to 255. This gives us 187 (EDIT: 189) options to work with, thus base 187 (189).

-- BaseN encoding/decoding blob
-- https://github.com/oploadk/base2base for computercraft

local a=string.format;local function b(c,d,e)local f,g,h={}for i=1,#c do g,h=i,c[i]*d;while true do h=(f[g]or 0)+h;f[g]=h%e;h=math.floor(h/e)if h==0 then break end;g=g+1 end end;return f end;local function j(k,l,m,n)local g,h;for i=1,#m do g,h=i,l*(m[i]or 0)while true do h=(k[g]or 0)+h;k[g]=h%n;h=math.floor(h/n)if h==0 then break end;g=g+1 end end end;local function o(self,p)local f,q={},#p;for i=1,q do f[i]=self.r_alpha_from[p:byte(q-i+1)]end;return f end;local function r(self,h)local f,q={},#h;for i=q,1,-1 do f[q-i+1]=self.alpha_to:byte(h[i]+1)end;return string.char(table.unpack(f))end;local function s(self,l)return self.power[l]or b(s(self,l-1),self.base_from,self.base_to)end;local function t(self,h)local f={}for i=1,#h do j(f,h[i],s(self,i-1),self.base_to)end;return f end;local function u(self,p)return r(self,t(self,o(self,p)))end;local function v(self,p)for i=1,#p do if not self.r_alpha_from[p:byte(i)]then return false end end;return true end;local w={__index={convert=u,validate=v},__call=function(self,p)return self:convert(p)end}function new_converter(x,y)local self={alpha_to=y,base_from=#x,base_to=#y}local z={}for i=1,#x do z[x:byte(i)]=i-1 end;self.r_alpha_from=z;self.power={[0]={1}}return setmetatable(self,w)end

local function byte_table_to_string(bytes)
	local str = ""
	for _, x in ipairs(bytes) do
		str = str .. string.char(x)
	end
	return str
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

local ascii = {}
for i = 0, 255 do table.insert(ascii, i) end
local label_charset = {}
for i = 32, 126 do table.insert(label_charset, i) end
for i = 161, 172 do table.insert(label_charset, i) end
for i = 174, 255 do table.insert(label_charset, i) end
label_charset = byte_table_to_string(label_charset)
ascii = byte_table_to_string(ascii)

local from_label = new_converter(label_charset, ascii)
local to_label = new_converter(ascii, label_charset)

local states = {
	IDLE = 0,
	TRANSMITTING = 1,
	RECEIVING = 2,
	RECEIVE_ERROR = 3
}

local function receive_data(side)
	local out = {}
	repeat sleep(0.05) until rs.getBundledInput(side) == states.TRANSMITTING
	rs.setBundledOutput(side, states.RECEIVING)
	local last
	local xseq = 1
	repeat
		local label = peripheral.call(side, "getLabel")
		if label then
			local received = from_label(label)
			if received ~= last then
				local seq, rest = received:byte(1), received:sub(2)
				if seq ~= xseq then
					print("expected", xseq, "got", seq)
				end
				last = received
				xseq = xseq + 1
				table.insert(out, rest)
			end
		end
		sleep(0.05)
	until rs.getBundledInput(side) ~= states.TRANSMITTING
	rs.setBundledOutput(side, states.IDLE)
	return table.concat(out)
end

local function send_data(side, data)
	local packets = {}
	local packet_index = 1
	local remaining, chunk = data
    while true do
        chunk, remaining = remaining:sub(1, 29), remaining:sub(30)
		local header = string.char(get_byte(packet_index, 0))
		table.insert(packets, header .. chunk)
		packet_index = packet_index + 1
		if #remaining == 0 then break end
    end
	local label = os.getComputerLabel()
	rs.setBundledOutput(side, states.TRANSMITTING)
	repeat sleep(0.05) until rs.getBundledInput(side) == states.RECEIVING
	for _, packet in ipairs(packets) do
		os.setComputerLabel(to_label(packet))
		sleep(0.05)
	end
	rs.setBundledOutput(side, states.IDLE)
	sleep(0.1)
	os.setComputerLabel(label)
end

local other
for _, name in pairs(peripheral.getNames()) do
	for _, method in pairs(peripheral.getMethods(name)) do
		if method == "getLabel" then
			other = name
			break
		end
	end
end

local option = ...

if option == "send" then
    write "Send: "
    local text = read()
    send_data(other, text)
elseif option == "receive" then
    print(receive_data(other))
end

return { to_label = to_label, from_label = from_label, send_data = send_data, receive_data = receive_data }
