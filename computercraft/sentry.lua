local laser = peripheral.find "plethora:laser"
local sensor = peripheral.find "plethora:sensor"
local targets = {
    enes18enes = true,
    enes20enes = true
}
local protect = {
    heav_ = true,
    gollark = true
}
local laser_power = 5

local function vector_sqlength(self)
	return self.x * self.x + self.y * self.y + self.z * self.z
end

local function project(line_start, line_dir, point)
	local t = (point - line_start):dot(line_dir) / vector_sqlength(line_dir)
	return line_start + line_dir * t, t
end

local function calc_yaw_pitch(v)
	local x, y, z = v.x, v.y, v.z
    local pitch = -math.atan2(y, math.sqrt(x * x + z * z))
    local yaw = math.atan2(-x, z)
    return math.deg(yaw), math.deg(pitch)
end

local function get_laser_target(entity)
	local target_location = entity.s
	for i = 1, 5 do
		target_location = entity.s + entity.v * (target_location:length() / 1.5)
	end
	return target_location
end

local function scan_entities()
	while true do
		local entities = sensor.sense()
        local fast_mode = false

        local protected_entities_present = {}

		for _, entity in pairs(entities) do
			entity.s = vector.new(entity.x, entity.y, entity.z)
			entity.v = vector.new(entity.motionX, entity.motionY, entity.motionZ)
			if entity.displayName ~= username and entity.displayName == entity.name and (math.floor(entity.yaw) ~= entity.yaw and math.floor(entity.pitch) ~= entity.pitch) then -- player, quite possibly
				entity.v = entity.v + vector.new(0, 0.0784, 0)
			end

            if protect[entity.displayName] then
                table.insert(protected_entities_present, entity)
            end

            print(#protected_entities_present, "protected entities exist")

            if targets[entity.displayName] then
                print("found", entity.displayName)
                local target_loc = get_laser_target(entity)
                local can_fire = true
                for _, other in pairs(protected_entities_present) do
                    local closest_approach, param = project(vector.new(0, 0, 0), target_loc, other.s)
                    if vector_sqlength(closest_approach) < 5 and param > 0 then
                        print(other.displayName, "too near, not firing")
                        can_fire = false break
                    end
                end
                if can_fire then
                    local y, p = calc_yaw_pitch(target_loc)
	                laser.fire(y, p, laser_power)
                end
            end
		end

        if fast_mode then sleep() else sleep(0.2) end
    end
end

scan_entities()