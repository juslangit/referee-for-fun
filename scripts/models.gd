class_name Models
extends RefCounted

## Loads the downloaded Sketchfab models and makes them usable.
##
## Nothing that comes off an asset site arrives ready. Every model has its own idea
## of which way up it is, how big a metre is, and where its origin sits — one of
## these is two metres tall standing up, another is lying on its back with its origin
## in the middle of its chest. So everything goes through `_normalise`, which turns it
## the right way up, scales it to a real height and stands it on the floor at its own
## feet. After that the game can treat them all the same.
##
## If a model is missing — someone has cloned the repo without the assets, or a
## download failed — every one of these falls back to the boxes in `figure.gd`. A
## game that will not start because an athlete is missing is worse than a game with a
## box in it.

const ATHLETE := "res://assets/sketchfab/olympic_athlete/olympic_athlete.glb"
const OFFICIAL := "res://assets/sketchfab/male_character_in_caual_clothing/male_character_in_caual_clothing.glb"
const KIT := "res://assets/sketchfab/badminton_racket_and_shuttlecock_low_poly/badminton_racket_and_shuttlecock_low_poly.glb"

## Real heights, in metres.
const PLAYER_HEIGHT := 1.80
const OFFICIAL_HEIGHT := 1.76

## A badminton racket is about 67 cm long, and a shuttlecock about 8.5 cm.
const RACKET_LENGTH := 0.67
const SHUTTLE_LENGTH := 0.085


## A player, in their team's colour, holding a racket.
static func player(team_colour: Color) -> Node3D:
	var figure := _normalise(ATHLETE, PLAYER_HEIGHT)
	if figure == null:
		return null

	# A bib, not a tint.
	#
	# Recolouring the athlete was the obvious thing and it does not work: the kit is
	# painted red in the texture, and multiplying red by blue gives a dark red rather
	# than a blue. Both teams came out looking like the same team, which in a game
	# where you are deciding who wins a rally is not a cosmetic problem. So the model
	# keeps its own colours and wears a numbered-bib band over the top, which is how
	# amateur tournaments tell sides apart anyway.
	_add_bib(figure, team_colour)

	# The athlete stands with their arms down, so the racket hangs at their side.
	var held := racket()
	if held != null:
		held.position = Vector3(0.30, 0.74, 0.06)
		held.rotation = Vector3(deg_to_rad(-72.0), 0.0, deg_to_rad(-8.0))
		figure.add_child(held)

	return figure


## A band round the chest in the team's colour, bright enough to read across a hall.
static func _add_bib(figure: Node3D, colour: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.75

	# Sized to hug the chest. The first attempt was a good deal larger and every
	# player was wearing a sandwich board.
	for band in [[1.21, 0.15], [1.03, 0.04]]:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.325, band[1], 0.225)
		var instance := MeshInstance3D.new()
		instance.name = "Bib"
		instance.mesh = mesh
		instance.position = Vector3(0.0, band[0], 0.0)
		instance.material_override = material
		instance.layers = Figure.PEOPLE_LAYER
		figure.add_child(instance)


## A line judge. Deliberately not in either team's colours.
static func official() -> Node3D:
	# No correcting rotation, despite the mesh inside this one measuring 1.83 x 0.31 x
	# 1.80 and looking exactly like a Z-up export lying on its back. That figure is
	# the mesh's *local* box, and Sketchfab's exporter has already put a quarter turn
	# on the node above it. Adding another one laid the poor man flat and made him ten
	# metres wide. Measure the assembled model, not the mesh inside it.
	return _normalise(OFFICIAL, OFFICIAL_HEIGHT)


static func racket() -> Node3D:
	return _part(KIT, "Obj_Racket", RACKET_LENGTH)


static func shuttlecock() -> Node3D:
	return _part(KIT, "Gp_Shuttle", SHUTTLE_LENGTH)


static func has_assets() -> bool:
	return ResourceLoader.exists(ATHLETE) and ResourceLoader.exists(KIT)


# --- making a downloaded model behave ------------------------------------------

## Instantiates a model, turns it upright, scales it to `height` and stands it on the
## floor with its feet at the origin.
static func _normalise(path: String, height: float, pre_rotation := Vector3.ZERO) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null

	var holder := Node3D.new()
	holder.name = path.get_file().get_basename()

	var model: Node3D = scene.instantiate()
	model.rotation = pre_rotation
	holder.add_child(model)

	var box := _bounds(model)
	if box.size.y <= 0.001:
		return holder

	model.scale = Vector3.ONE * (height / box.size.y)
	box = _bounds(model)

	# Feet on the floor, and centred on where the game thinks the person is.
	model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	_set_layer(holder, Figure.PEOPLE_LAYER)
	return holder


## Pulls one named piece out of a model — a racket out of a pack that also contains
## a shuttlecock and two spare rackets — and scales it on its longest side.
static func _part(path: String, part_name: String, length: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null

	var whole: Node3D = scene.instantiate()
	var found := _find(whole, part_name)
	if found == null:
		whole.queue_free()
		return null

	# Lift it out of the pack, and throw the rest away.
	var holder := Node3D.new()
	holder.name = part_name
	found.get_parent().remove_child(found)
	found.owner = null
	holder.add_child(found)
	whole.queue_free()

	var box := _bounds(found)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest > 0.001:
		found.scale = Vector3.ONE * (length / longest)
		box = _bounds(found)
		found.position -= box.get_center()

	_set_layer(holder, Figure.PEOPLE_LAYER)
	return holder


## Multiplies every material by a colour, which tints a textured model without
## throwing the texture away — setting a material_override would lose it entirely.
static func _tint(node: Node, colour: Color) -> void:
	for child in _every(node):
		if not child is MeshInstance3D or child.mesh == null:
			continue
		for surface in child.mesh.get_surface_count():
			var material: Material = child.mesh.surface_get_material(surface)
			var tinted: StandardMaterial3D
			if material is StandardMaterial3D:
				tinted = material.duplicate()
			else:
				tinted = StandardMaterial3D.new()
			# Multiplying a dark kit by a dark colour gives black. The tint is
			# lightened so the team still reads at a glance, which matters more here
			# than the exact shade of somebody's shirt.
			tinted.albedo_color = colour.lerp(Color.WHITE, 0.30) * 1.35
			child.set_surface_override_material(surface, tinted)


## The size of everything under `node`, in `node`'s own space.
##
## Written as a descent that carries the transform down rather than a walk back up
## the parents, which is what the first version did and got wrong: a model given a
## quarter turn came back with its unrotated size, so it was scaled by the wrong
## dimension and ended up five times too big and still lying on its back.
static func _bounds(node: Node3D) -> AABB:
	var found := _gather(node, Transform3D.IDENTITY, AABB(), [false])
	return found


static func _gather(node: Node, so_far: Transform3D, box: AABB, started: Array) -> AABB:
	var here := so_far
	if node is Node3D:
		here = so_far * (node as Node3D).transform

	if node is MeshInstance3D and node.mesh != null:
		var piece: AABB = here * node.mesh.get_aabb()
		box = piece if not started[0] else box.merge(piece)
		started[0] = true

	for child in node.get_children():
		box = _gather(child, here, box, started)
	return box


static func _set_layer(node: Node, layer: int) -> void:
	for child in _every(node):
		if child is VisualInstance3D:
			child.layers = layer


static func _find(node: Node, wanted: String) -> Node3D:
	for child in _every(node):
		if child.name == wanted and child is Node3D:
			return child
	return null


static func _every(node: Node) -> Array:
	var found := [node]
	for child in node.get_children():
		found.append_array(_every(child))
	return found
