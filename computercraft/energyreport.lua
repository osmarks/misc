local modem = {peripheral.find("modem", function(_, o) return o.isWireless() end)}
local storage = {peripheral.find "energy_storage"}
local function send(...)
    for _, modem in pairs(modem) do
        modem.transmit(48869, 48869, {...})
    end
end
while true do
	for _, s in pairs(storage) do
        local name = settings.get("storage_name_" .. peripheral.getName(s))
        send("mc_stored_rf/" .. name, "energy stored in RF", s.getEnergy())
        send("mc_capacity_rf/" .. name, "maximum capacity in RF", s.getEnergyCapacity())
    end
	sleep(1)
end
