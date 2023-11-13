local function select_item(item, mincount)
	local mincount = mincount or 1
	for i = 1, 16 do
		local it = turtle.getItemDetail(i)
		if it and it.count and it.name and it.count >= mincount and it.name == item then
			turtle.select(i)
			return true
		end
	end
	return false
end

local function run_cycle()
	turtle.up()
	select_item "minecraft:iron_block"
	turtle.place()
	turtle.up()
	select_item("minecraft:redstone", 2)
	turtle.place()
	turtle.down()
	turtle.down()
	turtle.dropUp(1)
	sleep(5)
end

while true do
	if turtle.getFuelLevel() > 4 then
		if select_item "minecraft:iron_block" and select_item("minecraft:redstone", 2) then
			print "Running."
			run_cycle()
		else
			print "Insufficient items."
		end
	else
		print "Insufficient fuel."
	end
	sleep(2)
end