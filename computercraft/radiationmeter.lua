local modem = {peripheral.find("modem", function(_, o) return o.isWireless() end)}
local function send(...)
    for _, modem in pairs(modem) do
        modem.transmit(48869, 48869, {...})
    end
end
local sensor = peripheral.find "environmentDetector"
while true do
    send("mek_radiation_sv_h", "Mekanism radiation level (Sv/h)", sensor.getRadiationRaw())
    sleep(1)
end