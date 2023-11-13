local component, computer = component, computer
if require then component = require "component" computer = require "computer" end
local wlan = component.proxy(component.list "modem"())
local computer_peripheral = component.proxy(component.list "computer"())
local reactor = component.proxy(component.list "nc_fusion_reactor"())
local gpu = component.proxy(component.list "gpu"())
local screen = component.list "screen"()
gpu.bind(screen)
wlan.setWakeMessage("poweron", true)

local function display(txt)
	local w, h = gpu.getResolution()
	gpu.set(1, 1, txt .. (" "):rep(w - #txt))
end

local function sleep(timeout)
	local deadline = computer.uptime() + (timeout or 0)
	repeat
		computer.pullSignal(deadline - computer.uptime())
	until computer.uptime() >= deadline
end

computer_peripheral.beep(400)
display "Initialized"

local NC_HEAT_CONSTANT = 1218.76

local last = nil

while true do
	local target_temp = reactor.getFusionComboHeatVariable() * NC_HEAT_CONSTANT * 1000
	local temp = reactor.getTemperature()
	display(("%f %f"):format(temp / target_temp, reactor.getEfficiency()))
	local too_high = temp > target_temp
	if too_high then
		if too_high ~= last then computer_peripheral.beep(800) end
		reactor.deactivate()
	else
		if too_high ~= last then computer_peripheral.beep(500) end
		reactor.activate()
	end
	last = too_high
	wlan.broadcast(1111, "poweron")
	sleep(0.5)
end