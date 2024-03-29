local modem = {peripheral.find("modem", function(_, o) return o.isWireless() end)}
local name = os.getComputerLabel()
local function send(...)
    for _, modem in pairs(modem) do
        modem.transmit(48869, 48869, {...})
    end
end

local reactor
repeat reactor = peripheral.find "fissionReactorLogicAdapter" print "checking reactor..." sleep(0.5) until reactor and reactor.getCoolant
local max_burn = settings.get "max_burn"
local turbine = peripheral.find "turbineValve"
local min_burn = 0.1
local scram_latch = false

while true do
    local coolant = reactor.getCoolant().amount
    send("mek_reactor_coolant_mb", "coolant in reactor tank", coolant)
    local coolant_capacity = reactor.getCoolantCapacity()
    send("mek_reactor_coolant_capacity_mb", "coolant in reactor max capacity", coolant_capacity)
    local waste = reactor.getWaste().amount
    local waste_capacity = reactor.getWasteCapacity()
    send("mek_reactor_waste_mb", "waste in reactor tank", waste)
    send("mek_reactor_waste_capacity_mb", "waste in reactor max capacity", waste_capacity)
    local fuel = reactor.getFuel().amount
    local fuel_capacity = reactor.getFuelCapacity()
    send("mek_reactor_fuel_mb", "fuel in reactor tank", fuel)
    send("mek_reactor_fuel_capacity_mb", "fuel in reactor max capacity", fuel_capacity)
    local temperature = reactor.getTemperature()
    send("mek_reactor_temperature_k", "temperature of reactor", temperature)
    send("mek_reactor_burn_rate_mb_t", "fuel burn rate of reactor", reactor.getActualBurnRate())
    -- turbine status
    local turbine_percent =  turbine.getEnergy() / turbine.getEnergyNeeded()
    send("mc_stored_rf/reactorturbine", "energy stored in RF", turbine.getEnergy())
    send("mc_capacity_rf/reactorturbine" , "maximum capacity in RF", turbine.getEnergyNeeded())
    if coolant < coolant_capacity / 2 or waste > waste_capacity / 2 or temperature > 500 then
        print "SCRAM"
        reactor.scram()
        scram_latch = true
    end

    if not scram_latch then
        reactor.setBurnRate(math.max(math.min((max_burn - min_burn) * (1 - turbine_percent) + min_burn, max_burn), min_burn))
        if not reactor.getStatus() then reactor.activate() end
    end
    
    sleep(1)
end
