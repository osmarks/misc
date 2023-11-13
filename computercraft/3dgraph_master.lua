	local m = peripheral.find "modem"
local CHAN = 7101
m.open(CHAN)

local function send(ms) m.transmit(CHAN, CHAN, ms) end

local function receive()
	while true do
		local _, _, c, rc, ms = os.pullEvent "modem_message"
		if type(ms) == "table" then
			return ms
		end
	end
end

local nodes = {}

parallel.waitForAny(function()
	send { "ping" }
	while true do
		local ty, id = unpack(receive())
		if ty == "pong" then
			print(id, "detected")
			table.insert(nodes, id)
		end
	end
end, function() sleep(0.5) end)

local d_min = {202, 65, 231}
local d_max = {202 + 63, 65 + 63, 231 + 63}
local block = "botania:managlass"

local eqn = ...
local fn, err = load(("local x, y, z = ...; return %s"):format(eqn), "=eqn", "t", math)
if not fn then error("syntax error: " .. err, 0) end

print(#nodes, "nodes are available")

local x_range = d_max[1] - d_min[1] + 1
local split = math.floor(x_range / #nodes)

local commands = {}
local x_acc = d_min[1]
for k, v in ipairs(nodes) do
	local x_size = split
	if k == #nodes then
		x_size = x_range - ((#nodes - 1) * split)
	end
	local t = x_acc
	x_acc = x_acc + x_size
	send {"plot", {
		x_min = d_min[1], x_max = d_max[1],
		y_min = d_min[2], y_max = d_max[2],
		z_min = d_min[3], z_max = d_max[3],
		x_mod = #nodes, x_mod_eq = k - 1,
		block = block,
		equation = eqn,
		id = v,
		f_min = d_min,
		f_max = d_max
	}}
end

local responses = {}
while #responses ~= #nodes do
	local m = receive()
	if m[1] == "response" then
		table.insert(responses, m[2])
		print("response from", m[2].id, m[2].response)
	end
end

print "Plot plotted."