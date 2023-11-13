local send_metric = require "metrics_interface"
peripheral.find("modem", function(_, o) o.open(48869) end)

while true do
    local _, _, c, rc, m = os.pullEvent "modem_message"
    if type(m) == "table" then
        print(unpack(m))
        send_metric(unpack(m))
    end
end

--[[
local modem = {peripheral.find("modem", function(_, o) return o.isWireless() end)}
local function send(...)
    for _, modem in pairs(modem) do
        modem.transmit(48869, 48869, {...})
    end
end
]]