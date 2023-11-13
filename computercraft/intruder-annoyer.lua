local authorized = settings.get "alarm.authorized"
local bounds = settings.get "alarm.bounds"
if type(bounds) == "string" then bounds = textutils.unserialise(bounds) end
local particle = peripheral.find "particle"
local sensor = peripheral.find "plethora:sensor"

local function random_in_range(min, max)
	local size = math.abs(min) + math.abs(max)
	print(size, min, max)
	return (math.random() * size) + min
end

local function detect_intruders()
	local es = sensor.sense()
	local positions = {}
	for _, e in pairs(es) do
		if e.x >= bounds[1] and e.x <= bounds[2] and e.y >= bounds[3] and e.y <= bounds[4] and e.z >= bounds[5] and e.z <= bounds[6] then
			table.insert(positions, { e.x, e.y, e.z })
			print(os.clock(), e.displayName)
			if e.displayName == authorized then return false end
		end
	end
	return positions
end

while true do
	local intruders = detect_intruders()
	print(intruders)
	if intruders and #intruders > 0 then
		-- generally fill building
		for _ = 1, 8 do
			particle.spawn("barrier", 
				random_in_range(bounds[1], bounds[2]),
				random_in_range(bounds[3], bounds[4]),
				random_in_range(bounds[5], bounds[6]))
		end
		-- specifically target intruder
		for _, position in pairs(intruders) do
			local x, y, z = unpack(position)
			for _ = 1, 16 do
				particle.spawn("barrier", 
					random_in_range(x - 2, x + 2),
					random_in_range(y - 2, y + 2),
					random_in_range(z - 2, z + 2))
			end
		end
		sleep()
	else
		sleep(1)
	end
end