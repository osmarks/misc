local modem = peripheral.find("modem", function(_, o)
    return o.maxPacketSize ~= nil
end)
local sha256 = require "/sha256"
local psk = settings.get "psk"

local function tohex(t)
    local out = {}
    for _, val in pairs(t) do
        table.insert(out, ("%02x"):format(val))
    end
    return table.concat(out)
end

modem.open(46111)
while true do
    local input = read()
    local target = ""
    local nonce = {}
    for i = 1, 16 do
        table.insert(nonce, math.random(0, 255))
    end
    nonce = tohex(nonce)
    modem.transmit(46110, 46110, input, tohex(sha256.digest(input .. psk .. target .. nonce)), target, nonce)
    local ev = {os.pullEvent "modem_message"}
    if #ev == 8 then
        local response, signature, device, nonce = ev[5], ev[6], ev[7], ev[8]
        if tohex(sha256.digest(response .. psk .. device .. nonce)) == signature then
            local ok, err = unpack(textutils.unserialise(response))
            if ok then
                print(err)
            else
                printError(err)
            end
            print(device)
        end
    end
end