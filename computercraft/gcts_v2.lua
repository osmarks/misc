local integrators = {peripheral.find "redstone_integrator"}
local mon = peripheral.find "monitor"

local spinner = {
    "|", "/", "-", "\\"
}

local function draw_status(god, operation, color)
    local r = term.redirect(mon)
    term.setBackgroundColor(color)
    term.clear()
    term.setCursorPos(3, 2)
    term.write "God Murder/"
    term.setCursorPos(3, 3)
    term.write "Resurrection"
    term.setCursorPos(3, 4)
    term.write "System"
    term.setCursorPos(3, 8)
    term.write "God Status:"
    term.setCursorPos(3, 9)
    term.write(god)
    term.setCursorPos(3, 11)
    if operation then
        term.write(operation .. " " .. spinner[(math.floor(os.clock() * 20) % #spinner) + 1])
    end
    term.redirect(r)
end

local function set_trapdoors(state)
    for _, i in pairs(integrators) do
        local s = state
        if s == "random" then s = math.random(0, 1) == 0 end
        i.setOutput("west", s)
    end
end

local god = "DEAD"
local operation

while true do
    if operation and math.random(0, 16) == 0 then
        if god == "DEAD" then
            god = "ALIVE"
        elseif god == "ALIVE" then
            god = "DEAD"
        end
        operation = nil
        set_trapdoors(false)
    end
    if not operation and math.random(0, 30) == 0 then
        if god == "DEAD" then
            operation = "Resurrecting"
        elseif god == "ALIVE" then
            operation = "Murdering"
        end
    end
    if operation then set_trapdoors "random" end
    local color = colors.black
    if operation == "Resurrecting" then
        color = colors.green
    elseif operation == "Murdering" then
        color = colors.red
    end
    draw_status(god, operation, color)
    sleep(operation and 0 or 1)
end