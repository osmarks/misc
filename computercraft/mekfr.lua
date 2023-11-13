local modem = {peripheral.find("modem", function(_, o) return o.isWireless() end)}
local gas_tanks = {peripheral.find "Ultimate Gas Tank"}
local name = os.getComputerLabel()
local function send(...)
    for _, modem in pairs(modem) do
        modem.transmit(48869, 48869, {...})
    end
end

local fuel_depletion_latch = false
local reactor = peripheral.find "Reactor Logic Adapter"

while true do
    if type(reactor.getEnergy()) == "string" then
        print("anomalous stringment", reactor.getEnergy())
    else
        local energy = reactor.getEnergy() / reactor.getMaxEnergy()
        send("mek_reactor_energy/" .. name, "fraction of fusion reactor's energy buffer which is full", energy)
        send("mek_reactor_plastemp/" .. name, "reported plasma temperature", reactor.getPlasmaHeat())
        send("mek_reactor_casetemp/" .. name, "reported case temperature", reactor.getCaseHeat())
        local total_stored, total_max = 0, 0
        for _, tank in pairs(gas_tanks) do
            total_max = total_max + tank.getMaxGas()
            total_stored = total_stored + tank.getStoredGas()
        end
        local tritium = total_stored / total_max
        send("mek_reactor_tritium/" .. name, "fraction of tritium buffer filled", tritium)
        if not fuel_depletion_latch and tritium < 0.5 then
            print "WARNING: Contingency Beta-4 initiated."
            fuel_depletion_latch = true
        end
        local injection_rate = math.floor(3 + 17 * (math.min(1, 1.1 - energy) / 0.9)) * 2
        print(injection_rate)
        if fuel_depletion_latch then
            injection_rate = 6
        end
        reactor.setInjectionRate(fuel_depletion_latch and 6 or injection_rate)
        send("mek_reactor_injectionrate/" .. name, "fuel injection rate (set by controller)", injection_rate)
        send("mek_reactor_powerout_rft/" .. name, "power output (RF/t)", reactor.getProducing() * 0.4)
    end
    sleep(1)
end