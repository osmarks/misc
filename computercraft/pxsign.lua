local privkey_path = ".potatos_dsk"
if not fs.exists(privkey_path) then
	error("Please save the potatOS disk signing key (ECC signing key) to " .. privkey_path .. " to use this program.")
end

local ecc = require "./ecc" "ecc"

local input, output, UUID_override = ...
local function fread(thing)
    local f = fs.open(thing, "r")
    local text = f.readAll()
    f.close()
    return text
end

local function hexize(key)
    local out = ""
    for _, v in pairs(key) do
        out = out .. string.format("%.2x", v)
    end
    return out
end

local function unhexize(key)
    local out = {}
    for i = 1, #key, 2 do
        local pair = key:sub(i, i + 1)
        table.insert(out, tonumber(pair, 16))
    end
    return out
end

local function fwrite(fname, text)
    local f = fs.open(fname, "w")
    f.write(text)
    f.close()
end

local pkey = unhexize(fread(privkey_path))

local UUID = ""
if UUID_override then UUID = UUID_override
else
	for i = 1, 10 do
		UUID = UUID .. string.char(math.random(97, 122))
	end
end

print("UUID:", UUID)

local text = fread(input):gsub("@UUID@", UUID)
local signature = hexize(ecc.sign(pkey, text))
local fullcode = ([[---PXSIG:%s
---PXUUID:%s
%s]]):format(signature, UUID, text)
fwrite(output, fullcode)