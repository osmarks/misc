local username = settings.get "username" or "gollark"
local ni = peripheral.wrap "back"
local speaker = peripheral.find "speaker"
local modem = peripheral.find "modem"
local offload_laser = settings.get "offload_laser"
local w, h = ni.canvas().getSize()
if _G.thing_group then
	pcall(_G.thing_group.remove)
end
if _G.canvas3d_group then
    pcall(_G.canvas3d_group.clear)
    pcall(_G.canvas3d_group.remove)
end
local group
local group_3d
local function initialize_group_thing()
	if group then pcall(group.remove) end
    if group_3d then pcall(group_3d.remove) end
	group = ni.canvas().addGroup({ w - 70, 10 })
    ni.canvas3d().clear()
    group_3d = ni.canvas3d().create()
	_G.thing_group = group
    _G.canvas3d_group = group_3d
end
initialize_group_thing()

local targets = {}

local use_spudnet = offload_laser

local spudnet_send, spudnet_background
if use_spudnet then
    print "SPUDNET interface loading."
    spudnet_send, spudnet_background = require "ni-ctl_spudnet_interface"()
end

local function offload_protocol(...)
    spudnet_send { "exec", {...} }
end

local function is_target(name)
	for target, type in pairs(targets) do
		if name:lower():match(target) then return type end
	end
end

local function vector_sqlength(self)
	return self.x * self.x + self.y * self.y + self.z * self.z
end

local function project(line_start, line_dir, point)
	local t = (point - line_start):dot(line_dir) / vector_sqlength(line_dir)
	return line_start + line_dir * t, t
end

local function calc_yaw_pitch(v)
	local x, y, z = v.x, v.y, v.z
    local pitch = -math.atan2(y, math.sqrt(x * x + z * z))
    local yaw = math.atan2(-x, z)
    return math.deg(yaw), math.deg(pitch)
end

local settings_cfg = {
    brake = { type = "bool", default = true, shortcode = "b" },
    counter = { type = "bool", default = false, shortcode = "c" }, -- counterattack
    highlight = { type = "bool", default = false, shortcode = "h" },
    dodge = { type = "bool", default = true, shortcode = "d" },
    power = { type = "number", default = 5, max = 5, min = 0.5 }, -- laser power
    flight = { type = "string", default = "std", shortcode = "f", alias = { fly = true } },
    drill = { type = "bool", default = false, shortcode = "D", persist = false },
    show_acceleration = { type = "bool", default = false },
    pitch_controls = { type = "bool", default = false },
    ext_highlight = { type = "bool", default = false }
}
local SAVEFILE = "ni-ctl-settings"
if fs.exists(SAVEFILE) then
    local f = fs.open(SAVEFILE, "r")
    for key, value in pairs(textutils.unserialise(f.readAll())) do
        settings_cfg[key].value = value
    end
    f.close()
end
local gsettings = {}
setmetatable(gsettings, {
    __index = function(_, key)
        local cfg = settings_cfg[key]
        if cfg.value == nil then return cfg.default else return cfg.value end
    end,
    __newindex = function(_, key, value)
        print("set", key, "to", value)
        settings_cfg[key].value = value
        if settings_cfg[key].persist ~= false then
            local kv = {}
            for key, cfg in pairs(settings_cfg) do
                kv[key] = cfg.value
            end
            local f = fs.open(SAVEFILE, "w")
            f.write(textutils.serialise(kv))
            f.close()
        end
        os.queueEvent "settings_change"
    end
})

local work_queue = {}

local addressed_lasers = {}
local function bool_to_yn(b)
	if b == true then return "y"
	elseif b == false then return "n"
	else return "?" end
end

local status_lines = {}
local notices = {}
local function push_notice(t)
	table.insert(notices, { t, os.epoch "utc" })
end

local function lase(entity)
	local target_location = entity.s
	for i = 1, 5 do
		target_location = entity.s + entity.v * (target_location:length() / 1.5)
	end
	local y, p = calc_yaw_pitch(target_location)
	if offload_laser then offload_protocol("fire", y, p, gsettings.power) else ni.fire(y, p, gsettings.power) end
end

local user_meta
local fast_mode_reqs = {}

local colortheme = {
    status = 0xFFFFFFFF,
    notice = 0xFF8800FF,
    follow = 0xFF00FFFF,
    watch =  0xFFFF00FF,
    laser =  0xFF0000FF,
    entity = 0x00FFFFFF,
    select = 0x00FF00FF
}

local function schedule(fn, time, uniquename)
    if uniquename then 
        work_queue[uniquename] = { os.clock() + time, fn }
    else
        table.insert(work_queue, { os.clock() + time, fn })
    end
end

local function direction_vector(yaw, pitch)
    return vector.new(
        -math.sin(math.rad(yaw)) * math.cos(math.rad(pitch)),
        -math.sin(math.rad(pitch)),
        math.cos(math.rad(yaw)) * math.cos(math.rad(pitch))
    )
end

--[[
local function ni.launch(yaw, pitch, power)
    ni.ni.launch(yaw, pitch, power)
    if user_meta then
        local impulse = vector.new(
            -math.sin(math.rad(yaw)) * math.cos(math.rad(pitch)),
            math.cos(math.rad(yaw)) * math.cos(math.rad(pitch)),
            -math.sin(math.rad(pitch))
        )
        if user_meta.isElytraFlying then
            impulse = 0.4 * impulse
        end
        user_meta.velocity = user_meta.velocity + (impulse * power)
    end
end]]

local gravity_motion_offset = 0.07840001

--[[
local inav_position = nil
local inav_delta = nil
local scaler = 20

local function navigation()
    while true do
        local real_pos = vector.new(gps.locate())
        if inav_position then
            print(inav_position - real_pos)
            local real_delta = (inav_position - real_pos):length()
            local delta_size = inav_delta:length()
            print("calculated delta was", delta_size / real_delta, "of real")
        end
        inav_position = real_pos
        inav_delta = vector.new(0, 0, 0)
        sleep(3)
    end
end
]]

local hud_entities = {}
local function render_hud()
    local flags = {}
    for key, cfg in pairs(settings_cfg) do
        if cfg.shortcode and cfg.type == "bool" then
            if gsettings[key] then
                table.insert(flags, cfg.shortcode)
            end 
        end
    end
    table.sort(flags)
    status_lines.flags = "Flags: " .. table.concat(flags)

    local i = 0
    local ok, err = pcall(group.clear)
    if not ok then
        initialize_group_thing()
    end
    local time = os.epoch "utc"
    for _, text in pairs(status_lines) do
        group.addText({ 0, i * 7 }, text, colortheme.status, 0.6)
        i = i + 1
    end
    for ix, info in pairs(notices) do
        if time >= (info[2] + 2000) then notices[ix] = nil end
        group.addText({ 0, i * 7 }, info[1], colortheme.notice, 0.6)
        i = i + 1
    end
    for thing, count in pairs(hud_entities) do
        local text = thing
        if count ~= 1 then text = text .. " " .. count end
        group.addText({ 0, i * 7 }, text, colortheme[is_target(thing) or "entity"], 0.6)
        i = i + 1
    end
end

local last_velocity
local last_time
local integrated_position = vector.new(0, 0, 0)

local function update_motion_vars(new_meta)
    local time = os.clock()
    if user_meta then
        -- walking hack
        if not (user_meta.isFlying or user_meta.isElytraFlying) then
            if user_meta.isInWater then new_meta.motionY = new_meta.motionY + 0.02
            else new_meta.motionY = new_meta.motionY + gravity_motion_offset end
        end
        user_meta.velocity = vector.new(new_meta.motionX, new_meta.motionY, new_meta.motionZ)
        user_meta.real_velocity = vector.new(new_meta.deltaPosX, new_meta.deltaPosY, new_meta.deltaPosZ)
        integrated_position = integrated_position + user_meta.real_velocity
        user_meta.motionX = new_meta.motionX
        user_meta.motionY = new_meta.motionY
        user_meta.motionZ = new_meta.motionZ
        user_meta.pitch = new_meta.pitch
        user_meta.yaw = new_meta.yaw
        if last_time and last_velocity then
            local timestep = time - last_time
            user_meta.acceleration = (user_meta.velocity - last_velocity) / timestep
        end
        last_velocity = user_meta.velocity
    end
    last_time = time
end

local function scan_entities()
	while true do
		fast_mode_reqs.laser = false
		fast_mode_reqs.acting = false
		local entities = ni.sense()
		local maybe_players = {}
		hud_entities = {}
		local lasers = {}
        
		for _, entity in pairs(entities) do
			entity.s = vector.new(entity.x, entity.y, entity.z)
			entity.v = vector.new(entity.motionX, entity.motionY, entity.motionZ)
			if entity.displayName ~= username then
				hud_entities[entity.displayName] = (hud_entities[entity.displayName] or 0) + 1
			end
			if entity.displayName ~= username and entity.displayName == entity.name and (math.floor(entity.yaw) ~= entity.yaw and math.floor(entity.pitch) ~= entity.pitch) then -- player, quite possibly
				entity.v = entity.v + vector.new(0, gravity_motion_offset, 0)
				table.insert(maybe_players, entity)
			end
            if entity.name == "plethora:laser" then
                fast_mode_reqs.laser = true
            end
			if entity.name == "plethora:laser" and not addressed_lasers[entity.id] then
				local closest_approach, param = project(entity.s, entity.v - user_meta.velocity, vector.new(0, 0, 0))
				if param > 0 and vector_sqlength(closest_approach) < 5 then
					push_notice "Laser detected"
					fast_mode_reqs.laser = true
					local time_to_impact = (entity.s:length() / (entity.v - user_meta.velocity):length()) / 20
					print("got inbound laser", time_to_impact, vector_sqlength(closest_approach), param)
					addressed_lasers[entity.id] = true
                    if gsettings.dodge then
                        schedule(function() 
                            push_notice "Executing dodging"
                            local dir2d = vector.new(entity.motionX - user_meta.motionX, 0, entity.motionZ - user_meta.motionZ)
                            local perpendicular_dir2d = vector.new(1, 0, -dir2d.x / dir2d.z)
                            -- NaN contingency measures
                            if perpendicular_dir2d.x ~= perpendicular_dir2d.x or perpendicular_dir2d.z ~= perpendicular_dir2d.z then
                                perpendicular_dir2d = vector.new(-dir2d.z / dir2d.x, 0, 1)
                            end
                            if perpendicular_dir2d.x ~= perpendicular_dir2d.x or perpendicular_dir2d.z ~= perpendicular_dir2d.z then
                                local theta = math.random() * math.pi * 2
                                perpendicular_dir2d = vector.new(math.cos(theta), 0, math.sin(theta))
                            end
                            local y, p = calc_yaw_pitch(perpendicular_dir2d)
                            if math.random(1, 2) == 1 then p = -p end
                            ni.launch(y, p, 3)
                        end, math.max(0, time_to_impact / 2 - 0.1))
                    end
					schedule(function() addressed_lasers[entity.id] = false end, 15)
					table.insert(lasers, entity)
				end
			end
		end
		for _, laser in pairs(lasers) do
			for _, player in pairs(maybe_players) do
				local closest_approach, param = project(laser.s, laser.v, player.s)
				print(player.displayName, closest_approach, param)
				if param < 0 and vector_sqlength(closest_approach - player.s) < 8 and gsettings.counter then
					print("execute counterattack", player.displayName)
					push_notice(("Counterattack %s"):format(player.displayName))
					targets[player.displayName:lower()] = "laser"
				end
			end
		end
		
        render_hud()

        pcall(function()
            group_3d.clear()
            group_3d.recenter()
        end)

        for _, entity in pairs(entities) do
            local action = is_target(entity.displayName)
            if action then
                if action == "laser" then
                    schedule(function() lase(entity) end, 0, entity.id)
                elseif action == "watch" then
                    schedule(function() ni.look(calc_yaw_pitch(entity.s)) end, 0, entity.id)
                elseif action == "follow" then
                    schedule(function()
                        local y, p = calc_yaw_pitch(entity.s)
                        ni.launch(y, p, math.min(entity.s:length() / 24, 2))
                    end, 0, entity.id)
                end
                fast_mode_reqs.acting = true
            end
            if gsettings.highlight and hud_entities[entity.displayName] and hud_entities[entity.displayName] < 20 then
                local color = colortheme[action or "entity"]
                local object = group_3d.addBox(entity.x - 0.25, entity.y - 0.25, entity.z - 0.25)
                object.setColor(color)
                object.setAlpha(128)
                object.setDepthTested(false)
                object.setSize(0.5, 0.5, 0.5)
                if gsettings.ext_highlight then
                    local frame = group_3d.addFrame({entity.x - 0.25, entity.y + 0.25, entity.z - 0.25})
                    frame.setDepthTested(false)
                    frame.addText({0, 0}, entity.displayName, nil, 3)
                end
            end
        end

        local fast_mode = false
        for _, m in pairs(fast_mode_reqs) do
            fast_mode = fast_mode or m
        end

        --status_lines.fast_mode = "Fast scan: " .. bool_to_yn(fast_mode)

        if fast_mode then sleep(0.1) else sleep(0.2) end
    end
end

local flight_shortcodes = {
    o = "off",
    b = "brake",
    h = "hpower",
    l = "lpower",
    s = "std",
    a = "align",
    v = "hover"
}

local flight_powers = {
    std = 1,
    lpower = 0.5,
    hpower = 4,
    align = 1,
    hover = 1
}

local flight_target = nil

local function xz_plane(v)
    return vector.new(v.x, 0, v.z)
end

-- As far as I can tell, a speed of more than 10 in the X/Z plane causes a reset of your velocity by the server and thus horrible rubberbanding.
local function maxvel_compensatory_launch(yaw, pitch, power)
    local effective_power = (user_meta and user_meta.isElytraFlying) and (power * 0.4) or power
    local impulse = direction_vector(yaw, pitch) * effective_power
    local power_over_velocity_limit = math.max(xz_plane(user_meta.velocity + impulse):length() - 10, 0)
    if user_meta and user_meta.isElytraFlying then
        power = power - power_over_velocity_limit / 0.4
    else
        power = power - power_over_velocity_limit
    end
    power = math.min(math.max(power, 0), 4)
    if power > 0 then
        ni.launch(yaw, pitch, power)
    end
end

local function run_flight()
    if flight_shortcodes[gsettings.flight] then gsettings.flight = flight_shortcodes[gsettings.flight] end
    local disp = gsettings.flight
    if user_meta.deltaPosY < -0.3 and gsettings.brake then
            ni.launch(0, 270, math.max(0.4, math.min(4, -user_meta.motionY / 1.5)))
            --ni.launch(0, 270, 0.4)
        --end
        fast_mode_reqs.flying = true
        disp = disp .. " F"
    else
        fast_mode_reqs.flying = false
    end
    if gsettings.flight ==  "std" or gsettings.flight == "hpower" or gsettings.flight == "lpower" or gsettings.flight == "align" or gsettings.flight == "hover" then
        if user_meta.isElytraFlying or user_meta.isSneaking then
            fast_mode_reqs.flying = true
        end
        if user_meta.isElytraFlying ~= user_meta.isSneaking then
            if not user_meta.isAirborne and user_meta.pitch < -15 then
                push_notice "Fast takeoff"
                ni.launch(0, 270, 1)
            end
            local power = flight_powers[gsettings.flight]
            if user_meta.isInWater then
                power = power * 2
            end
            local yaw, pitch = user_meta.yaw, user_meta.pitch
            if pitch == 90 and gsettings.pitch_controls then
                local y, p = calc_yaw_pitch(-user_meta.velocity)
                ni.launch(y, p, math.min(user_meta.velocity:length(), 4))
            else
                local raw_direction = direction_vector(yaw, pitch)
                local impulse = vector.new(raw_direction.x, raw_direction.y * 1.5, raw_direction.z) * power
                impulse = impulse + vector.new(0, 0.1, 0)
                local y, p = calc_yaw_pitch(impulse)
                maxvel_compensatory_launch(y, (gsettings.flight ~= "align" and p) or 10, math.min(4, impulse:length()))
            end
        end
    elseif gsettings.flight == "brake" then
        local y, p = calc_yaw_pitch(-user_meta.velocity)
        ni.launch(y, p, math.min(user_meta.velocity:length(), 1))
        fast_mode_reqs.flying = true
    end
    status_lines.flight = "Flight: " .. disp
end

local function ll_flight_control()
    while true do
        local ok, user_meta_temp
        if ni.getMetaOwner then
		    ok, user_meta_temp = pcall(ni.getMetaOwner, username)
        else
            ok, user_meta_temp = pcall(ni.getMetaByName, username)
        end
        if not ok or not user_meta_temp then
            speaker.playSound("entity.enderdragon.death")
            user_meta = nil
            for name, cfg in pairs(settings_cfg) do
                if cfg.persist == false then
                    cfg.value = nil
                end
            end
            work_queue = {}
            ni = peripheral.wrap "back"
            ni.canvas().clear()
            error("Failed to fetch user metadata (assuming death): " .. tostring(user_meta_temp))
        end
        user_meta = user_meta_temp
        update_motion_vars(user_meta)
        if user_meta.acceleration and gsettings.show_acceleration then
            status_lines.acceleration = ("Acc: %.2f/%.2f"):format(user_meta.acceleration:length(), user_meta.acceleration.y)
        end

		status_lines.vel = ("Vel: %.2f/%.2f"):format(user_meta.velocity:length(), user_meta.motionY)

        render_hud()

        local fast_mode = false
        for _, m in pairs(fast_mode_reqs) do
            fast_mode = fast_mode or m
        end

        --status_lines.fast_mode = "Fast scan: " .. bool_to_yn(fast_mode)

        schedule(run_flight, 0, "flight")

        if not fast_mode then sleep(0.1) end
    end
end

local function queue_handler()
    while true do
        local init = os.clock()
        for index, arg in pairs(work_queue) do
            if arg[1] <= os.clock() then
                arg[2]()
                work_queue[index] = nil
            end
        end
        if os.clock() == init then sleep() end
    end
end

local function estimate_tps()
    while true do
        local game_time_start = os.epoch "utc"
        sleep(5)
        local game_time_end = os.epoch "utc"
        local utc_elapsed_seconds = (game_time_end - game_time_start) / 5000
        status_lines.tps = ("TPS: %.0f"):format(20 / utc_elapsed_seconds)
    end
end

local function within_epsilon(a, b)
    return math.abs(a - b) < 1
end

-- TODO: unified navigation framework
local function fly_to_target()
    local last_s, last_t
    while true do
        while not user_meta do sleep() end
        if flight_target then
            local x, y, z = gps.locate()
            if not y then push_notice "GPS error"
            else
                if y < 256 then
                    ni.launch(0, 270, 4)
                end
                local position = vector.new(x, 0, z)
                local curr_t = os.clock()
                local displacement = flight_target - position
                status_lines.flight_target = ("%d from %d %d"):format(displacement:length(), flight_target.x, flight_target.z)
                local real_displacement = displacement
                if last_t then
                    local delta_t = curr_t - last_t
                    local delta_s = displacement - last_s
                    local deriv = delta_s * (1/delta_t)
                    displacement = displacement + deriv
                end
                local pow = math.max(math.min(4, displacement:length() / 40), 0)
                local yaw, pitch = calc_yaw_pitch(displacement)
                maxvel_compensatory_launch(yaw, pitch, pow)
                --sleep(0)
                last_t = curr_t
                last_s = real_displacement
                if within_epsilon(position.x, flight_target.x) and within_epsilon(position.z, flight_target.z) then flight_target = nil end
            end
        else
            status_lines.flight_target = nil
        end
        sleep(0.1)
    end
end

local function handle_commands()
    while true do
        local _, user, command, args = os.pullEvent "command"
        if user == username then
            if command == "lase" then
                if args[1] then
                    targets[table.concat(args, " "):lower()] = "laser"
                end
            elseif command == "ctg" then
                args[1] = args[1] or ".*"
                local arg = table.concat(args, " ")
                for k, v in pairs(targets) do
                    if k:lower():match(arg) then
                        chatbox.tell(user, k .. ": " .. v)
                        targets[k:lower()] = nil
                    end
                end
            elseif command == "watch" then
                if args[1] then
                    targets[table.concat(args, " "):lower()] = "watch"
                end
            elseif command == "select" then
                if args[1] then
                    targets[table.concat(args, " "):lower()] = "select"
                end
            elseif command == "follow" then
                if args[1] then
                    targets[table.concat(args, " "):lower()] = "follow"
                end
            elseif command == "notice_test" then
                push_notice(table.concat(args, " "))
            elseif command == "flyto" then
                if args[1] == "cancel" or args[1] == nil then
                    flight_target = nil
                else
                    local x, z = tonumber(args[1]), tonumber(args[2])
                    if type(x) ~= "number" or type(z) ~= "number" then
                        chatbox.tell(user, "Usage: \\flyto x z")
                    else
                        flight_target = vector.new(x, 0, z)
                    end
                end
            elseif command == "update" then
                local h, e = http.get "https://osmarks.net/stuff/ni-ctl.lua"
                assert(h, "HTTP: " .. (e or ""))
                local data = h.readAll()
                h.close()
                local file = fs.open(shell.getRunningProgram(), "w")
                file.write(data)
                file.close()
                chatbox.tell(user, "Update updated.")
            else
                for key, cfg in pairs(settings_cfg) do
                    if key == command or cfg.shortcode == command or (cfg.alias and cfg.alias[command]) then
                        if cfg.type == "bool" then
                            if args[1] and (args[1]:match "y" or args[1]:match "t" or args[1]:match "on") then
                                gsettings[key] = true
                            elseif args[1] and (args[1]:match "f" or args[1]:match "^n") then
                                gsettings[key] = false
                            else
                                gsettings[key] = not gsettings[key]
                            end
                            chatbox.tell(user, ("%s: %s"):format(key, tostring(gsettings[key])))
                        elseif cfg.type == "number" then
                            local value = tonumber(args[1])
                            if not value then chatbox.tell(user, "Not a number") end
                            if cfg.max and value > cfg.max then chatbox.tell(user, ("Max is %d"):format(cfg.max)) end
                            if cfg.min and value < cfg.min then chatbox.tell(user, ("Max is %d"):format(cfg.min)) end
                            gsettings[key] = value
                        else
                            gsettings[key] = args[1]
                        end
                        break
                    end
                end
            end
        end
    end
end

local function drill()
    while true do
        if gsettings.drill then
            repeat sleep() until user_meta
            if offload_laser then
                offload_protocol("fire", user_meta.yaw, user_meta.pitch, gsettings.power)
            else
                schedule(function() repeat sleep() until user_meta ni.fire(user_meta.yaw, user_meta.pitch, gsettings.power) end, 0, "drill")
            end
            sleep(0.1)
        else
            os.pullEvent "settings_change"
        end
    end
end

while true do
    local cmds = {ll_flight_control, queue_handler, scan_entities, handle_commands, estimate_tps, fly_to_target, drill}
    if spudnet_background then
        table.insert(cmds, spudnet_background)
    end
    local ok, err = pcall(parallel.waitForAny, unpack(cmds))
    if err == "Terminated" then break end
    printError(err)
    sleep(0.2)
end
