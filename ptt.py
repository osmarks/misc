#!/usr/bin/env python3
from pynput import keyboard
import subprocess
import wx
import wx.adv
import wx.lib.newevent
import sys
import os.path
import threading

scriptdir = os.path.dirname(os.path.abspath(sys.argv[0]))
red, green = os.path.join(scriptdir, "red.png"), os.path.join(scriptdir, "green.png")

l_key = keyboard.Key.f8
source = "alsa_input.usb-0c76_USB_PnP_Audio_Device-00.mono-fallback"

MuteSetEvent, EVT_MUTE_SET_EVENT = wx.lib.newevent.NewEvent()

class TaskBarIcon(wx.adv.TaskBarIcon):
	def __init__(self, frame):
		self.red_icon = wx.Icon(red)
		self.green_icon = wx.Icon(green)
		self.frame = frame
		super(TaskBarIcon, self).__init__()
		self.Bind(wx.adv.EVT_TASKBAR_LEFT_DOWN, self.on_left_down)
		self.Bind(EVT_MUTE_SET_EVENT, self.on_mute_set)
	
	def on_mute_set(self, event):
		self.set_icon(self.red_icon if event.muted else self.green_icon)

	def on_left_down(self, event):
		toggle()

	def set_icon(self, icon):
		self.SetIcon(icon, "PTT")

class App(wx.App):
	def OnInit(self):
		frame=wx.Frame(None)
		self.SetTopWindow(frame)
		self.taskbar_icon = TaskBarIcon(frame)
		return True

app = App(False)

muted = False

def mute():
	global muted
	if not muted:
		muted = True
		print("muted")
		subprocess.run(["pactl", "set-source-mute", source, "1"])
		# this could call set_icon on the taskbar icon object directly, but that seems to inconsistently cause mysterious crashes in cairo
		wx.PostEvent(app.taskbar_icon, MuteSetEvent(muted=muted))
def unmute():
	global muted
	if muted:
		muted = False
		print("unmuted")
		subprocess.run(["pactl", "set-source-mute", source, "0"])
		wx.PostEvent(app.taskbar_icon, MuteSetEvent(muted=muted))

def toggle():
	if muted: unmute()
	else: mute()

def on_press(key):
	if key == l_key: unmute()

def on_release(key):
	if key == l_key: mute()

mute()
threading.Thread(target=app.MainLoop).start()
with keyboard.Listener(
	on_press=on_press,
	on_release=on_release) as listener:
	try:
		listener.join()
	except KeyboardInterrupt:
		listener.stop()
		print("shutting down")
		unmute()
		app.Destroy()
		sys.exit(0)
