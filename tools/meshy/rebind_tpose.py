"""Re-binds a character that Meshy returned in an A-pose so its rest pose is a T.

    blender --background --python tools/meshy/rebind_tpose.py -- official_new
    blender --background --python tools/meshy/rebind_tpose.py -- official_new reweight

Reads  assets/meshy/<name>/<name>_rigged.glb
Writes assets/meshy/<name>/<name>_rigged.glb   (in place, after a .apose.glb backup)

Why this is needed and why rotating the bones was not enough
------------------------------------------------------------
Every arm angle in `badminton_clips.py` and its neighbours is written as a departure from
a T-pose — "straight out sideways", as the header there says — because that is how Meshy
generated the two athletes the clips were authored on. Measured, their upper arms rest 12
to 13 degrees off sideways. A character generated on 2026-09-17 came back resting **54**
degrees off, arms down and forward: an A-pose.

`rig_clips.lift_to_t_pose` corrects for that when posing, and the bone maths is right —
measured, the posed arm ends up within a couple of degrees of the reference rig's. But the
figure still came out wrong, because **the mesh is bound in the pose it was generated in**.
Forcing the shoulder 54 degrees back to a T stretches weights that were never painted for
it: the deltoid balloons, the torso is dragged with it, and an arm that the skeleton says
is pointing straight out reads as folded across the chest.

A bind pose cannot be undone by rotating a bone. It has to be rebuilt, which is what this
does, in the order that matters:

1. Pose the arms to a true T.
2. **Bake the mesh into that pose** by applying a copy of its Armature modifier, so the
   vertices themselves move to where the pose puts them.
3. Re-attach an Armature modifier, so it is deformable again.
4. Make the current pose the rest pose.

The weights are not repainted; they are the weights Meshy produced, now describing a T
instead of an A. That is enough for clips written against a T, and it is the difference
between a character that can use the project's 33 clips and one that cannot.

After this, `rig_clips.py` sees a rig within its `LEAVE_ALONE_WITHIN` threshold and applies
no correction at all — which is the right outcome. The correction in that file stays for
any future character that arrives in some third pose.

`reweight` — and why the pose alone was not the fault
-----------------------------------------------------
Rebuilding the bind pose took the rest from 54 degrees off sideways to 0 and made the
figure **worse**: the shoulders ballooned further and an arm the skeleton said was straight
out still read as folded across the chest. A bind pose that is right and a figure that is
wrong leaves one candidate — the weights themselves.

So `reweight` discards the vertex groups Meshy produced and has Blender paint its own from
the bone envelopes, on the T-posed rig, where automatic weighting has the best chance of
being sensible. It costs nothing, which is the whole argument for trying it before paying
Meshy 5 credits to rig the same mesh again and quite possibly return the same weights.
"""

import math
import os
import pathlib
import sys

import bpy
from mathutils import Vector

HERE = pathlib.Path(__file__).resolve().parent
ASSETS = HERE.parent.parent / "assets" / "meshy"

ARM_CHAIN = {"LeftArm": "LeftForeArm", "RightArm": "RightForeArm"}


def arm_offset(rig, bone_name):
    """How far this upper arm rests from straight out sideways, and the turn that fixes it."""
    child = ARM_CHAIN[bone_name]
    if bone_name not in rig.data.bones or child not in rig.data.bones:
        return 0.0, None
    along = rig.data.bones[child].head_local - rig.data.bones[bone_name].head_local
    if along.length < 1e-6:
        return 0.0, None
    along.normalize()
    sideways = Vector((1.0 if along.x >= 0.0 else -1.0, 0.0, 0.0))
    return math.degrees(along.angle(sideways)), along.rotation_difference(sideways)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not argv:
        raise SystemExit(__doc__)
    name = argv[0]
    reweight = "reweight" in argv[1:]
    source = ASSETS / name / f"{name}_rigged.glb"
    if not source.exists():
        raise SystemExit(f"missing {source}")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]

    before = {b: arm_offset(rig, b)[0] for b in ARM_CHAIN}
    print("  rests off sideways: " + ", ".join(f"{b} {d:.0f} deg" for b, d in before.items()))
    if max(before.values()) < 12.0:
        print("  already a T-pose — nothing to do")
        return

    # 1. Pose the arms straight out.
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    for bone_name in ARM_CHAIN:
        _, turn = arm_offset(rig, bone_name)
        if turn is None:
            continue
        posed = rig.pose.bones[bone_name]
        rest = posed.bone.matrix_local.to_3x3()
        posed.rotation_mode = "QUATERNION"
        posed.rotation_quaternion = (rest.inverted() @ turn.to_matrix() @ rest).to_quaternion()
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()

    # 2 and 3. Bake each mesh into the pose, then make it deformable again.
    for mesh in meshes:
        bpy.context.view_layer.objects.active = mesh
        armature_mods = [m for m in mesh.modifiers if m.type == "ARMATURE"]
        if not armature_mods:
            continue
        original = armature_mods[0]
        baked = mesh.modifiers.new(name="BakeTPose", type="ARMATURE")
        baked.object = original.object
        baked.use_deform_preserve_volume = original.use_deform_preserve_volume
        # Applying a *copy* leaves the original modifier in place, so the mesh stays
        # bound to the armature after its vertices have moved.
        bpy.ops.object.modifier_apply(modifier=baked.name)
        print(f"  baked {mesh.name} into the T-pose")

    # 4. The pose becomes the rest pose.
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()

    # 5. Optionally, weights painted from the bones rather than the ones Meshy shipped.
    if reweight:
        for mesh in meshes:
            for modifier in list(mesh.modifiers):
                if modifier.type == "ARMATURE":
                    mesh.modifiers.remove(modifier)
            mesh.vertex_groups.clear()
            bpy.ops.object.select_all(action="DESELECT")
            mesh.select_set(True)
            rig.select_set(True)
            bpy.context.view_layer.objects.active = rig
            bpy.ops.object.parent_set(type="ARMATURE_AUTO")
            print(f"  repainted {mesh.name}'s weights from the bones "
                  f"({len(mesh.vertex_groups)} groups)")
        bpy.ops.object.select_all(action="DESELECT")

    after = {b: arm_offset(rig, b)[0] for b in ARM_CHAIN}
    print("  now rests off sideways: " + ", ".join(f"{b} {d:.0f} deg" for b, d in after.items()))

    backup = ASSETS / name / f"{name}_rigged.apose.glb"
    if not backup.exists():
        os.replace(source, backup)
        print(f"  kept the A-posed original at {backup.name}")
    bpy.ops.export_scene.gltf(
        filepath=str(source), export_format="GLB",
        export_animations=True, export_skins=True, use_selection=False)
    print(f"\nwrote {source.relative_to(ASSETS.parent.parent)}")


main()
