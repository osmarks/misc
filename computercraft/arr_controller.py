import asyncio
import websockets
import umsgpack
import random
import time
import collections
import functools
import json
import math
import queue

SwitchConfig = collections.namedtuple("SwitchConfig", ["states", "connections", "position"])
Connection = collections.namedtuple("Connection", ["destination_switch", "destination_side", "metric"], defaults=[None, None, None])

def vecdistance(a, b): return math.sqrt(sum((p - q) ** 2 for p, q in zip(a, b)))
def invert(x): return { v: k for k, v in x.items() }
def make_bijection(x): return {**x, **invert(x)}

north_tjunction = (
    { "east": "north", "north": "east", "west": "east" },
    { "east": "west", "north": "west", "west": "north" }
)
south_tjunction = (
    { "east": "south", "south": "east", "west": "east" },
    { "east": "west", "south": "west", "west": "south" }
)
east_tjunction = (
    { "north": "south", "east": "south", "south": "east" },
    { "north": "east", "east": "north", "south": "north" }
)
west_tjunction = (
    { "south": "west", "west": "south", "north": "south" },
    { "west": "north", "north": "west", "south": "north" }
)
switch_configs = {
    "SW1": SwitchConfig(north_tjunction, {
        "north": Connection("SW2", "south"),
        "west": Connection("SW3", "east"),
        "east": Connection("SW1", "east", 8)
    }, (-5344, 95, 3108)),
    "SW2": SwitchConfig(south_tjunction, {
        "south": Connection("SW1", "north"),
        "west": Connection("SW4", "east"),
        "east": Connection("SW5", "south")
    }, (-5344, 95, 3090)),
    "SW3": SwitchConfig(north_tjunction, {
        "east": Connection("SW1", "west"),
        "north": Connection("SW4", "south"),
        #"west": Connection("SW3", "west")
    }, (-5360, 95, 3108)),
    "SW4": SwitchConfig(east_tjunction, {
        "east": Connection("SW2", "west"),
        "south": Connection("SW3", "north"),
        "north": Connection("SW4", "north", 24)
    }, (-5361, 95, 3091)),
    "SW5": SwitchConfig(west_tjunction, {
        "south": Connection("SW2", "east"),
        "west": Connection("SW6", "east"),
        "north": Connection("SW8", "south")
    }, (-5325, 94, 3084)),
    "SW6": SwitchConfig(east_tjunction, {
        "east": Connection("SW5", "west"),
        "south": Connection("SW6", "south", 6),
        "north": Connection("SW7", "east")
    }, (-5338, 94, 3079)),
    "SW7": SwitchConfig(east_tjunction, {
        "east": Connection("SW6", "north"),
        "south": Connection("SW7", "south", 6),
        #"north": Connection("SW7", "north", 6),
    }, (-5347, 94, 3074)),
    "SW8": SwitchConfig(south_tjunction, {
        "south": Connection("SW5", "north"),
        #"west": Connection("SW8", "west", 6),
        "east": Connection("SW8", "east", 6)
    }, (-5323, 93, 3069)),
}

for id, config in switch_configs.items():
    for side, connection in config.connections.items():
        if connection.metric is None:
            metric = vecdistance(config.position, switch_configs[connection.destination_switch].position)
            config.connections[side] = Connection(destination_switch=connection.destination_switch, destination_side=connection.destination_side, metric=metric)

stations = {
    "Test2": ("SW3", "west"),
    "Test1": ("SW8", "west"),
    "Test3": ("SW7", "north")
}
switches = {}
riders = {}
known_player_locations = {}
opposites = make_bijection({"north": "south", "east": "west"})
colors = {"north": 0b11111_00000_00000, "south": 0b00000_00000_11111, "east": 0b00000_11111_00000, "west": 0b11111_11111_00000}
unavailable_segments = collections.defaultdict(dict)

def build_graph(switch_configs):
    graph = collections.defaultdict(dict)
    for switch, config in switch_configs.items():
        for state in config.states:
            for in_side, out_side in state.items():
                graph[(switch, in_side, "inbound")][(switch, out_side, "outbound")] = 1
        for side, connection in config.connections.items():
            graph[(switch, side, "outbound")][(connection.destination_switch, connection.destination_side, "inbound")] = connection.metric
    return graph

graph = build_graph(switch_configs)

def bfs(target, start, is_unavailable):
    def heuristic(x, y): return vecdistance(switch_configs[x[0]].position, switch_configs[y[0]].position)
    
    frontier = queue.PriorityQueue()
    frontier.put((0, start))
    reached_from = {start: None}
    best_cost_to = {start: 0}

    while not frontier.empty():
        _, current = frontier.get()
        current_cost = best_cost_to[current]

        if current == target:
            break

        for next_node, hop_cost in graph[current].items():
            new_cost = current_cost + hop_cost
            if not is_unavailable(next_node) and (next_node not in best_cost_to or best_cost_to[next_node] > new_cost):
                reached_from[next_node] = current
                best_cost_to[next_node] = new_cost
                frontier.put((new_cost + heuristic(target, next_node), next_node))

    try:
        current = target
        path = []
        while current != start:
            path.append(current)
            current = reached_from[current]
        path.reverse()
        return path
    except KeyError:
        # route cannot be routed
        return None

def get_target_side(cart_id, current_switch, current_side, target):
    def is_unavailable(segment):
        for occupying_cart in unavailable_segments[segment]:
            if occupying_cart != cart_id:
                return True
        return False
    path = bfs(target + ("outbound",), (current_switch, current_side, "inbound"), is_unavailable)
    if path == [] or path == None:
        print("already there or failed")
        return current_side
    print(path, target)
    return path[0][1]

async def connect():
    send = None
    chat_tell = None
    async def socket_connection():
        async with websockets.connect("wss://spudnet.osmarks.net/v4?enc=msgpack") as websocket:
            nonlocal send
            send = lambda x: websocket.send(umsgpack.dumps(x))
            await send({"type": "identify", "key": "[REDACTED]", "channels": ["comm:arr"]})
            while True:
                data = umsgpack.loads(await websocket.recv())
                if data["type"] == "ping":
                    await send({"type": "pong", "seq": data["seq"]})
                elif data["type"] == "message":
                    info = data["data"]
                    if info["type"] == "sw_ping":
                        switch_id = info["id"]
                        switches[switch_id] = { "carts": info["carts"], "last_ping": time.time() }
                        switch = switch_configs[switch_id]

                        for cart in sorted(info["carts"], key=lambda k: k["distance"]):
                            if "dir" in cart and "pos" in cart:
                                # a thing is "inbound" relative to a switch unit if its movement direction and position are opposite
                                # otherwise, it's outbound
                                # things going in the same direction can share the same track, though, so we want to block off the *opposite* segment
                                unavailable_direction = "outbound" if opposites[cart["dir"]] == cart["pos"] else "inbound"
                                cart_id = cart["id"]
                                # clear out existing reservations by this cart
                                for segment, carts in unavailable_segments.items():
                                    if cart_id in carts:
                                        del carts[cart_id]
                                now = time.time()
                                unavailable_segments[(switch_id, cart["pos"], unavailable_direction)][cart_id] = now
                                # connections are indexed by outbound direction from the switch
                                if connection := switch.connections.get(cart["pos"]):
                                    opposite = "outbound" if unavailable_direction == "inbound" else "inbound"
                                    unavailable_segments[(connection.destination_switch, connection.destination_side, opposite)][cart_id] = now
                        for cart in sorted(info["carts"], key=lambda k: k["distance"]):
                            #print(cart)
                            rider = [ rider for rider in cart["riders"] if rider in riders ]
                            if "dir" in cart and "pos" in cart and opposites[cart["dir"]] == cart["pos"] and rider:
                                rider = rider[0]
                                target = get_target_side(cart["id"], switch_id, cart["pos"], riders[rider])
                                print("at", switch_id, "cart inbound on", cart["pos"], "with", cart["riders"], "set target side to", target)
                                switch_state = None
                                for i, state in enumerate(switch.states):
                                    if state[cart["pos"]] == target:
                                        switch_state = i
                                print("set state to", switch_state)
                                await send({"type": "send", "channel": "comm:arr", "data": 
                                    {"type": "sw_cmd", "cmd": "set", "lamp": colors[target],
                                    "switch": switch_state, "id": switch_id, "cid": random.randint(0, 0xFFFF_FFFF)}})

                    elif info["type"] == "st_ping":
                        for player in info["players"]:
                            known_player_locations[player] = (info["id"], time.time())

                    elif info["type"] == "st_ack":
                        if info["cid"]:
                            await chat_tell(info["cid"], { "done": "Cart dispensed.", "no_cart": "Sorry, out of carts.", "busy": "System in use." }.get(info["status"], info["status"]))

                elif data["type"] == "ok": pass
                else:
                    print(data)
    async def clear_switches():
        while True:
            clear = set()
            now = time.time()
            for id, switch in switches.items():
                if now - switch["last_ping"] >= 2:
                    clear.add(id)
            for clr in clear:
                del switches[clr]

            for segment, carts in unavailable_segments.items():
                clear = set()
                for cart_id, reserved_at in carts.items():
                    if now - reserved_at >= 15:
                        print("unreserve", cart_id)
                    clear.add(cart_id)
                for clr in clear:
                    del carts[clr]

            await asyncio.sleep(2)

    async def switchcraft_chat():
        async with websockets.connect("wss://chat.switchcraft.pw/[REDACTED]") as websocket:
            nonlocal chat_tell
            chat_tell = lambda name, msg: websocket.send(json.dumps({ "type": "tell", "user": name, "text": "[ARR] " + msg, "mode": "markdown" }))
            while True:
                packet = json.loads(await websocket.recv())
                if packet["type"] == "command":
                    if packet["command"] == "arr":
                        name = packet["user"]["name"]
                        if name == "PatriikPlays": return
                        try:
                            print(name, packet["args"])
                            if packet["args"][0] == "dest":
                                assert packet["args"][1] in switch_configs, "wrong"
                                riders[name] = packet["args"][1], packet["args"][2]
                                print("set ", name, packet["args"][1], packet["args"][2])

                                await chat_tell(name, "Done!")
                            
                            elif packet["args"][0] == "update" and name == "gollark":
                                await send({"type": "send", "channel": "comm:arr", "data": 
                                    { "type": "sw_cmd", "cmd": "update" }})
                                await send({"type": "send", "channel": "comm:arr", "data": 
                                    { "type": "st_cmd", "cmd": "update" }})

                                await chat_tell(name, "Done!")
                            
                            elif packet["args"][0] == "rdest" and name == "gollark":
                                assert packet["args"][1] in switch_configs, "wrong"
                                riders[packet["args"][3]] = packet["args"][1], packet["args"][2]
                                print("set ", packet["args"][3], packet["args"][1], packet["args"][2])
                            
                                await chat_tell(name, "Done!")

                            elif packet["args"][0] == "rto":
                                station = stations.get(packet["args"][1])
                                if station:
                                    riders[name] = station
                                    await chat_tell(name, "Destination set.")
                                else:
                                    await chat_tell(name, "Try going somewhere extant.")

                            elif packet["args"][0] == "goto":
                                if name in known_player_locations and (time.time() - 5) <= known_player_locations[name][1]:
                                    loc = known_player_locations[name][0]
                                    await chat_tell(name, f"You are at {loc}.")
                                    station = stations.get(packet["args"][1])
                                    if station:
                                        riders[name] = station
                                        await chat_tell(name, "Destination set. Dispensing cart.")
                                        await send({"type": "send", "channel": "comm:arr", "data": 
                                            { "type": "st_cmd", "cmd": "place_cart", "cid": name, "id": loc }})
                                    else:
                                        await chat_tell(name, "Try going somewhere extant.")
                                else:
                                    await chat_tell(name, "You are in the wrong place.")

                        except Exception as e:
                            await chat_tell(name, repr(e))

    async def repeatedly_do_switchcraft_chat_for_bad_reasons():
        while True:
            try:
                await switchcraft_chat()
            except Exception as e:
                print("connection failed probably", e)
                await asyncio.sleep(0.1)

    await asyncio.gather(clear_switches(), socket_connection(), repeatedly_do_switchcraft_chat_for_bad_reasons())

asyncio.run(connect())
