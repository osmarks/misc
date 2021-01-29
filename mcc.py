#!/usr/bin/env python3

import socket
import sys
import select
import time
import struct
import getpass
import asyncio
import prompt_toolkit, prompt_toolkit.widgets, prompt_toolkit.layout.containers, prompt_toolkit.application, prompt_toolkit.layout.layout, prompt_toolkit.key_binding, prompt_toolkit.document
import collections
import random
import netifaces

maddr = ("ff15::aeae", 44718)

def configure_multicast(maddr, ifn):
    mip, port = maddr
    haddr = socket.getaddrinfo("::", port, socket.AF_INET6, socket.SOCK_DGRAM)[0][-1]
    maddr = socket.getaddrinfo(mip, port, socket.AF_INET6, socket.SOCK_DGRAM)[0][-1]

    sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)

    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    if hasattr(socket, "SO_REUSEPORT"):
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)

    sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_MULTICAST_LOOP, 1)
    sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_MULTICAST_HOPS, 5)

    ifn = struct.pack("I", ifn)
    sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_MULTICAST_IF, ifn)

    group = socket.inet_pton(socket.AF_INET6, mip) + ifn
    sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_JOIN_GROUP, group)

    sock.bind(haddr)
    sock.setblocking(False)

    return sock, maddr

ta = prompt_toolkit.widgets.TextArea()

async def do_inputs(inq, out_callback):
    output = prompt_toolkit.widgets.TextArea()
    inp = prompt_toolkit.widgets.TextArea(height=1, prompt="[] ", multiline=False, wrap_lines=False)
    def accept(buffer):
        asyncio.get_event_loop().create_task(out_callback(buffer.text))
    inp.accept_handler = accept
    container = prompt_toolkit.layout.containers.HSplit([
        output,
        inp
    ])

    kb = prompt_toolkit.key_binding.KeyBindings()

    @kb.add("c-c")
    @kb.add("c-q")
    def _(event):
        sys.exit(0)
        event.app.exit()
    
    async def queue_watcher():
        while True:
            text = output.text + await inq.get() + "\n"
            if text.count("\n") > 100:
                text = "\n".join(text.split("\n")[1:])
            output.buffer.document = prompt_toolkit.document.Document(
                text=text, cursor_position=len(text) - 1
            )

    asyncio.get_event_loop().create_task(queue_watcher())

    await prompt_toolkit.Application(
        layout=prompt_toolkit.layout.layout.Layout(container, focused_element=inp),
        mouse_support=False,
        full_screen=False,
        key_bindings=kb
    ).run_async()

loop = asyncio.new_event_loop()

TYPE_PING = 0
TYPE_MESSAGE = 1

local_id = random.randint(0, 0xFFFF)

def shorthex(x): return "{:04x}".format(x)
def encode_packet(ty, nick, content):
    return struct.pack("!BH10s", ty, local_id, nick.encode("utf-8")) + content.encode("utf-8")
def decode_packet(pkt):
    ty, local_id, nick = struct.unpack("!BH10s", pkt[:13])
    content = pkt[13:]
    return ty, local_id, nick.rstrip(b"\0").decode("utf-8"), content.decode("utf-8")

Peer = collections.namedtuple("Peer", ["nick", "timeout_counter"])

async def run():
    try:
        interface = sys.argv[1]
        addrs = []
    except:
        for x in netifaces.interfaces():
            if "lo" not in x and netifaces.AF_INET6 in netifaces.ifaddresses(x):
                interface = x
                break
    if not interface:
        print("No valid network interface found")
        sys.exit(1)
    print("Using", interface)
    addrs = [a["addr"] for a in netifaces.ifaddresses(interface)[netifaces.AF_INET6]]
    ifn = socket.if_nametoindex(interface)
    sock, addr = configure_multicast(maddr, ifn)

    own_nick = getpass.getuser()
    peers = {}

    def cb():
        buf, remote = sock.recvfrom(2048)
        ip = remote[0]
        try:
            ty, lid, nick, content = decode_packet(buf)
            if lid == local_id and (addrs == [] or ip in addrs): return
            peer_id = ip + "/" + shorthex(lid)
            try:
                peer = peers[peer_id]
                if peer.nick != nick:
                    inq.put_nowait(f"! {peer.nick} ({peer_id}) is now {nick}")
            except KeyError:
                inq.put_nowait(f"! {nick} ({peer_id}) exists")
            peers[peer_id] = Peer(nick, 10)
            if ty == TYPE_MESSAGE:
                inq.put_nowait(f"{nick}: {content}")
        except Exception as e:
            inq.put_nowait(f"! Parse error {e} from {ip}")

    loop.add_reader(sock, cb)

    inq = asyncio.Queue()
    async def outq(s):
        if s.startswith("/nick "):
            newnick = s[6:]
            if len(newnick.encode("utf8")) > 10:
                inq.put_nowait("! Max nick length is 10 bytes")
                return
            inq.put_nowait(f"! You are now {newnick}")
            nonlocal own_nick
            own_nick = newnick
            return
        elif s.startswith("/peer"):
            p = [f"{p.nick} ({i})" for i, p in peers.items()]
            inq.put_nowait(f"! Peers: {', '.join(p)}")
            return
        inq.put_nowait(f"{own_nick}: {s}")
        sock.sendto(encode_packet(TYPE_MESSAGE, own_nick, s), addr)
    loop.create_task(do_inputs(inq, outq))

    while True:
        sock.sendto(encode_packet(TYPE_PING, own_nick, ""), addr)
        rem_queue = []
        for peer_id, peer in peers.items():
            count = peer.timeout_counter - 1
            if count == 0:
                rem_queue.append(peer_id)
                inq.put_nowait(f"! {peer.nick} ({peer_id}) no longer exists")
            else:
                peers[peer_id] = Peer(nick=peer.nick, timeout_counter=count)
        for r in rem_queue: del peers[r]
        await asyncio.sleep(1)

if __name__ == "__main__":
    loop.run_until_complete(run())