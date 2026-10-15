#!/usr/bin/env python3
"""Rigs an upright Tripo model with Meshy and files the result where clean_rig expects it.

    tools/tripo/rig_person.py umpire 1.72

Reads  assets/tripo/<name>/<name>_upright.glb
Writes assets/meshy/<name>/<name>_rigged_raw.glb, plus _walking and _running

Rigging is 5 Meshy credits. The task id is recorded before it is polled, so a run that
is interrupted resumes rather than paying again.
"""
import base64
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "meshy"))
import meshy  # noqa: E402


def main():
    name, height = sys.argv[1], float(sys.argv[2])
    src = meshy.PROJECT / f"assets/tripo/{name}/{name}_upright.glb"
    state = meshy.load()
    asset = state["assets"].get(name, {})
    if "rig" in asset:
        rig_id = asset["rig"]
    else:
        uri = "data:application/octet-stream;base64," + base64.b64encode(src.read_bytes()).decode()
        rig_id = meshy.call("POST", "v1/rigging", {"model_url": uri, "height_meters": height},
                            timeout=300)["result"]
        meshy.record(state, name, "rig", rig_id, 5)
    result = meshy.wait("v1/rigging", rig_id, "rig")["result"]
    out = meshy.ASSETS / name
    meshy.fetch(result["rigged_character_glb_url"], out / f"{name}_rigged_raw.glb")
    for clip, key in (("walking", "walking_glb_url"), ("running", "running_glb_url")):
        url = result.get("basic_animations", {}).get(key)
        if url:
            meshy.fetch(url, out / f"{name}_{clip}.glb")
    print(f"rigged {name}")


if __name__ == "__main__":
    main()
