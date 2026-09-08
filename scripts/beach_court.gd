class_name BeachCourt
extends Node3D

## The sand, the tape, the net and the referee's stand.
##
## Much simpler than the badminton hall, and the simplicity is the point: a beach court
## is a rectangle of tape lying on sand with a net across it and no building around it
## at all. There are no service courts, no short service line and no centre line, so of
## the badminton court's eleven painted lines only four survive here — the two sidelines
## and the two end lines. Everything a beach referee judges on the floor is decided by
## those four.
##
## The other difference that matters is that the free zone is **in play**. In badminton
## the paint is the edge of the world; on the beach a player may chase a ball five
## metres past the tape and put it back, so the sand has to keep going long after the
## court has stopped.

## The sand sits a little above the world origin, and the court is a shade darker and a
## few millimetres proud of it, so the two read as separate surfaces.
##
## The order of these three numbers is load-bearing and was wrong first time. SURFACE_Y
## is the top of the *court*, not the top of the surrounding sand, because the court is
## the higher of the two — and the tape has to sit above that again or the court is
## drawn over its own lines and the player is asked to judge an unmarked rectangle.
const SAND_THICKNESS := 0.02
const COURT_INLAY := 0.004
const SURFACE_Y := SAND_THICKNESS + COURT_INLAY
const LINE_Y := SURFACE_Y + 0.003

## How far the sand runs past the tape before the stands start.
const SAND_MARGIN := BeachSpec.FREE_ZONE + 1.5

## Where the referee's stand goes: beside a post, looking down the net.
##
## This is the real position and it is nothing like the badminton chair. A beach
## referee stands *above the net*, high enough to look down on the tape from directly
## over it, which is why they can judge a net touch nobody else in the venue can see.
## The eye has to clear the top of the post, or the referee spends the match looking at
## it. A real beach referee's head is above the post for exactly this reason: the whole
## value of the position is an unobstructed view straight down the top of the net.
const POST_TOP := BeachSpec.NET_HEIGHT + 0.35
const STAND_OFFSET := 0.45
const EYE_HEIGHT := POST_TOP + 0.55

## The stand is drawn on its own layer so the referee's own camera can cull it. Sitting
## inside your own chair is a view of the inside of a chair.
const STAND_LAYER := 4

## Seating is not built here yet. The badminton Stands are placed against a hall that
## is 13.4 m long and walled; dropped around a 16 m beach court they sit in the wrong
## place and are made of indoor furniture. The venue gets dressed once the match plays.
var _net_parts: Array[MeshInstance3D] = []
var _net_rest: Array[Vector3] = []
var _shake_left := 0.0
var _shake_strength := 0.0

var _sand_material: StandardMaterial3D
var _line_material: StandardMaterial3D
var _net_material: StandardMaterial3D
var _post_material: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_sand()
	_build_lines()
	_build_net()
	_build_referee_stand()


func _build_materials() -> void:
	# Sand, and a slightly darker sand for the court itself. Real beach courts are one
	# colour, but a rectangle the eye can find without hunting for the tape is worth
	# the small lie — and a player who cannot see where the court is cannot referee it.
	_sand_material = _make_material(Color(0.90, 0.80, 0.61))
	_line_material = _make_material(Color(0.96, 0.96, 0.94))
	_net_material = _make_material(Color(0.13, 0.14, 0.16))
	_post_material = _make_material(Color(0.72, 0.73, 0.76))


func _make_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.95
	return material


func _build_sand() -> void:
	var length := (BeachSpec.HALF_LENGTH + SAND_MARGIN) * 2.0
	var width := (BeachSpec.HALF_WIDTH + SAND_MARGIN) * 2.0
	_add_box(
		"Sand",
		Vector3(width, SAND_THICKNESS, length),
		Vector3(0.0, SAND_THICKNESS * 0.5, 0.0),
		_sand_material
	)

	# The court itself, a shade darker, so the rectangle reads from the stand.
	# Enough darker than the surrounding sand to find without hunting for the tape.
	# The first pass was a six-percent difference, which vanished completely under a
	# low sun — and a player who cannot see where the court is cannot referee it.
	var court := _make_material(Color(0.72, 0.58, 0.38))
	_add_box(
		"CourtSand",
		Vector3(BeachSpec.HALF_WIDTH * 2.0, COURT_INLAY, BeachSpec.HALF_LENGTH * 2.0),
		Vector3(0.0, SAND_THICKNESS + COURT_INLAY * 0.5, 0.0),
		court
	)

	# Something for the ball to land on. The truth is taken from the ball's own height
	# solve rather than from this collision, but without a floor a missed rally falls
	# through the world.
	var body := StaticBody3D.new()
	body.name = "SandBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, SAND_THICKNESS, length)
	shape.shape = box
	shape.position = Vector3(0.0, SAND_THICKNESS * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)


## Four lines, and every one of them painted inside its own boundary.
##
## Same rule as badminton and for the same reason: a beach court is measured to the
## outer edge of the tape, so tape centred on the boundary would put the line the
## player sees several centimetres away from the line the game judges against. On a
## 6 cm tape that is a whole ball's width of accidental lying.
func _build_lines() -> void:
	var side := BeachSpec.HALF_WIDTH
	var back := BeachSpec.HALF_LENGTH
	for dir in [1.0, -1.0]:
		_add_lengthwise_line("Sideline", dir * side, -dir, -back, back)
		_add_crosswise_line("EndLine", dir * back, -dir, -side, side)


func _add_lengthwise_line(name: String, at_x: float, inward: float,
		from_z: float, to_z: float) -> void:
	var w := BeachSpec.LINE_WIDTH
	_add_line(name, at_x, at_x + inward * w, from_z, to_z)


func _add_crosswise_line(name: String, at_z: float, inward: float,
		from_x: float, to_x: float) -> void:
	var w := BeachSpec.LINE_WIDTH
	_add_line(name, from_x, to_x, at_z, at_z + inward * w)


func _add_line(name: String, x1: float, x2: float, z1: float, z2: float) -> void:
	var lo_x := minf(x1, x2)
	var hi_x := maxf(x1, x2)
	var lo_z := minf(z1, z2)
	var hi_z := maxf(z1, z2)
	_add_box(
		name,
		Vector3(hi_x - lo_x, 0.004, hi_z - lo_z),
		Vector3((lo_x + hi_x) * 0.5, LINE_Y, (lo_z + hi_z) * 0.5),
		_line_material
	)


func _build_net() -> void:
	var width := BeachSpec.HALF_WIDTH * 2.0
	var top := BeachSpec.NET_HEIGHT
	var tape := 0.07

	var mesh_height := BeachSpec.NET_DEPTH - tape
	_net_parts.append(_add_box(
		"NetMesh",
		Vector3(width, mesh_height, 0.02),
		Vector3(0.0, top - tape - mesh_height * 0.5, 0.0),
		_net_material
	))
	_net_parts.append(_add_box(
		"NetTape",
		Vector3(width, tape, 0.03),
		Vector3(0.0, top - tape * 0.5, 0.0),
		_line_material
	))

	# The antennae: the flexible rods standing on the net above each sideline. They are
	# the only vertical boundary in the sport — a ball passing outside one is out even
	# if it lands squarely in the court — so they are built to scale rather than
	# suggested, and they are what the referee lines their eye up with.
	var antenna := _make_material(Color(0.92, 0.30, 0.24))
	for dir in [1.0, -1.0]:
		_add_box(
			"Antenna",
			Vector3(0.02, BeachSpec.ANTENNA_HEIGHT, 0.02),
			Vector3(dir * BeachSpec.ANTENNA_X, top + BeachSpec.ANTENNA_HEIGHT * 0.5, 0.0),
			antenna
		)

	for part in _net_parts:
		_net_rest.append(part.position)

	var body := StaticBody3D.new()
	body.name = "NetBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, BeachSpec.NET_DEPTH, 0.03)
	shape.shape = box
	shape.position = Vector3(0.0, top - BeachSpec.NET_DEPTH * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)

	for dir in [1.0, -1.0]:
		_add_box(
			"Post",
			Vector3(0.09, POST_TOP, 0.09),
			Vector3(dir * BeachSpec.POST_X, POST_TOP * 0.5, 0.0),
			_post_material
		)


## The referee's stand: a platform beside a post, high enough to look down on the tape.
func _build_referee_stand() -> void:
	var at_x := BeachSpec.POST_X + STAND_OFFSET
	var frame := _make_material(Color(0.30, 0.32, 0.36))

	var floor_to_feet := EYE_HEIGHT - 1.55
	var legs := _add_box(
		"StandFrame",
		Vector3(0.7, floor_to_feet, 0.7),
		Vector3(at_x, floor_to_feet * 0.5, 0.0),
		frame
	)
	var platform := _add_box(
		"StandPlatform",
		Vector3(0.9, 0.08, 0.9),
		Vector3(at_x, floor_to_feet, 0.0),
		frame
	)
	for part in [legs, platform]:
		part.layers = STAND_LAYER


func _add_box(name: String, size: Vector3, at: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = at
	node.material_override = material
	add_child(node)
	return node


## The net shakes when somebody touches it — the one offence in either sport that the
## whole venue can see happen.
func shake(strength := 1.0) -> void:
	_shake_left = 0.9
	_shake_strength = strength


func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	var fade := clampf(_shake_left / 0.9, 0.0, 1.0)
	var offset := sin(_shake_left * 46.0) * 0.05 * _shake_strength * fade
	for i in _net_parts.size():
		_net_parts[i].position = _net_rest[i] + Vector3(0.0, 0.0, offset)
	if _shake_left <= 0.0:
		for i in _net_parts.size():
			_net_parts[i].position = _net_rest[i]
