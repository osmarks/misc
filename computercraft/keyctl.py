#!/usr/bin/env python3
import requests
import argparse
import sys

parser = argparse.ArgumentParser(description="Manage keys in SPUDNET")
parser.add_argument("--spudnet_url", "-s", required=True, help="URL of the SPUDNET instance to access")
parser.add_argument("--key", "-K", required=True)
subparsers = parser.add_subparsers(required=True)
subparsers.dest = "command"
subparsers.add_parser("info", help="Get information about this key.")
subparsers.add_parser("dependent_keys", help="List keys issued by this key.")
subparsers.add_parser("disable_key", help="Disable this key.")
issue_key = subparsers.add_parser("issue_key", help="Issue a new key.")
issue_key.add_argument("--channel", "-c", action="append", help="Allow new key access to this channel. Can be repeated. If none specified, defaults to issuing key's channels.")
issue_key.add_argument("--bearer", "-b", help="Specifies bearer of new key")
issue_key.add_argument("--use", "-u", help="Specifies intended use of new key")
issue_key.add_argument("--permission_level", "-p", help="Specifies permission level of new key. Not currently used. Must be <= issuing key's permission level", type=int)

args = parser.parse_args()

def query(subpath, data):
    for key, value in list(data.items()):
        if value == None: del data[key]
    result = requests.post(args.spudnet_url + "/hki/" + subpath, json=data)
    if not result.ok:
        print(result.text)
        sys.exit(1)
    else:
        return result.json()

if args.command == "info":
    print(query("key-info", { "key": args.key }))
elif args.command == "dependent_keys":
    print(query("dependent-keys", { "key": args.key }))
elif args.command == "issue_key":
    print(query("issue-key", {
        "key": args.key,
        "bearer": args.bearer,
        "use": args.use,
        "permission_level": args.permission_level,
        "allowed_channels": args.channel
    }))
elif args.command == "disable_key":
    yn = input("Are you sure? All keys issued by this key will also be disabled. This action is irreversible. (y/n) ")
    if yn == "y":
        print(query("disable-key", { "key": args.key }))
    else:
        print("Action cancelled.")