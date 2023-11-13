local holo = peripheral.find "hologram"
local sensor = peripheral.find "plethora:sensor"
holo.setScale(1)
holo.setTranslation(0, 0, 0)
holo.setPaletteColor(1, 0xFFFFFF)

local W = 48
local H = 32

local function generate_strings(fn)
    local out = {}
    for x = 0, W - 1 do
        for z = 0, W - 1 do
            for y = 0, H - 1 do
                table.insert(out, fn(x / W, y / H, z / W) and "\1" or "\0")
            end
        end
    end
    return out
end

local function clamp_reflect(pos, vel, dir)
    if pos[dir] > 1 or pos[dir] < 0 then vel[dir] = -vel[dir] end
end

local ball = vector.new(0.5, 0.5, 0.5)
local vel = vector.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.1
while true do
    local run_display = false
    for _, entity in pairs(sensor.sense()) do
        if vector.new(entity.x, entity.y, entity.z):length() < 8 and entity.name == entity.displayName then
            run_display = true
            break
        end
    end
    if run_display then
        holo.setRaw(table.concat(generate_strings(function(x, y, z)
            local vpos = vector.new(x, y, z)
            return (ball - vpos):length() < 0.1
        end)))
    end
    ball = ball + vel
    clamp_reflect(ball, vel, "x")
    clamp_reflect(ball, vel, "y")
    clamp_reflect(ball, vel, "z")
end