local screen = peripheral.wrap "top"
screen.setTextScale(0.5)
local button = "front"
local door = "right"

local function pulse()
    rs.setOutput(door, true)
    sleep(1)
    rs.setOutput(door, false)
end

local function run_button()
    while true do
        os.pullEvent "redstone"
        if rs.getInput(button) then
            pulse()
        end
    end
end

local function randbytes(len)
    local x = {}
    for i = 1, len do
        table.insert(x, string.char(math.random(0, 255)))
    end
    return table.concat(x)
end

local function randcols(len)
    local x = {}
    for i = 1, len do
        table.insert(x, ("%01x"):format(math.random(0, 15)))
    end
    return table.concat(x)
end

local function run_screen()
    while true do
        screen.setBackgroundColor(colors.black)
        screen.clear()
        screen.setCursorPos(1, 1)
        screen.setTextColor(colors.white)
        screen.write "GTech(tm) Apiaristics Division RIMO"
        local w, h = screen.getSize()
        for i = 2, h do
            screen.setCursorPos(1, i)
            screen.blit(randbytes(w), randcols(w), randcols(w))
        end
        sleep(10)
    end
end

local function run_input()
    while true do
        local _, _, x, y = os.pullEvent "monitor_touch"
        print(x, y)
        if (x + y) % 11 == 3 then
            pulse()
        end
    end
end

parallel.waitForAll(run_button, run_screen, run_input)