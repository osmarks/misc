function g64(tbl)
    for i=1,#tbl do
        local total = 0
        repeat
            local count = peripheral.call("front", "pushItems", "south", 1, 64, tbl[i])
			if count == 0 then sleep(0.5) end
            print(tbl[i], count)
            total = total + count
        until total == 64 or turtle.getItemCount(tbl[i]) == 64
    end
end
local function push()
    peripheral.call("top", "pullItems", "down", 4, 64, 1)
end
turtle.select(4)
while true do
    g64 {1,2,3,5,6,7,9,10,11}
	push()
	while turtle.getItemCount(4) > 0 do sleep(0.5) push() end
    turtle.craft()
end