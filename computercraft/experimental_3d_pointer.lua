local dynmap = settings.get "tracker.map" or "https://dynmap.switchcraft.pw/"
local API = dynmap .. "up/world/world/"
local mon = peripheral.find "monitor"
if mon then mon.setTextScale(0.5) term.redirect(mon) end

local function fetch(url)
	local h = http.get(url)
	local o = h.readAll()
	h.close()
	return o
end

local target = ...
local operator = "gollark"
local canvas3 = peripheral.call("back", "canvas3d").create()
setmetatable(canvas3, {
	__gc = function() canvas3.clear() end
})
--local box = canvas3.addBox(0, 0, 0)
local line = canvas3.addLine({0, 0, 0}, {0, 0, 0})
line.setScale(4)

parallel.waitForAll(function()
while true do
	local raw = fetch(API .. os.epoch "utc")
	local data = textutils.unserialiseJSON(raw)
	local players = data.players
	local op
	local tplayer
	for _, player in pairs(players) do
		if player.name:match(target) then tplayer = player end
		if player.name == operator then op = player end
	end
	if tplayer then
		local tvec = vector.new(tplayer.x, tplayer.y, tplayer.z)
		local ovec = vector.new(op.x, op.y, op.z)
		local dirvec = (tvec - ovec):normalize() * 10
		print(tostring(dirvec))
		line.setPoint(2, dirvec.x, dirvec.y, dirvec.z)
	end
	sleep(1)
end end, function() while true do canvas3.recenter() sleep(0.1) end end)