local m = peripheral.find "modem"
local o = peripheral.find "monitor"

o.setTextScale(0.5)
 
local w, h = o.getSize()
local command_window = window.create(o, 1, h, w, 1)
local outputs_window = window.create(o, 1, 1, w, h - 1)

local function exec_in_window(w, f)
	local x, y = o.getCursorPos()
	local last = term.redirect(w)
	f()
	term.redirect(last)
	w.redraw()
	o.setCursorPos(x, y)
end
 
local function print_output(txt, color)
	exec_in_window(outputs_window, function()
		term.setTextColor(color or colors.white)
		print(txt)
	end)
end

local function splitspace(str)
    local tokens = {}
    for token in string.gmatch(str, "[^%s]+") do
        table.insert(tokens, token)
    end
    return tokens
end

local function controls()
	term.redirect(command_window)
	term.setBackgroundColor(colors.white)
	term.setTextColor(colors.black)
	term.clear()
	local hist = {}
	while true do
		write "> "
		local msg = read(nil, hist)
		table.insert(hist, msg)
		local tokens = splitspace(msg)
		local command = table.remove(tokens, 1)
		if command == "open" then
			local chan = tonumber(tokens[1])
			m.open(chan)
			print_output(("Opened %d"):format(chan), colors.gray)
		elseif command == "close" then
			local chan = tonumber(tokens[1])
			m.close(chan)
			print_output(("Closed %d"):format(chan), colors.gray)
		else
			print_output("Command invalid", colors.gray)
		end
	end
end

local function compact_serialize(x)
    local t = type(x)
    if t == "number" then
        return tostring(x)
    elseif t == "string" then
        return textutils.serialise(x)
    elseif t == "table" then
        local out = "{ "
        for k, v in pairs(x) do
            out = out .. string.format("[%s]=%s, ", compact_serialize(k), compact_serialize(v))
        end
        return out .. "}"
    elseif t == "boolean" then
        return tostring(x)
    else
        error("Unsupported type " .. t)
    end
end
 
local function safe_serialize(m)
    local ok, res = pcall(compact_serialize, m)
    if ok then return res
    else return ("[UNSERIALIZABLE %s: %s]"):format(tostring(m), res) end
end

local function tostring_with_default(x)
    if not x then return "[UNKNOWN]"
    else return tostring(x) end
end
 
local function receive()
	while true do
		local _, _, channel, reply_channel, message, distance = os.pullEvent "modem_message"
		print_output(("%d \16 %d | %s"):format(channel, reply_channel, tostring_with_default(distance)))
		print_output(safe_serialize(message), colors.lightGray)
	end
end
 
parallel.waitForAny(controls, receive)