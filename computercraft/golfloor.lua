local y = 135
local minx, maxx, minz, maxz = 2514, 2544, -1488, -1518
local w, h = maxx - minx, maxz - minz
local dead, alive = {"minecraft:concrete", 3}, {"minecraft:concrete", 0}

local function make_board()
local board = {}
	for x = 0, w do
		board[x] = {}
		for z = 0, h do
			local pick = false
			if math.random() < 0.5 then pick = true end
			board[x][z] = pick
		end
	end
	return board
end

local function wrap(n, max)
	return n % max
end

local function get_neighbours(board, x, y, w, h)
	local total = 0 
	for dx = -1, 1 do
		for dy = -1, 1 do
			if not (dx == 0 and dy == 0) then
				local thing = 0
				if board[wrap(x + dx, w)][wrap(y + dy, h)] then thing = 1 end
				total = total + thing
			end
		end
	end
	return total
end

local function setblock(x, y, z, state)
	local b
	if state then b = alive else b = dead end
	commands.execAsync(string.format("setblock %d %d %d %s %d", x, y, z, b[1], b[2]))
end

local function update(board, new_board)
	for x = 0, w do
		for y = 0, h do
			local alive_now = board[x][y]
			local alive_next

			local neighbours = get_neighbours(board, x, y, w, h)

			if alive_now then
				alive_next = neighbours == 2 or neighbours == 3
			else
				alive_next = neighbours == 3
			end

			new_board[x][y] = alive_next
		end
	end
	return new_board
end

local function draw(board)
	for x = 0, w do
		for z = 0, h do
			setblock(x + minx, y, z + minz, board[x][z])
		end
	end
end

local b1, b2 = make_board(), make_board()
local gens = 0
while true do
	draw(b1)
	update(b1, b2)
	b1, b2 = b2, b1
	gens = gens + 1
	if gens % 100 == 0 then b1 = make_board() end
	sleep(1)
end