#!/usr/bin/env python3
"""Generates 3D assets with Meshy and files them into the project.

    tools/meshy/meshy.py balance
    tools/meshy/meshy.py make shuttlecock "a badminton shuttlecock, ..." --prop
    tools/meshy/meshy.py make athlete_a "a badminton player, ..." --rig --height 1.80
    tools/meshy/meshy.py animate athlete_a 59 victory_cheer
    tools/meshy/meshy.py motion smash "a badminton player ..." --duration 3
    tools/meshy/meshy.py animate athlete_a motion:smash smash
    tools/meshy/meshy.py show

Every task is recorded in tools/meshy/manifest.json before it is polled, so a run
that is interrupted can be resumed instead of paid for twice. Credits are real money
and a preview task is 20 of them; nothing here should ever be generated twice by
accident.

Costs, from the API pricing page as of 2026-09-08:

    text-to-3d preview   20     rigging      5
    text-to-3d refine    10     animation    3
    text-to-motion       10  (prime; swift is 3)

A text-to-motion clip is kept by Meshy for three days, so it has to be put onto the
characters with `animate ... motion:<label>` inside that window.
"""

import argparse
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
PROJECT = HERE.parent.parent
ASSETS = PROJECT / "assets" / "meshy"
MANIFEST = HERE / "manifest.json"

API = "https://api.meshy.ai/openapi"
ENV_FILE = pathlib.Path.home() / ".claude" / ".env"


def key():
    """The API key, from the environment or from ~/.claude/.env."""
    found = os.environ.get("MESHY_API_KEY")
    if found:
        return found
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            if line.startswith("MESHY_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("MESHY_API_KEY is not set and is not in ~/.claude/.env")


def call(method, path, body=None, timeout=60):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(
        f"{API}/{path}", data=data, method=method,
        headers={"Authorization": f"Bearer {key()}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as error:
        detail = error.read().decode()[:400]
        sys.exit(f"{method} /{path} failed: {error.code} {error.reason}\n{detail}")


# --- the manifest ---------------------------------------------------------------

def load():
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text())
    return {"assets": {}, "spent": 0}


def save(state):
    MANIFEST.write_text(json.dumps(state, indent=2, sort_keys=True))


def record(state, name, stage, task_id, credits=0):
    asset = state["assets"].setdefault(name, {})
    asset[stage] = task_id
    state["spent"] = state.get("spent", 0) + credits
    save(state)


# --- waiting --------------------------------------------------------------------

def wait(path, task_id, label, every=6.0, limit=1800):
    """Polls a task to completion, printing progress as it goes."""
    started = time.time()
    last = -1
    while time.time() - started < limit:
        task = call("GET", f"{path}/{task_id}")
        status = task.get("status")
        progress = task.get("progress", 0)
        if progress != last:
            print(f"    {label}: {status} {progress}%")
            last = progress
        if status == "SUCCEEDED":
            return task
        if status in ("FAILED", "CANCELED"):
            sys.exit(f"    {label} {status}: {task.get('task_error')}")
        time.sleep(every)
    sys.exit(f"    {label} still running after {limit}s — check with `show`")


def fetch(url, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=300) as response:
        destination.write_bytes(response.read())
    size = destination.stat().st_size / 1024
    print(f"    saved {destination.relative_to(PROJECT)}  ({size:.0f} KB)")


# --- the commands ---------------------------------------------------------------

def cmd_balance(_args):
    print(f"{call('GET', 'v1/balance')['balance']} credits")
    state = load()
    print(f"{state.get('spent', 0)} spent by this tool so far")


def cmd_make(args):
    """Preview, texture, and optionally rig one asset."""
    state = load()
    asset = state["assets"].get(args.name, {})

    if "preview" in asset:
        print(f"  preview already made for {args.name}")
        preview_id = asset["preview"]
    else:
        print(f"  preview: {args.prompt[:70]}...")
        body = {
            "mode": "preview",
            "prompt": args.prompt,
            "ai_model": "meshy-5",
            "topology": "triangle",
            "target_polycount": args.polycount,
            "should_remesh": True,
        }
        # A character has to come out standing in a T-pose or nothing will rig it.
        if args.rig:
            body["pose_mode"] = "t-pose"
        preview_id = call("POST", "v2/text-to-3d", body)["result"]
        record(state, args.name, "preview", preview_id, 20)
    wait("v2/text-to-3d", preview_id, "preview")

    if "refine" in asset:
        print(f"  texture already made for {args.name}")
        refine_id = asset["refine"]
    else:
        print("  texturing")
        refine_id = call("POST", "v2/text-to-3d", {
            "mode": "refine",
            "preview_task_id": preview_id,
            "enable_pbr": False,
            "texture_resolution": "2k",
            "texture_prompt": args.texture or args.prompt,
        })["result"]
        record(state, args.name, "refine", refine_id, 10)
    textured = wait("v2/text-to-3d", refine_id, "texture")

    fetch(textured["model_urls"]["glb"], ASSETS / args.name / f"{args.name}.glb")

    if not args.rig:
        return

    state = load()
    asset = state["assets"].get(args.name, {})
    if "rig" in asset:
        print(f"  rig already made for {args.name}")
        rig_id = asset["rig"]
    else:
        print("  rigging")
        rig_id = call("POST", "v1/rigging", {
            "input_task_id": refine_id,
            "height_meters": args.height,
        })["result"]
        record(state, args.name, "rig", rig_id, 5)
    rigged = wait("v1/rigging", rig_id, "rig")

    result = rigged.get("result", {})
    fetch(result["rigged_character_glb_url"], ASSETS / args.name / f"{args.name}_rigged.glb")
    # Rigging throws in a walk and a run, which are two of the clips needed anyway.
    for clip, url_key in (("walking", "walking_glb_url"), ("running", "running_glb_url")):
        url = result.get("basic_animations", {}).get(url_key)
        if url:
            fetch(url, ASSETS / args.name / f"{args.name}_{clip}.glb")


def cmd_motion(args):
    """Generates a motion clip from a description, to be put onto characters later.

    Meshy's library has nothing that is a badminton shot in it; this is how one is made
    without keying it by hand. Motions live under their own key in the manifest, apart
    from the characters, because one motion goes onto every character.
    """
    state = load()
    motions = state.setdefault("motions", {})
    if args.label in motions:
        print(f"  motion {args.label} already made")
        task_id = motions[args.label]["task"]
    else:
        print(f"  motion: {args.prompt[:70]}...")
        task_id = call("POST", "v1/text-to-motion", {
            "prompt": args.prompt,
            "duration": args.duration,
            "mode": args.mode,
        })["result"]
        motions[args.label] = {"task": task_id, "prompt": args.prompt,
                               "duration": args.duration, "mode": args.mode}
        state["spent"] = state.get("spent", 0) + (10 if args.mode == "prime" else 3)
        save(state)
    done = wait("v1/text-to-motion", task_id, args.label)
    result = done.get("result") or done
    print(f"    {result.get('duration_ms', '?')} ms, {result.get('motion_format', '?')}, "
          f"kept until {done.get('expires_at', '?')}")


def cmd_animate(args):
    """Applies one library animation, or one generated motion, to a rigged character.

    `action` is a library id, or `motion:<label>` for a clip made by `motion`.
    """
    state = load()
    asset = state["assets"].get(args.name, {})
    if "rig" not in asset:
        sys.exit(f"{args.name} has not been rigged")

    body = {"rig_task_id": asset["rig"]}
    if args.action.startswith("motion:"):
        motion = state.get("motions", {}).get(args.action.split(":", 1)[1])
        if motion is None:
            sys.exit(f"no motion called {args.action.split(':', 1)[1]} — make it first")
        body["motion_task_id"] = motion["task"]
    else:
        body["action_id"] = int(args.action)

    stage = f"anim_{args.label}"
    if stage in asset:
        print(f"  {args.label} already made")
        task_id = asset[stage]
    else:
        print(f"  animating: {args.label} ({args.action})")
        task_id = call("POST", "v1/animations", body)["result"]
        record(state, args.name, stage, task_id, 3)
    done = wait("v1/animations", task_id, args.label)

    result = done.get("result", {})
    url = result.get("animation_glb_url") or result.get("glb_url")
    if url:
        fetch(url, ASSETS / args.name / f"{args.name}_{args.label}.glb")
    else:
        print(f"    no glb in result: {list(result)}")


def cmd_show(_args):
    state = load()
    print(f"{state.get('spent', 0)} credits spent by this tool")
    for name, stages in sorted(state["assets"].items()):
        print(f"\n  {name}")
        for stage, task_id in sorted(stages.items()):
            print(f"    {stage:<18} {task_id}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest="command", required=True)

    subs.add_parser("balance").set_defaults(run=cmd_balance)
    subs.add_parser("show").set_defaults(run=cmd_show)

    make = subs.add_parser("make")
    make.add_argument("name")
    make.add_argument("prompt")
    make.add_argument("--texture", default=None)
    make.add_argument("--rig", action="store_true")
    make.add_argument("--prop", action="store_true")
    make.add_argument("--height", type=float, default=1.78)
    make.add_argument("--polycount", type=int, default=12000)
    make.set_defaults(run=cmd_make)

    motion = subs.add_parser("motion")
    motion.add_argument("label")
    motion.add_argument("prompt")
    motion.add_argument("--duration", type=float, default=3.0)
    motion.add_argument("--mode", choices=("prime", "swift"), default="prime")
    motion.set_defaults(run=cmd_motion)

    animate = subs.add_parser("animate")
    animate.add_argument("name")
    animate.add_argument("action")
    animate.add_argument("label")
    animate.set_defaults(run=cmd_animate)

    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
