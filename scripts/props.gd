class_name Props
extends RefCounted

## Loads the downloaded furniture and fittings of the hall and makes them usable.
##
## Same problem as the characters, and worse. A model off an asset site arrives at
## whatever scale its author happened to work in and lying whichever way up their
## exporter felt like: the stadium seat in here is thirty-six units on its longest side
## with its origin twenty-five units above itself, and the line judge's folding chair
## is already in metres with its feet on the floor. So everything is measured on the
## way in and put where the game wants it.
##
## `correction` is supplied by the caller rather than guessed. The trick that works for
## people — a person is longest head to foot, so stand the longest axis up — is exactly
## wrong for a seat, which is deeper than it is tall.

const SEAT := "res://assets/sketchfab/stadium_seat/stadium_seat.glb"
const FOLDING_CHAIR := "res://assets/sketchfab/metal_folding_chair/metal_folding_chair.glb"
const HIGH_CHAIR := "res://assets/sketchfab/lifeguard_chair/lifeguard_chair.glb"
const TRUSS := "res://assets/sketchfab/rigging_truss_80cm_10meter_kolong/rigging_truss_80cm_10meter_kolong.glb"
const LAMP := "res://assets/sketchfab/stage_lights/stage_lights.glb"
const BOTTLE := "res://assets/sketchfab/sport_water_bottle/sport_water_bottle.glb"
const BAG := "res://assets/sketchfab/sports_bag/sports_bag.glb"
const BENCH := "res://assets/sketchfab/gym_bench_chair/gym_bench_chair.glb"

## A quarter turn about X, which is what an export from a Z-up package needs to stand
## up in Godot. Half the models here want it and half do not, so it is named.
##
## Which of the two quarter turns a given file needs is not guessable either: both stand
## the model up, and one of them stands it on its head. There is no way to tell from the
## outside, so it is looked at once and recorded.
static func z_up() -> Transform3D:
	return Transform3D.IDENTITY.rotated(Vector3.RIGHT, -PI * 0.5)


static func z_down() -> Transform3D:
	return Transform3D.IDENTITY.rotated(Vector3.RIGHT, PI * 0.5)


static func turned(degrees: float) -> Transform3D:
	return Transform3D.IDENTITY.rotated(Vector3.UP, deg_to_rad(degrees))


## One object, scaled to a real height and standing on the floor at its own feet.
static func node(path: String, height: float, correction := Transform3D.IDENTITY) -> Node3D:
	var found := _measure(path, height, correction)
	if found.is_empty():
		return null
	var holder := Node3D.new()
	holder.name = path.get_file().get_basename()
	var model: Node3D = load(path).instantiate()
	model.transform = found[1]
	holder.add_child(model)
	return holder


## The same object as a single mesh plus the transform that sizes it, for the things
## there are hundreds of. A MultiMesh draws one mesh many times and cannot instance a
## node tree, so every surface is merged into one mesh with a surface per material.
## Taking only the first mesh — which is the obvious thing to write — seats three
## hundred people in the front half of a chair.
##
## `keep` below one trades detail for speed — see `simplified`. The seats need it and the
## people do not.
static func merged(path: String, height: float, correction := Transform3D.IDENTITY,
		keep := 1.0) -> Array:
	if not ResourceLoader.exists(path):
		return []
	var model: Node3D = load(path).instantiate()

	var builders := {}
	var order: Array[Material] = []
	for child in _every(model):
		if not (child is MeshInstance3D):
			continue
		var piece := child as MeshInstance3D
		if piece.mesh == null:
			continue
		var place := correction * _local_transform(piece, model)
		for surface in piece.mesh.get_surface_count():
			var paint: Material = piece.get_active_material(surface)
			if not builders.has(paint):
				var fresh := SurfaceTool.new()
				fresh.begin(Mesh.PRIMITIVE_TRIANGLES)
				builders[paint] = fresh
				order.append(paint)
			(builders[paint] as SurfaceTool).append_from(piece.mesh, surface, place)
	model.queue_free()
	if order.is_empty():
		return []

	var mesh := ArrayMesh.new()
	for paint in order:
		var builder: SurfaceTool = builders[paint]
		if paint is StandardMaterial3D:
			# Instance colour is only allowed to touch the model's own paint if the
			# material says so, and it is what turns one seat into a stand full of them.
			var shaded: StandardMaterial3D = (paint as StandardMaterial3D).duplicate()
			shaded.vertex_color_use_as_albedo = true
			builder.set_material(shaded)
		# Simplifying needs shared corners to know which triangles are neighbours, and
		# a merged mesh comes out with every triangle owning its own three.
		if keep < 1.0:
			builder.index()
		builder.commit(mesh)
	if keep < 1.0:
		mesh = simplified(mesh, keep)

	var box := mesh.get_aabb()
	if box.size.y <= 0.0001:
		return []
	var fit := height / box.size.y
	var stand := Transform3D.IDENTITY.scaled(Vector3.ONE * fit)
	stand.origin.y -= box.position.y * fit
	return [mesh, stand]


## The same model with fewer triangles, keeping roughly `keep` of them.
##
## For the things drawn by the hundred. The stadium seat off Sketchfab is 7,404 triangles
## — as many as half a player — and there are 312 of them, which made the seats alone
## eighty per cent of everything drawn in the hall and held badminton to twenty-odd
## frames a second. From the chair a seat is a few pixels across and nobody can count its
## bolts.
##
## The work is done by the same level-of-detail generator Godot's importer uses, and the
## coarsest level that still keeps `keep` of the triangles is taken for good. Anything
## that goes wrong along the way — a mesh with no data to read, a generator that found
## nothing to remove — hands back the original, because a seat drawn slowly is better
## than no seat.
static func simplified(mesh: ArrayMesh, keep: float) -> ArrayMesh:
	var source := ImporterMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.is_empty() or arrays[Mesh.ARRAY_INDEX] == null:
			return mesh
		source.add_surface(mesh.surface_get_primitive_type(surface), arrays, [], {},
			mesh.surface_get_material(surface))
	source.generate_lods(25.0, 60.0, [])

	var fewer := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.get_surface_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var wanted := int(float(indices.size()) * keep)
		# Levels come finest first. The last one still holding enough triangles is the one.
		for level in source.get_surface_lod_count(surface):
			var coarser := source.get_surface_lod_indices(surface, level)
			if coarser.size() >= wanted and coarser.size() < indices.size():
				indices = coarser
		arrays[Mesh.ARRAY_INDEX] = indices
		fewer.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		fewer.surface_set_material(surface, source.get_surface_material(surface))
	return fewer


## The transform that scales a model to `height` and stands it on the floor. Measured
## from the assembled model rather than from the mesh inside it, because exporters put
## corrections on the nodes above the mesh and measuring the mesh alone reads those as
## part of the shape.
static func _measure(path: String, height: float, correction: Transform3D) -> Array:
	if not ResourceLoader.exists(path):
		return []
	var model: Node3D = load(path).instantiate()
	var box := AABB()
	var started := false
	for child in _every(model):
		if not (child is MeshInstance3D):
			continue
		var piece := child as MeshInstance3D
		if piece.mesh == null:
			continue
		var here: AABB = (correction * _local_transform(piece, model)) * piece.mesh.get_aabb()
		box = here if not started else box.merge(here)
		started = true
	model.queue_free()
	if not started or box.size.y <= 0.0001:
		return []

	var fit := height / box.size.y
	var placed := Transform3D.IDENTITY.scaled(Vector3.ONE * fit) * correction
	placed.origin.y -= box.position.y * fit
	# Centred over its own footprint, so an object put at a position stands there
	# rather than somewhere off to one side of it.
	placed.origin.x -= (box.position.x + box.size.x * 0.5) * fit
	placed.origin.z -= (box.position.z + box.size.z * 0.5) * fit
	return [box, placed]


static func _local_transform(node: Node3D, root: Node3D) -> Transform3D:
	var carried := Transform3D.IDENTITY
	var walker: Node = node
	while walker != null and walker is Node3D:
		carried = (walker as Node3D).transform * carried
		if walker == root:
			break
		walker = walker.get_parent()
	return carried


static func _every(node: Node) -> Array:
	var found := [node]
	for child in node.get_children():
		found.append_array(_every(child))
	return found
