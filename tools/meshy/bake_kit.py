"""Bakes a repainted kit into its own character file.

    blender --background --python tools/meshy/bake_kit.py -- player_blue libero

Reads  assets/meshy/<name>/<name>_animated.glb
       assets/meshy/<name>_<kit>/<name>_<kit>_texture.png
Writes assets/meshy/<name>_<kit>/<name>_<kit>_animated.glb

Why a second file rather than a material swap
---------------------------------------------
The obvious way to put a libero in a different shirt is to override the material at
runtime. It was tried on 2026-09-17 and it does not draw. The override was verified to
be set, with the right texture, on `char1` — the one visible MeshInstance3D of the right
player, on a layer the camera renders, with no competing `material_override` or
`material_overlay` — and re-applying it late, and forcing a garish albedo colour, and
hiding every other player to be certain nothing was standing in front, all came back the
original blue. Whatever swallows it was not found.

So this does what the project already does for the two teams: `player_red` and
`player_blue` are not one model tinted twice, they are two files. The libero is a third.
That needs no runtime material surgery at all — the model simply arrives wearing the
right shirt — and it is the path the game is known to render correctly.
"""

import os
import pathlib
import sys

import bpy

HERE = pathlib.Path(__file__).resolve().parent
ASSETS = HERE.parent.parent / "assets" / "meshy"


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 2:
        raise SystemExit(__doc__)
    name, kit = argv[0], argv[1]

    source = ASSETS / name / f"{name}_animated.glb"
    sheet = ASSETS / f"{name}_{kit}" / f"{name}_{kit}_texture.png"
    out_dir = ASSETS / f"{name}_{kit}"
    target = out_dir / f"{name}_{kit}_animated.glb"
    for path in (source, sheet):
        if not path.exists():
            raise SystemExit(f"missing {path}")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))

    # Replace the image *datablock* on every texture node rather than repointing the
    # existing one.
    #
    # The first version set `image.filepath` and called `reload()`, and it silently did
    # nothing: an image that arrived inside a GLB is **packed**, and `reload()` on a
    # packed image reloads the packed bytes, not the new path. The export then re-embedded
    # the original. It was convincing, too — Blender had taken the new *name*, so Godot
    # imported a texture called `..._libero_texture.png` that was still the blue kit. The
    # only thing that caught it was reading the colours back out of the exported file.
    fresh = bpy.data.images.load(str(sheet))
    fresh.pack()
    swapped = 0
    for material in bpy.data.materials:
        if not material.use_nodes:
            continue
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image is not fresh:
                node.image = fresh
                swapped += 1
    if swapped == 0:
        raise SystemExit("no image texture node found — nothing was repainted")
    print(f"  swapped {swapped} texture node(s) for {sheet.name}")

    out_dir.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(target),
        export_format="GLB",
        export_animations=True,
        export_skins=True,
        use_selection=False,
    )
    size = os.path.getsize(target) / 1e6
    print(f"\nwrote {target.relative_to(ASSETS.parent.parent)}  ({size:.1f} MB)")


main()
