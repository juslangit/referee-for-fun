"""Cleans a Tripo character after Meshy has rigged it, before the clips are forged.

    blender --background --python tools/tripo/clean_rig.py -- player_c

Reads  assets/meshy/<name>/<name>_rigged_raw.glb   (Meshy's file, kept as delivered)
       assets/tripo/<name>/<name>_flat.png         (tools/tripo/flatten_texture.py)
Writes assets/meshy/<name>/<name>_rigged.glb       (what rig_clips.py forges from)

Two fixes, both for "the players shading looks bad" (Luqman, 2026-10-15):

- Normals. Tripo's mesh is shaded smooth everywhere, so the blocky style's hard edges —
  jaw, the box of the head, sleeves, shoe soles — smear into dark gradients. Smooth by
  angle at 40 degrees keeps the planes flat and the corners crisp, which is how style C
  was drawn.
  Weighted normals on top flatten the broad planes, so small bumps stop shading.
- Texture and light. The flattened sheet replaces Tripo's noisy one, and a quarter of it
  is fed back as emission so the kit keeps its colour in a dark hall. The Meshy players
  this replaces were fully emissive and read flat; a quarter lifts the colour and leaves
  the shading to the lights.
"""

import math
import pathlib
import sys

import bpy

HERE = pathlib.Path(__file__).resolve().parent
PROJECT = HERE.parent.parent
ANGLE = 40.0
EMISSION = 0.25


def main():
    name = sys.argv[sys.argv.index("--") + 1]
    raw = PROJECT / "assets" / "meshy" / name / f"{name}_rigged_raw.glb"
    sheet = PROJECT / "assets" / "tripo" / name / f"{name}_flat.png"
    out = PROJECT / "assets" / "meshy" / name / f"{name}_rigged.glb"

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(raw))
    image = bpy.data.images.load(str(sheet))
    image.pack()

    for obj in [o for o in bpy.data.objects if o.type == "MESH" and o.parent]:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(ANGLE))
        # Weighted normals: each vertex takes the normal of the largest face around it,
        # so a broad plane — cheek, chest, shin — shades as one tone instead of picking
        # up every small bump Tripo left in the surface. Applied ahead of the armature.
        weighted = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
        weighted.mode = "FACE_AREA"
        weighted.weight = 100
        weighted.keep_sharp = True
        bpy.ops.object.modifier_move_to_index(modifier=weighted.name, index=0)
        bpy.ops.object.modifier_apply(modifier=weighted.name)
        for mat in obj.data.materials:
            nodes = mat.node_tree.nodes
            bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
            tex = next(n for n in nodes if n.type == "TEX_IMAGE")
            tex.image = image
            mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = EMISSION
            bsdf.inputs["Roughness"].default_value = 0.85
        print(f"  {obj.name}: smooth by angle {ANGLE:.0f}, flat sheet, emission {EMISSION}")

    bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB",
                              export_animations=False, export_yup=True)
    print(f"wrote {out.relative_to(PROJECT)}")


main()
