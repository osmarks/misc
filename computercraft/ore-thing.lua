local m = peripheral.find("modem", function(_, o) return o.isWireless() end)
 
local function send_metric(...)
	m.transmit(3054, 3054, {...})
end

function pulse(side)
	rs.setOutput(side,true)
	sleep(0.05)
	rs.setOutput(side,false)
	sleep(0.05)
end

while true do
	local exists, data = turtle.inspect()
	if not exists then sleep(0.05)
	elseif data.name == "minecraft:netherrack" or data.name == "minecraft:stone" then pulse "left"
	else send_metric("ores_made", "quantity of ores summoned from beespace", "inc", 1) pulse "right" end
end