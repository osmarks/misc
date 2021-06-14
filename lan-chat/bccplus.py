#!/usr/bin/env python3

import socket
import threading
import time
import sys
import subprocess
import os
import collections
import getpass
import re
import random
import ipaddress
import itertools
import struct

PORT = 44718
IPPROTO_IPV6 = getattr(socket, "IPPROTO_IPV6") if "IPPROTO_IPV6" in dir(socket) else 41 # workaround for weird Windows/old Python quirk

maddr = ("ff15::aeae", 44718)

def configure_multicast(maddr, ifn):
    mip, port = maddr
    haddr = socket.getaddrinfo("::", port, socket.AF_INET6, socket.SOCK_DGRAM)[0][-1]
    maddr = socket.getaddrinfo(mip, port, socket.AF_INET6, socket.SOCK_DGRAM)[0][-1]

    sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)

    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    if hasattr(socket, "SO_REUSEPORT"):
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)

    sock.setsockopt(IPPROTO_IPV6, socket.IPV6_MULTICAST_LOOP, 1)
    sock.setsockopt(IPPROTO_IPV6, socket.IPV6_MULTICAST_HOPS, 5)

    ifn = struct.pack("I", ifn)
    sock.setsockopt(IPPROTO_IPV6, socket.IPV6_MULTICAST_IF, ifn)

    group = socket.inet_pton(socket.AF_INET6, mip) + ifn
    sock.setsockopt(IPPROTO_IPV6, socket.IPV6_JOIN_GROUP, group)

    sock.bind(haddr)

    return sock, maddr

def chunks(l, n):
    n = max(1, n)
    return [l[i:i+n] for i in range(0, len(l), n)]

def recv(q, iface):
    s, _ = configure_multicast(maddr, iface)

    while True:
        data, peer = s.recvfrom(2048)
        peer = peer[0].split("%")[0], peer[1]
        q.put((data, peer))

def normalize_ip(ip):
    return str(ipaddress.ip_address(ip))

def shorthex(x): return "{:04x}".format(x)
def encode_packet(ty, nick, content):
    return struct.pack("!BH16s", ty, local_id, nick.encode("utf-8")) + content.encode("utf-8")
def decode_packet(pkt):
    ty, local_id, nick = struct.unpack("!BH16s", pkt[:19])
    content = pkt[19:]
    return ty, local_id, nick.rstrip(b"\0").decode("utf-8"), content.decode("utf-8")

MTY_PING = 0
MTY_MESSAGE = 1

if __name__ == "__main__":
    mynick = getpass.getuser() + "@" + socket.gethostname()
    peers = {}
    local_id = random.randint(0, 0xFFFF)

    # dark horrors, TODO refactor into more consistent interface (no pun intended)
    if sys.platform.startswith("win32"):
        out = subprocess.check_output(["ipconfig"])
        match = re.search(b"\n +Link-local IPv6 Address[ .]: ([a-f0-9:])%([0-9]+)", out)
        own_ips = {match.group(1)}
        iface = int(match.group(2))
        for match in re.findall(b"\n +IPv6 Address[ .]: ([a-f0-9:])", out):
            own_ips.add(match.group(1))
    else:
        try:
            raise PermissionError
            addrs = collections.defaultdict(set)
            for line in open("/proc/net/if_inet6").readlines():
                addr, ifnum, _, _, _, ifname = line.split()
                ifnum = int(ifnum, 16)
                addr = normalize_ip(":".join(chunks(addr, 4)))
                addrs[ifnum].add(addr)
                if ("wlan" in ifname or ifname.startswith("en") or ifname.startswith("eth")) and addr.startswith("fe80"):
                    iface = ifnum
            if not iface: raise SystemExit("No suitable interface found, suffer")
            own_ips = addrs[iface]
        except PermissionError:
            out =  subprocess.check_output(["ip", "addr", "show"]).decode("ascii")
            addrs = collections.defaultdict(set)
            for line in out.split("\n"):
                match = re.match("([0-9]+): ([A-Za-z0-9-_]+):", line)
                if match:
                    num, ifname = int(match.group(1)), match.group(2)
                    current_if = num
                    if "wlan" in ifname or ifname.startswith("en") or ifname.startswith("eth"):
                        iface = num
                match = re.match(" +inet6 ([a-z0-9:]+)/", line)
                if match:
                    addrs[current_if].add(match.group(1))
            own_ips = addrs[iface]

    print("IP:", own_ips, "Iface:", ifname or iface, "LocID:", shorthex(local_id))

    proc = None
    if sys.platform.startswith("win32"):
        from multiprocessing import Process, Queue
        packet_queue = Queue()
        proc = Process(target=recv, args=(packet_queue, iface))
        proc.start()
    else:
        import queue
        packet_queue = queue.Queue()
        thread = threading.Thread(target=recv, args=(packet_queue, iface)).start()

    def queuereader():
        while True:
            data, (remote_addr, _) = packet_queue.get()
            try:
                ty, remote_local_id, nick, content = decode_packet(data)
                if remote_addr in own_ips and remote_local_id == local_id: continue
                peer_id = remote_addr + "/" + shorthex(remote_local_id)
                try:
                    peer = peers[peer_id]
                    peer["ping_countdown"] = 5
                    if nick != peer["nick"]:
                        print("! %s (%s) is now %s" % (peer["nick"], peer_id, nick))
                        peer["nick"] = nick
                except KeyError:
                    print("! %s (%s) now exists" % (nick, peer_id))
                    peers[peer_id] = { "nick": nick, "ping_countdown": 5 }
                if ty == MTY_MESSAGE:
                    print(nick + ": " + content)
            except Exception as e:
                print("Parse error", e)

    s, dest = configure_multicast(maddr, iface)

    def pinger():
        while True:
            s.sendto(encode_packet(MTY_PING, mynick, ""), dest)
            for id, peer in list(peers.items()):
                peer["ping_countdown"] -= 1
                if peer["ping_countdown"] <= 0:
                    del peers[id]
                    print("! %s (%s) no longer exists" % (peer["nick"], id))
            time.sleep(1)

    threading.Thread(target=queuereader).start()
    threading.Thread(target=pinger).start()

    try:
        while True:
            msg = input("> ")
            if msg.startswith("/nick "):
                newnick = msg[6:]
                if len(newnick.encode("utf-8")) > 16:
                    print("! Max nick length is 16 bytes")
                else:
                    print("! You are now", newnick)
                    mynick = newnick
            elif msg.startswith("/peer"):
                p = ["%s (%s)" % (i, p["nick"]) for i, p in peers.items()]
                print("! Peers:", " ".join(p))
            else:
                s.sendto(encode_packet(MTY_MESSAGE, mynick, msg), dest)
                time.sleep(0.05)
    except KeyboardInterrupt:
        if proc: proc.terminate()
        os._exit(0)

# in case of things
"""
AF_INET AddressFamily.AF_INET
AF_INET6 AddressFamily.AF_INET6
IPPROTO_IPV6 41
IPV6_CHECKSUM 7
IPV6_DONTFRAG 62
IPV6_DSTOPTS 59
IPV6_HOPLIMIT 52
IPV6_HOPOPTS 54
IPV6_JOIN_GROUP 20
IPV6_LEAVE_GROUP 21
IPV6_MULTICAST_HOPS 18
IPV6_MULTICAST_IF 17
IPV6_MULTICAST_LOOP 19
IPV6_NEXTHOP 9
IPV6_PATHMTU 61
IPV6_PKTINFO 50
IPV6_RECVDSTOPTS 58
IPV6_RECVHOPLIMIT 51
IPV6_RECVHOPOPTS 53
IPV6_RECVPATHMTU 60
IPV6_RECVPKTINFO 49
IPV6_RECVRTHDR 56
IPV6_RECVTCLASS 66
IPV6_RTHDR 57
IPV6_RTHDRDSTOPTS 55
IPV6_RTHDR_TYPE_0 0
IPV6_TCLASS 67
IPV6_UNICAST_HOPS 16
IPV6_V6ONLY 26
SOL_ALG 279
SOL_HCI 0
SOL_IP 0
SOL_RDS 276
SOL_SOCKET 1
SOL_TCP 6
SOL_TIPC 271
SOL_UDP 17
"""