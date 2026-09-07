"""Builds the game's characters in Blender and exports them as glTF.

Run headless:

    blender --background --python tools/blender/character_forge.py -- [name ...]

With no names it builds everything. Output lands in assets/characters/.

Everything here is generated rather than modelled by hand, for one reason: there are
five characters and a dozen animations, and every one of them will need adjusting once
they are seen in the game. A script can be re-run in twenty seconds. A hand-modelled
character has to be opened, remembered, and edited.

The proportions are real. A 1.88 m athlete is 1.88 m tall in Blender, in Godot and on
court, so nobody has to guess at a scale factor later — which is exactly the trap the
downloaded models kept springing.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.realpath(__file__))
# Before importing clips, because Blender runs this file from wherever it likes.
if HERE not in sys.path:
    sys.path.insert(0, HERE)
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(PROJECT, "assets", "characters")


# --- who to build ---------------------------------------------------------------
#
# `build` is a single dial for how heavy somebody is: it widens the torso and the
# limbs together. Height does the rest, because almost every other measurement on a
# human body is a fraction of it.

CHARACTERS = {
    "athlete_tall": dict(
        height=1.88, build=0.88,
        kit=(0.82, 0.16, 0.18), trim=(0.96, 0.94, 0.92),
        skin=(0.74, 0.56, 0.43), hair=(0.10, 0.08, 0.07), shoe=(0.94, 0.94, 0.95),
    ),
    "athlete_average": dict(
        height=1.78, build=1.00,
        kit=(0.20, 0.36, 0.72), trim=(0.95, 0.95, 0.96),
        skin=(0.86, 0.70, 0.56), hair=(0.30, 0.20, 0.12), shoe=(0.12, 0.13, 0.16),
    ),
    "athlete_stocky": dict(
        height=1.70, build=1.20,
        kit=(0.94, 0.78, 0.16), trim=(0.16, 0.17, 0.20),
        skin=(0.56, 0.40, 0.30), hair=(0.06, 0.05, 0.05), shoe=(0.90, 0.30, 0.28),
    ),
    "athlete_wiry": dict(
        height=1.75, build=0.90,
        kit=(0.14, 0.62, 0.44), trim=(0.94, 0.94, 0.92),
        skin=(0.80, 0.62, 0.47), hair=(0.16, 0.12, 0.10), shoe=(0.94, 0.94, 0.95),
    ),
    # The crowd. Dressed like somebody who came to watch rather than to play.
    "spectator": dict(
        height=1.74, build=1.06,
        kit=(0.42, 0.44, 0.50), trim=(0.30, 0.32, 0.36),
        skin=(0.78, 0.60, 0.46), hair=(0.20, 0.15, 0.11), shoe=(0.22, 0.20, 0.19),
        audience=True,
    ),
}


# --- proportions ----------------------------------------------------------------
#
# Fractions of total height, from standard figure-drawing proportions. Keeping them
# in one place means a 1.70 m player and a 1.88 m player are the same person scaled,
# rather than two people who happen to disagree about where a knee goes.

P = dict(
    ankle=0.039, knee=0.285, hip=0.520, waist=0.610, chest=0.720,
    shoulder=0.818, neck=0.855, chin=0.878, crown=1.000,
    shoulder_width=0.115, hip_width=0.082, foot_length=0.150,
    upper_arm=0.055, forearm=0.048, thigh=0.070, shin=0.055, head=0.072,
)


def build_all(names):
    os.makedirs(OUT_DIR, exist_ok=True)
    for name in names:
        spec = CHARACTERS[name]
        print(f"\n=== {name} ===")
        _clear_scene()
        body = _build_body(name, spec)
        rig = _build_armature(name, spec)
        _skin(body, rig)
        _make_clips(rig, spec)
        path = os.path.join(OUT_DIR, f"{name}.glb")
        _export(body, rig, path)
        print(f"    wrote {path}")


# --- the body -------------------------------------------------------------------

def _build_body(name, spec):
    """A person, out of primitives, joined into one smooth-shaded mesh.

    Every piece is tagged with the bone that owns it and weighted to that bone alone.
    Automatic weights were tried first and tore the character apart: bone heat needs
    a clean closed surface, and this is two dozen overlapping primitives welded into
    one object. Rigid pieces are also the honest choice for the style — at this
    polygon count a smoothly deforming elbow would not read as anything anyway, and
    a ball joint at each hinge hides the seam.
    """
    h = spec["height"]
    b = spec["build"]
    parts = []

    mats = {
        "kit": _material("kit", spec["kit"]),
        "trim": _material("trim", spec["trim"]),
        "skin": _material("skin", spec["skin"]),
        "hair": _material("hair", spec["hair"]),
        "shoe": _material("shoe", spec["shoe"]),
    }

    shoulder_w = h * P["shoulder_width"] * b
    hip_w = h * P["hip_width"] * b

    # Torso: hips, waist and chest as three stacked, tapered blocks.
    parts.append(_limb("hips", (0, 0, h * P["hip"]), (0, 0, h * P["waist"]),
                       hip_w * 1.05, hip_w * 0.98, mats["kit"], "hips", sides=10))
    parts.append(_limb("waist", (0, 0, h * P["waist"]), (0, 0, h * P["chest"]),
                       hip_w * 0.95, shoulder_w * 0.82, mats["kit"], "spine", sides=10))
    parts.append(_limb("chest", (0, 0, h * P["chest"]), (0, 0, h * P["shoulder"]),
                       shoulder_w * 0.84, shoulder_w * 0.98, mats["kit"], "chest", sides=10))
    parts.append(_limb("neck", (0, 0, h * P["shoulder"]), (0, 0, h * P["neck"] + h * 0.012),
                       h * 0.030 * b, h * 0.028 * b, mats["skin"], "neck", sides=8))

    # Sized and placed so the top of the hair lands on the crown rather than above
    # it. Without that everybody stood about 4 cm taller than they were specified,
    # which rather defeats the point of using real measurements.
    head = _sphere("head", (0, h * 0.006, h * 0.931), h * P["head"] * 0.94,
                   mats["skin"], "head")
    head.scale = (0.88, 1.0, 1.10)
    parts.append(head)
    cap = _sphere("hair", (0, -h * 0.004, h * 0.938), h * P["head"] * 0.96,
                  mats["hair"], "head")
    cap.scale = (0.90, 1.0, 0.70)
    parts.append(cap)

    for side, sx in (("L", 1.0), ("R", -1.0)):
        sh = Vector((sx * shoulder_w, 0, h * P["shoulder"]))
        elbow = Vector((sx * shoulder_w * 1.06, 0, h * (P["shoulder"] - 0.155)))
        wrist = Vector((sx * shoulder_w * 1.10, 0, h * (P["shoulder"] - 0.300)))

        parts.append(_limb(f"upper_arm_{side}", sh, elbow,
                           h * P["upper_arm"] * b, h * P["upper_arm"] * 0.82 * b,
                           mats["kit"], f"upper_arm.{side}", sides=8))
        parts.append(_limb(f"forearm_{side}", elbow, wrist,
                           h * P["forearm"] * 0.82 * b, h * P["forearm"] * 0.66 * b,
                           mats["skin"], f"forearm.{side}", sides=8))
        hand = _sphere(f"hand_{side}", wrist + Vector((0, 0, -h * 0.022)),
                       h * 0.030 * b, mats["skin"], f"hand.{side}")
        hand.scale = (0.72, 1.05, 1.35)
        parts.append(hand)

        # Ball joints, so a rigid shoulder and elbow have no gap to open up.
        parts.append(_sphere(f"shoulder_ball_{side}", sh, h * P["upper_arm"] * 1.02 * b,
                             mats["kit"], f"upper_arm.{side}"))
        parts.append(_sphere(f"elbow_ball_{side}", elbow, h * P["forearm"] * 0.84 * b,
                             mats["skin"], f"forearm.{side}"))

        hip = Vector((sx * hip_w * 0.62, 0, h * P["hip"]))
        knee = Vector((sx * hip_w * 0.66, 0, h * P["knee"]))
        ankle = Vector((sx * hip_w * 0.66, 0, h * P["ankle"]))

        parts.append(_limb(f"thigh_{side}", hip, knee,
                           h * P["thigh"] * b, h * P["thigh"] * 0.74 * b,
                           mats["trim"], f"thigh.{side}", sides=8))
        parts.append(_limb(f"shin_{side}", knee, ankle,
                           h * P["shin"] * 0.78 * b, h * P["shin"] * 0.50 * b,
                           mats["skin"], f"shin.{side}", sides=8))
        parts.append(_sphere(f"hip_ball_{side}", hip, h * P["thigh"] * 1.02 * b,
                             mats["trim"], f"thigh.{side}"))
        parts.append(_sphere(f"knee_ball_{side}", knee, h * P["thigh"] * 0.78 * b,
                             mats["skin"], f"shin.{side}"))

        foot = _box(f"foot_{side}",
                    ankle + Vector((0, h * 0.030, -h * 0.020)),
                    (h * 0.055 * b, h * P["foot_length"], h * 0.040),
                    mats["shoe"], f"foot.{side}")
        parts.append(foot)

    body = _join(parts, f"{name}_body")
    bpy.ops.object.shade_smooth()
    # Smooth shading everywhere would round off the shoes and the shoulders into
    # blobs, so anything meeting at more than 50 degrees keeps its edge.
    bpy.ops.object.shade_auto_smooth(angle=math.radians(50))
    return body


# --- the rig --------------------------------------------------------------------

def _build_armature(name, spec):
    h = spec["height"]
    b = spec["build"]
    shoulder_w = h * P["shoulder_width"] * b
    hip_w = h * P["hip_width"] * b

    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    rig = bpy.context.object
    rig.name = f"{name}_rig"
    rig.data.name = f"{name}_skeleton"

    bones = rig.data.edit_bones
    bones.remove(bones[0])

    def bone(bone_name, head, tail, parent=None, connected=False):
        eb = bones.new(bone_name)
        eb.head = Vector(head)
        eb.tail = Vector(tail)
        if parent is not None:
            eb.parent = bones[parent]
            eb.use_connect = connected
        return eb

    bone("root", (0, 0, 0), (0, 0, h * 0.10))
    bone("hips", (0, 0, h * P["hip"]), (0, 0, h * P["waist"]), "root")
    bone("spine", (0, 0, h * P["waist"]), (0, 0, h * P["chest"]), "hips", True)
    bone("chest", (0, 0, h * P["chest"]), (0, 0, h * P["shoulder"]), "spine", True)
    bone("neck", (0, 0, h * P["shoulder"]), (0, 0, h * P["neck"]), "chest", True)
    bone("head", (0, 0, h * P["neck"]), (0, 0, h * P["crown"]), "neck", True)

    for side, sx in (("L", 1.0), ("R", -1.0)):
        arm = (sx * shoulder_w, 0, h * P["shoulder"])
        elbow = (sx * shoulder_w * 1.06, 0, h * (P["shoulder"] - 0.155))
        wrist = (sx * shoulder_w * 1.10, 0, h * (P["shoulder"] - 0.300))
        hand = (sx * shoulder_w * 1.12, 0, h * (P["shoulder"] - 0.360))

        # No separate shoulder bone. There was one, and rotating it threw the whole
        # arm clean off the body — a connected child whose head is pinned to a parent
        # tail that the rotation moves. The upper arm gives all the shoulder movement
        # this needs, and one less joint is one less thing to be wrong.
        bone(f"upper_arm.{side}", arm, elbow, "chest")
        bone(f"forearm.{side}", elbow, wrist, f"upper_arm.{side}", True)
        bone(f"hand.{side}", wrist, hand, f"forearm.{side}", True)

        hip = (sx * hip_w * 0.62, 0, h * P["hip"])
        knee = (sx * hip_w * 0.66, 0, h * P["knee"])
        ankle = (sx * hip_w * 0.66, 0, h * P["ankle"])
        toe = (sx * hip_w * 0.66, h * P["foot_length"], h * P["ankle"] * 0.4)

        bone(f"thigh.{side}", hip, knee, "hips")
        bone(f"shin.{side}", knee, ankle, f"thigh.{side}", True)
        bone(f"foot.{side}", ankle, toe, f"shin.{side}", True)

    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def _skin(body, rig):
    """Binds the mesh to the skeleton with automatic weights."""
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    # By name, using the groups every primitive already carries. Not automatic
    # weights: bone heat needs a clean closed surface and this is two dozen
    # overlapping primitives, which it turns into confetti.
    bpy.ops.object.parent_set(type="ARMATURE_NAME")


# --- primitives -----------------------------------------------------------------

def _limb(name, start, end, r1, r2, material, bone, sides=8):
    """A tapered cylinder from `start` to `end`."""
    start = Vector(start)
    end = Vector(end)
    direction = end - start
    length = direction.length
    bpy.ops.mesh.primitive_cone_add(
        vertices=sides, radius1=r1, radius2=r2, depth=length,
        location=(start + end) * 0.5,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    _assign(obj, material, bone)
    return obj


def _sphere(name, centre, radius, material, bone):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=8,
                                         radius=radius, location=centre)
    obj = bpy.context.object
    obj.name = name
    _assign(obj, material, bone)
    return obj


def _box(name, centre, size, material, bone):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centre)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    _assign(obj, material, bone)
    return obj


def _assign(obj, material, bone):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    # One vertex group, named after the bone, every vertex fully weighted to it. The
    # groups survive the join, so the whole body ends up correctly weighted without
    # anything having to guess.
    group = obj.vertex_groups.new(name=bone)
    group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")


def _material(name, rgb):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = 0.72
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.25
    return mat


def _join(parts, name):
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return joined


def _clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    # Actions are marked with a fake user so they survive to be exported, which also
    # means they survive into the *next* character. Left alone, the last one built
    # carried every clip of everybody built before it — the spectator arrived in the
    # game with fifty-one animations, forty-eight of which were somebody else's.
    for action in list(bpy.data.actions):
        action.use_fake_user = False
        bpy.data.actions.remove(action)

    for block in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials,
                  bpy.data.objects):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


# --- animation ------------------------------------------------------------------
#
# Every clip is a list of (frame, pose). A pose names bones and gives each one an
# XYZ rotation in degrees; anything not named returns to rest. That keeps a whole
# animation readable as about eight lines, which matters when there are a dozen of
# them and every one will want adjusting after it is seen in the game.

from clips import CLIPS, AUDIENCE_CLIPS  # noqa: E402  (sys.path is set above)


def _make_clips(rig, spec):
    clips = AUDIENCE_CLIPS if spec.get("audience") else CLIPS
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")

    for bone in rig.pose.bones:
        bone.rotation_mode = "XYZ"

    rig.animation_data_create()
    for clip_name, clip in clips.items():
        action = bpy.data.actions.new(clip_name)
        action.use_fake_user = True
        rig.animation_data.action = action

        for frame, pose in clip["keys"]:
            _apply_pose(rig, pose)
            for bone in rig.pose.bones:
                bone.keyframe_insert(data_path="rotation_euler", frame=frame)
                if bone.name in ("root", "hips"):
                    bone.keyframe_insert(data_path="location", frame=frame)
        print(f"    clip {clip_name:<16} {len(clip['keys'])} keys")

    rig.animation_data.action = None
    bpy.ops.object.mode_set(mode="OBJECT")


def _apply_pose(rig, pose):
    for bone in rig.pose.bones:
        bone.rotation_euler = (0.0, 0.0, 0.0)
        bone.location = (0.0, 0.0, 0.0)
    for bone_name, values in pose.items():
        bone = rig.pose.bones.get(bone_name)
        if bone is None:
            continue
        if bone_name in ("root", "hips") and len(values) == 6:
            bone.rotation_euler = [math.radians(v) for v in values[:3]]
            bone.location = values[3:]
        else:
            bone.rotation_euler = [math.radians(v) for v in values]


# --- export ---------------------------------------------------------------------

def _export(body, rig, path):
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_skins=True,
        export_yup=True,
    )


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build_all(argv or list(CHARACTERS))
