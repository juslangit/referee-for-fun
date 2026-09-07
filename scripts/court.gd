class_name Court
extends Node3D

## Builds the badminton court out of plain boxes, straight from CourtSpec.
##
## Everything here is grey-box on purpose. No models, no textures, no art. The only
## thing that has to be right at this stage is the geometry, because the geometry is
## what the player will be lying about.

## Lines sit a hair above the mat so they never z-fight with it.
const LINE_Y := 0.014
const MAT_THICKNESS := 0.01

## How far the green mat extends past the painted lines.
const MAT_MARGIN := 0.9

## Where the umpire chair stands, measured out from the doubles sideline.
const CHAIR_OFFSET := 0.9

## The sports hall the court sits inside. Roughly the size of a real one — the
## ceiling matters, because a high clear can genuinely hit a low roof.
const HALL_WIDTH := 20.0
const HALL_LENGTH := 26.0
const HALL_HEIGHT := 9.0

var _mat_material: StandardMaterial3D
var _line_material: StandardMaterial3D
var _hall_material: StandardMaterial3D
var _net_material: StandardMaterial3D
var _post_material: StandardMaterial3D
var _chair_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _ceiling_material: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_floor()
	_build_hall()
	_build_lines()
	_build_net()
	_build_umpire_chair()


func _build_materials() -> void:
	_hall_material = _make_material(Color(0.34, 0.32, 0.30))
	_mat_material = _make_material(Color(0.10, 0.30, 0.24))
	_line_material = _make_material(Color(0.95, 0.95, 0.92))
	_post_material = _make_material(Color(0.15, 0.15, 0.17))
	_chair_material = _make_material(Color(0.55, 0.52, 0.48))
	_wall_material = _make_material(Color(0.20, 0.22, 0.26))
	_ceiling_material = _make_material(Color(0.14, 0.15, 0.18))

	_net_material = _make_material(Color(0.08, 0.08, 0.09))
	_net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_net_material.albedo_color.a = 0.55
	_net_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _make_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	return material


func _build_floor() -> void:
	# The hall floor the court is laid on. Its top surface is y = 0.
	_add_box("HallFloor", Vector3(HALL_WIDTH, 0.4, HALL_LENGTH), Vector3(0.0, -0.2, 0.0), _hall_material)

	# The playing mat, laid on top of the hall floor.
	var mat_width := CourtSpec.HALF_WIDTH_DOUBLES * 2.0 + MAT_MARGIN * 2.0
	var mat_length := CourtSpec.HALF_LENGTH * 2.0 + MAT_MARGIN * 2.0
	_add_box(
		"CourtMat",
		Vector3(mat_width, MAT_THICKNESS, mat_length),
		Vector3(0.0, MAT_THICKNESS * 0.5, 0.0),
		_mat_material
	)

	# One flat collider for the whole hall, level with the top of the mat. This is
	# what the shuttle will land on, and where its landing point gets recorded.
	var body := StaticBody3D.new()
	body.name = "FloorBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALL_WIDTH, 0.4, HALL_LENGTH)
	shape.shape = box
	shape.position = Vector3(0.0, MAT_THICKNESS - 0.2, 0.0)
	body.add_child(shape)
	add_child(body)


## Four walls and a roof. Nothing here is decorative — a badminton hall is a closed
## box, and the shuttle needs something to be bounded by. It also stops the court
## reading as though it is floating in empty space.
func _build_hall() -> void:
	var t := 0.4
	var half_w := HALL_WIDTH * 0.5
	var half_l := HALL_LENGTH * 0.5

	var shell: Array[MeshInstance3D] = []

	for dir in [1.0, -1.0]:
		shell.append(_add_box(
			"SideWall",
			Vector3(t, HALL_HEIGHT, HALL_LENGTH),
			Vector3(dir * (half_w + t * 0.5), HALL_HEIGHT * 0.5, 0.0),
			_wall_material
		))
		shell.append(_add_box(
			"EndWall",
			Vector3(HALL_WIDTH + t * 2.0, HALL_HEIGHT, t),
			Vector3(0.0, HALL_HEIGHT * 0.5, dir * (half_l + t * 0.5)),
			_wall_material
		))

	shell.append(_add_box(
		"Ceiling",
		Vector3(HALL_WIDTH + t * 2.0, t, HALL_LENGTH + t * 2.0),
		Vector3(0.0, HALL_HEIGHT + t * 0.5, 0.0),
		_ceiling_material
	))

	# The shell must not cast shadows. It encloses the court completely, so if it
	# did, it would simply black out everything inside it.
	for piece in shell:
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_lines() -> void:
	var side := CourtSpec.HALF_WIDTH_DOUBLES
	var singles := CourtSpec.HALF_WIDTH_SINGLES
	var back := CourtSpec.HALF_LENGTH
	var short_service := CourtSpec.SHORT_SERVICE_LINE
	var long_service := CourtSpec.LONG_SERVICE_LINE_DOUBLES
	var w := CourtSpec.LINE_WIDTH

	# Every boundary line is painted INSIDE its own boundary, because a badminton
	# court is measured to the outer edge of the paint. Draw the lines centred on
	# the boundary instead and the line the player sees would sit 2 cm away from the
	# line the game judges against — which is exactly the sort of accidental lie
	# this game cannot afford.
	for dir in [1.0, -1.0]:
		# Doubles sidelines: the outer edge of the court, painted inwards.
		_add_lengthwise_line("DoublesSideline", dir * side, -dir, -back, back)
		# Singles sidelines: inset from the doubles lines, also painted inwards.
		_add_lengthwise_line("SinglesSideline", dir * singles, -dir, -back, back)
		# Back boundary lines, painted towards the net.
		_add_crosswise_line("BackBoundary", dir * back, -dir, -side, side)
		# Doubles long service lines, painted towards the net.
		_add_crosswise_line("LongServiceLine", dir * long_service, -dir, -side, side)
		# Short service lines, painted away from the net, into the service court.
		_add_crosswise_line("ShortServiceLine", dir * short_service, dir, -side, side)
		# Centre line, splitting the two service courts. It belongs to both of them,
		# so unlike every other line it is centred on its own position.
		_add_line(
			"CentreLine",
			-w * 0.5,
			w * 0.5,
			minf(dir * short_service, dir * back),
			maxf(dir * short_service, dir * back)
		)


func _build_net() -> void:
	var width := CourtSpec.HALF_WIDTH_DOUBLES * 2.0
	var top := CourtSpec.NET_HEIGHT_CENTRE
	var tape := 0.075

	# The mesh of the net, hanging below its tape.
	var mesh_height := CourtSpec.NET_DEPTH - tape
	_add_box(
		"NetMesh",
		Vector3(width, mesh_height, 0.02),
		Vector3(0.0, top - tape - mesh_height * 0.5, 0.0),
		_net_material
	)

	# The white tape along the top edge — the thing players actually aim just over.
	_add_box(
		"NetTape",
		Vector3(width, tape, 0.03),
		Vector3(0.0, top - tape * 0.5, 0.0),
		_line_material
	)

	for dir in [1.0, -1.0]:
		var post := MeshInstance3D.new()
		post.name = "NetPost"
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.03
		cylinder.bottom_radius = 0.04
		cylinder.height = CourtSpec.NET_HEIGHT_POST
		post.mesh = cylinder
		post.position = Vector3(dir * CourtSpec.POST_X, CourtSpec.NET_HEIGHT_POST * 0.5, 0.0)
		post.material_override = _post_material
		add_child(post)


func _build_umpire_chair() -> void:
	# The chair stands level with the net, just outside the sideline — where a real
	# umpire sits. The player never leaves it.
	var chair_x := CourtSpec.HALF_WIDTH_DOUBLES + CHAIR_OFFSET
	var seat_height := 1.55

	var chair := Node3D.new()
	chair.name = "UmpireChair"
	chair.position = Vector3(chair_x, 0.0, 0.0)
	add_child(chair)

	_add_box_to(chair, "Seat", Vector3(0.62, 0.08, 0.62), Vector3(0.0, seat_height, 0.0), _chair_material)
	_add_box_to(chair, "Backrest", Vector3(0.08, 0.72, 0.62), Vector3(0.27, seat_height + 0.4, 0.0), _chair_material)
	_add_box_to(chair, "Footrest", Vector3(0.5, 0.06, 0.5), Vector3(0.0, 0.85, 0.0), _chair_material)

	for x in [-0.26, 0.26]:
		for z in [-0.26, 0.26]:
			_add_box_to(
				chair,
				"Leg",
				Vector3(0.07, seat_height, 0.07),
				Vector3(x, seat_height * 0.5, z),
				_chair_material
			)


## Adds one painted line, given the rectangle it covers on the floor in metres.
func _add_line(line_name: String, x_min: float, x_max: float, z_min: float, z_max: float) -> void:
	var size := Vector3(x_max - x_min, 0.004, z_max - z_min)
	var centre := Vector3((x_min + x_max) * 0.5, LINE_Y, (z_min + z_max) * 0.5)
	_add_box(line_name, size, centre, _line_material)


## A line running down the length of the court, sitting at an x boundary.
## `inset` is which way the paint goes: -1 paints towards the middle of the court.
func _add_lengthwise_line(line_name: String, x_boundary: float, inset: float, z_min: float, z_max: float) -> void:
	var x_edge := x_boundary + inset * CourtSpec.LINE_WIDTH
	_add_line(line_name, minf(x_boundary, x_edge), maxf(x_boundary, x_edge), z_min, z_max)


## A line running across the width of the court, sitting at a z boundary.
func _add_crosswise_line(line_name: String, z_boundary: float, inset: float, x_min: float, x_max: float) -> void:
	var z_edge := z_boundary + inset * CourtSpec.LINE_WIDTH
	_add_line(line_name, x_min, x_max, minf(z_boundary, z_edge), maxf(z_boundary, z_edge))


func _add_box(box_name: String, size: Vector3, centre: Vector3, material: Material) -> MeshInstance3D:
	return _add_box_to(self, box_name, size, centre, material)


func _add_box_to(parent: Node, box_name: String, size: Vector3, centre: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.position = centre
	instance.material_override = material
	parent.add_child(instance)
	return instance
