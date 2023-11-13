local function fill_arr(length, with)
	local t = {}
	for i = 1, length do
		t[i] = 0
	end
	return t
end

--[[
registers are 16 bits
registers 0 to 15 are r0 to rf
register 0 always contains 0 because this makes many things more elegant
register 15 is additionally the program counter because why not
]]

local function init(code)
	-- preallocate 64KiB of memory
	-- 64KiB is enough for anyone
	-- (TODO: allow moar somehow?)
	local memory = fill_arr(65536, 0)
	-- load code into memory, at start
	for i = 1, #code do
		memory[i] = code:byte(i)
	end
	return {
		memory = memory,
		registers = fill_arr(16, 0)
	}
end

--[[
instructions (everything >8 bits is big endian):
HALT - 00 - halt execution
NOP  - 01 - do nothing
PEEK - 02 [register 1][register 2] [16-bit constant] - load value at (constant + ri2) in memory into ri1
POKE - 03 [register 1][register 2] [16-bit constant] - ↑ but other way round
ADD  - 04 [register 1][register 2] [16-bit constant] - save (constant + ri2) to ri1
JEQ  - 05 [register 1][register 2] [16-bit constant] - set program counter to constant if ri1 = ri2
JNE  - 06 [register 1][register 2] [16-bit constant] - set program counter to constant if ri1 != ri2
JLT  - 07 [register 1][register 2] [16-bit constant] - set program counter to constant if ri1 < ri2
SUB  - 08 [register 1][register 2] [16-bit constant] - save (ri2 - constant) to ri1
MUL  - 09 [register 1][register 2] [16-bit constant] - save (ri2 * constant) to ri1
DIV  - 10 [register 1][register 2] [16-bit constant] - save (ri2 / constant) to ri1
MOD  - 11 [register 1][register 2] [16-bit constant] - save (ri2 % constant) to ri1
SYSC - 12 something whatever TODO

TODO: bitops, syscalls

Integers are always unsigned because negative numbers are hard.
]]

local band = bit.band
local brshift = bit.brshift

local function hi_nybble(x) return brshift(x, 4) end
local function lo_nybble(x) return band(x, 0xF) end
local function u16from(hi, lo) return hi * 0x100 + lo end
local function truncate(x) return band(0xFFFF, x) end
local function u16_add(x, y) return truncate(x + y) end
local function u16_sub(x, y) return truncate(x - y) end
local function u16_div(x, y) return truncate(x / y) end
local function u16_mod(x, y) return truncate(x % y) end
local function u16to(x) return brshift(x, 8), band(x, 0xFF) end

local function step(state)
	local function get_reg(ix)
		if ix == 0 then return 0
		else return state.registers[ix + 1] end
	end
	local function set_reg(ix, x) if ix ~= 0 then state.registers[ix + 1] = x end end
	local function get_mem(pos)
		return u16from(state.memory[pos + 1], state.memory[pos  + 2])
	end
	local function set_mem(pos, x)
		local b1, b2 = u16to(x)
		state.memory[pos + 1] = b1
		state.memory[pos + 2] = b2
	end

	local bpos = state.registers[16]
	-- read four bytes from program counter location onward
	local b1, b2, b3, b4 = unpack(state.memory, bpos + 1, bpos + 5)

	-- increment program counter
	state.registers[16] = bpos + 4
	if state.registers[16] > #state.memory then
		return false
	end

	-- HALT
	if b1 == 0x00 then
		return false
	-- NOP
	elseif b1 == 0x01 then
		-- do nothing whatsoever
		-- still doing nothing
	-- PEEK
	elseif b1 == 0x02 then
		-- calculate address - sum constant + provided register value
		local addr = u16_add(u16from(b3, b4), get_reg(lo_nybble(b2)))
		set_reg(hi_nybble(b2), get_mem(addr))
	-- POKE
	elseif b1 == 0x03 then
		local addr = u16_add(u16from(b3, b4), get_reg(lo_nybble(b2)))
		set_mem(addr, get_reg(hi_nybble(b2)))
	-- ADD
	elseif b1 == 0x04 then
		set_reg(hi_nybble(b2), u16_add(u16from(b3, b4), get_reg(lo_nybble(b2))))
	-- JEQ
	elseif b1 == 0x05 then
		if get_reg(hi_nybble(b2)) == get_reg(lo_nybble(b2)) then
			state.registers[16] = u16from(b3, b4)
		end
	-- JNE - maybe somehow factor out the logic here, as it's very close to JEQ
	elseif b1 == 0x06 then
		if get_reg(hi_nybble(b2)) ~= get_reg(lo_nybble(b2)) then
			state.registers[16] = u16from(b3, b4)
		end
	-- JLT - see JNE
	elseif b1 == 0x07 then
		if get_reg(hi_nybble(b2)) < get_reg(lo_nybble(b2)) then
			state.registers[16] = u16from(b3, b4)
		end
	-- SUB
	elseif b1 == 0x08 then
		set_reg(hi_nybble(b2), u16_sub(get_reg(lo_nybble(b2)), u16from(b3, b4)))
	-- MUL
	elseif b1 == 0x09 then
		set_reg(hi_nybble(b2), u16_mul(u16from(b3, b4), get_reg(lo_nybble(b2))))
	-- DIV
	elseif b1 == 0x10 then
		set_reg(hi_nybble(b2), u16_div(get_reg(lo_nybble(b2)), u16from(b3, b4)))
	-- MOD
	elseif b1 == 0x11 then
		set_reg(hi_nybble(b2), u16_mod(get_reg(lo_nybble(b2)), u16from(b3, b4)))
	-- TEST
	elseif b1 == 0xFF then
		for i, v in ipairs(state.registers) do
			print(("r%x: %04x"):format(i - 1, v))
		end
	else
		error(("illegal opcode %02x at %04x"):format(b1, state.registers[16]))
	end

	return true
end

local function unhexize(s)
	local s = s:gsub("[^0-9A-Fa-f]", "")
	local out = {}
	for i = 1, #s, 2 do
		local pair = s:sub(i, i + 1)
		table.insert(out, string.char(tonumber(pair, 16)))
	end
	return table.concat(out)
end

local state = init(unhexize [[04 b0 00 08
04 10 01 ff
04 e0 ff 02
03 e0 a0 00
04 de 03 01
02 c0 a0 00
02 dd a0 00
ff 00 00 00
04 44 00 01
03 40 20 01
04 aa 00 01
07 ab 00 00]])

while step(state) do end