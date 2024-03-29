local input = peripheral.wrap "ironchests:copper_chest_0"
local drum_ri = peripheral.wrap "redstone_integrator_0"
local amaranthus_ri = peripheral.wrap "redstone_integrator_1"
local output_hydroangeas_chest = peripheral.wrap "minecraft:chest_2"
local disposal = peripheral.wrap "botania:open_crate_0"
local own_name = "turtle_0"
local aux_chest = peripheral.wrap "minecraft:chest_1"

local reqs = {
    "blue",
    "cyan"
}

local function manage_input_chest()
    local count = {}
    local slots = {}
    for slot, meta in pairs(input.list()) do
        if count[meta.name] then
            input.pushItems(peripheral.getName(disposal), slot)
        else
            count[meta.name] = meta.count
            slots[meta.name] = slot
        end
    end
    local ok = true
    for _, req in ipairs(reqs) do
        local name = ("botania:%s_mystical_flower"):format(req)
        if count[name] == nil or count[name] < 16 then
            ok = false
        end
    end
    return ok, slots
end

local function main()
    while true do
        local can_produce_hydroangeas, slot_map = manage_input_chest()
        local dest = output_hydroangeas_chest.list()[1]
        local seed_src = aux_chest.list()[2]
        amaranthus_ri.setOutput("east", can_produce_hydroangeas)
        if can_produce_hydroangeas and not dest or (dest and dest.count < 16) and seed_src then
            amaranthus_ri.setOutput("east", true)
            print "manufacturing cycle."
            aux_chest.pushItems(own_name, 1, 1)
            turtle.placeUp()
            turtle.dropDown()
            turtle.suckDown()
            aux_chest.pullItems(own_name, 1)
            for _, req in ipairs(reqs) do
                input.pushItems(own_name, slot_map[("botania:%s_mystical_flower"):format(req)], 1)
                turtle.craft()
                turtle.dropDown(2)
            end
            aux_chest.pushItems(own_name, 2, 1)
            turtle.dropDown()
            turtle.suckDown()
            output_hydroangeas_chest.pullItems(own_name, 1)
            sleep(3)
            local can_produce_hydroangeas, slot_map = manage_input_chest()
            if slot_map["botania:hydroangeas"] then
                print "moving from external"
                output_hydroangeas_chest.pullItems(peripheral.getName(input), slot_map["botania:hydroangeas"])
            end
            sleep(30)
        else
            print "enough hydroangeas or insufficient seeds or flowers"
            sleep(30)
        end
    end
end

local function run_drum()
    while true do
        if not amaranthus_ri.getOutput "east" then
            print "pulsing drum"
            drum_ri.setOutput("down", true)
            sleep(0.1)
            drum_ri.setOutput("down", false)
        end
        sleep(10)
    end
end

parallel.waitForAll(run_drum, main)