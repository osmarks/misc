import socket
import threading
import time
import sys
import os

BROADCAST_IP = "255.255.255.255"
PORT = 44718

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, True)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, True)
s.bind(("", PORT))

def recv():
    while True:
        try:
            data, (ip, port) = s.recvfrom(2048)
            print(ip + ": " + data.decode("utf8"))
        except Exception as e:
            print("parse error", e)

threading.Thread(target=recv).start()

try:
    while True:
        msg = input("> ").encode("utf8")
        s.sendto(msg, (BROADCAST_IP, PORT))
        time.sleep(0.05)
except KeyboardInterrupt:
    os._exit(0)