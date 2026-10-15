"""Renders clips of a forged character at chosen frames, for judging poses by eye.

    blender --background --python tools/meshy/clip_sheet.py -- <animated.glb> <out_dir> clip:frame ...

One PNG per clip:frame, front-three-quarter view from the opponent's side of the net, with
the court floor as a grey plane so a foot off the floor shows. `badminton_strokes.py` was
checked this way, contact frame by contact frame.
"""
import math
import sys

import bpy
import mathutils

args = sys.argv[sys.argv.index("--") + 1:]
src, out, wanted = args[0], args[1], [a for a in args[2:] if a != "--numbers"]
NUMBERS_ONLY = "--numbers" in args
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scene = bpy.context.scene
rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
try:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 420
scene.render.resolution_y = 520
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs[0].default_value = (0.78, 0.8, 0.82, 1)
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (0.7, 0.2, -0.5)
scene.collection.objects.link(sun)
bpy.ops.mesh.primitive_plane_add(size=6)
floor = bpy.context.active_object
mat = bpy.data.materials.new("floor")
mat.diffuse_color = (0.35, 0.5, 0.4, 1)
floor.data.materials.append(mat)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = 2.9
# The character faces -Y; the camera stands in front of them and a little to their right.
cam.location = mathutils.Vector((-3.2, -6.5, 1.15))
direction = mathutils.Vector((0, 0, 1.0)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
rig.animation_data_create()
for item in wanted:
    clip, frame = item.split(":")
    action = bpy.data.actions.get(clip)
    if action is None:
        print("NO CLIP", clip)
        continue
    rig.animation_data.action = action
    scene.frame_set(int(frame))
    # How far the lowest point of the body is off the floor: under zero is a foot through
    # the court, over a few centimetres is a stance hanging in the air.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    lowest = min((o.evaluated_get(depsgraph).matrix_world @ v.co).z
                 for o in bpy.data.objects if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)
                 for v in o.evaluated_get(depsgraph).to_mesh().vertices)
    print(f"LOWEST {clip}:{frame} {lowest:+.3f}")
    if not NUMBERS_ONLY:
        scene.render.filepath = f"{out}/{clip}_{frame}.png"
        bpy.ops.render.render(write_still=True)
print("done")
