local c = peripheral.find "nc_geiger_counter"
local m = peripheral.wrap "top"

while true do
    local lvl = c.getChunkRadiationLevel()
    print(lvl)
    m.transmit(3054, 3054, {"rads/" .. os.getComputerLabel(), "radiation level", "set", lvl})
    sleep(1)
end