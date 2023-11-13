peripheral.find("hologram", function(_, holo) holo.clear() end)
local hologram = peripheral.find("hologram")

local colors = {
	0xFF0000,
	0xFFFF00,
	0x00FF00
}

hologram.clear()
hologram.setScale(1/3)
hologram.setTranslation(0, 0, 0)
for i, color in pairs(colors) do
	hologram.setPaletteColor(i, color)
end
hologram.setRotationSpeed(0, 0, 0, 0)
hologram.setRotation(90, 0, 1, 0)

local line = {}

local function push_value(x)
	table.insert(line, x)
	if #line > 48 then
		table.remove(line, 1)
	end
end

push_value(16)

while true do
    local data = {}
    table.insert(data, ("\0"):rep(48 * 24 * 32))
    for z = 1, 48 do
		local height = line[z]
		if height then
			table.insert(data, ("\0"):rep(height - 1))
			if height > 20 then
				table.insert(data, "\1")
			elseif height < 12 then
				table.insert(data, "\3")
			else
				table.insert(data, "\2")
			end
			table.insert(data, ("\0"):rep(32 - height))
		end
    end
    table.insert(data, ("\0"):rep(48 * 23 * 32))
    hologram.setRaw(table.concat(data))
	local nxt = math.random(-1, 1) + line[#line]
	push_value(math.max(math.min(32, nxt), 1))
	sleep(0.5)
end