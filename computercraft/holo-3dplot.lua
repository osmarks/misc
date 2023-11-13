local holos = {"9631", "86dd", "2d4c", "6701"}
local colors = {0xFF0000, 0x00FF00, 0x0000FF}

local names = peripheral.getNames()

for i, holo in pairs(holos) do
    for _, name in pairs(names) do
        if name:match("^" .. holo) then
            holo = peripheral.wrap(name)
            break
        end
    end
    holos[i] = holo
    holo.setScale(1/3)
    holo.setTranslation(0, 1, 0)
    for i, col in pairs(colors) do
        holo.setPaletteColor(i, col)
    end
end

local gsize = math.sqrt(#holos)
assert(gsize == math.floor(gsize))
local W = 48
local H = 32
local half_H = H / 2

local function generate_strings(fn, base_x, base_z)
    local base_x = (base_x / gsize) * 2 - 1
    local base_z = (base_z / gsize) * 2 - 1
    print(base_x, base_z)
    local out = {}
    for x = 0, W - 1 do
        for z = 0, W - 1 do
            for y = 0, H - 1 do
                local lx, ly, lz = base_x + x / W, y / half_H - 1, base_z + z / W
                table.insert(out, fn(lx, ly, lz) and "\1" or "\0")
            end
        end
    end
    return out
end

local function fn(x, y, z)
    --return bit.bxor(x*48, y*48, z*48) == 24
    return math.sin(x-y*z)>0
end

while true do
    for i, holo in pairs(holos) do
        local o = i - 1
        local x, z = o % gsize, math.floor(o / gsize)
        print(i, x, z)
        local gs = table.concat(generate_strings(fn, x, z))
        holo.setRaw(gs)
    end
    break
end