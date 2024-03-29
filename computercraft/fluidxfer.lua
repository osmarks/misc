local modem = {peripheral.find("modem", function(_, o) return o.isWireless() end)}
local function send(...)
    for _, modem in pairs(modem) do
        modem.transmit(48869, 48869, {...})
    end
end
local input = peripheral.wrap(settings.get "input")
local subsystem = settings.get "subsystem"
local desc = settings.get "subsystem_description"
while true do
    for slot, tank in pairs(input.tanks()) do
        local target = settings.get("output_"  .. tank.name)
        local name = settings.get("name_" .. tank.name)
        if target and name then
            local transfer = input.pushFluid(target, nil, tank.name)
            print(target, transfer, tank.name)
            send("fluid_throughput_" .. subsystem .. "/" .. name, "millibuckets of fluid from " .. desc, transfer, "inc")
        end
    end
    sleep(1)
end