local ec = peripheral.find "ender_chest"
local ecinv = peripheral.find "minecraft:ender chest"

local f = fs.open("escan.log", "w")

local z = ...
if z then
    ec.setFrequency(tonumber(z, 16))
    return
end

for i = 0, 0xFFF do
    ec.setFrequency(i)
    local count = 0
    for _, s in pairs(ecinv.list()) do
        count = count + s.count
    end
    if count > 0 then
		local log = ("%s %s 0x%03x %d"):format(os.date "!%X", table.concat(ec.getFrequencyColors(), "/"), i, count)
        print(log)
		f.writeLine(log)
    end
	if i % 256 == 255 then
		f.flush()
	end
    os.queueEvent ""
	os.pullEvent ""
end

f.close()