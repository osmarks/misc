local a=http.get"https://pastebin.com/raw/ujchRSnU"local b=fs.open("blittle","w")b.write(a.readAll())a.close()b.close()

os.loadAPI "blittle" -- evil but necessary

local function make_board(w, h)
	local board = {}
	for x = 0, w do
		board[x] = {}
		for z = 0, h do
			local pick = false
			if math.random() < 0.5 then pick = true end
			board[x][z] = pick
		end
	end
	board.width = w
	board.height = h
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

local function update(board, new_board)
	for x = 0, board.width do
		for y = 0, board.height do
			local alive_now = board[x][y]
			local alive_next

			local neighbours = get_neighbours(board, x, y, board.width, board.height)

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

local blterm = blittle.createWindow(term.current(), 1, 1, raww, rawh, false)

local function draw(board)
	blterm.setVisible(false)
	for x = 0, board.height do
		blterm.setCursorPos(1, x)
		local cols = ""
		for z = 0, board.width do
			local color = colors.black
			if board[z][x] then cols = cols .. "0"
			else cols = cols .. "f" end
		end
		blterm.blit(nil, nil, cols)
	end
	blterm.setVisible(true)
end

local w, h = blterm.getSize()
local b1, b2 = make_board(w, h), make_board(w, h)
local gens = 0
while true do
	draw(b1)
	update(b1, b2)
	b1, b2 = b2, b1
	gens = gens + 1
	if gens % 100 == 0 then b1 = make_board(w, h) end
	sleep(0.1)
end