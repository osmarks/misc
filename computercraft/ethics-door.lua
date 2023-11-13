local integrators = {}
for i = 1017, 1022 do
    table.insert(integrators, peripheral.wrap("redstone_integrator_" .. i))
end
local big_screen = peripheral.wrap "top"
local sensor = peripheral.wrap "left"
local modem = peripheral.find "modem"
modem.open(56)

local function redraw(status, color, line)
    local orig = term.redirect(big_screen)
    term.setCursorPos(1, 1)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.clear()
    print [[GTech(tm) Hyperethical Door Engine(tm)]]
    if line then print(line) end
    print()
    if status then
        term.setTextColor(color)
        term.write(status)
    end
    term.redirect(orig)
end

local function set_state(state)
    for _, i in pairs(integrators) do
        i.setOutput("east", state)
    end
end

local function scan()
    local nearby = {}
    for k, v in pairs(sensor.sense()) do
        v.s = vector.new(v.x, v.y, v.z) + vector.new(-2, -2, 0)
        v.v = vector.new(v.motionX, v.motionY, v.motionZ)
        v.distance = v.s:length()
        if v.displayName == v.name then nearby[v.displayName] = v end
    end
    return nearby
end

local queue = {}
pcall(function()
    local f = fs.open("queue.txt", "r")
    queue = textutils.unserialise(f.readAll())
    f.close()
end)
local function push(x)
    table.insert(queue, x)
    if #x > 100 then
        table.remove(queue, 1)
    end
    pcall(function()
        local f = fs.open("queue.txt", "w")
        f.write(textutils.serialise(queue))
        f.close()
    end)
end

set_state(true)

local function listener()
    redraw()
    while true do
        local _, _, c, rc, m = os.pullEvent "modem_message"
        local player = m[1]
        local ethics = m[2]
        local message = m[3]
        local entry = scan()[player]
        if entry and entry.distance < 8 then
            local text = ("%s %s ethicality %d"):format(os.date "!%X", player, ethics)
            local status, color
            if ethics >= 3 then
                local in_queue = false
                for _, q in pairs(queue) do
                    if q == message then
                        in_queue = true
                        break
                    end
                end
                if in_queue then
                    status = "REPEAT"
                    color = colors.red
                else
                    status = "AUTHORIZED"
                    color = colors.lime
                    redraw(status, color, text)
                    set_state(false)
                    sleep(10)
                    push(message)
                    set_state(true)
                end
            else
                status = "BELOW THRESHOLD"
                color = colors.orange
            end
            redraw(status, color, text)
        end
    end
end

listener()