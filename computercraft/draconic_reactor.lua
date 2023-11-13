-- TODO: actually make graph?

local monitor = peripheral.find "monitor"
local storage = peripheral.find "draconic_rf_storage"
local re_in_gate = peripheral.wrap "flux_gate_3"
local re_out_gate = peripheral.wrap "flux_gate_6"
local dist_gate = peripheral.wrap "flux_gate_7"
local reactor = peripheral.find "draconic_reactor"
local capacity = (storage.getMaxEnergyStored or storage.getEnergyCapacity)()
local delay = 0.1
local ticks_delay = 0.1 / 0.05
local threshold = 1e9
local tx_out = 1e8
local target_field = 0.4
local target_saturation = 0.3

local function read_energy()
	return storage.getEnergyStored()
end

monitor.setTextScale(1)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
local data = {}

local prefixes = {"", "k", "M", "G", "T", "P", "E", "Z", "Y", "R", "Q"}
local function SI_prefix(value, unit)
    local i = 1
    local x = value
    while x > 1000 or x < -1000 do
        x = x / 1000
        i = i + 1
    end
    return ("%.3f%s%s"):format(x, prefixes[i], unit)
end

local function display(data)
	monitor.clear()
	local longest_label = 0
	for _, val in pairs(data) do
		if #val[1] > longest_label then longest_label = #val[1] end
	end
	local i = 1
	for _, val in pairs(data) do
		monitor.setCursorPos(1, i)
		monitor.setTextColor(val[3] or colors.white)
		monitor.write(val[1] .. ":" .. (" "):rep(longest_label - #val[1] + 2) .. val[2])
		i = i + 1
	end
end

re_in_gate.setOverrideEnabled(true)
re_out_gate.setOverrideEnabled(true)
dist_gate.setOverrideEnabled(true)
local past_RF_per_tick = {}
local history_length = 1200 / ticks_delay
local function display_stats()
	local previous
	while true do
		local energy = read_energy()
		local reactor_state = reactor.getReactorInfo()
		if previous then
			local diff = energy - previous
			local RF_per_tick = diff / ticks_delay
			table.insert(past_RF_per_tick, RF_per_tick)
			if #past_RF_per_tick > history_length then table.remove(past_RF_per_tick, 1) end
			local total = 0
			for _, h in pairs(past_RF_per_tick) do total = total + h end
			local average = total / #past_RF_per_tick
			
			local status = "OK"
			local status_col = colors.green
			if energy < threshold then
				status = "Storage Low"
				status_col = colors.yellow
			end
			if reactor_state.status == "warming_up" then
				status = "Reactor Precharge"
				status_col = colors.blue
			elseif reactor_state.status ~= "cold" and (reactor_state.status == "stopping" or reactor_state.temperature > 8000 or reactor_state.fieldStrength / reactor_state.maxFieldStrength < 0.2 or reactor_state.fuelConversion / reactor_state.maxFuelConversion > 0.83) then
				status = "Emergency Shutdown"
				status_col = colors.orange
				reactor.stopReactor()
				re_out_gate.setFlowOverride(0)
				re_in_gate.setFlowOverride(1e7)
			elseif reactor_state.status == "cold" then
				status = "Reactor Off"
				status_col = colors.pink
			end
			if reactor_state.temperature > 9000 then
				status = "Imminent Death"
				status_col = colors.red
			end
			if status == "OK" or status == "Storage Low" then
				re_in_gate.setFlowOverride(reactor_state.fieldDrainRate / (1 - target_field))
				local base_max_rft = reactor_state.maxEnergySaturation / 1000 * 1.5
				local conv_level = (reactor_state.fuelConversion / reactor_state.maxFuelConversion) * 1.3 - 0.3
				local max_rft = base_max_rft * (1 + conv_level * 2)
				re_out_gate.setFlowOverride(math.min(max_rft * 0.7, 5 * reactor_state.fieldDrainRate / (1 - target_field)))
			end
			dist_gate.setFlowOverride(energy > threshold and tx_out or 0)

			display {
				{ "Status", status, status_col },
				{ "Time", os.date "!%X" },
				{ "Stored", SI_prefix(energy, "RF"), energy < threshold and colors.yellow },
				{ "Capacity", SI_prefix(capacity, "RF") },
				{ "% filled", ("%.4f%%"):format(energy / capacity * 100) },
				{ "Inst I/O", SI_prefix(RF_per_tick, "RF/t") },
				{ "60s I/O" , SI_prefix(average, "RF/t") },
				{ "Fuel Consumed", ("%.4f%%"):format(100 * reactor_state.fuelConversion / reactor_state.maxFuelConversion) },
				{ "Saturation", ("%.4f%%"):format(100 * reactor_state.energySaturation / reactor_state.maxEnergySaturation) },
				{ "Field Strength", ("%.4f%%"):format(100 * reactor_state.fieldStrength / reactor_state.maxFieldStrength) },
				{ "Field Input", SI_prefix(re_in_gate.getFlow(), "RF/t") },
				{ "Generation Rate", SI_prefix(reactor_state.generationRate, "RF/t") },
				{ "Temperature", reactor_state.temperature }
			}
		end
		previous = energy
		sleep(delay)
	end
end

display_stats()