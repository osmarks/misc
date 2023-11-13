local fwd, right, up = ...
fwd, right, up = tonumber(fwd), tonumber(right), tonumber(up)

local function checkFull()
	while turtle.getItemCount(16) > 0 do
		write "Please clear inventory"
		
		read()
	end
end

local j = 1
local function digLevel()
	for i = 1, right do
		for i = 1, fwd do
			turtle.digDown()
			turtle.digUp()
			turtle.dig()
			turtle.forward()
			checkFull()
		end
		if i ~= right then
			local dir = turtle.turnRight
			if j % 2 == 0 then dir = turtle.turnLeft end
			dir()
			turtle.dig()
			turtle.forward()
			dir()
			j = j + 1
		end
	end
	while turtle.getFuelLevel() < 500 do
		write "Fuel low"
		read()
		turtle.refuel(1)
	end
end

for i = 1, up, 3 do
	digLevel()
	for i = 1, 3 do
		turtle.digUp()
		turtle.up()
	end
	turtle.turnRight()
	turtle.turnRight()
end