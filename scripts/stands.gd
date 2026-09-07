class_name Stands
extends Node3D

## The seating down both sides of the hall, and the people in it.
##
## The crowd is the only thing in the game that tells the player how much trouble
## they are in, and until now it was a disembodied voice with nothing attached. Now
## there is a room full of people to be shouted at by.
##
## Everybody is drawn with two MultiMeshes — one for bodies, one for heads — because
## three hundred separate nodes for scenery nobody looks at closely would cost more
## than the rest of the game put together. A MultiMesh draws them all in one go.

## Where the seating starts, how deep each row is, and how much each one rises.
const FIRST_ROW_X := 4.60
const ROW_DEPTH := 0.85
const ROW_RISE := 0.38
const ROWS := 6

## How far the seating runs along the hall, and how far apart people sit.
const HALF_LENGTH := 10.4
const SEAT_SPACING := 0.80

## The two sides of the hall. Typed, because a bare [1.0, -1.0] is an untyped Array
## and everything derived from an element of it becomes a Variant.
const SIDES: Array[float] = [1.0, -1.0]

## Shirt colours for the crowd. Mostly drab, with enough of the two team colours
## scattered through it to look like people who came to watch somebody in particular.
const SHIRTS := [
	Color(0.32, 0.34, 0.38),
	Color(0.45, 0.42, 0.40),
	Color(0.26, 0.30, 0.36),
	Color(0.52, 0.48, 0.44),
	Color(0.38, 0.36, 0.34),
	Color(0.72, 0.30, 0.28),
	Color(0.30, 0.48, 0.74),
]

var _bodies: MultiMeshInstance3D
var _heads: MultiMeshInstance3D
var _total := 0


func _ready() -> void:
	_build_seating()
	_build_crowd()


## How full the hall is, from empty to packed. A school hall has a handful of
## parents in it; an international final does not have a spare seat.
func set_density(density: float) -> void:
	var showing := roundi(_total * clampf(density, 0.0, 1.0))
	_bodies.multimesh.visible_instance_count = showing
	_heads.multimesh.visible_instance_count = showing


func _build_seating() -> void:
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.42, 0.42, 0.45)
	concrete.roughness = 0.95

	var front := StandardMaterial3D.new()
	front.albedo_color = Color(0.30, 0.31, 0.34)
	front.roughness = 0.95

	for side: float in SIDES:
		for row in ROWS:
			var height := ROW_RISE * float(row + 1)
			var x := side * (FIRST_ROW_X + ROW_DEPTH * (float(row) + 0.5))

			var step := MeshInstance3D.new()
			step.name = "Step"
			var box := BoxMesh.new()
			box.size = Vector3(ROW_DEPTH, height, HALF_LENGTH * 2.0)
			step.mesh = box
			step.position = Vector3(x, height * 0.5, 0.0)
			step.material_override = concrete if row % 2 == 0 else front
			add_child(step)


func _build_crowd() -> void:
	# Every seat, in a shuffled order. Shuffling matters: a half-empty hall is drawn
	# by showing only the first so many instances, and unshuffled that would seat
	# everybody in one solid block at one end.
	var seats: Array[Transform3D] = []
	for side: float in SIDES:
		for row in ROWS:
			var height := ROW_RISE * float(row + 1)
			var x := side * (FIRST_ROW_X + ROW_DEPTH * (float(row) + 0.5))
			var z := -HALF_LENGTH + SEAT_SPACING * 0.5
			while z < HALF_LENGTH:
				var seat := Transform3D.IDENTITY
				# Turned to face the court, with a little slouch either way.
				seat.basis = Basis(Vector3.UP, (PI * 0.5 * side) + randf_range(-0.18, 0.18))
				seat.origin = Vector3(x + randf_range(-0.12, 0.12), height, z)
				seats.append(seat)
				z += SEAT_SPACING
	seats.shuffle()
	_total = seats.size()

	# One colour per person, decided once. The head and the body are drawn by two
	# separate MultiMeshes, and if each picked its own colour every spectator would
	# be wearing somebody else's head.
	var shirts: Array[Color] = []
	for i in _total:
		shirts.append(SHIRTS[randi() % SHIRTS.size()])

	# The head sits low enough to overlap the shoulders. Any higher and three hundred
	# people appear to be balancing their heads an inch above their necks.
	_bodies = _make_crowd_mesh("Bodies", _body_mesh(), seats, shirts, 0.35)
	_heads = _make_crowd_mesh("Heads", _head_mesh(), seats, shirts, 0.78)


## `lift` raises the part above the step the person is sitting on, since both
## MultiMeshes work from the same seat positions.
func _make_crowd_mesh(
	part: String,
	mesh: Mesh,
	seats: Array[Transform3D],
	shirts: Array[Color],
	lift: float
) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = seats.size()

	for i in seats.size():
		var seat := seats[i]
		seat.origin += Vector3(0.0, lift, 0.0)
		multi.set_instance_transform(i, seat)
		multi.set_instance_color(i, shirts[i])

	var instance := MultiMeshInstance3D.new()
	instance.name = part
	instance.multimesh = multi
	instance.layers = Figure.PEOPLE_LAYER
	add_child(instance)
	return instance


func _body_mesh() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.40, 0.74, 0.32)
	mesh.material = _crowd_material()
	return mesh


func _head_mesh() -> Mesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.115
	sphere.height = 0.23
	sphere.radial_segments = 8
	sphere.rings = 5
	sphere.material = _crowd_material()
	return sphere


## Takes its colour from the instance rather than the material, so one mesh can be
## three hundred differently dressed people.
func _crowd_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	return material
