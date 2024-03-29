local modem = {peripheral.find("modem", function(_, o) return o.isWireless() end)}
local function send(...)
    for _, modem in pairs(modem) do
        modem.transmit(48869, 48869, {...})
    end
end
local pipe = peripheral.wrap(settings.get "pipe")
local label = settings.get "label"
local ctrl = settings.get "control_output"
local target_pressure = settings.get "target"
while true do
    local pressure = pipe.getPressure()
    send("pressure/" .. label, "bars of pressure in measured pipe", pressure)
    rs.setOutput(ctrl, pressure < target_pressure)
    sleep(1)
end