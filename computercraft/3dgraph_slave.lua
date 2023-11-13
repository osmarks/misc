local m = peripheral.find "modem"
local CHAN = 7101
m.open(CHAN)

local ephem_ID = math.random(0, 0xFFFFFFF)

local function receive()
	while true do
		local _, _, c, rc, ms = os.pullEvent "modem_message"
		if type(ms) == "table" then
			return ms
		end
	end
end

local function send(ms) m.transmit(CHAN, CHAN, ms) end

local raw_exec_async, pull_event = commands.execAsync, os.pullEvent

local tasks = {}
local tasks_debug = {}
local tasks_count = 0
local tasks_limit = 1000
local half_tasks_limit = tasks_limit / 2
local function exec_async(name, ...)
    if tasks_count >= tasks_limit then
		print "task limit reached, blocking"
        while tasks_count >= half_tasks_limit do
            pull_event "task_complete"
        end
		print "blocking complete"
    end
    local id = raw_exec_async(table.concat({name, ...}, " "))
    tasks_count = tasks_count + 1
    tasks[id] = true
    tasks_debug[id] = {name, ...}
end

local function fill(ax, ay, az, bx, by, bz, block)
	exec_async("fill", ax, ay, az, bx, by, bz, block, 0, "replace")
end

local env = {}
local function add(x) for k, v in pairs(x) do env[k] = v end end
add(math)
add(bit)
add(bit32)
env[vector] = vector

local function plot(args)
	print "plotting"
	parallel.waitForAll(function()
		local ax, ay, az = unpack(args.f_min)
		local bx, by, bz = unpack(args.f_max)
		local rx, ry, rz = (bx-ax), (by-ay), (bz-az)
		local fn = load(("local x, y, z = ...; return %s"):format(args.equation), "=eqn", "t", math)

		--[[print "Clearing"
		for x = args.x_min, args.x_max do
			
		end
		print "Cleared plot area"]]

		for x = args.x_min, args.x_max do
			local go = true
			if args.x_mod and args.x_mod_eq then
				if x % args.x_mod ~= args.x_mod_eq then
					go = false
				end
			end
			if go then
				-- clear thing
				fill(x, args.y_min, args.z_min, x, args.y_max, args.z_max, "air")
				for y = args.y_min, args.y_max do
					local pz = nil
					for z = args.z_min, args.z_max do
						local sx, sy, sz = (((x-ax)/rx)*2)-1, (((y-ay)/ry)*2)-1, (((z-az)/rz)*2)-1
						--print(sx, sy, sz)
						local place_here = fn(sx, sy, sz)
						if place_here and not pz then pz = z
						elseif pz and not place_here then
							fill(x, y, pz, x, y, z - 1, args.block)
							--print(x, y, pz, x, y, z - 1, args.block)
							pz = nil
						end
					end
					if pz then
						fill(x, y, pz, x, y, args.z_max, args.block)
						--print(x, y, pz, x, y, args.z_max, args.block)
					end
				end
			end
		end
	end, function()
		while true do
			local event, id, success, result, output = pull_event "task_complete"
			if tasks[id] then
				tasks_count = tasks_count - 1
				tasks[id] = nil
				if not success then
					error("thing failed: " .. table.concat(output, " "))
				elseif not result and output[1] ~= "No blocks filled" then
					printError(table.concat(output, " "))
					_G.debug_task = tasks_debug[id]
				end
				tasks_debug[id] = nil
			end
			if tasks_count == 0 then return end
		end
	end)

	return "done"
end

while true do
	local ty, arg = unpack(receive())
	if ty == "ping" then send { "pong", ephem_ID }
	elseif ty == "plot" and arg.id == ephem_ID then
		print("plot command received, running", arg.x_min, arg.x_max)
		local ok, err = pcall(plot, arg)
		print(err)
		send { "response", { id = ephem_ID, response = err } }
	end
end