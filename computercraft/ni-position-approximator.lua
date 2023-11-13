local iface = peripheral.wrap "back"
local x, y, z = gps.locate()

local approx = y
local function do_approx()
	local past_time = os.epoch "utc"
	while true do
		local time = os.epoch "utc"
		local diff = (time - past_time) / 1000
		past_time = time
		local meta = iface.getMetaByName "gollark"
		approx = approx + (meta.motionY * diff)
		sleep()
	end
end

local function do_gps()
	while true do
		local x, y, z = gps.locate() 
		print("real=", y, "\napprox=", approx, "\ndiff=", y - approx)
		sleep(0.5)
	end
end

parallel.waitForAll(do_approx, do_gps)