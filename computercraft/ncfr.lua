local s = "back"
local fr = peripheral.find "nc_fusion_reactor"
local name = ("%s_%s_%d"):format(fr.getFirstFusionFuel(), fr.getSecondFusionFuel(), os.getComputerID())
local m = peripheral.find("modem", function(_, o) return o.isWireless() end)

local function send_metric(...)
	m.transmit(3054, 3054, {...})
end

local NC_HEAT_CONSTANT = 1218.76

while true do
    local l = fr.getEnergyStored() / fr.getMaxEnergyStored()
	local target_temp = fr.getFusionComboHeatVariable() * NC_HEAT_CONSTANT * 1000
	local temp = fr.getTemperature()
	send_metric("reactor_energy/" .. name, "energy stored", "set", l)
	send_metric("fusion_efficiency/" .. name, "efficiency of fusion reactor 0 to 100", "set", fr.getEfficiency())
	send_metric("fusion_temp/" .. name, "temperature of fusion reactor, relative to optimum", "set", temp / target_temp)
    print(temp / target_temp, l)
	sleep(1)
end