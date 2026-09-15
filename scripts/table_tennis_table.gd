class_name TableTennisTable
extends Node3D

## The table, the net, the barriers around it, and the umpire's chair beside it.
##
## Everything else in this game is played on the floor. This is played on a surface **76
## centimetres above it**, which changes two things that matter. The ball's whole world is
## a plane at hip height, so a miss does not roll to a stop on the same surface it was
## judged against — it falls off the edge, and the edge is the call. And the umpire does
## not look down at the play from a chair: they sit **level with the tabletop**, a couple
## of metres to the side of the net, which is the only vantage point from which the
## difference between the top edge and the vertical side is visible at all.

const TOP_THICKNESS := TableTennisSpec.EDGE_BAND
const TOP_Y := TableTennisSpec.HEIGHT
const LINE_Y := TOP_Y + 0.0015

## The barriers that pen the playing area in. Real ones are 75 cm high and hold the
## sponsor's name, and they exist to stop a stray ball crossing into the next table.
const BARRIER_HEIGHT := 0.75
const BARRIER_X := 3.6
const BARRIER_Z := 5.4

## How high the dark surround goes behind the barriers.
const DRAPE_HEIGHT := 3.2

## Where the umpire sits: beside the net, level with the surface, close enough to hear
## the difference between wood and edge.
const CHAIR_OFFSET := 2.1
const EYE_HEIGHT := 1.25
const CHAIR_LAYER := 4

var stands: Stands
## The event round the table: see EventDressing.
var event: EventDressing

var _top_material: StandardMaterial3D
var _line_material: StandardMaterial3D
var _net_material: StandardMaterial3D
var _frame_material: StandardMaterial3D
var _floor_material: StandardMaterial3D
var _barrier_material: StandardMaterial3D

var _net_parts: Array[MeshInstance3D] = []
var _net_rest: Array[Vector3] = []
var _shake_left := 0.0
var _shake_strength := 0.0


func _ready() -> void:
	_build_materials()
	_build_floor()
	_build_table()
	_build_lines()
	_build_net()
	_build_barriers()
	_build_chair()
	_build_stands()


func _build_materials() -> void:
	# ITTF blue, matt, and dark enough that a white ball reads against it. The paint is
	# specified as non-reflective for exactly that reason.
	_top_material = _make_material(Color(0.09, 0.24, 0.42))
	_top_material.roughness = 0.98
	_line_material = _make_material(Color(0.95, 0.95, 0.93))
	_net_material = _make_material(Color(0.10, 0.12, 0.16))
	_frame_material = _make_material(Color(0.20, 0.21, 0.24))


func _make_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.92
	return material


func _build_floor() -> void:
	_floor_material = _make_material(Color(0.36, 0.16, 0.13))
	_add_box("Floor", Vector3(BARRIER_X * 2.4, 0.02, BARRIER_Z * 2.4),
		Vector3(0.0, 0.01, 0.0), _floor_material)


func _build_table() -> void:
	var width := TableTennisSpec.HALF_WIDTH * 2.0
	var length := TableTennisSpec.HALF_LENGTH * 2.0

	_add_box("Top", Vector3(width, TOP_THICKNESS, length),
		Vector3(0.0, TOP_Y - TOP_THICKNESS * 0.5, 0.0), _top_material)

	# The vertical side of the tabletop. It is drawn as its own strip because it is the
	# thing an edge ball is judged against: hit the face and the point is over, hit the
	# two centimetres of top above it and it is not.
	for dir in [1.0, -1.0]:
		_add_box("Edge", Vector3(0.004, TOP_THICKNESS, length),
			Vector3(dir * (TableTennisSpec.HALF_WIDTH + 0.002),
				TOP_Y - TOP_THICKNESS * 0.5, 0.0), _line_material)
		_add_box("Edge", Vector3(width, TOP_THICKNESS, 0.004),
			Vector3(0.0, TOP_Y - TOP_THICKNESS * 0.5,
				dir * (TableTennisSpec.HALF_LENGTH + 0.002)), _line_material)

	# Legs, set in from the corners the way a folding table's are.
	for dx in [1.0, -1.0]:
		for dz in [1.0, -1.0]:
			var leg_height := TOP_Y - TOP_THICKNESS
			_add_box("Leg", Vector3(0.06, leg_height, 0.06),
				Vector3(dx * (TableTennisSpec.HALF_WIDTH - 0.16),
					leg_height * 0.5,
					dz * (TableTennisSpec.HALF_LENGTH - 0.22)), _frame_material)

	var body := StaticBody3D.new()
	body.name = "SurfaceBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, TOP_THICKNESS, length)
	shape.shape = box
	shape.position = Vector3(0.0, TOP_Y - TOP_THICKNESS * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)


## Three lines, and the fewest of any surface in this game.
func _build_lines() -> void:
	var w := TableTennisSpec.HALF_WIDTH
	var l := TableTennisSpec.HALF_LENGTH
	var paint := TableTennisSpec.LINE_WIDTH

	for dir in [1.0, -1.0]:
		_add_line("Sideline", dir * w, dir * (w - paint), -l, l)
		_add_line("Endline", -w, w, dir * l, dir * (l - paint))

	# The centre line. It divides the halves for doubles service only, and is painted in
	# singles too — where, by the rules, it belongs to both halves at once.
	var half := TableTennisSpec.CENTRE_LINE_WIDTH * 0.5
	_add_line("CentreLine", -half, half, -l, l)


func _add_line(name: String, x1: float, x2: float, z1: float, z2: float) -> void:
	var lo_x := minf(x1, x2)
	var hi_x := maxf(x1, x2)
	var lo_z := minf(z1, z2)
	var hi_z := maxf(z1, z2)
	_add_box(name, Vector3(hi_x - lo_x, 0.002, hi_z - lo_z),
		Vector3((lo_x + hi_x) * 0.5, LINE_Y, (lo_z + hi_z) * 0.5), _line_material)


## A net 15 cm high that hangs over the sides of the table.
##
## The overhang is not decoration: a ball that passes outside the post but under the
## height of the net is still good, and the net sticking out either side is what makes
## that shot look as improbable as it is.
func _build_net() -> void:
	var span := (TableTennisSpec.HALF_WIDTH + TableTennisSpec.NET_OVERHANG) * 2.0
	var tape := 0.015
	_net_parts.append(_add_box("Net",
		Vector3(span, TableTennisSpec.NET_HEIGHT - tape, 0.006),
		Vector3(0.0, TOP_Y + (TableTennisSpec.NET_HEIGHT - tape) * 0.5, 0.0),
		_net_material))
	_net_parts.append(_add_box("NetTape", Vector3(span, tape, 0.008),
		Vector3(0.0, TOP_Y + TableTennisSpec.NET_HEIGHT - tape * 0.5, 0.0),
		_line_material))

	for part in _net_parts:
		_net_rest.append(part.position)

	for dir in [1.0, -1.0]:
		_add_box("NetPost", Vector3(0.02, TableTennisSpec.NET_HEIGHT + 0.02, 0.02),
			Vector3(dir * (TableTennisSpec.HALF_WIDTH + TableTennisSpec.NET_OVERHANG),
				TOP_Y + (TableTennisSpec.NET_HEIGHT + 0.02) * 0.5, 0.0), _frame_material)


func _build_barriers() -> void:
	_barrier_material = _make_material(Color(0.10, 0.18, 0.34))
	var barrier := _barrier_material
	# A dark surround behind the barriers, which every table tennis venue has and no
	# other venue in this game does. It is in the rules rather than the decor: the ball
	# is white and 40 mm across, and against a bright wall or a window nobody can follow
	# it — so the whole back of the hall is draped.
	var drape := _make_material(Color(0.06, 0.08, 0.13))
	for dir in [1.0, -1.0]:
		_add_box("Barrier", Vector3(0.05, BARRIER_HEIGHT, BARRIER_Z * 2.0),
			Vector3(dir * BARRIER_X, BARRIER_HEIGHT * 0.5, 0.0), barrier)
		_add_box("Barrier", Vector3(BARRIER_X * 2.0, BARRIER_HEIGHT, 0.05),
			Vector3(0.0, BARRIER_HEIGHT * 0.5, dir * BARRIER_Z), barrier)
		_add_box("Drape", Vector3(0.04, DRAPE_HEIGHT, BARRIER_Z * 2.2),
			Vector3(dir * (BARRIER_X + 0.5), DRAPE_HEIGHT * 0.5, 0.0), drape)
		_add_box("Drape", Vector3(BARRIER_X * 2.2, DRAPE_HEIGHT, 0.04),
			Vector3(0.0, DRAPE_HEIGHT * 0.5, dir * (BARRIER_Z + 0.5)), drape)


## The umpire's chair: beside the net, and low.
##
## Every other official in this game sits or stands above the play. This one is level
## with the surface, and that is the point — the edge ball can only be told from the side
## ball by somebody whose eye is on the same plane as the top of the table.
func _build_chair() -> void:
	var at_x := TableTennisSpec.HALF_WIDTH + CHAIR_OFFSET
	var to_the_seat := EYE_HEIGHT - 0.75
	for part in [
		_add_box("ChairFrame", Vector3(0.5, to_the_seat, 0.5),
			Vector3(at_x, to_the_seat * 0.5, 0.0), _frame_material),
		_add_box("ChairSeat", Vector3(0.6, 0.06, 0.6),
			Vector3(at_x, to_the_seat, 0.0), _frame_material),
	]:
		part.layers = CHAIR_LAYER

	# The umpire's own table, with the score indicator on it. It is the one piece of
	# equipment in this sport the official operates by hand.
	var desk := _add_box("UmpireDesk", Vector3(0.7, 0.04, 0.5),
		Vector3(at_x + 0.55, 0.72, 0.0), _frame_material)
	desk.layers = CHAIR_LAYER


func _build_stands() -> void:
	stands = Stands.new()
	stands.name = "Stands"
	stands.near_row_x = BARRIER_X + 0.7
	stands.far_row_x = BARRIER_X + 0.7
	stands.row_depth = 0.90
	stands.row_rise = 0.40
	stands.rows = 5
	stands.half_length = BARRIER_Z - 0.6
	stands.seat_spacing = 0.80
	add_child(stands)

	event = EventDressing.new()
	event.name = "Event"
	event.layout = EventLayouts.table_tennis()
	event.stands = stands
	add_child(event)


func _add_box(name: String, size: Vector3, at: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	view.mesh = mesh
	view.position = at
	view.material_override = material
	add_child(view)
	return view


func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left = maxf(0.0, _shake_left - delta)
	var left := _shake_left / 0.45
	for i in _net_parts.size():
		var wobble := sin(_shake_left * 46.0) * _shake_strength * left * 0.012
		_net_parts[i].position = _net_rest[i] + Vector3(0.0, 0.0, wobble)


## The net moving, which is how a let is seen as well as heard.
func shake_the_net(strength := 1.0) -> void:
	_shake_left = 0.45
	_shake_strength = clampf(strength, 0.0, 1.0)


func dress(tier: Venue.Tier, density: float) -> void:
	if stands == null:
		return
	stands.dress(tier)
	stands.set_density(density)
	# After the crowd, because the flags in it are held by people who are actually there.
	event.dress(tier)
	event.apply_paint("floor", _floor_material)
	event.apply_paint("barrier", _barrier_material)


func cheer() -> void:
	if stands != null:
		stands.cheer()


func jeer(share: float) -> void:
	if stands != null:
		stands.jeer(share)
