local integrators = {}
local sensor = peripheral.find "plethora:sensor"
for i = 993, 996 do
    table.insert(integrators, peripheral.wrap("redstone_integrator_" .. i))
end
local min_bb = vector.new(-7, -4, -9999999)
local max_bb = vector.new(3, 0, 9999999)
local entry_sides = {}

local function set_open(state)
    for _, i in pairs(integrators) do
        i.setOutput("up", state)
        i.setOutput("south", state)
    end
end

local function is_bounded_by(min, max, v)
    return min.x <= v.x and max.x >= v.x and min.y <= v.y and max.y >= v.y and min.z <= v.z and max.z >= v.z
end

local function scan()
    local nearby = sensor.sense()
    local any = false
    local ret = {}
    for k, v in pairs(nearby) do
        v.s = vector.new(v.x, v.y, v.z)
        v.v = vector.new(v.motionX, v.motionY, v.motionZ)
        v.distance = v.s:length()
        if v.displayName == v.name then
            if is_bounded_by(min_bb, max_bb, v.s) then table.insert(ret, v) end
            any = true
        end
    end
    return ret, any
end


while true do
    local es, run_fast = scan()
    local closed = false
    local seen = {}
    for _, e in pairs(es) do
        if entry_sides[e.name] == nil then
            entry_sides[e.name] = e.s.z > 0  -- true if on "closed" side
        end
        seen[e.name] = true
    end
    for _, entered_via_closed_side in pairs(entry_sides) do
        if entered_via_closed_side then
            closed = true
        end
    end
    set_open(not closed)
    for k, v in pairs(entry_sides) do
        print(os.clock(), k, v)
        if not seen[k] then
            entry_sides[k] = nil
        end
    end
    set_open(not closed)
    if not run_fast then sleep(0.1) end
end