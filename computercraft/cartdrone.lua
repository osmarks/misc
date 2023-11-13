local kinetic = peripheral.find "plethora:kinetic"
local modem = peripheral.find "modem"
local laser = peripheral.find "plethora:laser"
local sensor = peripheral.find "plethora:sensor"
modem.open(70)

local p = true

local target = vector.new(gps.locate())

local function calc_yaw_pitch(v)
    local pitch = -math.atan2(v.y, math.sqrt(v.x * v.x + v.z * v.z))
    local yaw = math.atan2(-v.x, v.z)
    return math.deg(yaw), math.deg(pitch)
end

local mob_names = { "Creeper", "Zombie", "Skeleton", "Blaze" }
local mob_lookup = {}
for _, mob in pairs(mob_names) do
    mob_lookup[mob] = true
end
 
local function calc_distance(entity)
    return math.sqrt(entity.x * entity.x + entity.y * entity.y + entity.z * entity.z)
end

local function sentry()
	while true do
    	local mobs = sensor.sense()
	    local nearest
    	for _, mob in pairs(mobs) do
        	if mob_lookup[mob.name] then
            	mob.distance = calc_distance(mob)
	            if nearest == nil or mob.distance < nearest.distance then
    	            nearest = mob
        	    end
	        end
    	end
	    if nearest then
			local y, p = calc_yaw_pitch(vector.new(nearest.x, nearest.y, nearest.z))
			laser.fire(y, p, 0.5)
	        sleep(0.2)
    	else
        	sleep(0.5)
		end
	end
end

local function fly()
	while true do
		kinetic.launch(0,270,0.320)
		sleep(0.2)
	end
end

parallel.waitForAll(
	fly,
	function()
		while true do
			local current = vector.new(gps.locate())
			local displacement = target - current
			if displacement:length() > 0.1 then
				displacement = displacement + vector.new(0, 0.3, 0)
				local y, p = calc_yaw_pitch(displacement)
				local pow = math.min(displacement:length() * 0.08, 2.0)
				print(y, p, pow)
				kinetic.launch(y, p, pow)
			end
			sleep(1)
		end
	end,
	function()
		while true do
			event, side, frequency, replyFrequency, message, distance = os.pullEvent("modem_message")
			if message == "up" then
				target.y = target.y + 1
			elseif message == "down" then
				target.y = target.y - 1
			elseif message == "north" then
				target.z = target.z - 1
			elseif message == "south" then
				target.z = target.z + 1
			elseif message == "west" then
				target.x = target.x - 1
			elseif message == "east" then
				target.x = target.x + 1
			end
		end
	end,
	sentry
)

				--[[
				local xDev = tarX - x
				local yDev = tarY - y
				local zDev = tarZ - z
				if yDev+0.1 < 0 then
					local power = math.min(math.abs(yDev) / 6 ,0.1)
					print(power, "down", y, tarY, power, yDev)
					kinetic.launch(0,90, power)
				end
				if yDev-0.1 > 0 then
					local power = math.min(math.abs(yDev) / 6 ,0.1)
					print(power, "up", y, tarY, power, yDev)
					kinetic.launch(0,270, power)
				end
				if xDev+0.1 < 0 then
					local power = math.min(math.abs(xDev) / 8 ,0.33)
					print(power, "west", x, tarX, power, xDev)
					kinetic.launch(90,0, power)
					sleep(0.1)
					kinetic.launch(270,0, power * 0.75)
				end
				if xDev-0.1 > 0 then
					local power = math.min(math.abs(xDev) / 8 ,0.33)
					print(power, "east", x, tarX, power, xDev)
					kinetic.launch(270,0, power)
					sleep(0.1)
					kinetic.launch(90,0, power  * 0.75)
				end
				if zDev+0.1 < 0 then
					local power = math.min(math.abs(zDev) / 8 ,0.33)
					print(power, "north", z, tarZ, power, zDev)
					kinetic.launch(180,0, power)
					sleep(0.1)
					kinetic.launch(0,0, power * 0.75)
				end
				if zDev-0.1 > 0 then
					local power = math.min(math.abs(zDev) / 8 ,0.33)
					print(power, "south", z, tarZ, power, zDev)
					kinetic.launch(0,0, power)
					sleep(0.1)
					kinetic.launch(180,0, power  * 0.75)
				end
			end
			]]