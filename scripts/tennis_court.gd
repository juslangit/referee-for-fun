class_name TennisCourt
extends Node3D

## A tennis court, and the first net in this game that is not a straight line.
##
## Two things here are unlike the other three courts. The court is **two courts** — the
## singles lines sit inside the doubles ones, so a ball in the tramlines is in for one
## match and out for another off the same bounce. And the net **sags**: 1.07 m where it
## is tied to the posts and 0.914 m in the middle, so a shot down the centre clears a
## lower net than one up the line. It is built as a row of panels stepping down towards
## the middle, because a single box cannot droop.

const SURFACE_THICKNESS := 0.02
const SURFACE_Y := SURFACE_THICKNESS
const LINE_Y := SURFACE_Y + 0.003

## Where the umpire's chair goes: at the net, to one side, high enough to see both
## service boxes and the far baseline.
const CHAIR_OFFSET := 1.6
const EYE_HEIGHT := 2.85
const CHAIR_LAYER := 4

## How many panels the net is made of. Enough that the sag reads as a curve.
const NET_PANELS := 24

var stands: Stands

var _net_parts: Array[MeshInstance3D] = []
var _net_rest: Array[Vector3] = []
var _shake_left := 0.0
var _shake_strength := 0.0

var _surface_material: StandardMaterial3D
var _line_material: StandardMaterial3D
var _net_material: StandardMaterial3D
var _post_material: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_surface()
	_build_lines()
	_build_net()
	_build_chair()
	_build_stands()


func _build_materials() -> void:
	_surface_material = _make_material(Color(0.22, 0.42, 0.58))
	_line_material = _make_material(Color(0.96, 0.96, 0.94))
	_net_material = _make_material(Color(0.11, 0.12, 0.14))
	_post_material = _make_material(Color(0.28, 0.30, 0.33))


func _make_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.92
	return material


func _build_surface() -> void:
	var length := (TennisSpec.HALF_LENGTH + TennisSpec.RUN_BACK) * 2.0
	var width := (TennisSpec.HALF_WIDTH_DOUBLES + TennisSpec.SIDE_ROOM) * 2.0
	_add_box("Surround", Vector3(width, SURFACE_THICKNESS, length),
		Vector3(0.0, SURFACE_THICKNESS * 0.5, 0.0),
		_make_material(Color(0.14, 0.32, 0.30)))

	# The court itself, in the blue a hard court is painted, against the green of the
	# run-back. Real courts use exactly this contrast so that everybody can see where
	# the playing surface stops without reading the line.
	_add_box("Court",
		Vector3(TennisSpec.HALF_WIDTH_DOUBLES * 2.0, 0.004,
			TennisSpec.HALF_LENGTH * 2.0),
		Vector3(0.0, SURFACE_THICKNESS + 0.002, 0.0), _surface_material)

	var body := StaticBody3D.new()
	body.name = "SurfaceBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, SURFACE_THICKNESS, length)
	shape.shape = box
	shape.position = Vector3(0.0, SURFACE_THICKNESS * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)


## Nine lines, and the reason a tennis court looks busy.
func _build_lines() -> void:
	var doubles := TennisSpec.HALF_WIDTH_DOUBLES
	var singles := TennisSpec.HALF_WIDTH_SINGLES
	var back := TennisSpec.HALF_LENGTH
	var service := TennisSpec.SERVICE_LINE

	for dir in [1.0, -1.0]:
		# Both pairs of sidelines, each painted inside its own boundary — a tennis court
		# is measured to the outer edge of the paint, as every court in this game is.
		_add_lengthwise("DoublesSideline", dir * doubles, -dir, -back, back)
		_add_lengthwise("SinglesSideline", dir * singles, -dir, -back, back)
		# The baseline, which is allowed to be twice as wide as anything else.
		_add_line("Baseline", -doubles, doubles,
			dir * back, dir * (back - TennisSpec.BASELINE_WIDTH))
		# The service line runs only between the singles sidelines.
		_add_crosswise("ServiceLine", dir * service, -dir, -singles, singles)
		# And the centre mark, a short stub on the baseline saying where the halves meet.
		_add_line("CentreMark", -TennisSpec.LINE_WIDTH * 0.5, TennisSpec.LINE_WIDTH * 0.5,
			dir * back, dir * (back - 0.10))

	# The centre service line, from one service line to the other, straight down the
	# middle. It belongs to both boxes, so unlike every other line it is centred on its
	# own position rather than painted to one side.
	_add_line("CentreService", -TennisSpec.LINE_WIDTH * 0.5, TennisSpec.LINE_WIDTH * 0.5,
		-service, service)


func _add_lengthwise(name: String, at_x: float, inward: float,
		from_z: float, to_z: float) -> void:
	_add_line(name, at_x, at_x + inward * TennisSpec.LINE_WIDTH, from_z, to_z)


func _add_crosswise(name: String, at_z: float, inward: float,
		from_x: float, to_x: float) -> void:
	_add_line(name, from_x, to_x, at_z, at_z + inward * TennisSpec.LINE_WIDTH)


func _add_line(name: String, x1: float, x2: float, z1: float, z2: float) -> void:
	var lo_x := minf(x1, x2)
	var hi_x := maxf(x1, x2)
	var lo_z := minf(z1, z2)
	var hi_z := maxf(z1, z2)
	_add_box(name, Vector3(hi_x - lo_x, 0.004, hi_z - lo_z),
		Vector3((lo_x + hi_x) * 0.5, LINE_Y, (lo_z + hi_z) * 0.5), _line_material)


## A net that droops, built as panels stepping down towards the middle.
##
## Every other net in this game is a box, because every other net is level. This one is
## the reason TennisSpec.net_height_at exists: a shot down the centre has 15 cm less net
## to beat than one up the line, and that is a real part of how the sport is played
## rather than a detail of how it is drawn.
func _build_net() -> void:
	var span := TennisSpec.POST_X * 2.0
	var panel := span / float(NET_PANELS)
	var tape := 0.05

	for i in NET_PANELS:
		var x := -TennisSpec.POST_X + panel * (float(i) + 0.5)
		var top := TennisSpec.net_height_at(x)
		var mesh_height := top - tape
		_net_parts.append(_add_box("NetPanel",
			Vector3(panel, mesh_height, 0.02),
			Vector3(x, mesh_height * 0.5, 0.0), _net_material))
		_net_parts.append(_add_box("NetTape",
			Vector3(panel, tape, 0.03),
			Vector3(x, top - tape * 0.5, 0.0), _line_material))

	for part in _net_parts:
		_net_rest.append(part.position)

	var body := StaticBody3D.new()
	body.name = "NetBody"
	for i in NET_PANELS:
		var x := -TennisSpec.POST_X + panel * (float(i) + 0.5)
		var top := TennisSpec.net_height_at(x)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(panel, top, 0.03)
		shape.shape = box
		shape.position = Vector3(x, top * 0.5, 0.0)
		body.add_child(shape)
	add_child(body)

	for dir in [1.0, -1.0]:
		_add_box("Post", Vector3(0.08, TennisSpec.NET_HEIGHT_POST + 0.06, 0.08),
			Vector3(dir * TennisSpec.POST_X,
				(TennisSpec.NET_HEIGHT_POST + 0.06) * 0.5, 0.0), _post_material)


func _build_chair() -> void:
	var at_x := TennisSpec.POST_X + CHAIR_OFFSET
	var frame := _make_material(Color(0.30, 0.32, 0.36))
	var to_the_seat := EYE_HEIGHT - 1.35
	for part in [
		_add_box("ChairFrame", Vector3(0.8, to_the_seat, 0.8),
			Vector3(at_x, to_the_seat * 0.5, 0.0), frame),
		_add_box("ChairSeat", Vector3(1.0, 0.08, 1.0),
			Vector3(at_x, to_the_seat, 0.0), frame),
	]:
		part.layers = CHAIR_LAYER


func _build_stands() -> void:
	stands = Stands.new()
	stands.name = "Stands"
	stands.near_row_x = TennisSpec.HALF_WIDTH_DOUBLES + TennisSpec.SIDE_ROOM + 0.8
	stands.far_row_x = TennisSpec.HALF_WIDTH_DOUBLES + TennisSpec.SIDE_ROOM + 0.8
	stands.row_depth = 0.92
	stands.row_rise = 0.42
	stands.rows = 6
	stands.half_length = TennisSpec.HALF_LENGTH + 1.0
	stands.seat_spacing = 0.82
	add_child(stands)


func dress(tier: Venue.Tier, density: float) -> void:
	if stands == null:
		return
	stands.dress(tier)
	stands.set_density(density)


func cheer() -> void:
	if stands != null:
		stands.cheer()


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


## The net shivering, which is how a net cord is seen as well as heard.
func shake(strength := 1.0) -> void:
	_shake_left = 0.9
	_shake_strength = strength


func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	var fade := clampf(_shake_left / 0.9, 0.0, 1.0)
	var offset := sin(_shake_left * 46.0) * 0.045 * _shake_strength * fade
	for i in _net_parts.size():
		_net_parts[i].position = _net_rest[i] + Vector3(0.0, 0.0, offset)
	if _shake_left <= 0.0:
		for i in _net_parts.size():
			_net_parts[i].position = _net_rest[i]
