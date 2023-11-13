pcall(function() os.loadAPI "bigfont" end)

local OSes = {
    "PotatOS",
    "ShutdownOS",
    "YomatOS",
    "TomatOS",
	"ChorOS",
	"BurritOS",
	"GovOS",
}

local function random_pick(list)
    return list[math.random(1, #list)]
end

local function random_color()
	return math.pow(2, math.random(0, 15))
end

local function HSL(hue, saturation, lightness)
    if hue < 0 or hue > 360 then
        return 0x000000
    end
    if saturation < 0 or saturation > 1 then
        return 0x000000
    end
    if lightness < 0 or lightness > 1 then
        return 0x000000
    end
    local chroma = (1 - math.abs(2 * lightness - 1)) * saturation
    local h = hue/60
    local x =(1 - math.abs(h % 2 - 1)) * chroma
    local r, g, b = 0, 0, 0
    if h < 1 then
        r,g,b=chroma,x,0
    elseif h < 2 then
        r,b,g=x,chroma,0
    elseif h < 3 then
        r,g,b=0,chroma,x
    elseif h < 4 then
        r,g,b=0,x,chroma
    elseif h < 5 then
        r,g,b=x,0,chroma
    else
        r,g,b=chroma,0,x
    end
    local m = lightness - chroma/2
    return (r+m) * 16777216 + (g+m) * 65535 + (b+m) * 256
end

local default_palette = { 0x000000, 0x7F664C, 0x57A64E, 0xF2B233, 0x3366CC, 0xB266E5, 0x4C99B2, 0x999999, 0x4C4C4C, 0xCC4C4C, 0x7FCC19, 0xDEDE6C, 0x99B2F2, 0xE57FD8, 0xF2B2CC, 0xFFFFFF }
local palette = { 0x000000 }
for i = 0, 13 do
	table.insert(palette, HSL((i / 13) * 360, 1.0, 0.4))
end
table.insert(palette, 0xFFFFFF)
 
local function init_screen(t)
	t.setTextScale(4)
	t.setBackgroundColor(colors.black)
--	t.setCursorPos(1, 1)
--	t.clear()
	for i, c in pairs(default_palette) do
		t.setPaletteColor(math.pow(2, 16 - i), c)
	end
end

local function write_screen_slow(term, text, delay)
	local w, h = term.getSize()
	term.setCursorBlink(true)
	for i = 1, #text do
		local char = text:sub(i, i)
		local x, y = term.getCursorPos()
		term.write(char)
		if x == w then
			term.scroll(1)
			term.setCursorPos(1, h)
		end
		sleep(delay)
	end
	term.setCursorBlink(false)
end

local monitors = {peripheral.find("monitor", function(_, m) init_screen(m) return true end)}

local function unpotatoplexer()
	while true do
		local t = random_pick(monitors)
		t.setTextColor(random_color())
		if math.random(0, 1000) == 40 then
			if bigfont then bigfont.writeOn(t, 1, "hello", 2, 2) end
		else
			write_screen_slow(t, random_pick(OSes) .. " ", 0.05)
		end
	end
end

local threads = {}
for i = 1, 5 do
	table.insert(threads, unpotatoplexer)
end
parallel.waitForAll(unpack(threads))