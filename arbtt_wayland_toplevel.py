#!/usr/bin/env python3
from functools import partial
from datetime import datetime, timezone
from wl_framework.network.connection import WaylandConnection
from wl_framework.protocols.base import UnsupportedProtocolError
from wl_framework.protocols.foreign_toplevel import ForeignTopLevel
from wl_framework.protocols.data_control import DataControl
from wl_framework.protocols.idle_notify import ( IdleNotifyManager, IdleNotifier as _IdleNotifier )
import asyncio.subprocess as subprocess
import orjson

class ForeignTopLevelMonitor(ForeignTopLevel):
	def __init__(self, *args, **kwargs):
		self.tlwindows = {}
		super().__init__(*args, **kwargs)

	def on_toplevel_created(self, toplevel):
		self.tlwindows[toplevel.obj_id] = {}

	def on_toplevel_synced(self, toplevel):
		self.tlwindows[toplevel.obj_id]["app_id"] = toplevel.app_id
		self.tlwindows[toplevel.obj_id]["title"] = toplevel.title
		self.tlwindows[toplevel.obj_id]["states"] = toplevel.states
		self.tlwindows[toplevel.obj_id]["outputs"] = { x.name for x in toplevel.outputs }

	def on_toplevel_closed(self, toplevel):
		del self.tlwindows[toplevel.obj_id]

# not actually using this
class ClipboardMonitor(DataControl):

	def on_new_selection(self, offer):
		self._print_selection(offer)
		self._receive(offer)

	def on_new_primary_selection(self, offer):
		self._print_selection(offer, is_primary=True)
		self._receive(offer, is_primary=True)

	# Internal
	def _receive(self, offer, is_primary=False):
		if offer is None:
			return
		for mime in (
			'text/plain;charset=utf-8',
			'UTF8_STRING',
		):
			if mime in offer.get_mime_types():
				offer.receive(mime, partial(self._on_received, is_primary=is_primary))
				break

	def _print_selection(self, offer, is_primary=False):
		_selection = 'primary' if is_primary else 'main'
		if offer is None:
			self.log(f"{_selection.capitalize()} selection cleared")
			return
		self.log(f"New {_selection} selection offers:")
		for mime_type in offer.get_mime_types():
			self.log(f"  {mime_type}")

	def _on_received(self, mime_type, data, is_primary=False):
		if data:
			data = data.decode('utf-8')
		self.log(f"Received {' primary' if is_primary else 'main'} selection: '{data}'")

class IdleNotifier(_IdleNotifier):
	def __init__(self, *args, **kwargs):
		super().__init__(*args, **kwargs)
		self.idle_start = None

	def on_idle(self):
		self.idle_start = datetime.now(tz=timezone.utc)

	def on_resume(self):
		self.idle_start = None

class WlMonitor(WaylandConnection):
	def on_initial_sync(self, data):
		super().on_initial_sync(data)
		self.toplevels = ForeignTopLevelMonitor(self)
		#self.clipboard = ClipboardMonitor(self)
		self.idle = IdleNotifyManager(self, IdleNotifier)
		self.idle_notifier = self.idle.get_idle_notifier(0, self.display.seat)

INTERVAL_MS = 60_000

def generate_log_entry(wl: WlMonitor()):
	entry = {"desktop": ""}
	now = datetime.now(timezone.utc)
	entry["date"] = now.isoformat()
	entry["rate"] = INTERVAL_MS
	if wl.idle_notifier.idle_start:
		entry["inactive"] = int((now.timestamp() - wl.idle_notifier.idle_start.timestamp()) * 1000)
	else:
		entry["inactive"] = 0
	def arbitrary_output(window):
		s = window["outputs"]
		try:
			return s.pop()
		except KeyError:
			return ""
	entry["windows"] = [ { "title": x["title"], "program": x["app_id"], "active": "activated" in x["states"], "hidden": "minimized" in x["states"] } for x in wl.toplevels.tlwindows.values() ]
	return entry

if __name__ == '__main__':
	import sys

	import asyncio
	from wl_framework.loop_integrations import AsyncIOIntegration

	async def init():
		arbtt_importer = await subprocess.create_subprocess_exec("arbtt-import", "-a", "-t", "JSON", stdin=subprocess.PIPE)
		loop = AsyncIOIntegration()
		try:
			app = WlMonitor(eventloop_integration=loop)
			await asyncio.sleep(1)
			while True:
				entry = generate_log_entry(app)
				arbtt_importer.stdin.write(orjson.dumps(entry))
				arbtt_importer.stdin.write(b"\n")
				await asyncio.sleep(INTERVAL_MS / 1000)
		except RuntimeError as e:
			print(e)
			sys.exit(1)
	try:
		asyncio.run(init())
	except KeyboardInterrupt:
		print()
