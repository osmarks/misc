local map = {}
local w = 300
local h = 300
local seed = 349259
require("perlin") -- not mine.
-- it uses globals. spiteful, but i do not care enough about code quality for this.


local biomecols = {
    empty      = {0.5, 0.5, 0.5},
    forest     = {  0, 0.5,   0},
    rainforest = {  0, 0.5, 0.5},
    ocean      = {  0,   0,   1},
    plains     = {  0,   1,   0},
    desert     = {  1,   1,   0},
}

local PERSISTENCE = 0.3
local ITERS = 4
local function oct_noise(x, y, seed, gen)
    local total = 0
    local frequency = 1
    local amplitude = 1
    local norm = 0
    for i = 1, ITERS do
        total = total + gen:noise(x * frequency, y * frequency, seed + i) * amplitude
        norm = norm + amplitude
        frequency = frequency * 2
        amplitude = amplitude * PERSISTENCE
    end
    return total
end

local sf = 1/20 -- scaling factor.
local function pick_biome(x, y, gen)
    local islandicity = gen:noise(x*sf/10, y*sf/10, 302382359)/2+1/2
    islandicity = math.min(math.max(0,islandicity*3),1)
    local mainland_modifier = gen:noise(x*sf/20, y*sf/20, 302382359)/2
    local is_ocean = gen:noise(x*sf/4, y*sf/4, 555575)/2+1/2 + gen:noise(x*sf, y*sf, 555575)/(25-islandicity*10) + mainland_modifier
    local humidity = oct_noise(x*sf/2, y*sf/2, 10000, gen)/2+1/2
    local temp = oct_noise(x*sf/6, y*sf/6, 20000, gen)/2+1/2
    --return { is_ocean, humidity, temp }
    --
    if is_ocean > 0.45 then return "ocean" end
    if is_ocean > 0.43 and humidity < 0.6 then return "desert" end -- coast?
    if temp > 0.75 then return "desert" end
    if humidity < 0.5 then
        if temp > 0.5 then
            return "desert"
        else
            return "plains"
        end
    else
        if humidity > 0.75 then
            return "rainforest"
        else
            if temp < 0.6 then
                return "forest"
            else
                return "plains"
            end
        end
    end
    return "empty"
    --]]
end

function love.load()
    local noise = perlin(seed)
    local gen = noise
    for x=1, w do
        map[x] = {}
        for y=1, h do
            map[x][y] = 0
        end
    end
    for x=1, w do
        for y=1, h do
            local biome = pick_biome(x, y, noise)
            --map[x][y] = biome
            map[x][y] = biomecols[biome]
        end
    end
end

function love.draw()
    for x=1, w do
        for y=1, h do
            love.graphics.setColor(unpack(map[x][y]))
            love.graphics.rectangle("fill",x*2, y*2, 2, 2)
        end
    end
end