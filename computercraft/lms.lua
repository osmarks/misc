local function update()
	local h = http.get "https://pastebin.com/raw/L0ZKLBRG"
	local f = fs.open(shell.getRunningProgram(), "w")
	f.write(h.readAll())
	f.close()
	h.close()
end

if ... == "update" then update() end

local m = peripheral.find "modem"
local s = peripheral.find "speaker"

local chan = 3636
print "Welcome to the Lightweight Messaging System (developed by GTech Potatronics)"

m.open(chan)

local username = settings.get "lms.username"
if username == nil then
	write "Username: "
	username = read()
end
 
local w, h = term.getSize()
local send_window = window.create(term.current(), 1, h, w, 1)
local message_window = window.create(term.current(), 1, 1, w, h - 1)
 
local function notification_sound()
	if s then
		for i = 4, 12, 4 do
			s.playNote("flute", 3, i)
			sleep(0.2)
		end
	end
end

local function exec_in_window(w, f)
	local x, y = term.getCursorPos()
	local last = term.redirect(w)
	f()
	term.redirect(last)
	w.redraw()
	term.setCursorPos(x, y)
end
 
local function print_message(txt)
	exec_in_window(message_window, function()
		print(txt)
	end)
end

local function trim(s)
   return s:match( "^%s*(.-)%s*$" )
end
 
local banned_text = {
    "yeet",
    "ecs dee",
	"dab",
}

if debug and debug.getmetatable then
    _G.getmetatable = debug.getmetatable
end

local function to_case_insensitive(text)
	return text:gsub("[a-zA-Z]", function(char) return ("[%s%s]"):format(char:lower(), char:upper()) end)
end

local function filter(text)
    local out = text
    for _, b in pairs(banned_text) do
        out = out:gsub(to_case_insensitive(b), "")
    end
    return out
end
 
local function strip_extraneous_spacing(text)
    return text:gsub("%s+", " ")
end
 
local function collapse_e_sequences(text)
    return text:gsub("ee+", "ee")
end
 
local function preproc(text)
    return trim(filter(strip_extraneous_spacing(collapse_e_sequences(text:sub(1, 128)))))
end

local function add_message(msg, usr)
	local msg, usr = preproc(msg), preproc(usr)
	if msg == "" or usr == "" then return end
	print_message(usr .. ": " .. msg)
end
 
local function send()
	term.redirect(send_window)
	term.setBackgroundColor(colors.white)
	term.setTextColor(colors.black)
	term.clear()
	local hist = {}
	while true do
		local msg = read(nil, hist)
		if msg == "!!exit" then return
		elseif msg == "!!update" then update() print_message "Updated. Please restart the program."
		else
			table.insert(hist, msg)
			if preproc(msg) == "" then
				print_message "Your message is considered spam."
			else
				add_message(msg, username)
				m.transmit(chan, chan, { message = msg, username = username })
			end
		end
	end
end
 
local function recv()
	while true do
		local _, _, channel, _, message = os.pullEvent "modem_message"
		if channel == chan and type(message) == "table" and message.message and message.username then
			notification_sound()
			add_message(message.message, message.username)
		end
	end
end
 
m.transmit(chan, chan, { username = username, message = "Connected." })
parallel.waitForAny(send, recv)