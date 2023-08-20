#!/usr/bin/env python
from mpris2 import get_players_uri, Player
from os.path import expanduser
savepath = expanduser("~/.local/share/last_media.txt")
players = list(get_players_uri())
last = None
try:
    with open(savepath) as f:
        last = f.read()
except:
    pass

players = list(get_players_uri())
for player_uri in players:
    player = Player(dbus_interface_info={"dbus_uri": player_uri})
    if player.PlaybackStatus == "Playing":
        player.Pause()
        with open(savepath, "w") as f:
            f.write(player_uri)
        break
else:
    if last in players:
        Player(dbus_interface_info={"dbus_uri": last}).Play()
    else:
        player.Play()