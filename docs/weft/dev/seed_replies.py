# SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
#
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Seed a local Synapse with a room that has plain replies and no threads.

Usage: python3 -I seed_replies.py http://localhost:8008
Uses the users from seed_threads.py (password: weft-test-pw), creating them if
missing, and a room "Conference hallway" where conversations interleave and
people answer with ordinary replies, the way most Matrix rooms look today.
"""
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8008"
PW = "weft-test-pw"
USERS = ["alice", "bob", "carol", "dave"]


def call(method, path, body=None, token=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {path} -> {e.code}: {e.read().decode()}")


def login_or_register(name):
    try:
        r = call("POST", "/_matrix/client/v3/login", {
            "type": "m.login.password",
            "identifier": {"type": "m.id.user", "user": name},
            "password": PW,
        })
    except SystemExit:
        r = call("POST", "/_matrix/client/v3/register", {
            "username": name, "password": PW, "auth": {"type": "m.login.dummy"},
        })
    return r["access_token"], r["user_id"]


tokens, ids = {}, {}
for u in USERS:
    tokens[u], ids[u] = login_or_register(u)

room = call("POST", "/_matrix/client/v3/createRoom", {
    "name": "Conference hallway",
    "preset": "private_chat",
    "invite": [ids[u] for u in USERS[1:]],
}, tokens["alice"])["room_id"]
quoted = urllib.parse.quote(room)
for u in USERS[1:]:
    call("POST", f"/_matrix/client/v3/join/{quoted}", {}, tokens[u])

txn = [int(time.time() * 1000)]


def send(user, text, reply_to=None):
    txn[0] += 1
    content = {"msgtype": "m.text", "body": text}
    if reply_to:
        content["m.relates_to"] = {"m.in_reply_to": {"event_id": reply_to}}
    eid = call("PUT", f"/_matrix/client/v3/rooms/{quoted}/send/m.room.message/{txn[0]}",
               content, tokens[user])["event_id"]
    time.sleep(0.15)
    return eid


talk = send("alice", "Is anyone recording the state res talk in room B?")
lunch = send("bob", "Lunch after the keynote? There's a ramen place nearby")
rec = send("carol", "I think the C3VOC team records everything", talk)
send("dave", "Ramen sounds great 🍜", lunch)
send("bob", "Slides for my talk are up, link in the schedule")
rec2 = send("alice", "Great, then I'll go to the Rust workshop instead", rec)
lunch2 = send("carol", "Count me in, can we go at 12:30?", lunch)
send("dave", "Their stream had no audio for the first 10 min though", rec2)
send("alice", "12:30 works, meet at the entrance", lunch2)
wifi = send("dave", "Does the wifi work for anyone on the second floor?")
send("bob", "Same here, using my phone hotspot", wifi)
send("carol", "Fixed now, they restarted the access point", wifi)
send("alice", "👋 see you all at the social later")

print(json.dumps({"room_id": room, "login": "dave", "password": PW, "homeserver": BASE}, indent=2))
