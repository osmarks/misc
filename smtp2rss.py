import asyncio
from aiosmtpd.controller import UnthreadedController
from aiosmtpd.smtp import SMTP, syntax
from email.message import Message, EmailMessage
from email import message_from_bytes
from email.header import Header, decode_header, make_header
import aiosqlite
from datetime import datetime, timezone
from aiohttp import web
import re
import json
import feedparser.sanitizer
import rfeed
import base64
from lxml.html.clean import Cleaner

def now(): return datetime.now(tz=timezone.utc)
def decode_mime(subject): return str(make_header(decode_header(subject)))

def handle_addr(a):
    if a:
        if x := re.search("<(.*)>$", a.strip()):
            return x.group(1)
        else:
            return a.strip()

async def open_connection():
    conn = await aiosqlite.connect("./smtp2rss.sqlite3")
    conn.row_factory = aiosqlite.Row
    await conn.execute("PRAGMA journal_mode = WAL")
    await conn.executescript("""
CREATE TABLE IF NOT EXISTS mails (
    id INTEGER PRIMARY KEY,
    timestamp REAL NOT NULL,
    full_mail BLOB NOT NULL,
    from_addr TEXT,
    to_addr TEXT,
    subject TEXT
);
    """)
    await conn.commit()
    return conn

routes = web.RouteTableDef()

import dominate
from dominate.tags import *

def base_template(title, content, err=None):
    doc = dominate.document(title=title)

    with doc.head:
        meta(name="viewport", content="width=device-width, initial-scale=1.0")
        style("""
* {
    box-sizing: border-box;
}

h1, h2, h3 {
    margin-top: 0;
    border-bottom: 1px solid gray;
    font-weight: normal;
}

.mails .entry {
    border: 1px solid gray;
    margin: 0.5em;
    padding: 0.5em;
}
""")
    with doc:
        if err: div(err, cls="error")
        h1(title, cls="title")
        m = main()
        m += content

    return web.Response(text=doc.render(), content_type="text/html")

preference = {
    "text/html": 2,
    "text/plain": 1
}

def clean_html(html):
    cleaner = Cleaner(
        page_structure=True,
        meta=True,
        embedded=True,
        links=True,
        style=False,
        processing_instructions=True,
        inline_style=True,
        scripts=True,
        javascript=True,
        comments=True,
        frames=True,
        forms=True,
        annoying_tags=True,
        remove_unknown_tags=True,
        safe_attrs_only=True
    )
    try:
        return cleaner.clean_html(feedparser.sanitizer._sanitize_html(html.replace("<!doctype html>", ""), "utf-8", "text/html"))
    except:
        return "HTML parse error"

def email_to_html(emsg, debug_info=False):
    if isinstance(emsg, Message):
        payload = emsg.get_payload()
        if isinstance(payload, list):
            if not debug_info and emsg.get_content_type() == "multipart/alternative":
                payload.sort(key=lambda x: preference.get(x.get_content_type(), 0))
                return email_to_html(payload[-1], debug_info)
            else:
                html = [ email_to_html(thing, debug_info) for thing in payload ]
        else:
            if "attachment" in emsg.get("content-disposition", ""):
                html = div("[attachment]")
            else:
                try:
                    payload = emsg.get_payload(decode=True).decode("utf-8")
                except:
                    payload = emsg.get_payload(decode=True).decode("latin1")
                if emsg.get_content_subtype() == "html":
                    html = div(dominate.util.raw(clean_html(payload)))
                else:
                    html = pre(payload)
    else:
        html = [ email_to_html(thing, debug_info) for thing in emsg.get_body(list(preference.keys())) ]
    return div([
        pre([ f"{header}: {value}\n" for header, value in emsg.items() ]) if debug_info else "",
        html
    ], cls="entry")

async def run():
    accessed_feeds = {}

    loop = asyncio.get_event_loop()
    db = await open_connection()

    class Handler:
        async def handle_DATA(handler, server, session, envelope):
            mail = message_from_bytes(envelope.content)
            print("got mail", handle_addr(mail["From"]), handle_addr(mail["To"]), mail["Subject"])
            await db.execute_insert("INSERT INTO mails (timestamp, full_mail, from_addr, to_addr, subject) VALUES (?, ?, ?, ?, ?)", 
                (now().timestamp(), envelope.content, handle_addr(mail["From"]), handle_addr(mail["To"]), decode_mime(mail["Subject"])))
            await db.commit()
            return "250 OK"

    controller = UnthreadedController(Handler(), loop=loop, hostname="127.0.0.1")
    srv = await controller._create_server()
    controller.server = srv
    print(controller.hostname, controller.port)

    @routes.get("/")
    async def index(req):
        page = int(req.query.get("page", 0))
        exclude = [ feed for feed, time in accessed_feeds.items() if (time.timestamp() > (now().timestamp() - 3600)) ]
        items = await db.execute_fetchall("SELECT * FROM mails WHERE from_addr NOT IN (SELECT value FROM json_each(?)) ORDER BY timestamp DESC LIMIT 25 OFFSET ?", (json.dumps(exclude), page * 25))
        def display_mail(row):
            data = message_from_bytes(row["full_mail"])
            return div([
                div([ datetime.fromtimestamp(row["timestamp"], tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S"), " / ", f"{row['from_addr'] or '[from addr missing]'}→{row['to_addr'] or '[to addr missing]'}", " / ", row["subject"] or "[no subject]" ]),
                email_to_html(data, True)
            ], cls="entry")
        return base_template("Unused Mails", div([
            display_mail(mail) for mail in items
        ], cls="mails"))

    @routes.get("/feed/{from}")
    async def feed(req):
        accessed_feeds[req.match_info["from"]] = now()
        items = []
        for mail in await db.execute_fetchall("SELECT * FROM mails WHERE from_addr = ? ORDER BY timestamp DESC LIMIT 20", (req.match_info["from"],)):
            data = message_from_bytes(mail["full_mail"])
            content = email_to_html(data, debug_info=False).render()
            items.append(rfeed.Item(
                title=mail["subject"],
                guid=rfeed.Guid(f"smtp2rss-{mail['id']}"),
                pubDate=datetime.fromtimestamp(mail["timestamp"], tz=timezone.utc),
                author=req.match_info["from"],
                description=content.strip()
            ))
        return web.Response(text=rfeed.Feed(
            title=f"{req.match_info['from']} via SMTP2RSS",
            lastBuildDate=now(),
            link="http://localhost:3394",
            description="",
            items=items
        ).rss())

    app = web.Application()
    app.router.add_routes(routes)

    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "100.64.0.2", 3394)
    await site.start()

loop = asyncio.get_event_loop_policy().get_event_loop()
loop.run_until_complete(run())
loop.run_forever()
