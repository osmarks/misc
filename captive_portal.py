import subprocess
import requests
from bs4 import BeautifulSoup
import re
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import urllib.parse, urllib3
from dns.resolver import Resolver
import dns.resolver
import string
import random

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class CustomDNSAdapter(HTTPAdapter):
    def __init__(self, dns_server, *args, **kwargs):
        self.dns_server = dns_server
        super().__init__(*args, **kwargs)

    def send(self, request, **kwargs):
        connection_pool_kwargs = self.poolmanager.connection_pool_kw

        old_url = request.url
        parsed_url = urllib.parse.urlparse(request.url)
        hostname = parsed_url.hostname
        connection_pool_kwargs["server_hostname"] = hostname
        request.headers["Host"] = hostname

        custom_resolver = Resolver()
        custom_resolver.nameservers = [self.dns_server]
        try:
            ip = custom_resolver.resolve(hostname).rrset[0].to_text()
            request.url = parsed_url._replace(netloc=ip).geturl()
        except dns.resolver.NXDOMAIN:
            pass

        response = super().send(request, **kwargs)
        response.url = old_url
        return response

session = requests.Session()

DETECTPORTAL_URL = "http://detectportal.firefox.com/canonical.html"
DETECTPORTAL_CONTENT = '<meta http-equiv="refresh" content="0;url=https://support.mozilla.org/kb/captive-portal"/>'
PRIORITY_KEYWORDS = {"registr", "login", "signup", "signin"}
CONFIRM_SUFFIXES = {"2", "repeat", "confirm", "_repeat", "_confirm"}
EMAIL_BASE = "0t.lt"

FIELDTYPES = ("email", "postcode")

def is_priority(url):
    url = url.replace("-", "").replace("_", "")
    for keyword in PRIORITY_KEYWORDS:
        if keyword in url:
            return True
    return False

def get_dns():
    constate = subprocess.check_output(["nmcli", "dev", "show"]).decode("utf-8")
    for line in constate.splitlines():
        name, val = line.split(":", 1)
        if name == "IP4.DNS[1]":
            return val.strip()

dns_server = get_dns()
print("DNS server", dns_server)
adapter = CustomDNSAdapter(dns_server)
session.mount("http://", adapter)
session.mount("https://", adapter)
session.verify = False
session.headers.update({"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36"})

tried = set()
queue = []

def generate_email():
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=10)) + "@" + EMAIL_BASE

def generate_generic():
    return "".join(random.choices(string.ascii_lowercase, k=10)).title()

def handle_response(response):
    tried.add(response.url)
    soup = BeautifulSoup(response.text, "html.parser")
    queue_ext = []
    for link in soup.find_all("a"):
        if href := link.get("href"):
            href = urllib.parse.urljoin(response.url, href)
            if is_priority(href):
                queue_ext.insert(0, href)
            else:
                queue_ext.append(href)

    for form in soup.find_all("form"):
        fields = {}

        for input in form.find_all("input"):
            name = input.get("name", "")
            if not name: continue

            repeat = None
            for other_field, value in fields.items():
                for suffix in CONFIRM_SUFFIXES:
                    xname = other_field + suffix
                    if xname == name:
                        repeat = name, value
            if repeat:
                k, v = repeat
                fields[k] = v
                continue

            fieldtype = None
            for ty in FIELDTYPES:
                if ty in name.lower():
                    fieldtype = ty
                elif ty in input.get("id", "").lower():
                    fieldtype = ty
                elif ty in input.get("placeholder", "").lower().replace(" ", ""):
                    fieldtype = ty

            if input.get("type") == "checkbox":
                fields[name] = input.get("value", "on")
            elif input.get("type") == "hidden":
                fields[name] = input.get("value")
            elif input.get("type") == "radio":
                if name not in fields:
                    fields[name] = input.get("value")
            else:
                match fieldtype:
                    case "email":
                        fields[name] = generate_email()
                    case "postcode":
                        fields[name] = "W1A 1AA" # ISO standard postcode (real)
                    case None:
                        fields[name] = generate_generic()

        for select in form.find_all("select"):
            name = select.get("name", "")
            if not name: continue

            for option in select.find_all("option"):
                if option.get("disabled") is not None: continue
                fields[name] = option.get("value", generate_generic())
            else:
                fields[name] = generate_generic()
                continue

        action = urllib.parse.urljoin(response.url, form.get("action", ""))
        if form.get("method") == "get":
            response = session.get(action, params=fields)
        else:
            response = session.post(action, data=fields)
        handle_response(response)

    queue.extend(x for x in queue_ext if x not in tried)

while True:
    response = session.get(DETECTPORTAL_URL)
    if response.text == DETECTPORTAL_CONTENT:
        print("OK")
        raise SystemExit(0)
    handle_response(response)
    try:
        next_url = queue.pop(0)
    except IndexError:
        print("No more URLs to try")
        break
    try:
        print(next_url)
        response = session.get(next_url)
    except Exception as e:
        print(e)
        continue
    handle_response(response)
    if len(tried) > 100:
        print("Tries exceeded")
        break

print("KO")
raise SystemExit(1)
