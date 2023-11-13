local xoshiro128, xoshiro128genstate

do
	-- http://prng.di.unimi.it/xoshiro128plusplus.c port

	local function normalize(x)
		return x % 0x80000000
	end

	local rotl = bit32.lrotate
	local bxor = bit.bxor
	local lshift = bit32.lshift

	local function statexor(s, i1, i2)
		s[i1] = bxor(s[i1], s[i2])
	end

	xoshiro128 = function(state)
		local result = normalize(rotl(state[1] + state[4], 7) + state[1])
		local t = lshift(state[2], 9)
		statexor(state, 3, 1)
		statexor(state, 4, 2)
		statexor(state, 2, 3)
		statexor(state, 1, 4)
		state[3] = bxor(state[3], t)
		state[4] = rotl(state[4], 11)
		return result
	end

	xoshiro128genstate = function()
		local s = {normalize(os.epoch "utc"), math.random(0x7FFFFFFF), os.getComputerID(), math.random(0x7FFFFFFF)}
		xoshiro128(s)
		return s
	end
end

local oetemplate = [[local bitbxor, stringchar, tableconcat, tableinsert, bitband, LO, lrotate, lshift = bit.bxor, string.char, table.concat, table.insert, bit.band, 0x0F, bit32.lrotate, bit.blshift

local function statexor(s, i1, i2)
	s[i1] = bitbxor(s[i1], s[i2])
end

local function rand(s)
	local result = (lrotate(s[1] + s[4], 7) + s[1]) % 0x80000000
	local t = lshift(s[2], 9)
	statexor(s, 3, 1)
	statexor(s, 4, 2)
	statexor(s, 2, 3)
	statexor(s, 1, 4)
	s[3] = bitbxor(s[3], t)
	s[4] = lrotate(s[4], 11)
	return result
end

local function a(x)
	local b = {}
	for i = 1, #x, 2 do
		local h = bitband(x:byte(i) - 33, LO)
		local l = bitband(x:byte(i + 1) - 81, LO)
		local s = (h * 0x10) + l
		tableinsert(b, stringchar(bitbxor(rand(k) % 256, s)))
	end
	return tableconcat(b)
end]]

local miniobftemplate = [[local k=%s;local a,b,c,d,e,f,g,A=bit.bxor,string.char,table.concat,table.insert,bit.band,0x0F,bit32.lrotate,bit.blshift;local function h(i,j,m)i[j]=a(i[j],i[m])end;local function n(i)local o=(g(i[1]+i[4],7)+i[1])%%0x80000000;local p=A(i[2],9)h(i,3,1)h(i,4,2)h(i,2,3)h(i,1,4)i[3]=a(i[3],p)i[4]=g(i[4],11)return o end;local function q(r)local s={}for t=1,#r,2 do local u=e(r:byte(t)-33,f)local l=e(r:byte(t+1)-81,f)local i=u*0x10+l;d(s,b(a(n(k)%%256,i)))end;return c(s)end]]

local function obfstrt(x)
	local state = xoshiro128genstate()
	local function encode(d)
		local out = {}
		for i = 1, #d do
			local byte = bit.bxor(xoshiro128(state) % 256, d:byte(i))
			local hi = bit.brshift(byte, 4) + bit.blshift(bit.band(0x02, byte), 3)
			local lo = bit.band(0x0F, byte) + bit.band(0x10, byte)
			table.insert(out, string.char(hi + 33))
			table.insert(out, string.char(lo + 81))
		end
		return table.concat(out)
	end
	return miniobftemplate:format(textutils.serialise(state)) .. "\n" .. x:gsub(
		"{{([^}]+)}}",
		function(q) return ("(q%q)"):format(encode(q)) end
	)
end

local function bydump(code)
	return string.dump(load(code, "@æ"))
end

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local sgsub, sbyte, ssub, schar, sfind = string.gsub, string.byte, string.sub, string.char, string.find
 
-- encoding
local function b64enc(data)
    return ((sgsub(data, '.', function(x)
        local r,b='',sbyte(x)
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(ssub(x,i,i)=='1' and 2^(6-i) or 0) end
        return ssub(b, c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local b64code = [[local a='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'local b,c,d,e,f=string.gsub,string.byte,string.sub,string.char,string.find;local function b64dec(g)g=b(g,'[^'..a..'=]','')return b(g,'.',function(h)if h=='='then return''end;local i,j='',f(a,h)-1;for k=6,1,-1 do i=i..(j%2^k-j%2^(k-1)>0 and'1'or'0')end;return i end):gsub('%d%d%d?%d?%d?%d?%d?%d?',function(h)if#h~=8 then return''end;local l=0;for k=1,8 do l=l+(d(h,k,k)=='1'and 2^(8-k)or 0)end;return e(l)end)end]]
local maincode = [[load(potatOS.decompress(b64dec(%q)), "@a", "b")]]

local function bycomp(code)
	local dumped = bydump(code)
	local comp = potatOS.compress(dumped)
	return b64code .. "\n" .. maincode:format(b64enc(comp))
end

return {
	obfstrt = obfstrt,
	bydump = bydump,
	nulzcod = nulzcod,
	bycomp = bycomp
}