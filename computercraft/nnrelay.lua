if require then
    component = require "component"
    computer = require "computer"
end

computer.beep(200)

--local net = component.proxy(component.list "internet"())
local modem_id = component.list "modem"()
local modem = component.proxy(modem_id)

modem.open(1025) -- command channel
modem.open(1024) -- nanobot reply channel

while true do
    local event = {computer.pullSignal()}
    if event[1] == "modem_message" then
        table.remove(event, 1) -- event
        table.remove(event, 1) -- to
        local from = table.remove(event, 1) -- from
        local port = table.remove(event, 1)
        local distance = table.remove(event, 1) -- distance
        if print then print(port, distance) end
        if distance < 16 then
            if port == 1024 then
                --computer.beep(800)
                modem.broadcast(1026, from, table.unpack(event))
            elseif port == 1025 then
                --computer.beep(1600)
                --table.remove(event) -- remove last two arguments added when transmitting
                table.remove(event)
                modem.broadcast(1024, table.unpack(event))
            end
        end
    end
end