-- converts a value between 0 and 127 to bits, least significant bits first
local function to_bits(charbyte)
	if charbyte > 127 then error "invalid character" end
	local out = {}
	for i = 0, 6 do 
		local bitmask = bit.blshift(1, i)
		local bit = bit.brshift(bit.band(bitmask, charbyte), i)
		table.insert(out, bit)
	end
	return out
end

local function from_bits(bit_table)
	local int = 0
	for i = 0, 6 do
		local index = i + 1 -- Lua...
		int = bit.bor(int, bit.blshift(bit_table[index], i))
	end
	return int
end

local rx_side = settings.get "rx_side" or "right"
local tx_side = settings.get "tx_side" or "left"

local function send(str)
	str = "\127" .. str
	for i = 1, #str do
		local byte = str:byte(i)
		for _, bit in ipairs(to_bits(byte)) do
			rs.setOutput(tx_side, bit == 1)
			sleep(0.1)
		end
	end
	rs.setOutput(tx_side, false)
end

local function receive(char_callback)
	local str = ""
	repeat
		os.pullEvent "redstone"
	until rs.getInput(rx_side)
	while true do
		local bits = {}
		for i = 0, 6 do
			if rs.getInput(rx_side) then 
				table.insert(bits, 1)
			else
				table.insert(bits, 0)
			end
			sleep(0.1)
		end
		local char = string.char(from_bits(bits))
		if char == "\0" then break end
		if char ~= "\127" and char_callback then char_callback(char) end
		str = str .. char
	end
	return str:sub(2)
end

local w, h = term.getSize()
local send_window = window.create(term.current(), 1, h, w, 1)
local message_window = window.create(term.current(), 1, 1, w, h - 1)

local function exec_in_window(w, f)
    local x, y = term.getCursorPos()
    local last = term.redirect(w)
    f()
    term.redirect(last)
    w.redraw()
    term.setCursorPos(x, y)
end
 
local function write_char(txt)
    exec_in_window(message_window, function()
        write(txt)
    end)
end

local function sender()
    term.redirect(send_window)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.white)
    term.clear()
    while true do
        local msg = read()
		send(msg)
    end
end

local function receiver()
	while true do
		receive(write_char)
		write_char "\n"
	end
end

parallel.waitForAll(sender, receiver)