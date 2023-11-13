if os.getComputerLabel() == nil then os.setComputerLabel(("Sandbox-%d"):format(os.getComputerID())) end

local function update()
	local h = http.get "https://pastebin.com/raw/SJHZqiGY"
	local f = fs.open("startup", "w")
	f.write(h.readAll())
	h.close()
	f.close()
end

local function run()
	term.setPaletteColor(colors.white, 0xffffff)
	term.setPaletteColor(colors.black, 0x000000)
	term.clear()
	term.setCursorPos(1, 1)

	local h = http.get "https://pastebin.com/raw/Frv3xkB9"
	local fn, err = load(h.readAll(), "@yafss")
	h.close()
	if not fn then error(err) end
	local yafss = fn()

	local startup_message = [[Welcome to this GTech-sponsored computer.
This shell is running in a sandbox. Any changes you make outside of "/persistent" will NOT be saved.
Please save any important data or work elsewhere.]]

	local FS_overlay = {
		["startup"] = ([[
print(%q)
shell.setPath(shell.path() .. ":/persistent")
]]):format(startup_message),
		["/rom/programs/update.lua"] = [[os.update()
print "Updated sandbox"
os.full_reboot()]]
	}

	local running = true
	local function reinit_sandbox() running = false end

	local API_overrides = {
		["~expect"] = _G["~expect"],
		os = {
			shutdown = reinit_sandbox,
			reboot = reinit_sandbox,
			setComputerLabel = function() error "Nope." end,
			update = update,
			full_reboot = os.reboot
		}
	}

	if not fs.exists "boxdata" then fs.makeDir "boxdata" end
	if not fs.exists "boxdata/persistent" then fs.makeDir "boxdata/persistent" end
	for _, file in pairs(fs.list "boxdata") do
		if file ~= "persistent" then fs.delete(fs.combine("boxdata", file)) end
	end
	
	parallel.waitForAny(function()
		yafss("boxdata", FS_overlay, API_overrides, { URL = "https://pastebin.com/raw/hvy03JuM" })
	end,
	function()
		while running do coroutine.yield() end
	end)
end

local ok, err = pcall(update)
if not ok then printError("Update error: " .. err) end

local function full_screen_message(msg)
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.clear()
	term.setCursorPos(1, 1)
	print(msg)
end

while true do
	local ok, err = pcall(run)
	if not ok then
		full_screen_message("Sandbox crashed. Press any key to restart. Error: \n" .. err)
	else
		full_screen_message "Sandbox exited. Press any key to restart."
	end
	coroutine.yield "key"
end