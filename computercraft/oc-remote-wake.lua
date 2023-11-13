local wlan = component.proxy(component.list "modem"())
local computer_peripheral = component.proxy(component.list "computer"())
wlan.setWakeMessage("poweron", true)

local function sleep(timeout)
	local deadline = computer.uptime() + (timeout or 0)
	repeat
		computer.pullSignal(deadline - computer.uptime())
	until computer.uptime() >= deadline
end

local function try_power_on(comp)
	local p = component.proxy(comp)
	if p.isOn and p.turnOn then
		if not p.isOn() then
			p.turnOn()
			computer_peripheral.beep(440)
		end
	end
	if p.isRunning and p.start then
		if not p.isRunning() then
			p.start()
			computer_peripheral.beep(800)
		end
	end
end

while true do
	for addr in component.list "turtle" do try_power_on(addr) end
	for addr in component.list "computer" do try_power_on(addr) end
	sleep(1)
end