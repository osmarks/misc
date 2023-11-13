local integrators = {
	redstone_integrator_788 = "north",
	redstone_integrator_790 = "east"
}
local screen = peripheral.find "monitor"
local side = "north"
local button_side = "front"
local modem = peripheral.find "modem"
modem.open(49961)
os.pullEvent = function(filter)
	while true do
		local ev = {coroutine.yield(filter)}
		if ev[1] == filter then
			return unpack(ev)
		end
	end
end
local w, h = screen.getSize()

screen.setTextScale(1.5)
screen.setBackgroundColor(colors.black)
screen.clear()

local function set_open(state)
	for i, side in pairs(integrators) do
		peripheral.call(i, "setOutput", side, not state)
	end
end

local scramble = {}
for i = 1, ((w * h) - 2) do
	table.insert(scramble, string.char(47 + i))
end

local function shuffle()
	for i = 1, (#scramble - 1) do
		local j = math.random(i, #scramble)
		local a = scramble[i]
		local b = scramble[j]
		scramble[j] = a
		scramble[i] = b
	end
end

local function draw_display()
	screen.setTextColor(colors.black)
	for i = 0, ((w * h) - 3) do
		local x = i % w
		local y = math.floor(i / w)
		screen.setCursorPos(x + 1, y + 1)
		local c = scramble[i + 1]
		screen.setBackgroundColor(2 ^ ((string.byte(c) - 48) % 15))
		screen.write(c)
	end
	screen.setTextColor(colors.white)
	screen.setBackgroundColor(colors.black)
	screen.write "CE"
end

local function flash_display(color)
	screen.setBackgroundColor(color)
	screen.clear()
	sleep(0.1)
	draw_display()
end

set_open(false)
draw_display()

local can_open = false

local function monitor_ui()
	local inp = ""
	while true do
		local _, _, x, y = os.pullEvent "monitor_touch"
		if y == h and x == w then
			print "E"
			flash_display(colors.blue)
			shuffle()
			inp = ""
			if can_open then set_open(true) sleep(1) set_open(false) end
			draw_display()
		elseif y == h and x == (w - 1) then
			print "C"
			flash_display(colors.red)
			shuffle()
			draw_display()
			inp = ""
		else
			flash_display(colors.lime)
			local i = (x - 1) + (y - 1) * w
			inp = inp .. string.char(i + 48)
		end
	end
end
local function comms()
	while true do
		local _, _, c, rc, open = os.pullEvent "modem_message"
		can_open = open
	end
end
local function button()
	while true do
		os.pullEvent "redstone"
		set_open(rs.getInput(button_side))
	end
end

parallel.waitForAll(monitor_ui, button, comms)