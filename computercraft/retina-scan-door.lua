local other_monitor
repeat
    other_monitor = peripheral.wrap "monitor_5213"
until other_monitor
local integrators = {}
for i = 937, 942 do
    table.insert(integrators, peripheral.wrap("redstone_integrator_" .. i))
end
local big_screen = peripheral.wrap "left"
local sensor = peripheral.wrap "right"
local screen_center = vector.new(1, 0, 0.5)

local trusted = {
    gollark = true,
    heav_ = true,
    ["6_4"] = true
}
local targets = {}

local function center(text)
    local w, h = term.getSize()
    local x, y = term.getCursorPos()
    local start = (w-#text)/2
    term.setCursorPos(start, y)
    term.write(text)
end

local function redraw()
    big_screen.setTextScale(0.5)
    local orig = term.redirect(big_screen)
    term.setCursorPos(1, 4)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.clear()
    center "Initiative Sigma Conference Room"
    term.setCursorPos(1, 5)
    center "Restricted Area"
    term.setCursorPos(1, 6)
    center "Retina Scan Required"
    term.setCursorPos(1, 1)
    term.redirect(orig)
end

redraw()

local function set_state(state)
    for _, i in pairs(integrators) do
        i.setOutput("west", state)
        i.setOutput("east", state)
    end
end

local function scan()
    local nearby = sensor.sense()
    local ret = {}
    for k, v in pairs(nearby) do
        v.s = vector.new(v.x, v.y, v.z)
        v.v = vector.new(v.motionX, v.motionY, v.motionZ)
        v.distance = v.s:length()
        if v.displayName == v.name then ret[v.name] = v end
    end
    return ret
end

local function angles_to_axis(yaw, pitch)
    return vector.new(
        -math.sin(math.rad(yaw)) * math.cos(math.rad(pitch)),
        -math.sin(math.rad(pitch)),
        math.cos(math.rad(yaw)) * math.cos(math.rad(pitch))
    )
end

local function vector_sqlength(self)
	return self.x * self.x + self.y * self.y + self.z * self.z
end

local function project(line_start, line_dir, point)
	local t = (point - line_start):dot(line_dir) / vector_sqlength(line_dir)
	return line_start + line_dir * t, t
end

set_state(false)

local function display_animation()
    local orig = term.redirect(big_screen)
    for y = 1, select(2, term.getSize()) do
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1, y)
        term.setBackgroundColor(colors.red)
        term.clearLine()
        sleep(0.1)
    end
    term.redirect(orig)
end

local function is_looking_at_screen(p)
    local closest_point, t = project(p.s, angles_to_axis(p.yaw, p.pitch), screen_center)
    local dist = (closest_point - screen_center):length()
    return p.distance < 5 and dist < 0.6
end

local function retina_scan()
    while true do
        local nearby = scan()
        for _, p in pairs(nearby) do
            if is_looking_at_screen(p) then
                display_animation()
                print(p.name)
                local new_scan = scan()
                if trusted[p.name] and new_scan[p.name] and is_looking_at_screen(new_scan[p.name]) then
                    print "opening"
                    set_state(true)
                end
                redraw()
                sleep(2)
                set_state(false)
            end
        end
        sleep(0.1)
    end
end

local function inner_door()
    local orig = term.redirect(other_monitor)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 3)
    center " Press to exit"
    term.redirect(orig)
    while true do
        local ev, side = os.pullEvent "monitor_touch"
        if side == peripheral.getName(other_monitor) then
            print "opening from inside"
            set_state(true)
            sleep(2)
            set_state(false)
        end
    end
end

parallel.waitForAll(inner_door, retina_scan)