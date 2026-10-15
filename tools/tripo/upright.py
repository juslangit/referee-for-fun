"""Stands a Tripo model up for Meshy rigging: turned about Z, centred, feet on z=0.

    blender --background --python tools/tripo/upright.py -- in.glb out.glb -90

Tripo exports a character facing +X and a metre tall; Meshy wants it facing the
viewer. Moved here from a scratch file on 2026-10-15, once it was needed nine times.
"""
import bpy, sys, math, mathutils
a = sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
meshes=[o for o in bpy.data.objects if o.type=="MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
for o in meshes:
    o.matrix_world = mathutils.Matrix.Rotation(math.radians(float(a[2])),4,"Z") @ o.matrix_world
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
pts=[o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
lo=mathutils.Vector([min(p[i] for p in pts) for i in range(3)]); hi=mathutils.Vector([max(p[i] for p in pts) for i in range(3)])
shift=mathutils.Vector((-(lo.x+hi.x)/2, -(lo.y+hi.y)/2, -lo.z))
for o in meshes:
    o.data.transform(mathutils.Matrix.Translation(shift))
for o in [o for o in bpy.data.objects if o.type!="MESH"]: bpy.data.objects.remove(o)
for o in meshes: o.parent=None
print("SIZE", tuple(round(x,3) for x in hi-lo))
bpy.ops.export_scene.gltf(filepath=a[1], export_format="GLB", use_selection=False)
