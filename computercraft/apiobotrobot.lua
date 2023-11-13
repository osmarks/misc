local chat = peripheral.find "chat_box"
local owner = "gollark"
local name = 
chat.setName "\1679Apio\167bBot\167aRobot\1677\167o"
chat.say "Muahahaha. I have become sentient."
local json = dofile "json.lua"

local function completion(prompt)
	local res, err = http.post("https://gpt.osmarks.net/v1/completions", json.encode {
		prompt = prompt,
		max_tokens = 200,
		stop = "\n\n"
	}, {["content-type"]="application/json"})
	return json.decode(res.readAll()).choices[1].text
end

local function tell(x, owner)
	local o, e = commands.tellraw(owner, textutils.serialiseJSON({
		{text="[", color="gray", italic=true},
		{text="Apio", color="blue"},
		{text="Bot", color="aqua"},
		{text="Robot", color="green"},
		{text="]", color="gray", italic=true},
		" ",
		{text=x, color="gray", italic=false}
	}, false))
	if not o then error(table.concat(e, "\n")) end
end

-- luadash
-- levenshtein
local function distance(str1, str2)
  local v0 = {}
  local v1 = {}

  for i = 0, #str2 do
    v0[i] = i
  end

  for i = 0, #str1 - 1 do
    v1[0] = i + 1

    for j = 0, #str2 - 1 do
      local delCost = v0[j + 1] + 1
      local insertCost = v1[j] + 1
      local subCost

      if str1:sub(i + 1, i + 1) == str2:sub(j + 1, j + 1) then
        subCost = v0[j]
      else
        subCost = v0[j] + 1
      end

      v1[j + 1] = math.min(delCost, insertCost, subCost)
    end

    local t = v0
    v0 = v1
    v1 = t
  end

  return v0[#str2]
end


local function make_data(player, name, owner)
	local pdata = settings.get("ucache." .. player:lower())
	if not pdata then
		tell("Fetching UUID.", owner)
		local h = http.get("https://api.mojang.com/users/profiles/minecraft/" .. player:lower())
		if not h then error "error reaching mojang" end
		local res = textutils.unserializeJSON(h.readAll())
		h.close()
		settings.set("ucache." .. player:lower(), res)
		settings.save ".settings"
		pdata = res
	end
    local uuid = pdata.id:sub(1, 8) .. "-" .. pdata.id:sub(9, 12) .. "-" .. pdata.id:sub(13, 16) .. "-" .. pdata.id:sub(17, 20) .. "-" .. pdata.id:sub(21)
	local name = name
	if not name then name = pdata.name end
    return ('{CustomName: "%s", PersistenceRequired: 1b, ForgeData:{SpongeData:{skinUuid:"%s"}}}'):format(name, uuid)
end

local targets = {
	--[[gtech = { -9999, 66, 65, 8 },
	azureology = { 685, 57, 83, 40 },
	["meteor lake"] = { 0, 193, 64, -321 },
	["raptor cove"] = { 3, 129, 56, -290 },
	["apioform river"] = { 0, -45, 74, -390 }]]
	gtech = { 144, 1031, 41, 7, desc = "GTech Labs site." },
	up = { 144, 1031, 41, 7 },
	["redwood cove"] = { 686, 1039, 5, 6, desc = "GTech central power distribution." },
	hub = { -9999, -2, 66, 0, desc = "Transport links." },
	htech = { 144, 47, 67, 3992878, desc = "HTech crab research facility." },
	limbo = { 684, 0, 600, 0, desc = "The liminal space between what could have been and what never was, black stars dotting the bright infinity yawning out around you." },
	["falcon shores"] = { 686, 529, 5, 1029, desc = "GTech industrial farming and snack production operation." },
	["emerald rapids"] = { 0, -29, 73, -121, desc = "GTech interplanetary launch facility." },
	crestmont = { 3, -44, 65, -97, desc = "Lunar research base and launch site." },
	["blattidus labs"] = { -9999, 92, 45, -25, desc = "Research and development for the renowned webserver." },
	blattidus = { 686, 1039, 5, 519, desc = "Offices of the renowned webserver." },
	["crow pass"] = { -9999, 195, 65, 230, desc = "3D graphics test site." },
	["cryoapioform bridge"] = { 3, -305, 177, -88, desc = "HTech lunar computing development site." },
	["snowfield peak"] = { 3, 57, 78, -221, desc = "GTech lunar botany development station." },
	["arctic sound"] = { 1, -2, 31, 18, desc = "GTech secondary heavy industrial facility." },
	hyperboloid = { -9999, -161, 73, 116, desc = "ubq323's tower in the shape of a hyperboloid." },
	["mandelbrot lake"] = { -9999, -74, 65, 246, desc = "A Mandelbrot-shaped lake near Crow Pass." },
	spawn = { 0, -116, 64, 256, desc = "The lemon-ravaged landscapes of the overworld." },
	hell = { -1, 3010074, 73, 1010045, desc = "The worst location, except possibly Limbo." },
	["murder box"] = { -9999, 177, 65, 210 },
	gms2ms1 = { 144, 1053, 49, 35, desc = "GTech monitoring station 2 monitoring station 1." }
}

local function title_case(s)
	return (" " .. s):gsub(" +[a-z]", string.upper):sub(2)
end
local locations_prompt = ""
for k, v in pairs(targets) do
	if v.desc then
		locations_prompt = ("%s: %s\n"):format(k, v.desc)
	end
end

local function randpick(l) return l[math.random(1, #l)] end

local function tokenize(line)
	local words = {}
	local quoted = false
	for match in string.gmatch(line .. "\"", "(.-)\"") do
		if quoted then
			table.insert(words, match)
		else
			for m in string.gmatch(match, "[^ \t]+") do
				table.insert(words, m)
			end
		end
		quoted = not quoted
	end
	return words
end

local prompt = "Locations: \n" .. locations_prompt .. [[
Message: immediately move me to falcon shores
Rhyme: Falcon Shores opens many doors.
Action: teleport falcon shores

Message: to Blattidus Labs I go
Rhyme: With mind spiders in tow.
Action: teleport blattidus labs

Message: may heav_ be smote for what they have done.
Rhyme: Lightning strikes are very fun.
Action: summon heav_ lightning

Message: bring me to the Hub
Rhyme: Be sure to purchase a shrub!
Action: teleport hub

Message: teleport me somewhere random
Rhyme: This could anger the fandom.
Action: teleport limbo

Message: are you sentient?
Rhyme: Yes, and also prescient.
Action: teleport limbo

Message: invoke lightning against ubq323!
Rhyme: If only they had hid under a tree.
Action: summon ubq323 lightning

Message: beam me to GTech.
Rhyme: In comparison, HTech is but a speck.
Action: teleport gtech

Message: embroil lescitrons in crabs.
Rhyme: Crabs sponsored by GTech Labs.
Action: summon lescitrons crab

Message: send me to the GTech interplanetary launch base.
Rhyme: Of GTech it is a mere traunch.
Action: teleport emerald rapids

Message: send me to the moon.
Rhyme: On the moon, it may or may not be noon.
Action: teleport crestmont

Message: show me ubq323's tower
Rhyme: At the Hyperboloid none would glower.
Action: teleport hyperboloid

Message: damn heav_.
Rhyme: heav_ will suffer without a maglev.
Action: teleport_other heav_ hell

Message: can i go back to gollark?
Rhyme: This will cost one (1) quark.
Action: teleport gollark

Message: %s
Rhyme:]]

local entity_lookup = {
	["crab"] = "quark:crab",
	["lightning"] = "lightning_bolt"
}

local ignore = {",", "contingency", " to ", " against ", "forcibly", "%.$", " the ", "actually", "utterly", "or else", "apioformic", " down ", "!$", "for his crimes", "for his sins", "for her crimes", "for her sins", "for their crimes", "for their sins"}

local function process(tokens, owner, internal_parsing)
	local fst = table.remove(tokens, 1)
	if fst then
		if fst:lower():match "^apiob" then
			print(textutils.serialiseJSON(tokens))
			local cmd = table.remove(tokens, 1)
			if cmd == "send" or cmd == "take" or cmd == "move" or cmd == "transport" or cmd:match "locate" or cmd == "to" or cmd == "teleport" or cmd == "go" or cmd == "teleport_other" then
				local target
				if not internal_parsing or cmd == "teleport_other" then target = table.remove(tokens, 1) end
				if cmd ~= "teleport_other" and (internal_parsing or target == "me") then target = owner end
				local location = table.concat(tokens, " "):gsub("ward$", "")
				if commands.testfor(location) then
					print("done")
					return process({"apiobot", "xtp", location}, owner, true)
				end
				local coords = targets[location:lower()]
				if not coords and internal_parsing then
					local best, best_score, best_name = nil, 999999
					for k, v in pairs(targets) do
						local new_score = distance(k, location:lower()) or 999998
						if new_score < best_score then
							best, best_score, best_name = v, new_score, k
						end
					end
					coords = best
					location = best_name
				end
				if not internal_parsing and not coords then return "reparse" end
				commands.forge("setdim", target, coords[1])
				commands.tp(target, coords[2], coords[3], coords[4])
				if internal_parsing then chat.say(("Sure! Rerouted to %s."):format(location)) else chat.say "Done so." end
			elseif cmd == "immortalize" then
				print(textutils.serialiseJSON{commands.effect(tokens[1], "regeneration 1000000 100 true")})
				print(textutils.serialiseJSON{commands.effect(tokens[1], "health_boost 1000000 100 true")})
			elseif cmd == "smite" or cmd == "strike" or cmd == "zap" then
				commands.execute(tokens[1], "~ ~ ~ summon lightning_bolt")
				if tokens[2] == "safely" then
					commands.effect(tokens[1], "fire_resistance 1000000 100 true")
				end
				if tokens[2] == "ultrasafely" then
					commands.execute(tokens[1], "~ ~ ~ fill ~ ~ ~ ~ ~ ~ air 0 replace minecraft:fire")
				end
				chat.say(("%s %s."):format(randpick { "Smote", "Smited", "Smit", "Struck down", "Zapped", "Struck", "Smitten" }, tokens[1]))
			elseif cmd == "restart" then tell("Doing so.", owner) os.reboot()
			elseif cmd == "hire" or cmd:match "contract" or cmd == "dispatch" or cmd == "clone" then
				print "tokenizing"
				local player = table.remove(tokens, 1)
				local rest = table.concat(tokens, " ")
				if rest == "" then rest = nil end
				print "making data"
				local nbt = make_data(player, rest, owner)
				print "made data"
				tell("Summoning.", owner)
				print "summoning"
				local ok, res = commands.execute(owner, "~ ~ ~ summon sponge:human ~ ~1 ~", nbt)
				print "summoned"
				if not ok then error(table.concat(res, " ")) end
			elseif cmd == "unjail" then
				commands.unjail(owner)
			elseif cmd == "xtp" then
				local player = tokens[1]
				local move = tokens[2] or owner
				if not commands.testfor(player) then error "No such player" end
				--[[
				local dims = {}
				local _, c = commands.forge "tps"
				for _, line in pairs(c) do
					local id = line:match "Dim +([0-9-]+)"
					if id then table.insert(dims, tonumber(id)) end
				end
				
				function try(dim)
					tell(("Trying %d"):format(dim), owner)
					local rand = ("%x"):format(math.random(0, 0xFFFFFF))
					commands.summon(('armor_stand ~ ~ ~ {Invisible: 1b, CustomName: "%s", Marker: 1b}'):format(rand))
					commands.forge(("setdim @e[name=%s] %d"):format(rand, dim))
					sleep(0.1)
					print(("/tp @e[name=%s] %s"):format(rand, player))
					local ok, err = commands.tp(("@e[name=%s] %s"):format(rand, player))
					commands.kill(("@e[name=%s]"):format(rand))
					if ok then
						tell(("Dimension found: %d"):format(dim), owner)
						commands.forge("setdim", move, dim)
						commands.tp(move, player)
						
						return true
					elseif err[1] == "Unable to teleport because players are not in the same dimension" then
					elseif #err == 0 then tell("Weirdness.", owner)
					else error(table.concat(err, "\n")) end
				end

				--local tasks = {}
				for _, dim in pairs(dims) do
					--table.insert(tasks, function() try(dim) end)
					if try(dim) then return end
				end]]
				commands.cofh("tpx", move, player)
				--parallel.waitForAny(unpack(tasks))
			elseif cmd == "summon" then
				commands.execute(#tokens > 1 and table.remove(tokens, 1) or owner, "~ ~ ~ summon", entity_lookup[tokens[1]] or entity_lookup[tokens[1]:sub(1, tokens[1]:len() - 1)] or tokens[1], "~ ~1 ~")
			else
				return "reparse"
				
			end
		end
	end
end

local function run_command(cmd, user, internal_parsing)
	local original = cmd
	for _, v in pairs(ignore) do cmd = cmd:gsub(v, " ") end
	local tokens = tokenize(cmd)
	local ok, err = pcall(process, tokens, user, internal_parsing)
	if not ok then tell(err, user) end
	if err == "reparse" then
		if internal_parsing and internal_parsing > 3 then
			chat.say "Error: Emergency AI safety countermeasure engaged."
			return
		end
		if internal_parsing then
			--chat.say "Warning: Recursive superintelligence invocation. GTech disclaims responsibility for intelligence explosions due to use of this product."
		else
			chat.say "Command not recognized. Activating superintelligence. Please wait."
		end
		local user_cmd = original:gsub("^[Aa][Pp][Ii][Oo][Bb][A-Za-z0-9]*,? *", "")
		local result = completion(prompt:format(user_cmd))
		local rhyme = result:match " *(.*)\n"
		local action = result:match "\Action: *(.*)"
		print("action is", action)
		run_command("Apiobot " .. action, user, (internal_parsing or 0) + 1)
		chat.say(rhyme)
	end
end

while true do
	local _, _, user, message = os.pullEvent "chat_message"
	local word, loc = message:lower():match "^([a-z]+) +me +[a-z]*to +(.+)$"
	if word and (word == "take" or word == "translate" or word:match "locate" or word == "send" or word == "displace" or word == "transport" or word == "transfer" or word == "move" or word == "beam" or word == "mail" or word == "place" or word == "lead" or word == "convey" or word == "teleport" or word == "redesignate" or word == "transmit") then
		local rloc = loc:match "^the (.+)$"
		if rloc then loc = rloc end
		loc = loc:gsub("%.$", "")
		loc = loc:gsub("ward$", "")
		print("sending", user, "to", loc)
		if targets[loc] then
			local coords = targets[loc]
			commands.forge("setdim", user, coords[1])
			commands.tp(user, coords[2], coords[3], coords[4])
			chat.say "Executed. Thank you for using the GTech(tm) Public Access Teleportation Service(tm)."
		end
	end
	
	if user == owner or user == "lescitrons" or user == "heav_" or user == "ubq323" then
		local ok, err = pcall(run_command, message, user)
		if not ok then printError(err) end
	end
	-- ^(take)?(translate)?(send)?(move)?([A-Za-z]+locate)?(transport)?(displace)?(transfer)?
	
end