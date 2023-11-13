-- TODO: actually make graph?

local monitor = peripheral.find "monitor"
local storage = peripheral.find(settings.get "storage_type" or "draconic_rf_storage")
local capacity = (storage.getMaxEnergyStored or storage.getEnergyCapacity)()
local delay = 0.1
local ticks_delay = 0.1 / 0.05

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
		monitor.write(val[1] .. ":" .. (" "):rep(longest_label - #val[1] + 2) .. val[2])
		i = i + 1
	end
end

local past_RF_per_tick = {}
local history_length = 1200 / ticks_delay
local function display_stats()
	local previous
	while true do
		local energy = read_energy()
		if previous then
			local diff = energy - previous
			local RF_per_tick = diff / ticks_delay
			table.insert(past_RF_per_tick, RF_per_tick)
			if #past_RF_per_tick > history_length then table.remove(past_RF_per_tick, 1) end
			local total = 0
			for _, h in pairs(past_RF_per_tick) do total = total + h end
			local average = total / #past_RF_per_tick
			
			display {
				{ "Time", ("%s.%03d"):format(os.date "!%X", os.epoch "utc" % 1000) },
				{ "Stored", SI_prefix(energy, "RF") },
				{ "Capacity", SI_prefix(capacity, "RF") },
				{ "% filled", ("%.4f%%"):format(energy / capacity * 100) },
				{ "Inst I/O", SI_prefix(RF_per_tick, "RF/t") },
				{ "60s I/O" , SI_prefix(average, "RF/t") },
			}
		end
		previous = energy
		sleep(delay)
	end
end

display_stats()