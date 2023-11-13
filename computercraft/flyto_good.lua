local mods = peripheral.wrap "back"
local tx, tz = ...
tx, tz = tonumber(tx), tonumber(tz) 
local target = vector.new(tx, 0, tz)

local last_t
local last_s

local function calc_yaw_pitch(v)
	local x, y, z = v.x, v.y, v.z
    local pitch = -math.atan2(y, math.sqrt(x * x + z * z))
    local yaw = math.atan2(-x, z)
    return math.deg(yaw), math.deg(pitch)
end

local function within_epsilon(a, b)
    return math.abs(a - b) < 1
end

while true do
    local x, y, z = gps.locate()
    if not y then print "GPS error?"
    else
        if y < 256 then
            mods.launch(0, 270, 4)
        end
        local position = vector.new(x, 0, z)
        local curr_t = os.epoch "utc"
        local displacement = target - position
        local real_displacement = displacement
        if last_t then
            local delta_t = (curr_t - last_t) / 1000
            local delta_s = displacement - last_s
            local deriv = delta_s * (1/delta_t)
            displacement = displacement + deriv
            --pow = pow + 0.0784 + delta_t / 50
        end
        local pow = math.max(math.min(4, displacement:length() / 40), 0)
        print(pow)
        local yaw, pitch = calc_yaw_pitch(displacement)
        mods.launch(yaw, pitch, math.abs(pow))
        --sleep(0)
        last_t = curr_t
        last_s = real_displacement
        if within_epsilon(position.x, target.x) and within_epsilon(position.z, target.z) then break end
        sleep(0.1)
    end
end