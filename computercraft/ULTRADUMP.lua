local a=http.get"https://pastebin.com/raw/KXHSsHkt"local b=fs.open("ser","w")b.write(a.readAll())a.close()b.close()

local ultradump = {}
local ser = require "/ser"
local e = ser.serialize

local function copy(x)
	if type(x) == "table" then
		local out = {}
		for k, v in pairs(x) do
			out[k] = v
		end
		return out
	else return x end
end

function ultradump.dump(x)
	local objects = {}
	local enclookup = {}
	local count = 0

	local function addobj(o)
		objects[o] = count
		local c = count
		count = count + 1
		return c
	end

	local function mkref(id)
		return { _to = id }
	end

	local function recurse(x)
		if enclookup[x] then print("Using From Cache", x) return enclookup[x] end -- If we already have an encoded copy cached, use it
		local t = type(x)

		if t == "string" or t == "number" then
			return x
		elseif t == "table" then
			local mt = debug.getmetatable(x)
			local out = {}
			local id = addobj(out)
			local ref = mkref(id)
			enclookup[x] = ref
			for k, v in pairs(x) do
				out[recurse(k)] = recurse(v) -- copy table
			end
			if mt then out._mt = recurse(mt) end -- If table has metatable, add it to output table
			return ref
		elseif t == "function" then
			local ok, code = pcall(string.dump, x)
			if ok then
				local info = debug.getinfo(x, "u") -- contains number of upvalues of function
				local upvalues = {}
				for i = 1, info.nups do
					local name, value = debug.getupvalue(x, i)
					upvalues[i] = value -- upvalues seem to be handled by index, so the name's not important
				end
				local env
				if getfenv then env = getfenv(x)
				else env = upvalues[1] end -- it seems that in Lua 5.3 the first upvalue is the function environment.
				local out = { 
					_t = "f", -- type: function
					c = code,
					u = recurse(upvalues),
					e = recurse(env)
				}
				local id = addobj(out)
				local ref = mkref(id)
				enclookup[x] = ref
				return ref
			else
				return nil -- is a non-Lua-defined function, so we can't operate on it very much
			end
		end
	end

	local root = recurse(x)

	local inverted = {}
	for k, v in pairs(objects) do
		inverted[v] = k
	end

	print(e(root), e(objects), e(inverted))

	inverted._root = copy(root)

	return inverted
end

function ultradump.load(objects)
	local function recurse(x)
		local t = type(x)
		if t == "string" or t == "number" then
			return x
		elseif t == "table" then

		else
			error("Unexpected Type " .. t)
		end
	end

	return recurse(objects._root)
end

local input = {
	1, 2, 3, function() print "HI!" end
}
input[5] = input

local out = ultradump.dump(input)
--print(e(out))

return ultradump