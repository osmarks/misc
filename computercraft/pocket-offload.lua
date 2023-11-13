local spudnet_send, spudnet_background = require "ni-ctl_spudnet_interface"()

local function loop()
    while true do
        local _, data = os.pullEvent "spudnet_message"
        if data[1] == "exec" then
            spudnet_send { "result", peripheral.call("back", unpack(data[2])) }
        end
    end
end

parallel.waitForAll(loop, spudnet_background)