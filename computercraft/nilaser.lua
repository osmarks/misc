local ni = peripheral.find "neuralInterface"
if not ni or not ni.fire or not ni.sense then error "Neural interface with laser and entity sensor required!" end
local args = {...}
local power = table.remove(args, 1)
local num_power = tonumber(power)
if num_power then power = num_power end
local follow_mode, stare_mode = power == "follow", power == "stare"
local laser_mode = not (follow_mode or stare_mode)
if #args == 0 or not power then
	error([[Usage: nilaser <power> <patterns to match targets...>]])
end

local function calc_yaw_pitch(x, y, z)
    local pitch = -math.atan2(y, math.sqrt(x * x + z * z))
    local yaw = math.atan2(-x, z)
    return math.deg(yaw), math.deg(pitch)
end

local function is_target(entity)
	for _, pattern in pairs(args) do
		if entity.name:match(pattern) or entity.displayName:match(pattern) then return true end
	end
	return false
end

while true do
	for _, entity in pairs(ni.sense()) do
		if is_target(entity) then
			print(entity.name, entity.displayName)
			local y, p = calc_yaw_pitch(entity.x, entity.y, entity.z)
			if laser_mode then
				ni.fire(y, p, power)
			elseif follow_mode then
				ni.launch(y, p, 1)
			elseif stare_mode then
				ni.look(y, p)
			end
		end
	end
	sleep(0.05)
end