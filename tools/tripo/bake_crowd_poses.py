"""Freezes a rigged Tripo spectator into the three static poses the stands draw.

    blender --background --python tools/tripo/bake_crowd_poses.py -- fan_uncle

Reads  assets/meshy/<name>/<name>_animated.glb   (from build_person.sh)
Writes assets/characters/<name>_sit.glb, _lean.glb and _stand.glb

The stands draw three hundred people with MultiMeshes, which have no skeleton, so a
spectator has to arrive already posed, as plain geometry. Same idea as
tools/blender/crowd_poses.py, which did it for the forge's spectator: put the rig in a
pose from one of the character's own clips, apply the armature so the deformation
becomes the mesh, and export with no rig and no animation. The realistic fans replaced
the forge's spectator on 2026-10-15.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler

PROJECT = Path(__file__).resolve().parent.parent.parent

TEXTURE = 1024

## Which clip, how far into it, and any extra lean on the spine (degrees about X).
POSES = {
    "sit": ("sit", 0.5, 0.0),
    "lean": ("sit", 0.5, 12.0),
    "stand": ("celebrate", 0.45, 0.0),
}


def bake(name, pose):
    clip, at, lean = POSES[pose]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(PROJECT / f"assets/meshy/{name}/{name}_animated.glb"))
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    action = next((a for a in bpy.data.actions if a.name == clip or a.name.startswith(clip + "_")
                   or a.name.endswith("|" + clip)), None)
    if action is None:
        sys.exit(f"{name} has no {clip} clip: {[a.name for a in bpy.data.actions]}")
    rig.animation_data_create()
    rig.animation_data.action = action
    start, end = action.frame_range
    bpy.context.scene.frame_set(int(start + (end - start) * at))
    # Unhooked from the clip, the bones keep the pose they were just put in, and the
    # lean can be added on top without the clip putting it back.
    rig.animation_data.action = None
    if lean:
        spine = rig.pose.bones.get("Spine02") or rig.pose.bones.get("Spine01") or rig.pose.bones.get("Spine")
        spine.rotation_quaternion = spine.rotation_quaternion @ Euler(
            (math.radians(lean), 0, 0)).to_quaternion()
    bpy.context.view_layer.update()

    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for mesh in meshes:
        bpy.context.view_layer.objects.active = mesh
        for mod in list(mesh.modifiers):
            if mod.type == "ARMATURE":
                bpy.ops.object.modifier_apply(modifier=mod.name)
        world = mesh.matrix_world.copy()
        mesh.parent = None
        mesh.matrix_world = world
        mesh.vertex_groups.clear()
    for obj in [o for o in bpy.data.objects if o.type != "MESH"]:
        bpy.data.objects.remove(obj)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    # A spectator is a few dozen pixels tall from the chair; Tripo's 4K texture is
    # wasted on them and would be stored three times over, once per pose.
    for image in bpy.data.images:
        if image.size[0] > TEXTURE:
            image.scale(TEXTURE, TEXTURE)
    out = PROJECT / f"assets/characters/{name}_{pose}.glb"
    bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_animations=False,
                              export_skins=False, export_apply=True)
    print(f"wrote {out.relative_to(PROJECT)}")


name = sys.argv[sys.argv.index("--") + 1]
for pose in POSES:
    bake(name, pose)
