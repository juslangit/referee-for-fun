"""Bakes the crowd: the spectator frozen sitting down and frozen on their feet.

Run headless:

    blender --background --python tools/blender/crowd_poses.py

Three hundred people in a hall are drawn by two MultiMeshes, and a MultiMesh draws one
mesh many times without a skeleton — it cannot pose anything. So a seated spectator has
to arrive already seated, as geometry.

That is what this does: it builds the spectator out of `character_forge`, puts the rig
into one pose, applies the armature modifier so the deformation becomes the mesh, and
exports a static glTF with no rig and no animations in it. `Stands` then keeps both
meshes and swaps which one a given spectator is drawn with.

Two builds, because the crowd used to be two different downloaded people and losing that
would make a hall of three hundred identical men. Here the difference is height and
weight off the forge's own dials, which is a truer difference than two unrelated models
at two unrelated scales.
"""

import os
import sys

import bpy

HERE = os.path.dirname(os.path.realpath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import character_forge as forge
from clips import _SEATED, _pose


# On their feet, arms up. Every bone the seated pose folds is simply left at rest, which
# is a person standing straight, so this only has to say what the arms and the back do.
_ON_THEIR_FEET = {
    "spine": (-4, 0, 0),
    "head": (8, 0, 0),
    "upper_arm.L": (-18, 0, 132), "forearm.L": (-34, 0, 0),
    "upper_arm.R": (-18, 0, -132), "forearm.R": (-34, 0, 0),
}

## Leaning forward a little, from the middle of the `sit` clip: the same person, not
## quite sitting the same way.
_SEATED_LEAN = _pose(_SEATED, spine=(10, 2, 0), head=(-4, 3, 0))


# The shirt is almost white on purpose. `Stands` tints it per spectator with the
# MultiMesh's instance colour, which multiplies, so whatever is painted here is a filter
# over every shirt in the hall — a grey shirt can only ever come out a darker grey. Near
# white lets the instance colour *be* the shirt, which is how three hundred people end up
# in three hundred shirts including a scattering in the two team colours.
#
# Nothing else is tinted. Skin, hair, shoes and trim keep what is painted here, which is
# why the two builds have different colouring: instance colour used to cover the whole
# person at once and could not tell a face from a shirt.
_SHIRT = (0.92, 0.92, 0.93)

PEOPLE = {
    "crowd_a": dict(
        height=1.74, build=1.06,
        kit=_SHIRT, trim=(0.30, 0.32, 0.36),
        skin=(0.78, 0.60, 0.46), hair=(0.20, 0.15, 0.11), shoe=(0.22, 0.20, 0.19),
        audience=True,
    ),
    "crowd_b": dict(
        height=1.63, build=0.94,
        kit=_SHIRT, trim=(0.34, 0.33, 0.30),
        skin=(0.62, 0.46, 0.35), hair=(0.09, 0.07, 0.06), shoe=(0.30, 0.30, 0.32),
        audience=True,
    ),
}

POSES = {
    "sit": _SEATED,
    "lean": _SEATED_LEAN,
    "stand": _ON_THEIR_FEET,
}


def build_all():
    os.makedirs(forge.OUT_DIR, exist_ok=True)
    for name, spec in PEOPLE.items():
        for pose_name, pose in POSES.items():
            forge._clear_scene()
            body = forge._build_body(name, spec)
            rig = forge._build_armature(name, spec)
            forge._skin(body, rig)

            bpy.context.view_layer.objects.active = rig
            bpy.ops.object.mode_set(mode="POSE")
            # Every bone on to Euler first. A pose bone is on quaternions by default and
            # `_apply_pose` writes `rotation_euler`, which on a quaternion bone is
            # recorded and ignored — the first run of this script exported six identical
            # files of a man standing to attention and the sizes matching to the byte was
            # the only sign.
            for bone in rig.pose.bones:
                bone.rotation_mode = "XYZ"
            forge._apply_pose(rig, pose)
            bpy.ops.object.mode_set(mode="OBJECT")
            bpy.context.view_layer.update()

            _bake(body)
            _stand_on_the_floor(body)

            path = os.path.join(forge.OUT_DIR, f"{name}_{pose_name}.glb")
            _export_static(body, path)
            print(f"    wrote {path}")


def _bake(body):
    """Turns the posed deformation into the mesh itself, and drops the rig."""
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    for modifier in list(body.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def _stand_on_the_floor(body):
    """Puts the lowest vertex at y = 0.

    A seated pose drops the hips and folds the legs, and whether the shoes still touch
    the floor afterwards depends on the numbers in the pose rather than on anything this
    script knows. Both meshes are placed on the same seat position in the game, so they
    have to agree about where the bottom of a person is.
    """
    lowest = min((body.matrix_world @ v.co).z for v in body.data.vertices)
    body.location.z -= lowest
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)


def _export_static(body, path):
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        # No rig and no clips: this is furniture-shaped geometry now, and a MultiMesh
        # would ignore both anyway.
        export_animations=False,
        export_skins=False,
        export_yup=True,
    )


if __name__ == "__main__":
    build_all()
