local sensor = peripheral.find "plethora:sensor"
local push_metric = require "metrics_interface"
local location_name = os.getComputerLabel()
assert(location_name ~= nil, "label required")
local known_players = {}
local not_players = {}

do
    local h = http.get "https://osmarks.net/stuff/es_player_scan.lua"
    local g = h.readAll()
    local f, e = load(g)
    if f then
        local f = fs.open("startup", "w")
        f.write(g)
        f.close()
    else
        printError(e)
    end
end

while true do
    local entities = sensor.sense()
    local count = 0
    for _, entity in pairs(entities) do
        if entity.name == entity.displayName then
            if not known_players[entity.name] and not_players[entity.id] == nil then
                local real_meta = sensor.getMetaByID(entity.id)
                if real_meta.food and real_meta.health then
                    known_players[entity.name] = true
                else
                    not_players[entity.id] = os.epoch "utc"
                end
            end

            if known_players[entity.name] then
                count = count + 1
            end
        end
    end
    local now = os.epoch "utc"
    for entity_id, time in pairs(not_players) do
        if (now - 60000) >= time then
            not_players[entity_id] = nil
        end
    end
    term.setCursorPos(1, 1)
    term.clear()
    print("Welcome to GTech(tm) Omniscient Surveillance Apparatus(tm).", count, "players found.")
    push_metric("player_count/" .. location_name, "players in a facility", count)
    sleep(5)
end