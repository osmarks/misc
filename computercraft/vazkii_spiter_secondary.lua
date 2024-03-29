local output_hydroangeas_chest = peripheral.wrap "minecraft:chest_2"
local own_name = "turtle_1"
local hh_ri = peripheral.wrap "redstone_integrator_2"

while true do
    output_hydroangeas_chest.pushItems(own_name, 1, nil, 1)
    local count = turtle.getItemCount()
    hh_ri.setOutput("west", true)
    turtle.drop()
    sleep(10)
    turtle.suck()
    hh_ri.setOutput("west", false)
    output_hydroangeas_chest.pullItems(own_name, 1, nil, 1)
    sleep(30)
end