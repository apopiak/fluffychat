# SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
#
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Seed a local Synapse with a room whose timeline matches the Weft mockup scenario.

Usage: python3 -I seed_threads.py http://localhost:8008
Creates users alice, bob, carol, dave (password: weft-test-pw) if missing,
a room "Hackathon crew", and messages with m.thread relations.
Prints the room id and the login for the web client.
"""
import json
import sys
import time
import urllib.error
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
        err = e.read().decode()
        raise SystemExit(f"{method} {path} -> {e.code}: {err}")


def login_or_register(name):
    try:
        r = call("POST", "/_matrix/client/v3/login", {
            "type": "m.login.password",
            "identifier": {"type": "m.id.user", "user": name},
            "password": PW,
        })
        return r["access_token"], r["user_id"]
    except SystemExit:
        r = call("POST", "/_matrix/client/v3/register", {
            "username": name, "password": PW, "auth": {"type": "m.login.dummy"},
        })
        return r["access_token"], r["user_id"]


tokens = {}
ids = {}
for u in USERS:
    tokens[u], ids[u] = login_or_register(u)

room = call("POST", "/_matrix/client/v3/createRoom", {
    "name": "Hackathon crew",
    "preset": "private_chat",
    "invite": [ids[u] for u in USERS[1:]],
}, tokens["alice"])["room_id"]
for u in USERS[1:]:
    call("POST", f"/_matrix/client/v3/join/{urllib.request.quote(room)}", {}, tokens[u])

txn = [int(time.time() * 1000)]
threads = {}


def send(user, text, thread=None):
    txn[0] += 1
    content = {"msgtype": "m.text", "body": text}
    if thread:
        root, last = threads[thread]
        content["m.relates_to"] = {
            "rel_type": "m.thread",
            "event_id": root,
            "is_falling_back": True,
            "m.in_reply_to": {"event_id": last},
        }
    r = call("PUT", f"/_matrix/client/v3/rooms/{urllib.request.quote(room)}/send/m.room.message/{txn[0]}",
             content, tokens[user])
    eid = r["event_id"]
    if thread:
        threads[thread] = (threads[thread][0], eid)
    time.sleep(0.15)
    return eid


threads["teal"] = (None, None)
root = send("alice", "Dinner Friday? Thinking Thai 🍜")
threads["teal"] = (root, root)
send("bob", "Thai works, 7pm?", "teal")
root2 = send("carol", "Who's presenting at the hackathon?")
threads["violet"] = (root2, root2)
send("dave", "7 is good, I'll book", "teal")
send("bob", "did you see the cat on the roof")
send("dave", "I can, if someone brings the HDMI adapter", "violet")
send("alice", "Booked ✅ table for 5", "teal")
send("alice", "🎉")
root3 = send("carol", "Anyone up for a run tomorrow morning?")
threads["run"] = (root3, root3)
send("bob", "What time?", "run")
send("alice", "7:30 at the river", "run")
send("dave", "Also: who has the HDMI adapter now?")
send("carol", "Too early for me 😅", "run")

print(json.dumps({"room_id": room, "login": "dave", "password": PW, "homeserver": BASE}, indent=2))
