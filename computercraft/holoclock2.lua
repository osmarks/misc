peripheral.find("hologram", function(_, holo) holo.clear() end)
local hologram = peripheral.find("hologram")

local date
local config = {
	dateColor = 0xFFFFFF,
	holoScale = 3
}

local symbols = {
	["0"] = {
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 0 },
		{ 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
	},
	["1"] = {
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 0 },
	},
	["2"] = {
		{ 0, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 0 },
		{ 1, 0, 0, 0, 0 },
		{ 0, 1, 1, 1, 0 },
	},
	["3"] = {
		{ 0, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
	},
	["4"] = {
		{ 0, 0, 0, 0, 0 },
		{ 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 0 },
	},
	["5"] = {
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 0 },
		{ 1, 0, 0, 0, 0 },
		{ 0, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
	},
	["6"] = {
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 0 },
		{ 1, 0, 0, 0, 0 },
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
	},
	["7"] = {
		{ 0, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 0 },
	},
	["8"] = {
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
	},
	["9"] = {
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
	},
	[":"] = {
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 1, 0, 0 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 1, 0, 0 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0 },
	},
	["."] = {
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 1, 0, 0 },
	}
}

local function drawSymbolOnProjector(plane, x, y, symbol)
	local xPos = x
	for j = 1, #symbols[symbol] do
		for i = 1, #symbols[symbol][j] do
			if symbols[symbol][j][i] == 1 then
				--hologram.set(xPos, y, z, 1)
                plane[xPos * 32 + y] = 1
			else
				--hologram.set(xPos, y, z, 0)
                plane[xPos * 32 + y] = nil
			end
			xPos = xPos + 1
		end
		xPos = x
		y = y - 1
	end
end

local function drawText(plane, x, y, text)
	for i = 1, string.len(text) do
		local symbol = string.sub(text, i, i)
		drawSymbolOnProjector(plane, i * 6 + 4, 16, symbol)
	end
end

local function centerText(plane, text)
	local textWidth = string.len(text) * 6
	local holoWidth = 48
	drawText(plane, math.floor(textWidth - (holoWidth / 2)), 1, text)
end

hologram.clear()
hologram.setScale(3)
hologram.setTranslation(0, 0, 0)
hologram.setPaletteColor(1, config.dateColor)
hologram.setScale(config.holoScale)
hologram.setRotationSpeed(0, 0, 0, 0)
hologram.setRotation(90, 0, 1, 0)

while true do
	local time = os.time()
	local hour = math.floor(time)
	local min = math.floor((time - hour) * 60)
    local plane = {}
    centerText(plane, ("%02d:%02d"):format(hour, min))
    local data = {}
    table.insert(data, ("\0"):rep(48 * 24 * 32))
    for z = 1, 48 do
        for y = 1, 32 do
            table.insert(data, plane[z * 32 + y] and "\1" or "\0")
            --table.insert(data, "\1")
        end
    end
    table.insert(data, ("\0"):rep(48 * 23 * 32))
    hologram.setRaw(table.concat(data))
	sleep(0.5)
end