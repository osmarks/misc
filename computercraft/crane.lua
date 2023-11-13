--[[
License for the LZW compression:
MIT License
Copyright (c) 2016 Rochet2
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local util_raw = [[
local function canonicalize(path)
	return fs.combine(path, "")
end

local function segments(path)
	if canonicalize(path) == "" then return {} end
	local segs, rest = {}, path
	repeat
		table.insert(segs, 1, fs.getName(rest))
		rest = fs.getDir(rest)
	until rest == ""
	return segs
end

local function slice(tab, start, end_)
	return {table.unpack(tab, start, end_)}
end

local function compact_serialize(x)
	local t = type(x)
	if t == "number" then
		return tostring(x)
	elseif t == "string" then
		return textutils.serialise(x)
	elseif t == "table" then
		local out = "{"
		for k, v in pairs(x) do
			out = out .. string.format("[%s]=%s,", compact_serialize(k), compact_serialize(v))
		end
		return out .. "}"
	elseif t == "boolean" then
		return tostring(x)
	else
		error("Unsupported type " .. t)
	end
end

local function drop_last(t)
	local clone = slice(t)
	local length = #clone
	local v = clone[length]
	clone[length] = nil
	return clone, v
end
]]

local util = loadstring(util_raw .. "\nreturn {segments = segments, slice = slice, drop_last = drop_last, compact_serialize = compact_serialize}")()

local runtime = util_raw .. [[
local savepath = ".crane-persistent/" .. fname

-- Simple string operations
local function starts_with(s, with)
	return string.sub(s, 1, #with) == with
end
local function ends_with(s, with)
	return string.sub(s, -#with, -1) == with
end
local function contains(s, subs)
	return string.find(s, subs) ~= nil
end

local function copy_some_keys(keys)
	return function(from)
		local new = {}
		for _, key_to_copy in pairs(keys) do
			local x = from[key_to_copy]
			if type(x) == "table" then
				x = copy(x)
			end
			new[key_to_copy] = x
		end
		return new
	end
end

local function find_path(image, path)
	local focus = image
	local path = path
	if type(path) == "string" then path = segments(path) end
	for _, seg in pairs(path) do
		if type(focus) ~= "table" then error("Path segment " .. seg .. " is nonexistent or not a directory; full path " .. compact_serialize(path)) end
		focus = focus[seg]
	end
	return focus
end

local function get_parent(image, path)
	local init, last = drop_last(segments(path))
	local parent = find_path(image, init) or image
	return parent, last
end

-- magic from http://lua-users.org/wiki/SplitJoin
-- split string into lines
local function lines(str)
	local t = {}
	local function helper(line)
		table.insert(t, line)
		return ""
	end
	helper((str:gsub("(.-)\r?\n", helper)))
	return t
end

local function make_read_handle(text, binary)
	local lines = lines(text)
	local h = {}
	local line = 0
	function h.close() end
	if not binary then
		function h.readLine() line = line + 1 return lines[line] end
		function h.readAll() return text end
	else
		local remaining = text
		function h.read()
			local by = string.byte(remaining:sub(1, 1))
			remaining = remaining:sub(2)
			return by
		end
	end
	return h
end

local function make_write_handle(writefn, binary)
	local h = {}
	function h.close() end
	function h.flush() end
	if not binary then
		function h.write(t) return writefn(t) end
		function h.writeLine(t) return writefn(t .. "\n") end
	else
		function h.write(b) return writefn(string.char(b)) end
	end
	return h
end

local function mount_image(i)
	local options = i.options
	local image = i.tree
	
	local filesystem = copy_some_keys {"getName", "combine", "getDir"} (_G.fs)
	
	function filesystem.getFreeSpace()
		return math.huge -- well, it's in-memory...
	end
	
	function filesystem.exists(path)
		return find_path(image, path) ~= nil
	end
	
	function filesystem.isDir(path)
		return type(find_path(image, path)) == "table"
	end
	
	function filesystem.makeDir(path)
		local p, n = get_parent(image, path)
		p[n] = {}
	end
	
	function filesystem.delete(path)
		local p, n = get_parent(image, path)
		p[n] = nil
	end
	
	function filesystem.copy(from, to)
		local pf, nf = get_parent(image, from)
		local contents = pf[nf]
		local pt, nt = get_parent(image, to)
		pt[nt] = contents
	end
	
	function filesystem.move(from, to)
		filesystem.copy(from, to)
		local pf, nf = get_parent(image, from)
		pf[nf] = nil
	end
	
	function filesystem.contents(path)
		return find_path(image, path)
	end
	
	function filesystem.list(path)
		local out = {}
		local dir = find_path(image, path)
		for k, v in pairs(dir) do table.insert(out, k) end
		return out
	end
	
	function filesystem.open(path, mode)
		local parent, childname = get_parent(image, path)
		local node = parent[childname]
		local is_binary = ends_with(mode, "b")
		if starts_with(mode, "r") then
			if type(node) ~= "string" then error(path .. ": not a file!") end
			return make_read_handle(node, is_binary)
		elseif starts_with(mode, "a") or starts_with(mode, "w") then
			local function writer(str)
				parent[childname] = parent[childname] .. str
				if options.save_on_change then filesystem.save() end
			end
			if not starts_with(mode, "a") or node == nil then parent[childname] = "" end
			return make_write_handle(writer, is_binary)
		end
	end
	
	function filesystem.find(wildcard)
		-- Taken from Harbor: https://github.com/hugeblank/harbor/blob/master/harbor.lua
		-- Body donated to harbor by gollark, from PotatOS, and apparently indirectly from cclite:
		-- From here: https://github.com/Sorroko/cclite/blob/62677542ed63bd4db212f83da1357cb953e82ce3/src/emulator/native_api.lua
		local function recurse_spec(results, path, spec)
			local segment = spec:match('([^/]*)'):gsub('/', '')
			local pattern = '^' .. segment:gsub('[*]', '.+'):gsub('?', '.') .. '$'
			
			if filesystem.isDir(path) then
				for _, file in ipairs(filesystem.list(path)) do
					if file:match(pattern) then
						local f = filesystem.combine(path, file)
						
						if filesystem.isDir(f) then
							recurse_spec(results, f, spec:sub(#segment + 2))
						end
						if spec == segment then
							table.insert(results, f)
						end
					end
				end
			end
		end
		local results = {}
		recurse_spec(results, '', wildcard)
		return results
	end
	
	function filesystem.getDrive()
		return "crane-vfs-" .. fname
	end

	function filesystem.isReadOnly(path)
		return false
	end

	local fo = fs.open
	function filesystem.save()
		local f = fo(savepath, "w")
		f.write(compact_serialize(i))
		f.close()
	end

	return filesystem
end

local function deepmerge(t1, t2)
	local out = {}
	for k, v in pairs(t1) do
		local onother = t2[k]
		if type(v) == "table" and type(onother) == "table" then
			out[k] = deepmerge(v, onother)
		else
			out[k] = v
		end
	end
	for k, v in pairs(t2) do
		if not out[k] then
			out[k] = v
		end
	end
	return out
end

local cli_args = {...}

local f = fs.open("/rom/apis/io.lua", "r") -- bodge reloading IO library
local IO_API_code = f.readAll()
f.close()

local function load_API(code, env, name)
	local e = setmetatable({}, { __index = env })
	load(code, "@" .. name, "t", env)()
	env[name] = e
end

local function replacement_require(path)
	return dofile(path)	
end

local function execute(image, filename)
	local image = image
	if fs.exists(savepath) then
		local f = fs.open(savepath, "r")
		image = deepmerge(image, textutils.unserialise(f.readAll()))
	end

	local f = mount_image(image)

	local env = setmetatable({ fs = f, rawfs = _G.fs, require = replacement_require, 
		os = setmetatable({}, { __index = _ENV.os }), { __index = _ENV })
	load_API(IO_API_code, env, "io")
	local func, err = load(f.contents(filename), "@" .. filename, "t", env)
	if err then error(err)
	else
		env.os.reboot = function() func() end
		return func(unpack(cli_args)) 
	end
end
]]

-- LZW Compressor
local a=string.char;local type=type;local b=string.sub;local c=table.concat;local d={}local e={}for f=0,255 do local g,h=a(f),a(f,0)d[g]=h;e[h]=g end;local function i(j,k,l,m)if l>=256 then l,m=0,m+1;if m>=256 then k={}m=1 end end;k[j]=a(l,m)l=l+1;return k,l,m end;local function compress(n)if type(n)~="string"then return nil,"string expected, got "..type(n)end;local o=#n;if o<=1 then return"u"..n end;local k={}local l,m=0,1;local p={"c"}local q=1;local r=2;local s=""for f=1,o do local t=b(n,f,f)local u=s..t;if not(d[u]or k[u])then local v=d[s]or k[s]if not v then return nil,"algorithm error, could not fetch word"end;p[r]=v;q=q+#v;r=r+1;if o<=q then return"u"..n end;k,l,m=i(u,k,l,m)s=t else s=u end end;p[r]=d[s]or k[s]q=q+#p[r]r=r+1;if o<=q then return"u"..n end;return c(p)end

local wrapper = [[local function y(b)local c="-"local d="__#"..math.random(0,10000)local e="\0";return b:gsub(c,d):gsub(e,c):gsub(d,e)end;local z="decompression failure; please redownload or contact developer";local a=string.char;local type=type;local b=string.sub;local c=table.concat;local d={}local e={}for f=0,255 do local g,h=a(f),a(f,0)d[g]=h;e[h]=g end;local function i(j,k,l,m)if l>=256 then l,m=0,m+1;if m>=256 then k={}m=1 end end;k[j]=a(l,m)l=l+1;return k,l,m end;local function n(j,k,l,m)if l>=256 then l,m=0,m+1;if m>=256 then k={}m=1 end end;k[a(l,m)]=j;l=l+1;return k,l,m end;local function dec(o)if type(o)~="string"then return nil,z end;if#o<1 then return nil,z end;local p=b(o,1,1)if p=="u"then return b(o,2)elseif p~="c"then return nil,z end;o=b(o,2)local q=#o;if q<2 then return nil,z end;local k={}local l,m=0,1;local r={}local s=1;local t=b(o,1,2)r[s]=e[t]or k[t]s=s+1;for f=3,q,2 do local u=b(o,f,f+1)local v=e[t]or k[t]if not v then return nil,z end;local w=e[u]or k[u]if w then r[s]=w;s=s+1;k,l,m=n(v..b(w,1,1),k,l,m)else local x=v..b(v,1,1)r[s]=x;s=s+1;k,l,m=n(x,k,l,m)end;t=u end;return c(r)end;local o,e=dec(y(%s));if e then error(e) end;load(o,"@loader","t",_ENV)(...)]]

local function encode_nuls(txt)
	local replace = "\0"
	local temp_replacement = ("__#%d#__"):format(math.random(-131072, 131072))
	local replace_with = "-"
	return txt:gsub(replace, temp_replacement):gsub(replace_with, replace):gsub(temp_replacement, replace_with)
end

local function compress_code(c)
	local comp = encode_nuls(compress(c))
	local txt = string.format("%q", comp):gsub("\\(%d%d%d)([^0-9])", function(x, y) return string.format("\\%d%s", tonumber(x), y) end)
	local out = wrapper:format(txt)
	--print(loadstring(out)())
	return out
end

local function find_imports(code)
	local imports = {}

	for i in code:gmatch "%-%-| CRANE ADD [\"'](.-)[\"']" do
		table.insert(imports, i)
		print("Detected explicit import", i)
	end
	return imports
end

local function add(path, content, tree)
	local segs, last = util.drop_last(util.segments(path))
	local deepest = tree
	for k, seg in pairs(segs) do
		if not deepest[seg] then
			deepest[seg] = {}
		end
		deepest = deepest[seg]
	end
	deepest[last] = content
end

local function load_from_root(file, tree)
	print("Adding", file)
	if not fs.exists(file) then error(file .. " does not exist.") end
	if fs.isDir(file) then
		for _, f in pairs(fs.list(file)) do
			load_from_root(fs.combine(file, f), tree)
		end
		return
	end

	local f = fs.open(file, "r")
	local c = f.readAll()
	f.close()
	add(file, c, tree)
	local imports = find_imports(c)
	for _, i in pairs(imports) do
		load_from_root(i, tree)
	end
end

local args = {...}
if #args < 2 then
	error([[Usage:
crane [output] [bundle startup] [other files to bundle] ]])
end

local root = args[2]
local ftree = {}

for _, wildcard in pairs(util.slice(args, 2)) do
	for _, possibility in pairs(fs.find(wildcard)) do
		load_from_root(possibility, ftree)
	end
end


local function minify(code)
	local url = "https://osmarks.tk/luamin/"
	http.request(url, code)
	while true do
		local event, result_url, handle = os.pullEvent()
		if event == "http_success" then
			local text = handle.readAll()
			handle.close()
			return text
		elseif event == "http_failure" then
			local text = handle.readAll()
			handle.close()
			error(text)
		end
	end
end

ftree[root] = minify(ftree[root])
local serialized_tree = util.compact_serialize({
	tree = ftree,
	options = {
		save_on_change = true
	}
})

local function shortest(s1, s2)
	if #s1 < #s2 then return s1 else return s2 end
end

local output = minify(([[
local fname = %s
%s
local image = %s
return execute(image, fname)
]]):format(util.compact_serialize(root), runtime, serialized_tree))

local f = fs.open(args[1], "w")
f.write("--| CRANE BUNDLE v2\n" .. shortest(compress_code(output), output))
f.close()

print "Done!"