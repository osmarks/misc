CHANNEL_GPS = 65534
CHANNEL_SNMP = 999

local function trilaterate(A, B, C)
    local a2b = B.pos - A.pos
    local a2c = C.pos - A.pos

    if math.abs(a2b:normalize():dot(a2c:normalize())) > 0.999 then
        return nil
    end

    local d = a2b:length()
    local ex = a2b:normalize()
    local i = ex:dot(a2c)
    local ey = (a2c - ex * i):normalize()
    local j = ey:dot(a2c)
    local ez = ex:cross(ey)

    local r1 = A.distance
    local r2 = B.distance
    local r3 = C.distance

    local x = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
    local y = (r1 * r1 - r3 * r3 - x * x + (x - i) * (x - i) + j * j) / (2 * j)

    local result = A.pos + ex * x + ey * y

    local zSquared = r1 * r1 - x * x - y * y
    if zSquared > 0 then
        local z = math.sqrt(zSquared)
        local result1 = result + ez * z
        local result2 = result - ez * z

        return result1, result2
    end
    return result
end

-- from Opus somewhere
local function permutation(tbl, n)
	local function permgen(a, n)
		if n == 0 then
			coroutine.yield(a)
		else
			for i=1,n do
				a[n], a[i] = a[i], a[n]
				permgen(a, n - 1)
				a[n], a[i] = a[i], a[n]
			end
		end
	end
	local co = coroutine.create(function() permgen(tbl, n) end)
	return function()
		local _, res = coroutine.resume(co)
		return res
	end
end

local known_opus_devices = {
    ["6_4_milo_2"] = { -3182, 62, -5125, dimension = "overworld" },
    ["NationalCenterForMissingTurtles #1"] = { -3174, 73, -5124, dimension = "overworld" },
    ["computer_19171"] = { -3178, 64, -5130, dimension = "overworld" },
    ["RangerStore"] = { 217, 72, 123, dimension = "overworld" },
    ["AlexMilo"] = { -1785, 50, -2759, dimension = "overworld" },
    ["Solar-newmilo"] = { -3073, 78, -3008, dimension = "overworld" },
    ["ScorchMilo"] = { 269, 58, 421, dimension = "overworld" },
    ["scorchsfurninator"] = { 269, 54, 421, dimension = "overworld" },
    ["OMGFurni"] = { 4874, 76, -1701, dimension = "overworld" },
    ["computer_21867"] = { -7118, 52, -7354, dimension = "overworld" },
    ["LeClercMilo"] = { -7116, 50, -7357, dimension = "overworld" },
    ["manager_of_ground_trap"] = { 291, 31, -11, dimension = "overworld" },
    ["CodedPythonMilo"] = { -2597, 65, 4998, dimension = "overworld" },
    ["DistantMilo2"] = { -417, 80, -3049, dimension = "overworld" },
    ["NationalCenterForMissingTurtles #2"] = { 6, 35, -41, dimension = "nether" },
    ["CobbleGen69"] = { 3996, 52, 2900, dimension = "end" },
    ["GTech Storage"] = { 3955, 35, -2914, dimension = "end" },
    ["NationalCenterForMissingTurtles #3"] = { 4858, 75, 1975, dimension = "end" },
    ["BoomStorage"] = { -6016, 71, 1248, dimension = "overworld" },
    ["TS-shack"] = { 69, 69, -69, dimension = "nether" }
}

local state = {
    debug = false,
    fixes = {},
    modem_side = nil,
    channel_gps_was_closed = nil,
    channel_snmp_was_closed = nil,
    listener_running = false,
    use_saved_fixes = false,
    mse_threshold = 0.01,
    passive = false,
    max_fixes = 4,
    max_fix_age = nil,
    actual_position = nil -- for testing of Opus device positions
}

function initialize(modem_side)
    -- Find a modem
    if modem_side == nil then
        for _, side in ipairs(rs.getSides()) do
            if peripheral.getType(side) == "modem" and peripheral.call(side, "isWireless") then
                modem_side = side
                break
            end
        end
    end

    if modem_side == nil then
        if state.debug then
            print("No wireless modem attached")
        end
        return nil
    end
    if state.debug then
        print("Using", modem_side, "modem")
    end

    state.modem_side = modem_side

    local modem = peripheral.wrap(modem_side)
    state.channel_gps_was_closed = false
    if not modem.isOpen(CHANNEL_GPS) then
        modem.open(CHANNEL_GPS)
        state.channel_was_closed = true
        if state.debug then print "Opened GPS" end
    end
    state.channel_snmp_was_closed = false
    if not modem.isOpen(CHANNEL_SNMP) then
        modem.open(CHANNEL_SNMP)
        state.channel_snmp_was_closed = true
        if state.debug then print "Opened SNMP" end
    end
end

function teardown()
    if state.modem_side and state.channel_gps_was_closed then
        peripheral.call(state.modem_side, "close", CHANNEL_GPS)
    end
    if state.modem_side and state.channel_snmp_was_closed then
        peripheral.call(state.modem_side, "close", CHANNEL_SNMP)
    end
    state.modem_side = nil
end

function listener()
    state.listener_running = true
    while true do
        local e, side, channel, reply_channel, message, distance = os.pullEvent "modem_message"
        if e == "modem_message" then
            if side == state.modem_side and distance then
                local fix
                if channel == CHANNEL_GPS and reply_channel == CHANNEL_GPS and type(message) == "table" and #message == 3 and tonumber(message[1]) and tonumber(message[2]) and tonumber(message[3]) and message[1] == message[1] and message[2] == message[2] and message[3] == message[3] then
                    local vec = vector.new(message[1], message[2], message[3])
                    fix = { pos = vec, dim = message.dimension, src = "gps:" .. tostring(vec) }
                elseif channel == CHANNEL_SNMP and type(message) == "table" and type(message.status) == "string" and type(message.label) == "string" and #message.status <= 100 and #message.label <= 32 then
                    local data = known_opus_devices[message.label]
                    if state.debug and data then
                        print(("Got Opus message %d %s %s"):format(reply_channel, message.label, message.status))
                    end
                    if data then
                        fix = { pos = vector.new(unpack(data)), dim = data.dimension, src = "opus:" .. message.label }
                        if state.actual_position then
                            local disrepancy = (fix.pos - state.actual_position):length() - distance
                            if disrepancy > 0.1 then
                                print("Disrepancy of ", disrepancy, "on", message.label)
                            end
                        end
                    end
                end
                if fix then
                    local time = os.clock()
                    fix.time = time
                    fix.distance = distance
                    for i, old_fix in pairs(state.fixes) do
                        if tostring(old_fix.pos) == tostring(fix.pos) then
                            table.remove(state.fixes, i)
                            if state.debug then
                                print("Duplicate fix, dropping old")
                            end
                        end
                        if state.max_fix_age then
                            if time > state.max_fix_age + fix.time then
                                table.remove(state.fixes, i)
                                if state.debug then
                                    print("Fix over max age")
                                end
                            end
                        end
                    end
                    if state.debug then
                        print(fix.distance .. " metres from " .. tostring(fix.pos))
                        if fix.dim then
                            print("Dimension", fix.dim)
                        end
                    end
                    table.insert(state.fixes, fix)
                    if #state.fixes > state.max_fixes then
                        table.remove(state.fixes, 1)
                    end
                    os.queueEvent "fix_acquired"
                end
            end
        end
    end
end

function configure(args)
    for k, v in pairs(args) do
        state[k] = v
    end
end

function locate(timeout, _debug)
    state.debug = _debug
    -- Let command computers use their magic fourth-wall-breaking special abilities
    if commands then
        return commands.getBlockPosition()
    end

    if not state.modem_side then
        initialize()
    end

    if state.debug then
        print("Finding position...")
    end

    if not state.passive then peripheral.call(state.modem_side, "transmit", CHANNEL_GPS, CHANNEL_GPS, "PING") end

    local spawn_listener = not state.listener_running

    local pos
    local dimension

    if state.use_saved_fixes == false then
        state.fixes = {}
    end

    local fns = {
        function() sleep(timeout or 1) end,
        function()
            while true do
                os.pullEvent "fix_acquired"
                for _, fix in pairs(state.fixes) do
                    if fix.distance == 0 then
                        if state.debug then print("Distance 0 to", fix.pos) end
                        pos = fix.pos
                        return
                    end
                end
                if state.debug then
                    print("Fixes at", #state.fixes)
                end
                local candidate_positions = {}
                local dimvotes = {}
                for _, fix in pairs(state.fixes) do
                    if fix.dim then
                        dimvotes[fix.dim] = (dimvotes[fix.dim] or 0) + 1
                    end
                end
                local best
                for dim, votes in pairs(dimvotes) do
                    if best == nil or votes > best then
                        dimension = dim
                    end
                end
                if #state.fixes >= 3 then
                    for fixes in permutation(state.fixes, 3) do
                        local pos1, pos2 = trilaterate(fixes[1], fixes[2], fixes[3])
                        if pos1 and pos1.x == pos1.x and pos1.y == pos1.y and pos1.z == pos1.z then candidate_positions[tostring(pos1)] = pos1 end
                        if pos2 and pos2.x == pos2.x and pos2.y == pos2.y and pos2.z == pos2.z then candidate_positions[tostring(pos2)] = pos2 end
                    end
                    local best_error, best_candidate
                    for key, candidate in pairs(candidate_positions) do
                        local total_square_error = 0
                        for _, fix in pairs(state.fixes) do
                            total_square_error = total_square_error + ((candidate - fix.pos):length() - fix.distance)^2
                        end
                        local mean_square_error = total_square_error / #state.fixes
                        if best_error == nil or mean_square_error < best_error then
                            best_candidate = candidate
                            best_error = mean_square_error
                        end
                    end
                    if best_error < state.mse_threshold and (#state.fixes > 3 or #candidate_positions == 1) then
                        if state.debug then
                            print("Best candidate position is", best_candidate, "with error", best_error)
                        end
                        pos = best_candidate
                        return
                    else
                        if state.debug then
                            print("Position fix above error threshold:", best_candidate, best_error)
                        end
                    end
                end
            end
        end
    }

    if spawn_listener then table.insert(fns, listener) end

    parallel.waitForAny(unpack(fns))

    if spawn_listener then
        state.listener_running = false
    end

    teardown()

    if pos then
        if state.debug then
            print("Position is " .. pos.x .. "," .. pos.y .. "," .. pos.z)
        end
        if state.debug and dimension then
            print("Dimension is", dimension)
        end
        return pos.x, pos.y, pos.z, dimension
    else
        if debug then
            print("Could not determine position")
        end
        return nil
    end
end

return { CHANNEL_GPS = CHANNEL_GPS, locate = locate, configure = configure, listener =  listener }