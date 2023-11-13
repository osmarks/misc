local privkey_path = ".potatos_dsk"
if not fs.exists(privkey_path) then
	error("Please save the potatOS disk signing key (or alternate table-format ECC signing key) to " .. privkey_path .. " to use this program.")
end

local ecc = require "./ecc"
local t = ecc "ecc"

local thing, UUID_override = ...
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

local _, side = os.pullEvent "disk"
local mp = disk.getMountPath(side)
local path = fs.combine(mp, "startup")
local sig_path = fs.combine(mp, "signature")

local UUID_path = fs.combine(mp, "UUID")
local UUID = ""

if UUID_override then UUID = UUID_override
else
	if fs.exists(UUID_path) then UUID = fread(UUID_path)
	else
		for i = 1, 10 do
			UUID = UUID .. string.char(math.random(97, 122))
		end
	end
end

print("UUID:", UUID)

disk.setLabel(side, thing)
local text = fread(thing):gsub("@UUID@", UUID)

fwrite(path, text)
print "Written data."
fwrite(sig_path, hexize(t.sign(
    pkey,
    text
)))
fwrite(UUID_path, tostring(UUID))
print "Written signature."
print("Disk ID:", disk.getID(side))