local other_monitor
repeat
    other_monitor = peripheral.wrap "monitor_5206"
    sleep(1)
until other_monitor
local integrators = {}
for i = 931, 936 do
    table.insert(integrators, peripheral.wrap("redstone_integrator_" .. i))
end
local big_screen = peripheral.wrap "front"
local sensor = peripheral.wrap "left"
local laser = peripheral.wrap "manipulator_572"
local modem = peripheral.find "modem"

local trusted = {
    gollark = true,
    heav_ = true,
    ["6_4"] = true
}
local targets = {}

local function redraw(status, color)
    local orig = term.redirect(big_screen)
    term.setCursorPos(1, 1)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.clear()
    print [[GTech(tm) EM-02
Level 6-G/105 credentials required.
Enter credentials:]]
    term.setTextColor(color)
    term.write(status)
    term.setTextColor(colors.black)
    for i = 0, 3 do
        for y = (i * 3 + 8), ((i + 1) * 3 + 8) do
            for x = 1, 18, 6 do
                local j = math.floor(x/6) * 4 + i
                term.setBackgroundColor(2^(j))
                term.setCursorPos(x, y)
                local s = "      "
                if y % 3 == 0 then
                    s = ("  %02d  "):format(j)
                end
                term.write(s)
            end
        end
    end
    term.redirect(orig)
end

local function set_state(state)
    for _, i in pairs(integrators) do
        i.setOutput("north", state)
    end
end

local function scan()
    local nearby = sensor.sense()
    for k, v in pairs(nearby) do
        v.s = vector.new(v.x, v.y, v.z) + vector.new(-2, -2, 0)
        v.v = vector.new(v.motionX, v.motionY, v.motionZ)
        v.distance = v.s:length()
        if v.displayName ~= v.name then nearby[k] = nil end
    end
    return nearby
end

set_state(true)
local ctr = ""


local function enable_lasing(player)
    targets[player] = os.epoch "utc"
    modem.transmit(55, 55, { "lase", player })
end

local function monitor_loop()
    while true do
        local continue = true
        if #ctr == 0 then
            redraw("READY", colors.orange)
        elseif #ctr == 6 then
            local nearby = scan()
            local ok = false
            for _, e in pairs(nearby) do
                print(e.displayName, trusted[e.displayName])
                if trusted[e.displayName] and e.distance < 5 then
                    ok = true
                    break
                end
            end
            if ctr:match "55555" then
                ok = false
            end
            if ok then
                redraw("AUTH SUCCESS", colors.lime)
                print("yay open")
                set_state(false)
                sleep(3)
                set_state(true)
                ctr = ""
                continue = false
            else
                redraw("AUTH FAILURE", colors.red)
                table.sort(nearby, function(a, b) return a.distance <= b.distance end)
                if nearby[1] then
                    enable_lasing(nearby[1].name)
                end
                ctr = ""
                continue = false
                sleep(5)
            end
        else
            redraw(("*"):rep(#ctr), colors.blue)
        end
        if continue then
            local ev, side, x, y = os.pullEvent "monitor_touch"
            local realpos = y - 8
            if ev == "monitor_touch" and side == peripheral.getName(big_screen) and realpos >= 0 then
                print(x, y)
                local cy, cx = math.floor(realpos / 3), math.floor((x - 1) / 6)
                ctr = ctr .. ("%01x"):format(cy + cx * 4)
                print(ctr)
            end
        end
    end
end

local function other_monitor_loop()
    local orig = term.redirect(other_monitor)
    term.setCursorPos(1, 1)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.clear()
    print [[GTech(tm) EM-02
Press to open door.]]
    term.setTextColor(colors.black)
    term.redirect(orig)
    while true do
        local ev, side, x, y = os.pullEvent "monitor_touch"
        if side == peripheral.getName(other_monitor) then
            print "opened from inside"
            set_state(false)
            sleep(3)
            set_state(true)
        end
    end
end

local function calc_yaw_pitch(v)
	local x, y, z = v.x, v.y, v.z
    local pitch = -math.atan2(y, math.sqrt(x * x + z * z))
    local yaw = math.atan2(-x, z)
    return math.deg(yaw), math.deg(pitch)
end

local function lase(entity)
	local target_location = entity.s - vector.new(0, 1, 0)
	for i = 1, 5 do
		target_location = entity.s + entity.v * (target_location:length() / 1.5)
	end
	local y, p = calc_yaw_pitch(target_location)
    laser.fire(y, p, 1)
end

local function laser_defense()
    while true do
       local entities = scan()
       local now = os.epoch "utc"
       local action_taken = false
       for _, entity in pairs(entities) do
           local targeted_at = targets[entity.name]
           if targeted_at and targeted_at > (now - 60000) then
                print("lasing", entity.displayName, entity.s)
                lase(entity)
                action_taken = true
           end
       end
       if not action_taken then sleep(0.5) end
    end
end

local function laser_commands()
    modem.open(55)
    while true do
        local _, _, c, rc, m = os.pullEvent "modem_message"
        if c == 55 and type(m) == "table" and m[1] == "lase" and type(m[2]) == "string" then
            targets[m[2]] = os.epoch "utc"
            print("command to lase", m[2], "remotely")
        end
    end
end

parallel.waitForAll(monitor_loop, laser_defense, other_monitor_loop, laser_commands)