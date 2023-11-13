local sensor = peripheral.wrap "right"
local laser = peripheral.wrap "left"
local modem = peripheral.find "modem"

local targets = {}

local function scan()
    local nearby = sensor.sense()
    local ret = {}
    for k, v in pairs(nearby) do
        v.s = vector.new(v.x, v.y, v.z)
        v.v = vector.new(v.motionX, v.motionY, v.motionZ)
        v.distance = v.s:length()
        if v.displayName == v.name then ret[v.name] = v end
    end
    return ret
end

local function calc_yaw_pitch(v)
	local x, y, z = v.x, v.y, v.z
    local pitch = -math.atan2(y, math.sqrt(x * x + z * z))
    local yaw = math.atan2(-x, z)
    return math.deg(yaw), math.deg(pitch)
end

local function vector_sqlength(self)
	return self.x * self.x + self.y * self.y + self.z * self.z
end

local function project(line_start, line_dir, point)
	local t = (point - line_start):dot(line_dir) / vector_sqlength(line_dir)
	return line_start + line_dir * t, t
end

local function angles_to_axis(yaw, pitch)
    return vector.new(
        -math.sin(math.rad(yaw)) * math.cos(math.rad(pitch)),
        -math.sin(math.rad(pitch)),
        math.cos(math.rad(yaw)) * math.cos(math.rad(pitch))
    )
end

local laser_origin = vector.new(0, 0, 0)

local function would_hit(beam_line, safe_position, target_position)
    local point, t = project(laser_origin, beam_line, safe_position)
    return t > 0 and (point - safe_position):length() < 1.5 and safe_position:length() < target_position:length()
end

local function lase(entity, others)
	local target_location = entity.s - vector.new(0, 1, 0)
	for i = 1, 5 do
		target_location = entity.s + entity.v * (target_location:length() / 1.5)
	end
	local y, p = calc_yaw_pitch(target_location)
    local line = angles_to_axis(y, p)
    for _, other in pairs(others) do
        if would_hit(line, other.s, target_location) then
            --print("would hit", other.name)
            return false
        end
    end
    if would_hit(line, vector.new(-3, 0, 2), target_location) then
        return false
    end
    print(y)
    if y > (-90 + 45) or y < (-90 - 45) then
        return false
    end
    rs.setOutput("front", true)
    laser.fire(y, p, 1)
    sleep(0.05)
    rs.setOutput("front", false)
end

local function laser_defense()
    while true do
       local entities = scan()
       local now = os.epoch "utc"
       local action_taken = false
       for _, entity in pairs(entities) do
           local targeted_at = targets[entity.name]
           if targeted_at and targeted_at > (now - 60000) then
                print("lasing", entity.displayName, entity.s)
                lase(entity, entities)
                action_taken = true
           end
       end
       if not action_taken then sleep(0.2) end
    end
end

local function laser_commands()
    modem.open(55)
    while true do
        local _, _, c, rc, m = os.pullEvent "modem_message"
        if c == 55 and type(m) == "table" and m[1] == "lase" and type(m[2]) == "string" then
            targets[m[2]] = os.epoch "utc"
            print("command to lase", m[2], "remotely")
        end
    end
end

parallel.waitForAll(laser_defense, laser_commands)