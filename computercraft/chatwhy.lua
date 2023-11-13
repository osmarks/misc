local cb = peripheral.find "chat_box"
local receiver = settings.get "cc2chat.receiver" or "gollark"

local rawterm = term.native()

local queue = ""

local redirect = {}

for k, v in pairs(rawterm) do redirect[k] = v end

function redirect.write(text)
	queue = queue .. text
	rawterm.write(text)
end

function redirect.setCursorPos(x, y)
	local cx, cy = term.getCursorPos()
	local dx, dy = x - cx, y - cy
	if dx > 0 then
		queue = queue .. (" "):rep(dx)
	end
	if dy > 0 then
		queue = queue .. (" "):rep(dy)
	end
	rawterm.setCursorPos(x, y)
end

term.redirect(redirect)

local function evconvert()
	while true do
		local _, user, message = os.pullEvent "chat"
		local raw = false
		for x in message:gmatch "!(.*)" do message = x raw = true end
		if user == receiver or settings.get "cc2chat.insecure" then
			--[[for i = 1, #message do
				local char = message:sub(i, i)
				os.queueEvent("key", string.byte(char))
				os.queueEvent("char", char)
			end]]
			os.queueEvent("paste", message)
			if not raw then
				os.queueEvent("key", 28) -- enter
			end
		end
	end
end

local function sendbatch()
	while true do
		if #queue > 0 then
			cb.tell(receiver, queue, os.getComputerLabel():sub(1, 16))
			queue = ""
		end
		sleep(0.1)
	end
end

parallel.waitForAll(
	evconvert,
	sendbatch,
	function() shell.run "shell" end
)