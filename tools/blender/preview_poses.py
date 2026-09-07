"""Renders a character in a row of poses so the clips can be looked at.

    blender --background --python tools/blender/preview_poses.py -- athlete_average

Writes tools/blender/_preview.png. The poses in clips.py were set by running this and
adjusting, because guessing which way a bone rotates from its rest orientation is a
good way to produce a person whose elbow bends the wrong way.
"""

import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.realpath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import character_forge as forge  # noqa: E402
from clips import CLIPS, AUDIENCE_CLIPS  # noqa: E402

# Which clip, and which keyframe of it, to show in each column.
SHOTS = [
    ("rest", None),
    ("ready", 1),
    ("run", 1),
    ("lunge", 1),
    ("smash", 1),
    ("smash", 2),
    ("forehand", 2),
    ("celebrate", 1),
    ("tired", 0),
    ("argue", 1),
]

AUDIENCE_SHOTS = [("rest", None), ("sit", 0), ("clap", 0), ("clap", 1), ("cheer", 1)]


BONE_TEST = ["upper_arm.L", "upper_arm.R", "forearm.L", "thigh.L"]


def bone_check(name):
    """One column per bone, each rotated 40 degrees on its own, to see what moves."""
    spec = forge.CHARACTERS[name]
    forge._clear_scene()
    height = spec["height"]
    spacing = height * 0.75
    for column, bone_name in enumerate(BONE_TEST):
        body = forge._build_body(f"{name}_{column}", spec)
        rig = forge._build_armature(f"{name}_{column}", spec)
        forge._skin(body, rig)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="POSE")
        for bone in rig.pose.bones:
            bone.rotation_mode = "XYZ"
        forge._apply_pose(rig, {bone_name: (40, 0, 0)})
        bpy.ops.object.mode_set(mode="OBJECT")
        # Only the rig moves. The body is parented to it, so moving both put every
        # character at twice its column and half of them off the side of the render.
        rig.location.x = column * spacing
    _set_up_camera(len(BONE_TEST) * spacing, height)
    _render(os.path.join(HERE, "_bonecheck.png"))
    print("bones: " + "  |  ".join(BONE_TEST))


def main(name):
    spec = forge.CHARACTERS[name]
    clips = AUDIENCE_CLIPS if spec.get("audience") else CLIPS
    shots = AUDIENCE_SHOTS if spec.get("audience") else SHOTS

    forge._clear_scene()
    height = spec["height"]
    spacing = height * 0.75

    for column, (clip_name, key_index) in enumerate(shots):
        body = forge._build_body(f"{name}_{column}", spec)
        rig = forge._build_armature(f"{name}_{column}", spec)
        forge._skin(body, rig)

        if clip_name != "rest":
            bpy.context.view_layer.objects.active = rig
            bpy.ops.object.mode_set(mode="POSE")
            for bone in rig.pose.bones:
                bone.rotation_mode = "XYZ"
            forge._apply_pose(rig, clips[clip_name]["keys"][key_index][1])
            bpy.ops.object.mode_set(mode="OBJECT")

        # Only the rig moves. The body is parented to it, so moving both put every
        # character at twice its column and half of them off the side of the render.
        rig.location.x = column * spacing

    _set_up_camera(len(shots) * spacing, height)
    _render(os.path.join(HERE, "_preview.png"))
    print("labels: " + "  |  ".join(
        f"{c}{'' if k is None else f'[{k}]'}" for c, k in shots))


def _set_up_camera(width, height):
    centre = (width - height * 0.75) * 0.5
    bpy.ops.object.camera_add(location=(centre, -width, height * 0.55))
    camera = bpy.context.object
    camera.rotation_euler = (math.radians(90), 0, 0)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = width * 1.08
    bpy.context.scene.camera = camera

    bpy.ops.object.light_add(type="SUN", location=(width * 0.4, -width, height * 3))
    key = bpy.context.object
    key.data.energy = 4.0
    key.rotation_euler = (math.radians(52), 0, math.radians(28))

    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("World")
        bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.13, 0.14, 0.16, 1)


def _render(path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 2000
    scene.render.resolution_y = 700
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    print("wrote", path)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv and argv[0] == "bones":
        bone_check(argv[1] if len(argv) > 1 else "athlete_average")
    else:
        main(argv[0] if argv else "athlete_average")
