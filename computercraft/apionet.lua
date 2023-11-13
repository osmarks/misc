local component, computer = component, computer
if require then component = require "component" computer = require "computer" end
local netcards = {}
for addr in component.list "modem" do table.insert(netcards, component.proxy(addr)) end
local tunnels = {}
for addr in component.list "tunnel" do table.insert(tunnels, component.proxy(addr)) end
local computer_id = component.list "computer"()
local computer_peripheral = component.proxy(computer_id)
local computer_sid = computer_id:sub(1, 8)
local eeprom = component.proxy(component.list "eeprom"())

computer_peripheral.beep(600)

local recents = {}

local PORT = 4096
local DBG_PORT = 4097

for _, card in pairs(netcards) do
	card.open(PORT)
	card.open(DBG_PORT)
	card.setWakeMessage("poweron", true)
	if card.setStrength then card.setStrength(math.huge) end
	computer_peripheral.beep(1500)
end
for _, tun in pairs(tunnels) do tun.setWakeMessage("poweron", true) computer_peripheral.beep(1200) end

computer_peripheral.beep(400)

while true do
	local ev, _, _, port, distance, mtxt, mid = computer.pullSignal(5)
	if ev == "modem_message" and type(mid) == "string" and mtxt ~= nil and (port == PORT or port == 0) and not recents[mid] then
		recents[mid] = computer.uptime() + 120
		for _, card in pairs(netcards) do
			pcall(card.broadcast, PORT, mtxt, mid, computer_sid)
		end
		for _, tun in pairs(tunnels) do
			pcall(tun.send, mtxt, mid, computer_sid)
		end
	end
	if ev == "modem_message" and type(mtxt) == "string" and port == DBG_PORT and distance < 8 then
		if mtxt == "ping" then
			computer_peripheral.beep(1000)
			card.broadcast(DBG_PORT, computer_sid)
		elseif mtxt == "flash" and type(mid) == "string" then
			computer_peripheral.beep(800)
			eeprom.set(mid)
		end
	end
	local uptime = computer.uptime()
	for mid, deadline in pairs(recents) do
		if uptime > deadline then
			recents[mid] = nil
		end
	end
end