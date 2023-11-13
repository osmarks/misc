local function spudnet()
    local channel = settings.get "offload_channel"

    if not http or not http.websocket then return "Websockets do not actually exist on this platform" end
    
    local ws
    local try_connect_loop, recv

    local function send_packet(msg)
        local ok, err = pcall(ws.send, textutils.serialiseJSON(msg))
        if not ok then printError(err) try_connect_loop() end
    end

    local function assert_ok(packet)
        if packet.type == "error" then error(("%s %s %s"):format(packet["for"], packet.error, packet.detail)) end
    end
 
    local function connect()
        if ws then ws.close() end
        local err
        local url = "wss://spudnet.osmarks.net/v4?enc=json&rand=" .. math.random(0, 0xFFFFFFF)
        ws, err = http.websocket(url)
        if not ws then print("websocket failure %s", err) return false end
        ws.url = url
 
        send_packet { type = "identify", implementation = "ni-ctl SPUDNET interface", key = settings.get "spudnet_key" }
        assert_ok(recv())
        send_packet { type = "set_channels", channels = {channel} }
        assert_ok(recv())
        return true
    end
    
    recv = function()
        while true do
            local e, u, x, y = os.pullEvent()
            if e == "websocket_message" and u == ws.url then
                return textutils.unserialiseJSON(x)
            elseif e == "websocket_closed" and u == ws.url then
                printError(("websocket: %s/%d"):format(x, y or 0))
            end
        end
    end

    try_connect_loop = function()
        while not connect() do
            sleep(0.5)
        end
    end
    
    try_connect_loop()
 
    local function send(data)
        send_packet { type = "send", channel = channel, data = data }
        assert_ok(recv())
    end
    
    local ping_timeout_timer = nil
 
    local function ping_timer()
        while true do
            local _, t = os.pullEvent "timer"
            if t == ping_timeout_timer and ping_timeout_timer then
                -- 15 seconds since last ping, we probably got disconnected
                print "SPUDNET timed out, attempting reconnect"
                try_connect_loop()
            end
        end
    end
    
    local function main()
        while true do
            local packet = recv()
            if packet.type == "ping" then
                send_packet { type = "pong", seq = packet.seq }
                if ping_timeout_timer then os.cancelTimer(ping_timeout_timer) end
                ping_timeout_timer = os.startTimer(15)
            elseif packet.type == "error" then
                print("SPUDNET error", packet["for"], packet.error, packet.detail, textutils.serialise(packet))
            elseif packet.type == "message" then
                os.queueEvent("spudnet_message", packet.data, packet)
            end
        end
    end
 
    return send, function() parallel.waitForAll(ping_timer, main) end
end

return spudnet