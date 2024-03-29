local modem = {peripheral.find("modem", function(_, o) return o.isWireless() end)}
local function send(...)
    for _, modem in pairs(modem) do
        modem.transmit(48869, 48869, {...})
    end
end
local input = peripheral.wrap(settings.get "input")
local output = settings.get "output"
local subsystem = settings.get "subsystem"
local desc = settings.get "subsystem_description"
local namecache = {}
while true do
    for slot, stack in pairs(input.list()) do
        local name
        if namecache[stack.name] then
            name = namecache[stack.name]
        else
            name = input.getItemDetail(slot).displayName
            namecache[stack.name] = name
        end
        local transfer = input.pushItems(output, slot)
        print(transfer, name)
        send("item_throughput_" .. subsystem .. "/" .. name, "items produced in " .. desc, transfer, "inc")
    end
    sleep(1)
end