local holos = {peripheral.find "hologram"}
local translations = {
    ["4bebae02"] = {0, 0, 0},
    ["721c3701"] = {0, 0, -1/3},
    ["30358553"] = {0, 0, 1/3}
}
local colors = {
    0xFF0000,
    0x00FF00,
    0x0000FF,
    0xFFFF00,
    0xFF00FF,
    0x00FFFF,
    0x000000,
    0xFFFFFF,
    0x888888
}

for i, holo in pairs(holos) do
    holo.setTranslation(unpack(translations[peripheral.getName(holo):sub(1, 8)]))
    for c = 1, 3 do
        holo.setPaletteColor(c, colors[(i - 1) * 3 + c])
    end
end

local W = 48
local H = 32

local function generate_strings(fn)
    local out = {}
    for _ in pairs(holos) do
        table.insert(out, {})
    end
    for x = 1, W do
        for z = 1, W do
            for y = 1, H do
                local color = fn(x, y, z)
                local targ = math.ceil(color / 3)
                for i, t in pairs(out) do
                    if i == targ then
                        table.insert(t, string.char((color - 1) % 3 + 1))
                    else
                        table.insert(t, "\0")
                    end
                end
            end
        end
    end
    return out
end

local function random()
    return math.random(0, 9)
end

while true do
    local s = generate_strings(random)
    for i, holo in pairs(holos) do
        holo.setRaw(table.concat(s[i]))
    end
    sleep(0.2)
end