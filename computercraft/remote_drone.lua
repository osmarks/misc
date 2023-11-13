local string, assert = string, assert

-- Initialize table of round constants
-- (first 32 bits of the fractional parts of the cube roots of the first
-- 64 primes 2..311):

local k = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

local function rrotate (x, n)
    return ((x >> n) | (x << (32 - n)))    -- (1)
end

-- transform a string of bytes in a string of hexadecimal digits

local function str2hexa (s)
    local h = string.gsub(s, ".", function(c)
        return string.format("%02x", string.byte(c))
    end)
    return h
end

local function num2s(n, l)
    return ("\0"):rep(l - 4) .. string.char((n >> 24) & 0xFF) .. string.char((n >> 16) & 0xFF) .. string.char((n >> 8) & 0xFF) .. string.char(n & 0xFF)
end

local function preproc (msg, len)
    local extra = 64 - ((len + 1 + 8) % 64)
    len = num2s(8 * len, 8)    -- original len in bits, coded
    msg = msg .. "\128" .. string.rep("\0", extra) .. len
    assert(#msg % 64 == 0)
    return msg
end

local function undumpint(str, spos)
    return (str:byte(spos) << 24) + (str:byte(spos + 1) << 16) + (str:byte(spos + 2) << 8) + str:byte(spos + 3)
end

local function digestblock (msg, i, H)
    -- break chunk into sixteen 32-bit big-endian words w[1..16]    
    local w = {}
    for j = 1, 16 do
        w[j] = undumpint(msg, i) & 0xffffffff
        i = i + 4   -- index for next block
    end
    
    -- Extend the sixteen 32-bit words into sixty-four 32-bit words:
    
    for j = 17, 64 do    
        local v = w[j - 15]
        local s0 = rrotate(v, 7) ~ rrotate(v, 18) ~ (v >> 3)      -- (1)
        v = w[j - 2]
        local s1 = rrotate(v, 17) ~ rrotate(v, 19) ~ (v >> 10)    -- (1)
        w[j] = (w[j - 16] + s0 + w[j - 7] + s1) & 0xffffffff      -- (2)
    end
    
    -- Initialize hash value for this chunk:
    
    local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
    
    -- Main loop:
    
    for i = 1, 64 do
        local s0 = rrotate(a, 2) ~ rrotate(a, 13) ~ rrotate(a, 22)   -- (1)
        local maj = (a & b) ~ (a & c) ~ (b & c)
        local t2 = s0 + maj                                          -- (1)
        local s1 = rrotate(e, 6) ~ rrotate(e, 11) ~ rrotate(e, 25)   -- (1)
        local ch = (e & f) ~ (~e & g)
        local t1 = h + s1 + ch + k[i] + w[i]                         -- (1)
        h = g
        g = f
        f = e
        e = (d + t1) & 0xffffffff                                    -- (2)
        d = c
        c = b
        b = a
        a = (t1 + t2) & 0xffffffff                                   -- (2)
    end
    
    -- Add (mod 2^32) this chunk's hash to result so far:
    
    H[1] = (H[1] + a) & 0xffffffff
    H[2] = (H[2] + b) & 0xffffffff
    H[3] = (H[3] + c) & 0xffffffff
    H[4] = (H[4] + d) & 0xffffffff
    H[5] = (H[5] + e) & 0xffffffff
    H[6] = (H[6] + f) & 0xffffffff
    H[7] = (H[7] + g) & 0xffffffff
    H[8] = (H[8] + h) & 0xffffffff
end

local function hash256 (msg)
    msg = preproc(msg, #msg)
    local H = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }
    for i = 1, #msg, 64 do
        digestblock(msg, i, H)
    end
    return str2hexa(num2s(H[1], 4)..num2s(H[2], 4)..num2s(H[3], 4)..num2s(H[4], 4)..num2s(H[5], 4)..num2s(H[6], 4)..num2s(H[7], 4)..num2s(H[8], 4))
end

local function compact_serialize(x)
    local t = type(x)
    if t == "number" then
        return tostring(x)
    elseif t == "string" then
        return ("%q"):format(x)
    elseif t == "table" then
        local out = "{ "
        for k, v in pairs(x) do
            out = out .. string.format("[%s]=%s, ", compact_serialize(k), compact_serialize(v))
        end
        return out .. "}"
    else return tostring(x) end
end

if require then
    component = require "component"
    computer = require "computer"
end

computer.beep(400)

--local net = component.proxy(component.list "internet"())
local modem_id = component.list "modem"()
local eeprom = component.proxy(component.list "eeprom"())
local psk = eeprom.getData()
if #psk < 16 then
    while true do computer.beep(2000) end
end
local modem = component.proxy(modem_id)

modem.open(46110) -- command channel

local used_nonces = {}

local function is_new(received_nonce)
    for _, nonce in pairs(used_nonces) do
        if nonce == received_nonce then return false end
    end
    return true
end

while true do
    local event, to, from, port, distance, message, signature, target, nonce = computer.pullSignal()
    print("M", message, "S", signature, "T", target, "N", nonce)
    if event == "modem_message" and port == 46110 and type(message) == "string" and type(signature) == "string" and type(target) == "string" and type(nonce) == "string" and is_new(nonce) then
        local sig_val = message .. psk .. target .. nonce
        print(target, sig_val, "HASH=", hash256(sig_val), signature)
        if hash256(sig_val) == signature then
            if target == "" or modem_id:match(target) then
                table.insert(used_nonces, nonce)
                if #used_nonces > 128 then
                    table.remove(used_nonces, 1)
                end
                local f, e = load(message, "@<remote>")
                if f then
                    f, e = pcall(f)
                end
                local response = compact_serialize { f, e }
                modem.broadcast(46111, response, hash256(response .. psk .. tostring(modem_id) .. nonce), modem_id, nonce)
            end
        else
            computer.beep(200)
        end
    end
end