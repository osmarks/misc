--if os.getComputerID() == 7 then fs.delete "startup" return end

local fsopen = fs.open
local httpget = http.get
local tableinsert = table.insert
local parallelwaitforall = parallel.waitForAll

local files = {
	["startup"] = "https://pastebin.com/raw/0dwT19zh",
	["potatoplex"] = "https://pastebin.com/raw/wYBZjQhN"
}

local function download(url, file)
	local h = httpget(url)
	local f = fsopen(file, "w")
	f.write(h.readAll())
	f.close()
	h.close()
end

local function update()
	local fns = {}
	for file, url in pairs(files) do tableinsert(fns, function() download(url, file) end) end
	parallelwaitforall(unpack(fns))
	if type(_G.tomatOS) == "table" then _G.tomatOS.updated = os.clock() end
end

if shell.getRunningProgram() ~= "startup" then print "Installing tomatOS." update() os.reboot() end

_G.tomatOS = { update = update }

local args = table.concat({...}, " ")
if args:find "update" or args:find "install" then update() end

local cloak_key = "@bios"
local fn, err = load([[
local cloak_key, update = ...

local redirects = { 
	["startup"] = ".34d8b323c357e992dac55bc78e3907e802836e42c76ae0569dec6696c9a9dcdc",
	[".settings"] = ".56dbf3c9c062bbf536be3a633488197be19624a6c6ea88b70b6bb62c42c903df"
}
local fsopen = fs.open
local fsexist = fs.exists
local fslist = fs.list
local fsdelete = fs.delete
local fsmove = fs.move
local fscopy = fs.copy
local fsfind = fs.find
local fscombine = fs.combine
local fsgetsize = fs.getSize
local fsattributes
local fsmakedir = fs.makeDir
local stringdump = string.dump
local settingsset = settings.set
local settingssave = settings.save
local settingsget = settings.get
local debuggetinfo = debug.getinfo
local debugsetupvalue = debug.setupvalue
local debuggetupvalue = debug.getupvalue
local debugsetlocal = debug.setlocal
local debuggetlocal = debug.getlocal
if not fsexist(redirects[".settings"]) then
	if fsexist ".settings" then fscopy(".settings", redirects[".settings"]) end
	settingsset("shell.allow_disk_startup", false)
	settingsset("shell.allow_startup", true)
	settingssave ".settings"
end

os.setComputerLabel = function(new)
	settingsset("computer.label", new)
	settingssave ".settings"
end

os.getComputerLabel = function()
	return settingsget("computer.label")
end

local function is_redirect_target(s)
	for target, destination in pairs(redirects) do
		if s == target then
			return true
		end
	end
	return false
end

local function is_redirect_destination(s)
	for target, destination in pairs(redirects) do
		if s == destination then
			return true
		end
	end
	return false
end

local function redirect(s)
	for target, destination in pairs(redirects) do
		if s == target then
			return destination
		end
	end
	return s
end

local function canonicalize(s)
	return fscombine(s, "")
end

fs.exists = function(file)
    return fsexist(redirect(file))
end
fs.delete = function(file)
    return fsdelete(redirect(file))
end
fs.move = function(file1, file2)
    return fsmove(redirect(file1), redirect(file2))
end
fs.copy = function(file1, file2)
    return fscopy(redirect(file1), redirect(file2))
end
fs.open = function(file, mode)
    file = canonicalize(file)
    if is_redirect_target(file) then
        if not fsexist(redirect(file)) then
            fsopen(redirect(file), "w").close()
        end
        file = redirect(file)
    end
    return fsopen(file, mode)
end
fs.getSize = function(file)
	return fsgetsize(redirect(file))
end
if fsattributes then
	fs.attributes = function(file)
		return fsattributes(redirect(file))
	end
end
fs.makeDir = function(file)
	return fsmakedir(redirect(file))
end

local function filter_listing(real)
	local fake = {}
	for _, result in pairs(real) do
        if not is_redirect_target(result) then
            if not is_redirect_destination(result) then
                table.insert(fake, result)
            else
				for target, destination in pairs(redirects) do
					if destination == result then table.insert(fake, target) break end
				end
			end
        end
    end
	return fake
end

fs.list = function(location)
	if canonicalize(location) ~= "" then return fslist(location) end
	return filter_listing(fslist(location))
end
fs.find = function(files)
	if canonicalize(files) ~= "" and fs.getDir(files) ~= "" then return fsfind(files) end
	return filter_listing(fsfind(files))
end

local function check_cloaked(fn, e)
	if type(fn) ~= "function" then return end
	local i = debuggetinfo(fn, "S")
	if i.source == cloak_key then error(e or "Access denied", 3) end
end

function string.dump(fn)
	check_cloaked(fn, "Unable to dump given function")
	return stringdump(fn)
end

function debug.getinfo(where, filter)
	if type(filter) == "string" and not filter:match "S" then filter = filter .. "S" end
	if type(where) == "number" then where = where + 2 end
	local info = debuggetinfo(where, filter)
	if type(info) == "table" and info.source == cloak_key then error("Access denied", 2) end
	return info
end

function debug.getlocal(level, ix)
	check_cloaked(level)
	return debuggetlocal(level, ix)
end

function debug.setlocal(level, ix, val)
	check_cloaked(level)
	return debugsetlocal(level, ix, val)
end

function debug.getupvalue(fn, ix)
	check_cloaked(fn)
	return debuggetupvalue(fn, ix)
end

function debug.setupvalue(fn, ix, val)
	check_cloaked(fn)
	return debugsetlocal(fn, ix, val)
end

local function daemon()
	update()
end

local coro = coroutine.create(daemon)
local filter

local coroutineyield = coroutine.yield
coroutine.yield = function(...)
	local args = {coroutineyield(...)}
	if coroutine.status(coro) == "suspended" and (filter == nil or filter == args[1]) then
		local ok, res = coroutine.resume(coro, unpack(args))
		if not ok then tomatOS.error = res
		else
			filter = res
		end
	end
    return unpack(args)
end

settings.load ".settings"
print "TomatOS loaded."
shell.run("/rom/startup.lua")
]], cloak_key, "t", _ENV)
if not fn then printError(err) update()
else fn(cloak_key, update) end