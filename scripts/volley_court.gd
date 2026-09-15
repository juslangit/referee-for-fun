class_name VolleyCourt
extends Node3D

## An indoor volleyball court, in a hall.
##
## The beach court is a rectangle of tape on sand with nothing around it. This one is a
## sprung wooden floor inside a building, with a line the beach has no use for: the
## attack line, three metres from the net on each side.
##
## The referee stands where they do on the beach — on a platform at the post, looking
## down the top of the net — because that is where the first referee stands in both
## versions of the sport.

const FLOOR_THICKNESS := 0.02
const SURFACE_Y := FLOOR_THICKNESS
const LINE_Y := SURFACE_Y + 0.003

## How far the floor runs past the lines before the walls start.
const FLOOR_MARGIN := VolleySpec.FREE_ZONE + 2.0

const POST_TOP := VolleySpec.NET_HEIGHT + 0.35
const STAND_OFFSET := 0.45
const EYE_HEIGHT := POST_TOP + 0.55
const STAND_LAYER := 4

const HALL_HEIGHT := 11.0

## How far out the side walls are. Past the back row of the stands, which start just beyond
## the free zone and climb six rows: the walls used to stand where the floor ends, which put
## them through the second row of seats and hid everybody behind it.
const HALL_HALF_WIDTH := VolleySpec.HALF_WIDTH + VolleySpec.FREE_ZONE + 1.0 + 6.0 * 0.90 + 0.7

var stands: Stands
## The event round the court: see EventDressing.
var event: EventDressing

var _net_parts: Array[MeshInstance3D] = []
var _net_rest: Array[Vector3] = []
var _shake_left := 0.0
var _shake_strength := 0.0

var _floor_material: StandardMaterial3D
var _line_material: StandardMaterial3D
var _net_material: StandardMaterial3D
var _post_material: StandardMaterial3D
var _hall_material: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_floor()
	_build_lines()
	_build_net()
	_build_referee_stand()
	_build_hall()
	_build_stands()


func _build_materials() -> void:
	# A sprung maple floor under hall lights, and the court painted on it. The first
	# pass had the two within a few percent of each other and the whole hall read as
	# one flat brown.
	_floor_material = _make_material(Color(0.86, 0.71, 0.48))
	_line_material = _make_material(Color(0.96, 0.96, 0.94))
	_net_material = _make_material(Color(0.13, 0.14, 0.16))
	_post_material = _make_material(Color(0.72, 0.73, 0.76))
	_hall_material = _make_material(Color(0.28, 0.29, 0.34))


func _make_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	return material


func _build_floor() -> void:
	var length := (VolleySpec.HALF_LENGTH + FLOOR_MARGIN) * 2.0
	var width := (VolleySpec.HALF_WIDTH + FLOOR_MARGIN) * 2.0
	_add_box("Floor", Vector3(width, FLOOR_THICKNESS, length),
		Vector3(0.0, FLOOR_THICKNESS * 0.5, 0.0), _floor_material)

	# The court itself, a shade darker than the surrounding boards. A real hall paints
	# the free zone a different colour for exactly this reason: so the players and the
	# officials can see where the court stops without reading the line.
	var inside := _make_material(Color(0.92, 0.46, 0.26))
	_add_box("CourtFloor",
		Vector3(VolleySpec.HALF_WIDTH * 2.0, 0.004, VolleySpec.HALF_LENGTH * 2.0),
		Vector3(0.0, FLOOR_THICKNESS + 0.002, 0.0), inside)

	var body := StaticBody3D.new()
	body.name = "FloorBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, FLOOR_THICKNESS, length)
	shape.shape = box
	shape.position = Vector3(0.0, FLOOR_THICKNESS * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)


## Six lines: two sidelines, two end lines, and the two attack lines that are the whole
## reason this sport needs a rotation kept in anybody's head.
func _build_lines() -> void:
	var side := VolleySpec.HALF_WIDTH
	var back := VolleySpec.HALF_LENGTH
	for dir in [1.0, -1.0]:
		_add_lengthwise_line("Sideline", dir * side, -dir, -back, back)
		_add_crosswise_line("EndLine", dir * back, -dir, -side, side)
		# Painted away from the net, into the back zone, because the front zone is
		# measured to the far edge of the attack line.
		_add_crosswise_line("AttackLine", dir * VolleySpec.ATTACK_LINE, dir, -side, side)


func _add_lengthwise_line(name: String, at_x: float, inward: float,
		from_z: float, to_z: float) -> void:
	_add_line(name, at_x, at_x + inward * VolleySpec.LINE_WIDTH, from_z, to_z)


func _add_crosswise_line(name: String, at_z: float, inward: float,
		from_x: float, to_x: float) -> void:
	_add_line(name, from_x, to_x, at_z, at_z + inward * VolleySpec.LINE_WIDTH)


func _add_line(name: String, x1: float, x2: float, z1: float, z2: float) -> void:
	var lo_x := minf(x1, x2)
	var hi_x := maxf(x1, x2)
	var lo_z := minf(z1, z2)
	var hi_z := maxf(z1, z2)
	_add_box(name, Vector3(hi_x - lo_x, 0.004, hi_z - lo_z),
		Vector3((lo_x + hi_x) * 0.5, LINE_Y, (lo_z + hi_z) * 0.5), _line_material)


func _build_net() -> void:
	var width := VolleySpec.HALF_WIDTH * 2.0
	var top := VolleySpec.NET_HEIGHT
	var tape := 0.07

	var mesh_height := VolleySpec.NET_DEPTH - tape
	_net_parts.append(_add_box("NetMesh", Vector3(width, mesh_height, 0.02),
		Vector3(0.0, top - tape - mesh_height * 0.5, 0.0), _net_material))
	_net_parts.append(_add_box("NetTape", Vector3(width, tape, 0.03),
		Vector3(0.0, top - tape * 0.5, 0.0), _line_material))

	var antenna := _make_material(Color(0.92, 0.30, 0.24))
	for dir in [1.0, -1.0]:
		_add_box("Antenna", Vector3(0.02, VolleySpec.ANTENNA_HEIGHT, 0.02),
			Vector3(dir * VolleySpec.ANTENNA_X,
				top + VolleySpec.ANTENNA_HEIGHT * 0.5, 0.0), antenna)

	for part in _net_parts:
		_net_rest.append(part.position)

	var body := StaticBody3D.new()
	body.name = "NetBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, VolleySpec.NET_DEPTH, 0.03)
	shape.shape = box
	shape.position = Vector3(0.0, top - VolleySpec.NET_DEPTH * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)

	for dir in [1.0, -1.0]:
		_add_box("Post", Vector3(0.09, POST_TOP, 0.09),
			Vector3(dir * VolleySpec.POST_X, POST_TOP * 0.5, 0.0), _post_material)


func _build_referee_stand() -> void:
	var at_x := VolleySpec.POST_X + STAND_OFFSET
	var frame := _make_material(Color(0.30, 0.32, 0.36))
	var floor_to_feet := EYE_HEIGHT - 1.55
	for part in [
		_add_box("StandFrame", Vector3(0.7, floor_to_feet, 0.7),
			Vector3(at_x, floor_to_feet * 0.5, 0.0), frame),
		_add_box("StandPlatform", Vector3(0.9, 0.08, 0.9),
			Vector3(at_x, floor_to_feet, 0.0), frame),
	]:
		part.layers = STAND_LAYER


## Four walls and a ceiling, so the hall is a room rather than a floor in the void.
func _build_hall() -> void:
	var length := (VolleySpec.HALF_LENGTH + FLOOR_MARGIN) * 2.0
	var width := HALL_HALF_WIDTH * 2.0

	# Plain concrete under the stands, between the sports floor and the walls.
	_add_box("HallFloor", Vector3(width, FLOOR_THICKNESS, length),
		Vector3(0.0, -0.006, 0.0), _make_material(Color(0.30, 0.30, 0.32)))

	for dir in [1.0, -1.0]:
		_add_box("EndWall", Vector3(width, HALL_HEIGHT, 0.3),
			Vector3(0.0, HALL_HEIGHT * 0.5, dir * (length * 0.5)), _hall_material)
		_add_box("SideWall", Vector3(0.3, HALL_HEIGHT, length),
			Vector3(dir * (width * 0.5), HALL_HEIGHT * 0.5, 0.0), _hall_material)

	var roof := _make_material(Color(0.13, 0.14, 0.17))
	_add_box("Ceiling", Vector3(width, 0.3, length),
		Vector3(0.0, HALL_HEIGHT, 0.0), roof)


func _build_stands() -> void:
	stands = Stands.new()
	stands.name = "Stands"
	stands.near_row_x = VolleySpec.HALF_WIDTH + VolleySpec.FREE_ZONE + 1.0
	stands.far_row_x = VolleySpec.HALF_WIDTH + VolleySpec.FREE_ZONE + 1.0
	stands.row_depth = 0.90
	stands.row_rise = 0.40
	stands.rows = 6
	stands.half_length = VolleySpec.HALF_LENGTH + 1.6
	stands.seat_spacing = 0.80
	add_child(stands)

	event = EventDressing.new()
	event.name = "Event"
	event.layout = EventLayouts.indoor()
	event.stands = stands
	add_child(event)


func dress(tier: Venue.Tier, density: float) -> void:
	if stands == null:
		return
	stands.dress(tier)
	stands.set_density(density)
	# After the crowd, because the flags in it are held by people who are actually there.
	event.dress(tier)
	event.apply_paint("free_zone", _floor_material)
	event.apply_paint("posts", _post_material)
	event.apply_paint("hall", _hall_material)


func cheer() -> void:
	if stands != null:
		stands.cheer()


## The hall getting to its feet over a call rather than a rally.
func jeer(share: float) -> void:
	if stands != null:
		stands.jeer(share)


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
