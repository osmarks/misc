import urllib3, json

http = urllib3.PoolManager()
def send(x):
    http.request("POST", "https://spudnet.osmarks.net/httponly", body=json.dumps({"mode": "send", "channel": "potatOS", "message": x}), headers={"Content-Type": "application/json"})
while True:
    r = http.request("POST", "https://spudnet.osmarks.net/httponly", body=json.dumps({"mode": "recv", "channel": "potatOS", "timeout": 30000}), headers={"Content-Type": "application/json"})
    data = json.loads(r.data)
    if data["result"] != None:
        res = data["result"]["data"]
        try:
            send(repr(eval(res)))
        except Exception as e:
            send(repr(e))