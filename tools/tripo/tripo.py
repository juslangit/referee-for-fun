#!/usr/bin/env python3
"""Turns an approved concept picture into a textured 3D model with Tripo.

    tools/tripo/tripo.py balance
    tools/tripo/tripo.py make player_c dev/concepts/2026-10-15/athlete_C_blue_single.png --faces 15000

The concept art is drawn in OpenArt first and approved by Luqman; Tripo only ever
sees an approved picture. Characters then go to Meshy for rigging (tools/meshy),
because the 33 clips are authored on Meshy's 24-bone skeleton.

Every task is recorded in tools/tripo/manifest.json before it is polled, so an
interrupted run resumes instead of paying twice.
"""

import argparse
import json
import os
import pathlib
import sys
import time
import urllib.request
import uuid

HERE = pathlib.Path(__file__).resolve().parent
PROJECT = HERE.parent.parent
ASSETS = PROJECT / "assets" / "tripo"
MANIFEST = HERE / "manifest.json"
API = "https://api.tripo3d.ai/v2/openapi"
ENV_FILE = pathlib.Path.home() / ".claude" / ".env"
MODEL_VERSION = "v3.0-20250812"


def key():
    found = os.environ.get("TRIPO_API_KEY")
    if found:
        return found
    for line in ENV_FILE.read_text().splitlines():
        if line.startswith("TRIPO_API_KEY="):
            return line.split("=", 1)[1].strip()
    sys.exit("TRIPO_API_KEY is not set and is not in ~/.claude/.env")


def call(method, path, body=None, data=None, headers=None):
    headers = {"Authorization": f"Bearer {key()}", **(headers or {})}
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(f"{API}/{path}", data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            reply = json.load(response)
    except urllib.error.HTTPError as error:
        sys.exit(f"{method} {path}: {error.code} {error.read().decode()}")
    if reply.get("code") != 0:
        sys.exit(f"{method} {path}: {reply}")
    return reply["data"]


def upload(path):
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
            f"filename=\"{path.name}\"\r\nContent-Type: image/png\r\n\r\n").encode()
    body += path.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    return call("POST", "upload", data=body,
                headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})["image_token"]


def load():
    return json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {"assets": {}}


def save(state):
    MANIFEST.write_text(json.dumps(state, indent=1, sort_keys=True) + "\n")


def wait(task_id, every=5.0, limit=1800):
    start = time.time()
    while time.time() - start < limit:
        # A dropped connection while polling is not a failed task. `call` exits on any
        # HTTP error, which on 2026-10-15 left the line judge's build half-done while
        # the task carried on at Tripo; a status check is free to repeat.
        try:
            task = call("GET", f"task/{task_id}")
        except SystemExit as error:
            print(f"  poll failed, retrying: {error}", flush=True)
            time.sleep(every)
            continue
        status = task.get("status")
        print(f"  {status} {task.get('progress', '')}", flush=True)
        if status == "success":
            return task
        if status in ("failed", "cancelled", "banned", "expired", "unknown"):
            sys.exit(f"task {task_id} ended {status}: {task}")
        time.sleep(every)
    sys.exit(f"task {task_id} did not finish in {limit} s")


def cmd_balance(_args):
    print(call("GET", "user/balance"))


def cmd_make(args):
    state = load()
    asset = state["assets"].setdefault(args.name, {})
    if "task" not in asset:
        token = upload(PROJECT / args.image)
        before = call("GET", "user/balance")["balance"]
        asset["task"] = call("POST", "task", {
            "type": "image_to_model",
            "file": {"type": "png", "file_token": token},
            "model_version": MODEL_VERSION,
            "texture": True,
            "pbr": False,
            "texture_quality": "detailed",
            "face_limit": args.faces,
            "orientation": "align_image",
        })["task_id"]
        asset.update(image=args.image, faces=args.faces, version=MODEL_VERSION,
                     balance_before=before)
        save(state)
    print(f"task {asset['task']}")
    task = wait(asset["task"])
    output = task["output"]
    url = output.get("pbr_model") or output.get("model") or output.get("base_model")
    out = ASSETS / args.name / f"{args.name}.glb"
    out.parent.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve(url, out)
    asset["balance_after"] = call("GET", "user/balance")["balance"]
    asset["spent"] = asset["balance_before"] - asset["balance_after"]
    save(state)
    print(f"wrote {out.relative_to(PROJECT)}  ({out.stat().st_size / 1e6:.1f} MB), "
          f"spent {asset['spent']} credits")


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(required=True)
    sub.add_parser("balance").set_defaults(run=cmd_balance)
    make = sub.add_parser("make")
    make.add_argument("name")
    make.add_argument("image")
    make.add_argument("--faces", type=int, default=15000)
    make.set_defaults(run=cmd_make)
    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
