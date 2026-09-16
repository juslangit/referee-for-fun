class_name TakrawCourt
extends Node3D

## A sepak takraw court, in a hall.
##
## The badminton doubles court, measured again from ISTAF's rulebook rather than borrowed,
## with the lines this sport adds: a service circle in each half and a quarter circle in each
## corner at the net. The net is lower than badminton's and stretched between padded posts,
## with a white band standing up above each sideline.
##
## The referee sits on a tall chair beside the post, well above the net — no rule says how
## tall, but every broadcast frame shows the referee's eye a long way over the tape — so the
## whole court is below them, feet and circles included.

const FLOOR_THICKNESS := 0.02
const SURFACE_Y := FLOOR_THICKNESS
const LINE_Y := SURFACE_Y + 0.003

## How far the sports mat runs past the lines: the 3 m free zone, and a little more.
const FLOOR_MARGIN := TakrawSpec.FREE_ZONE + 1.0

const POST_TOP := TakrawSpec.NET_HEIGHT_AT_POST
## The chair stands a little behind the post, and tall. The Canadian federation puts the
## referee's eye "about 2 feet above the net"; broadcast frames of the 2026 World Cup show a
## stand with steps and the referee well over the tape. This is the higher of the two, because
## at 60 cm over the tape the inside player in the near quarter circle — a metre in front of
## the chair — filled a third of the referee's view before every serve.
const STAND_OFFSET := 0.8
const EYE_HEIGHT := TakrawSpec.NET_HEIGHT + 0.95
const STAND_LAYER := 4

const HALL_HEIGHT := 9.0

## Where the hall's side walls stand: behind the back row of the stands.
const HALL_HALF_WIDTH := TakrawSpec.HALF_WIDTH + TakrawSpec.FREE_ZONE + 1.0 + 6.0 * 0.90 + 0.7

## How many straight pieces make a circle. Enough that it reads as round from the chair.
const CIRCLE_SEGMENTS := 48

var stands: Stands
## The event round the court: see EventDressing.
var event: EventDressing

var _net_parts: Array[MeshInstance3D] = []
var _net_rest: Array[Vector3] = []
var _shake_left := 0.0
var _shake_strength := 0.0

var _floor_material: StandardMaterial3D
var _surround_material: StandardMaterial3D
var _line_material: StandardMaterial3D
var _net_material: StandardMaterial3D
var _tape_material: StandardMaterial3D
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
	# A synthetic sports mat, one colour over court and free zone alike, as at Titiwangsa.
	# The colour is the venue's; this is the plain one a community hall would have.
	# The court itself. `EventDressing` repaints this one as the ladder climbs — the
	# takraw layout paints it blue at the league and pink at the final, the way a real
	# ISTAF court is laid — so it has to be the court and nothing else.
	_floor_material = _make_material(Color(0.20, 0.42, 0.40))
	# The hall floor the court is painted on. Until now one dark teal slab covered the
	# court and the run-off together, so there was no court to see: just lines on a
	# green field. A real hall paints the court and leaves the floor round it alone,
	# which is how anyone watching knows where the court stops without reading a line.
	# Polished concrete, as a community hall has, rather than volleyball's sprung wood.
	# Cooler and darker than the hall wall behind it, which the takraw layout paints a
	# warm beige at this rung. A first pass matched the two too closely and the floor
	# and the wall merged into one grey at the horizon, so the room had no floor.
	_surround_material = _make_material(Color(0.50, 0.51, 0.53))
	_line_material = _make_material(Color(0.96, 0.96, 0.94))
	_net_material = _make_material(Color(0.08, 0.08, 0.10))
	_tape_material = _make_material(Color(0.96, 0.96, 0.94))
	_post_material = _make_material(Color(0.72, 0.73, 0.76))
	_hall_material = _make_material(Color(0.28, 0.29, 0.34))


func _make_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	return material


func _build_floor() -> void:
	var length := (TakrawSpec.HALF_LENGTH + FLOOR_MARGIN) * 2.0
	var width := (TakrawSpec.HALF_WIDTH + FLOOR_MARGIN) * 2.0
	_add_box("Floor", Vector3(width, FLOOR_THICKNESS, length),
		Vector3(0.0, FLOOR_THICKNESS * 0.5, 0.0), _surround_material)

	# The court, laid a couple of millimetres proud of the floor so it never z-fights,
	# and drawn to the outside of the boundary lines — the lines are painted inside the
	# court, so the court is the full 13.4 by 6.1 m.
	_add_box("CourtFloor",
		Vector3(TakrawSpec.HALF_WIDTH * 2.0, 0.004, TakrawSpec.HALF_LENGTH * 2.0),
		Vector3(0.0, FLOOR_THICKNESS + 0.002, 0.0), _floor_material)

	var body := StaticBody3D.new()
	body.name = "FloorBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, FLOOR_THICKNESS, length)
	shape.shape = box
	shape.position = Vector3(0.0, FLOOR_THICKNESS * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)


## The lines: every one drawn inwards from the court's edge, so a ball on a line is in.
func _build_lines() -> void:
	var side := TakrawSpec.HALF_WIDTH
	var back := TakrawSpec.HALF_LENGTH
	var w := TakrawSpec.LINE_WIDTH
	for dir in [1.0, -1.0]:
		_add_line("Sideline", dir * side, dir * (side - w), -back, back)
		_add_line("BackLine", -side, side, dir * back, dir * (back - w))
	var c := TakrawSpec.CENTRE_LINE_WIDTH * 0.5
	_add_line("CentreLine", -side, side, -c, c)

	for team_side in [1.0, -1.0]:
		# The service circle, its line inside the 30 cm radius.
		var circle := TakrawSpec.service_circle(team_side)
		_add_arc("ServiceCircle", circle, TakrawSpec.SERVICE_CIRCLE_RADIUS, 0.0, TAU)
		# The two quarter circles at the net, from the sideline round to the centre line.
		for across in [1.0, -1.0]:
			var corner := TakrawSpec.quarter_circle(team_side, across)
			# The quarter inside the court and in this side's half: facing the middle of the
			# court across, and this side's back line along.
			var inward: float = PI if across > 0.0 else 0.0
			var toward_back: float = PI * 0.5 * team_side
			var ends := [inward, inward + (toward_back if across < 0.0 else -toward_back)]
			if across > 0.0 and team_side < 0.0:
				ends = [PI, PI * 1.5]
			_add_arc("QuarterCircle", corner, TakrawSpec.QUARTER_CIRCLE_RADIUS,
				minf(ends[0], ends[1]), maxf(ends[0], ends[1]))


## A painted arc on the floor, `radius` to its outer edge, line width inwards. Angles are
## measured in the floor plane from +X towards +Z.
func _add_arc(name: String, centre: Vector3, radius: float, from_angle: float,
		to_angle: float) -> void:
	var inner := radius - TakrawSpec.LINE_WIDTH
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var steps := maxi(4, int(ceil(CIRCLE_SEGMENTS * (to_angle - from_angle) / TAU)))
	for i in steps:
		var a0 := lerpf(from_angle, to_angle, float(i) / steps)
		var a1 := lerpf(from_angle, to_angle, float(i + 1) / steps)
		var o0 := Vector3(cos(a0), 0.0, sin(a0))
		var o1 := Vector3(cos(a1), 0.0, sin(a1))
		var p := [o0 * inner, o0 * radius, o1 * radius, o1 * inner]
		for index in [0, 2, 1, 0, 3, 2]:
			tool.add_vertex(p[index])
	var arc := MeshInstance3D.new()
	arc.name = name
	arc.mesh = tool.commit()
	arc.position = Vector3(centre.x, LINE_Y + 0.0015, centre.z)
	arc.material_override = _arc_material()
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arc)


## The line paint, seen from either face: an arc built by hand has a winding, and a line
## that vanishes because it was wound the wrong way is a line the referee cannot see.
func _arc_material() -> StandardMaterial3D:
	var paint: StandardMaterial3D = _line_material.duplicate()
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	return paint


func _add_line(name: String, x1: float, x2: float, z1: float, z2: float) -> void:
	var lo_x := minf(x1, x2)
	var hi_x := maxf(x1, x2)
	var lo_z := minf(z1, z2)
	var hi_z := maxf(z1, z2)
	var line := _add_box(name, Vector3(hi_x - lo_x, 0.004, hi_z - lo_z),
		Vector3((lo_x + hi_x) * 0.5, LINE_Y, (lo_z + hi_z) * 0.5), _line_material)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The net: 70 cm of black mesh under a white top tape, a bottom tape, a white band standing
## up over each sideline, and the posts 30 cm outside the court.
func _build_net() -> void:
	var width := TakrawSpec.HALF_WIDTH * 2.0 + 0.2
	var top := TakrawSpec.NET_HEIGHT
	var tape := 0.05
	var mesh_height := TakrawSpec.NET_DEPTH - tape * 2.0

	_net_parts.append(_add_box("NetMesh", Vector3(width, mesh_height, 0.015),
		Vector3(0.0, top - tape - mesh_height * 0.5, 0.0), _net_material))
	_net_parts.append(_add_box("NetTape", Vector3(width, tape, 0.025),
		Vector3(0.0, top - tape * 0.5, 0.0), _tape_material))
	_net_parts.append(_add_box("NetBottomTape", Vector3(width, tape, 0.02),
		Vector3(0.0, top - TakrawSpec.NET_DEPTH + tape * 0.5, 0.0), _tape_material))
	for dir in [1.0, -1.0]:
		_net_parts.append(_add_box("SideBand",
			Vector3(0.05, TakrawSpec.NET_DEPTH + TakrawSpec.SIDE_BAND_HEIGHT, 0.02),
			Vector3(dir * TakrawSpec.SIDE_BAND_X,
				top - TakrawSpec.NET_DEPTH + (TakrawSpec.NET_DEPTH + TakrawSpec.SIDE_BAND_HEIGHT) * 0.5,
				0.0), _tape_material))
	for part in _net_parts:
		_net_rest.append(part.position)

	var body := StaticBody3D.new()
	body.name = "NetBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, TakrawSpec.NET_DEPTH, 0.03)
	shape.shape = box
	shape.position = Vector3(0.0, top - TakrawSpec.NET_DEPTH * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)

	for dir in [1.0, -1.0]:
		# Padded, as they are at every televised event: a sleeve thicker than the pole.
		_add_box("Post", Vector3(0.14, POST_TOP, 0.14),
			Vector3(dir * TakrawSpec.POST_X, POST_TOP * 0.5, 0.0), _post_material)


## The referee's chair: a tall stand beside the post on the +X side.
func _build_referee_stand() -> void:
	var at_x := TakrawSpec.POST_X + STAND_OFFSET
	var frame := _make_material(Color(0.10, 0.10, 0.12))
	var to_the_seat := EYE_HEIGHT - 0.85
	for part in [
		_add_box("StandFrame", Vector3(0.6, to_the_seat, 0.6),
			Vector3(at_x, to_the_seat * 0.5, 0.0), frame),
		_add_box("StandSeat", Vector3(0.7, 0.06, 0.7),
			Vector3(at_x, to_the_seat, 0.0), frame),
	]:
		part.layers = STAND_LAYER


## Four walls and a ceiling, far enough out that the stands fit inside.
func _build_hall() -> void:
	var length := (TakrawSpec.HALF_LENGTH + FLOOR_MARGIN) * 2.0
	var width := HALL_HALF_WIDTH * 2.0
	_add_box("HallFloor", Vector3(width, FLOOR_THICKNESS, length),
		Vector3(0.0, -0.006, 0.0), _make_material(Color(0.30, 0.30, 0.32)))
	for dir in [1.0, -1.0]:
		_add_box("EndWall", Vector3(width, HALL_HEIGHT, 0.3),
			Vector3(0.0, HALL_HEIGHT * 0.5, dir * (length * 0.5)), _hall_material)
		_add_box("SideWall", Vector3(0.3, HALL_HEIGHT, length),
			Vector3(dir * (width * 0.5), HALL_HEIGHT * 0.5, 0.0), _hall_material)
	_add_box("Ceiling", Vector3(width, 0.3, length),
		Vector3(0.0, HALL_HEIGHT, 0.0), _make_material(Color(0.13, 0.14, 0.17)))


func _build_stands() -> void:
	stands = Stands.new()
	stands.name = "Stands"
	stands.near_row_x = TakrawSpec.HALF_WIDTH + TakrawSpec.FREE_ZONE + 1.0
	stands.far_row_x = TakrawSpec.HALF_WIDTH + TakrawSpec.FREE_ZONE + 1.0
	stands.row_depth = 0.90
	stands.row_rise = 0.40
	stands.rows = 6
	stands.half_length = TakrawSpec.HALF_LENGTH + 1.6
	stands.seat_spacing = 0.80
	add_child(stands)

	event = EventDressing.new()
	event.name = "Event"
	event.layout = EventLayouts.takraw()
	event.stands = stands
	add_child(event)


func dress(tier: Venue.Tier, density: float) -> void:
	if stands == null:
		return
	stands.dress(tier)
	stands.set_density(density)
	# After the crowd, because the flags in it are held by people who are actually there.
	event.dress(tier)
	event.apply_paint("floor", _floor_material)
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
	var offset := sin(_shake_left * 46.0) * 0.04 * _shake_strength * fade
	for i in _net_parts.size():
		_net_parts[i].position = _net_rest[i] + Vector3(0.0, 0.0, offset)
	if _shake_left <= 0.0:
		for i in _net_parts.size():
			_net_parts[i].position = _net_rest[i]
