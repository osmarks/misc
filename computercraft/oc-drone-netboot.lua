local net = component.proxy(component.list "internet"())
local eeprom = component.proxy(component.list "eeprom"())

local function fetch(url)
	local res, err = net.request(url)
	if not res then error(url .. " error: " .. err) end
	local out = {}
	while true do
		local chunk, err = res.read()
		if err then error(url .. " error: " .. err) end
		if chunk then table.insert(out, chunk)
		else return table.concat(out) end
	end
end

local eepromdata = eeprom.getData()
if eepromdata == "" then error "No URL loaded" end
local fn = assert(load(fetch(eepromdata)))
fn()