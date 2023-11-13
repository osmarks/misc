local enderchest = peripheral.find "minecraft:ender chest"
local targets = {}
for _, name in pairs(peripheral.call("right", "getNamesRemote")) do
    if peripheral.getType(name) == "minecraft:ironchest_iron" then
        table.insert(targets, name)
    end
end
local discard = {
    ["minecraft:cobblestone"] = true
}

while true do
    for slot, content in pairs(enderchest.list()) do
        if discard[content.name] then
            enderchest.drop(slot)
        else
            local remaining = content.count
            for _, target in pairs(targets) do
                remaining = remaining - enderchest.pushItems(target, slot)
                if remaining == 0 then break end
            end
        end
    end
    sleep(1)
end