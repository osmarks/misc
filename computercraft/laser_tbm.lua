local laser = peripheral.find "plethora:laser"
local modem = peripheral.find "modem"
local channel = 26535
local count = 8
local go = false
modem.open(channel)

--[[
local movement_notifications = {}
local function moved_count()
    local c = 0
    for k in pairs(movement_notifications) do
        c = c + 1
    end
    return c
end
]]

local function main()
    while true do
        --print("reset movement notifications")
        --movement_notifications = {}
        --while true do
            --[[if turtle.detect() then
                laser.fire(-180, 0, 5)
                --laser.fire(0, 0, 5)
            end
            local ok, reason = turtle.forward()
            if ok then
                print("transmit movement notification")
                modem.transmit(channel, channel, { "moved", os.getComputerID() })
                break
            elseif reason == "Out of fuel" then
                print("Refuel")
                turtle.refuel()
                sleep(1)
            end]]
            if go then laser.fire(270, 0, 5) else sleep(1) end
        --end
        --[[
        local calls = {}
        for i = 1, 16 do
            table.insert(calls, function() laser.fire(0, 90, 5) end)
        end
        parallel.waitForAll(unpack(calls))
        --laser.fire(0, -270, 5)
        while (not go or moved_count() ~= (count - 1)) do
            print("count is", moved_count(), moved_count() == count - 1, "go", go)
            os.pullEvent()
        end
        ]]
    end
end

local function communications()
    while true do
        local _, _, c, rc, msg, distance = os.pullEvent "modem_message"
        if c == channel and type(msg) == "table" then
            if msg[1] == "ping" then
                modem.transmit(channel, channel, { "pong", gps.locate() })
            elseif distance and msg[1] == "stop" and distance < 32 then
                print("stop command")
                go = false
            elseif distance and msg[1] == "start" and distance < 32 then
                print("start command")
                go = true
            elseif distance and msg[1] == "moved" and distance < 32 then
                print("got movement notification")
                movement_notifications[msg[2]] = true
            elseif distance and msg[1] == "update" and distance < 32 then
                local h = http.get "https://osmarks.net/stuff/laser_tbm.lua"
                local t = h.readAll()
                h.close()
                local f, e = load(t)
                if not f then printError(e)
                else
                    local f = fs.open("startup", "w")
                    f.write(t)
                    f.close()
                    print "updated"
                    os.reboot()
                end
            elseif distance and msg[1] == "forward" and distance < 32 then
                turtle.forward()
            end
        end
    end
end

parallel.waitForAll(communications, main)