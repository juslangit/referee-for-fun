class_name Court
extends Node3D

## Builds the badminton court out of plain boxes, straight from CourtSpec.
##
## Everything here is grey-box on purpose. No models, no textures, no art. The only
## thing that has to be right at this stage is the geometry, because the geometry is
## what the player will be lying about.

const MAT_THICKNESS := 0.01

## The height of the playing surface: the one number that says where the floor is.
##
## It is two mat thicknesses, because the green mat sits on top of the run-off apron
## rather than straight on the hall floor. Everything that needs to know where the floor
## is takes it from here — the lines, the collider, and the shuttle, which decides it
## has landed when its cork tip crosses this height.
##
## Having it written down twice is how the shuttle ended up landing a centimetre inside
## the floor: the apron was laid under the mat, the surface rose, and the shuttle was
## still measuring against the old number. From the umpire's chair that is invisible.
## From a camera directly overhead it is the whole picture — the shuttle was buried in
## the court with a sliver of skirt showing.
const SURFACE_Y := MAT_THICKNESS * 2.0

## Lines sit a hair above the mat so they never z-fight with it.
const LINE_Y := SURFACE_Y + 0.004

## How far the green mat extends past the painted lines, and how far the run-off
## surround extends past that.
##
## Every photograph of a real tournament shows the same thing: a green playing surface
## with the lines on it, and a wide apron around it in another colour with the
## advertising boards standing at its edge. At a BWF event that apron is bright red and
## it is the single most recognisable thing in the hall. At a club it is more green.
## The run-off is not decoration — it is the two and a bit metres a player needs to
## chase a shuttle past the baseline without hitting a board.
const MAT_MARGIN := 0.50
const RUN_OFF := 2.30

## Where the umpire chair stands, measured out from the doubles sideline.
const CHAIR_OFFSET := 0.9

## The umpire's own chair is drawn on its own layer so their camera can leave it out.
## The player sits in it, and a real umpire does not spend the match looking at the
## inside of their own backrest — which is exactly what a first-person camera placed
## on the seat of a solid model sees.
const CHAIR_LAYER := 4

## The sports hall the court sits inside. Roughly the size of a real one — the
## ceiling matters, because a high clear can genuinely hit a low roof.
##
## It is not centred on the court any more. A tournament hall has courts side by side,
## so there is a second one behind the umpire and the room has to be long enough to
## hold it. The umpire looks the other way, towards -X, where the crowd is: the people
## in the stands are the only thing that ever tells the player how much trouble they
## are in, and putting a second court between them and the chair would have moved them
## twenty metres away to buy some depth.
const HALL_MIN_X := -13.5
const HALL_MAX_X := 27.0
const HALL_LENGTH := 27.0
const HALL_HEIGHT := 9.0

## Where the far edge of the run-off is, which is where the boards stand and where the
## seating starts.
static func run_off_x() -> float:
	return CourtSpec.HALF_WIDTH_DOUBLES + MAT_MARGIN + RUN_OFF


static func run_off_z() -> float:
	return CourtSpec.HALF_LENGTH + MAT_MARGIN + RUN_OFF

## How long the net keeps wobbling after somebody catches it, and how far.
const NET_SHAKE_SECONDS := 0.9
const NET_SHAKE_AMPLITUDE := 0.055

## The seating and the crowd in it.
var stands: Stands

## Everything else in the hall: truss, lamps, boards, scoreboard, kit and flashes.
var venue: Venue
## The event round the hall: see EventDressing.
var event: EventDressing

var _net_parts: Array[MeshInstance3D] = []
var _net_rest: Array[Vector3] = []
var _shake_left := 0.0
var _shake_strength := 0.0

var _mat_material: StandardMaterial3D
var _run_off_material: StandardMaterial3D
var _run_off: MeshInstance3D
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
	_build_stands()
	_build_lines()
	_build_net()
	_build_umpire_chair()


func _build_materials() -> void:
	_hall_material = _make_material(Color(0.34, 0.32, 0.30))
	_mat_material = _make_material(Color(0.10, 0.30, 0.24))
	_line_material = _make_material(Color(0.95, 0.95, 0.92))
	_post_material = _make_material(Color(0.15, 0.15, 0.17))
	_chair_material = _make_material(Color(0.55, 0.52, 0.48))
	_run_off_material = _make_material(Color(0.10, 0.30, 0.24))
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
	_add_box(
		"HallFloor",
		Vector3(HALL_MAX_X - HALL_MIN_X, 0.4, HALL_LENGTH),
		Vector3((HALL_MAX_X + HALL_MIN_X) * 0.5, -0.2, 0.0),
		_hall_material
	)

	# The run-off apron: the wide coloured surround the boards stand at the edge of, and
	# the two and a bit metres a player has to chase a shuttle into past the baseline.
	# Laid first and lowest, with the playing mat sitting on top of it.
	_run_off = _add_box(
		"RunOff",
		Vector3(run_off_x() * 2.0, MAT_THICKNESS, run_off_z() * 2.0),
		Vector3(0.0, MAT_THICKNESS * 0.5, 0.0),
		_run_off_material
	)

	# The playing mat, laid on top of the run-off.
	var mat_width := CourtSpec.HALF_WIDTH_DOUBLES * 2.0 + MAT_MARGIN * 2.0
	var mat_length := CourtSpec.HALF_LENGTH * 2.0 + MAT_MARGIN * 2.0
	_add_box(
		"CourtMat",
		Vector3(mat_width, MAT_THICKNESS, mat_length),
		Vector3(0.0, SURFACE_Y - MAT_THICKNESS * 0.5, 0.0),
		_mat_material
	)

	# One flat collider for the whole hall, level with the top of the mat. It is on
	# its own layer and the shuttle deliberately ignores it — the shuttle works out
	# its own landing point exactly, and a physics collision would have destroyed
	# the impact velocity before that could happen. This collider is here for
	# everything else that will need a floor: players, and anything dropped.
	var body := StaticBody3D.new()
	body.name = "FloorBody"
	body.collision_layer = Shuttle.LAYER_FLOOR
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALL_MAX_X - HALL_MIN_X, 0.4, HALL_LENGTH)
	shape.shape = box
	shape.position = Vector3((HALL_MAX_X + HALL_MIN_X) * 0.5, SURFACE_Y - 0.2, 0.0)
	body.add_child(shape)
	add_child(body)


## The seating down both sides, and the people in it.
func _build_stands() -> void:
	stands = Stands.new()
	stands.name = "Stands"
	add_child(stands)

	venue = Venue.new()
	venue.name = "Venue"
	add_child(venue)
	venue.dress(Venue.Tier.REGIONAL)

	# What the Venue does not already have: the broadcast, the photographers, the flags.
	event = EventDressing.new()
	event.name = "Event"
	event.layout = EventLayouts.badminton()
	event.stands = stands
	add_child(event)
	event.dress(Venue.Tier.REGIONAL)


## Dresses the hall for one rung of the career ladder. Everything that changes with
## the venue goes through here, so there is one place to look for what a promotion
## actually does to what the player sees.
func dress(tier: Venue.Tier) -> void:
	if venue != null:
		venue.dress(tier)
	if stands != null:
		stands.dress(tier)
	if event != null:
		event.dress(tier)
	_paint_hall(tier)


## The shell of the building, which is a different building at each rung of the ladder.
## A school hall is a bright room with cream block walls; an arena is a black box you
## cannot see the edges of. Repainting is all it takes, because the shell is only ever
## a backdrop — the shuttle needs something to be bounded by and the court needs
## something to not be floating in.
func _paint_hall(tier: Venue.Tier) -> void:
	var walls := Color(0.20, 0.21, 0.24)
	var roof := Color(0.16, 0.17, 0.19)
	# Dark at every venue, because the hall is lit as a dark bowl with the court burning
	# in the middle of it. The tiers still differ, but between shades of dark rather than
	# between a bright room and a black one — a cream wall under a lit court reads as a
	# large glowing surface behind the players and undoes the whole effect.
	match tier:
		Venue.Tier.SCHOOL:
			walls = Color(0.20, 0.19, 0.17)
			roof = Color(0.13, 0.13, 0.12)
		Venue.Tier.REGIONAL:
			walls = Color(0.13, 0.14, 0.16)
			roof = Color(0.09, 0.10, 0.12)
		Venue.Tier.ARENA:
			walls = Color(0.07, 0.08, 0.10)
			roof = Color(0.05, 0.05, 0.07)
	if _wall_material != null:
		_wall_material.albedo_color = walls
	if _ceiling_material != null:
		_ceiling_material.albedo_color = roof

	# The apron is the loudest thing in the room about how big this tournament is. A
	# club lays green all the way out; a BWF event lays a red carpet, and there is no
	# mistaking one hall for the other from the chair.
	if _run_off_material != null:
		_run_off_material.albedo_color = (
			Color(0.62, 0.09, 0.11) if tier == Venue.Tier.ARENA else Color(0.09, 0.27, 0.21)
		)


## Four walls and a roof. Nothing here is decorative — a badminton hall is a closed
## box, and the shuttle needs something to be bounded by. It also stops the court
## reading as though it is floating in empty space.
func _build_hall() -> void:
	var t := 0.4
	var width := HALL_MAX_X - HALL_MIN_X
	var middle := (HALL_MAX_X + HALL_MIN_X) * 0.5
	var half_l := HALL_LENGTH * 0.5

	var shell: Array[MeshInstance3D] = []

	for x in [HALL_MIN_X - t * 0.5, HALL_MAX_X + t * 0.5]:
		shell.append(_add_box(
			"SideWall",
			Vector3(t, HALL_HEIGHT, HALL_LENGTH),
			Vector3(x, HALL_HEIGHT * 0.5, 0.0),
			_wall_material
		))
	for dir in [1.0, -1.0]:
		shell.append(_add_box(
			"EndWall",
			Vector3(width + t * 2.0, HALL_HEIGHT, t),
			Vector3(middle, HALL_HEIGHT * 0.5, dir * (half_l + t * 0.5)),
			_wall_material
		))

	shell.append(_add_box(
		"Ceiling",
		Vector3(width + t * 2.0, t, HALL_LENGTH + t * 2.0),
		Vector3(middle, HALL_HEIGHT + t * 0.5, 0.0),
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
	_net_parts.append(_add_box(
		"NetMesh",
		Vector3(width, mesh_height, 0.02),
		Vector3(0.0, top - tape - mesh_height * 0.5, 0.0),
		_net_material
	))

	# The white tape along the top edge — the thing players actually aim just over.
	_net_parts.append(_add_box(
		"NetTape",
		Vector3(width, tape, 0.03),
		Vector3(0.0, top - tape * 0.5, 0.0),
		_line_material
	))

	for part in _net_parts:
		_net_rest.append(part.position)

	# The net is solid. Until now the shuttle flew straight through it, which is the
	# one thing in badminton everybody can see happen.
	var body := StaticBody3D.new()
	body.name = "NetBody"
	body.collision_layer = Shuttle.LAYER_WORLD
	body.collision_mask = 0

	# A shuttle hitting the net does not bounce off it. It stops and falls, which is
	# what makes a net cord such a miserable way to lose a rally.
	var deadening := PhysicsMaterial.new()
	deadening.bounce = 0.02
	deadening.friction = 1.0
	body.physics_material_override = deadening

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, CourtSpec.NET_DEPTH, 0.02)
	shape.shape = box
	shape.position = Vector3(0.0, top - CourtSpec.NET_DEPTH * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)

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

	# A real high chair if the download is there. It is turned to face the court and
	# pushed a little further out than the boxes were, because the player's eye sits
	# where the seat is and a backrest drawn across the camera is a wall.
	var real := Props.node(Props.HIGH_CHAIR, 2.75)
	if real != null:
		real.position = Vector3(0.28, 0.0, 0.0)
		# Turned to face the court, so the umpire sits looking across it rather than
		# down the length of the hall.
		#
		# The sign was wrong from the day the model went in, and nothing caught it for a
		# reason worth writing down: the chair is on `CHAIR_LAYER`, which the umpire's own
		# camera leaves out — the player is *sitting* in it, so it is never once in their
		# view during a match. It is only ever seen in a cutscene, where the seat and the
		# backrest faced the back wall and the ladder stood on the far side, so the umpire
		# who climbed it would have been looking away from the court. Luqman, 2026-09-18:
		# "in cutscenes, fix the umpire chair, it facing backwards".
		real.rotation.y = PI * 0.5
		chair.add_child(real)
		_set_layer(real, CHAIR_LAYER)
		return

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


## Sets the net wobbling. This is the whole of what a net touch looks like from the
## umpire's chair, so how hard it shakes is how obvious the offence was — a racket
## brushing the cord barely moves it, a player falling into it is unmistakable.
func shake_net(strength := 1.0) -> void:
	_shake_strength = clampf(strength, 0.0, 1.0)
	_shake_left = NET_SHAKE_SECONDS


func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta

	var fading := maxf(0.0, _shake_left / NET_SHAKE_SECONDS)
	var swing := sin(_shake_left * 34.0) * NET_SHAKE_AMPLITUDE * _shake_strength * fading

	for i in _net_parts.size():
		var rest: Vector3 = _net_rest[i]
		_net_parts[i].position = rest + Vector3(0.0, 0.0, swing)


## Adds one painted line, given the rectangle it covers on the floor in metres.
## Puts every visible part of a subtree on one render layer.
func _set_layer(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_layer(child, layer)


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


## The hall coming up out of its seats for a rally, and the photographers going off with
## it at the venues that have any.
##
## Every other sport's court has had this from the start; badminton's did not, because
## badminton drove its own stands from inside the match instead. When badminton moved
## onto the shared spine that call site went with it, and the spine drives the stands
## through `cheer()` and `jeer()` — so for a while the badminton hall never moved at all.
## See `dev/checks/_inherit`.
func cheer() -> void:
	if stands != null:
		stands.cheer()
	if venue != null:
		venue.flash()


## The hall getting to its feet over a call rather than a rally.
func jeer(share: float) -> void:
	if stands != null:
		stands.jeer(share)
