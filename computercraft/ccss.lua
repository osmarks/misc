--process.spawn(function() shell.run "ccss_player_positions_agent" end, "ccss_player_positions_agent")
process.spawn(function()
	while true do
		local game_time_start = os.epoch "utc"
		sleep(1)
		local game_time_end = os.epoch "utc"
		local utc_elapsed_seconds = (game_time_end - game_time_start) / 1000
		local tps = 20 / utc_elapsed_seconds
		os.queueEvent("ccss_update", ("TPS is approximately %f"):format(tps))
	end
end, "tpsmeter")

local palette = {
	blue =      0x303289,
	yellow =    0xedad15,
	red =       0x8d2423,
	magenta =   0xa43098,
	green =     0x4a5b25,
	lightBlue = 0x2587c5,
	white =     0xffffff,
	pink =      0xd06385
}

local function draw(street, sub, super, col)
	local m = peripheral.find "monitor"
	local w, h = m.getSize()
	m.setBackgroundColor(colors.black)
	m.setTextColor(colors.white)
	m.clear()
	m.setCursorPos(2, 1)
	m.write(super)
	bigfont.writeOn(m, 1, street, 2, 2)
	m.setCursorPos(2, 5)
	m.write(sub)
	if col then
		local c, p = colors[col], palette[col]
		if p then
			m.setPaletteColor(c, p)
		end
		m.setBackgroundColor(c)
		for y = 1, h do
			m.setCursorPos(w, y)
			m.write " "
		end
	end
end

local street = settings.get "ccss.street"
local super = settings.get "ccss.super" or ""
if not street then
	street = "Name Wanted"
	super = "Submit your suggestions to gollark."
end
local col = settings.get "ccss.color"

print("Sign for", street, "running.")

local sub = ""
while true do
	local ok, err = pcall(draw, street, sub, super, col)
	if not ok then printError(err) end
	local _, newsub = os.pullEvent "ccss_update"
	sub = newsub
end