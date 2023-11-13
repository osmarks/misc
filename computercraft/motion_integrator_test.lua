local ni = peripheral.wrap "back"
package.path = "/?;/?.lua;" .. package.path
local gps_patch = require "gps_patch"

local estimated_position = vector.new(gps_patch.locate())
local function integrate_motion()
    local lt = os.clock()
    while true do
        local meta = ni.getMetaOwner()
        local v = vector.new(meta.deltaPosX, meta.deltaPosY, meta.deltaPosZ)
        --if math.floor(os.clock()) == os.clock() then print("vel", v) end
        local time = os.clock()
        local dt = time - lt
        estimated_position = estimated_position + v
        --estimated_position = channelwise(round_to_frac, estimated_position, meta.withinBlock)
        lt = time
    end
end

local function compare_against_gps()
    while true do
        local pos = vector.new(gps_patch.locate())
        print("delta", pos - estimated_position)
        sleep(1)
    end
end

parallel.waitForAll(integrate_motion, compare_against_gps)