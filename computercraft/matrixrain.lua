local mat = peripheral.wrap "right"
mat.setPaletteColor(colors.black, 0)
mat.setPaletteColor(colors.green, 0x15b01a)
mat.setPaletteColor(colors.lime, 0x01ff07)
mat.setTextScale(0.5)
local w, h = mat.getSize()

local function rchar()
    return string.char(math.random(0, 255))
end

local function wrap(x)
    return (x - 1) % h + 1
end

local cols = {}
for i = 1, w do
    local base = math.random(1, h)
    table.insert(cols, { base, base + math.random(1, h - 5) })
end

while true do
    for x, col in pairs(cols) do
        local start = col[1]
        local endp = col[2]
        mat.setCursorPos(x, start)
        mat.write " "
        mat.setCursorPos(x, wrap(endp - 1))
        mat.setTextColor(colors.green)
        mat.write(rchar())
        mat.setTextColor(colors.lime)
        mat.setCursorPos(x, endp)
        mat.write(rchar())
        col[1] = col[1] + 1
        col[2] = col[2] + 1

        col[1] = wrap(col[1])
        col[2] = wrap(col[2])
    end
    sleep(0.1)
end