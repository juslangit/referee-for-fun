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
##
## The two sides are no longer the same distance out. The umpire faces -X, and the
## people over there are the only thing in the game that tells the player how much
## trouble they are in, so that stand sits as close to the run-off as it can. The +X
## stand is behind the chair and gives up its place to the second court.
const FIRST_ROW_X := 6.55
const FAR_ROW_X := 20.4
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

## The crowd. Three free Sketchfab models, all static and low-poly, which is exactly
## what a MultiMesh wants — one mesh drawn a hundred times in a single call. Anything
## rigged would have to be posed per instance, which a MultiMesh cannot do.
##
## Three rather than one because a MultiMesh instance colour covers the whole person at
## once — shirt, skin and trousers together — so recolouring can only ever produce light
## and shade, never a different set of clothes. Three hundred copies of one man in an
## orange shirt is what that looks like from the chair. A second and third body is the
## only way to break it up, so the hall is dealt out between them.
##
## `stand` says what the file needs doing to it to be the right way up. Not a yes or no:
## two of these needed a quarter turn about X and they needed opposite ones, because
## both turns stand a model up and one of them stands it on its head. There is no
## telling from the outside — every one of these was rendered in a row and looked at,
## which is how the woman was caught hanging upside down by her ankles.
##
## Two, not three. Three others were tried and every one of them was rejected on sight
## rather than on triangle count, which is the useful part: a free asset library is full
## of things that are the right size and the wrong object. One was ninety-four triangles
## with a cube for a head. One turned out to be a close-up of a hand holding a phone.
## One was a man in his underwear. Two spectators who are actually dressed beat three
## where the third is wearing boxer shorts in the fourth row of an international final.
const CROWD_MODELS := [
	{"path": "res://assets/sketchfab/simple_low_poly_character/simple_low_poly_character.glb",
		"stand": "none", "height": 1.75, "share": 0.55},
	{"path": "res://assets/sketchfab/low_poly_woman/low_poly_woman.glb",
		"stand": "down", "height": 1.66, "share": 0.45},
]

## Kept for the check that decides between painted people and the fallback boxes.
const CROWD_MODEL := "res://assets/sketchfab/simple_low_poly_character/simple_low_poly_character.glb"

## How big a seat is, and how far in front of it its occupant stands.
const SEAT_HEIGHT := 0.86
const SEAT_DEPTH := 0.34

## A yaw put on the crowd model so that it faces the way the seat is turned. Which
## direction a model calls forward is a decision its author made and did not write
## down, so this is set by looking at the hall rather than worked out.
const CROWD_FACING := 180.0

## How far a spectator comes off their seat when the hall reacts, and how long the
## reaction takes to die down.
const CHEER_HEIGHT := 0.22
const CHEER_SECONDS := 0.9

## What fraction of the hall bothers to get up for any one rally.
const CHEER_SHARE := 0.45

var _heads: MultiMeshInstance3D
var _total := 0

## One MultiMesh per kind of person, each with its own slice of the seats and its own
## record of who is out of their chair.
var _crowds: Array[MultiMeshInstance3D] = []
var _crowd_seats: Array = []
var _crowd_shapes: Array[Transform3D] = []
var _crowd_jumps: Array = []

## Where everybody sits, and how far through their jump each of them is. Kept so a
## cheer can be drawn by moving instances rather than by animating three hundred
## skeletons, which is the one thing a MultiMesh cannot do.
var _seats: Array[Transform3D] = []
var _shape := Transform3D.IDENTITY
var _jump: PackedFloat32Array = PackedFloat32Array()
var _cheering := false


## Which rung of the ladder this hall is on. A school hall has bare steps and a
## handful of people on them; an arena has a seat bolted down for every one of them.
var tier := Venue.Tier.REGIONAL


func _ready() -> void:
	dress(tier)


## Builds the seating and the people in it. Safe to call again, because a career moves
## between venues and the hall has to be rebuilt when it does.
func dress(which: Venue.Tier) -> void:
	tier = which
	for child in get_children():
		# Detached before being freed, not just queued. queue_free happens at the end of
		# the frame, so the old lights and the new ones would both be in the world at
		# once — and two WorldEnvironments in one scene is a coin toss over which one
		# the renderer uses.
		remove_child(child)
		child.queue_free()
	_heads = null
	_crowds.clear()
	_crowd_seats.clear()
	_crowd_shapes.clear()
	_crowd_jumps.clear()
	_seats.clear()
	_build_seating()
	_build_crowd()


## Sets the hall off, which is what it does when a rally ends well.
##
## Ten hand-animated spectators used to do this while the other three hundred sat
## perfectly still, and the ten of them were the only figures in the building that did
## not match. Moving the instances instead means the whole hall reacts and there is
## only ever one kind of person in the stands.
func cheer() -> void:
	for group in _crowd_jumps.size():
		var jumps: PackedFloat32Array = _crowd_jumps[group]
		for i in jumps.size():
			if jumps[i] <= 0.0 and randf() < CHEER_SHARE:
				jumps[i] = CHEER_SECONDS
		_crowd_jumps[group] = jumps
	_cheering = not _crowds.is_empty()


func _process(delta: float) -> void:
	if not _cheering:
		return

	var still_going := false
	for group in _crowds.size():
		var multi: MultiMesh = _crowds[group].multimesh
		var jumps: PackedFloat32Array = _crowd_jumps[group]
		var seats: Array[Transform3D] = _crowd_seats[group]
		var shape: Transform3D = _crowd_shapes[group]
		for i in jumps.size():
			if jumps[i] <= 0.0:
				continue
			jumps[i] = maxf(jumps[i] - delta, 0.0)
			still_going = still_going or jumps[i] > 0.0
			# One arc up and back down, so nobody lands before the shout has finished.
			var through := 1.0 - jumps[i] / CHEER_SECONDS
			var seat := seats[i]
			seat.origin.y += sin(through * PI) * CHEER_HEIGHT
			multi.set_instance_transform(i, seat * shape)
		_crowd_jumps[group] = jumps
	_cheering = still_going


## How full the hall is, from empty to packed. A school hall has a handful of
## parents in it; an international final does not have a spare seat.
func set_density(density: float) -> void:
	var part := clampf(density, 0.0, 1.0)
	# Thinned out evenly across all three kinds of person, or a half-empty hall would
	# be a hall containing only the first of them.
	for group in _crowds.size():
		var multi: MultiMesh = _crowds[group].multimesh
		multi.visible_instance_count = roundi(float(multi.instance_count) * part)
	if _heads != null:
		_heads.multimesh.visible_instance_count = roundi(_total * part)


## Where one row of one side sits. The near side is pushed out past the second court,
## so the two sides cannot share a number any more.
func _row_x(side: float, row: int) -> float:
	var start := FAR_ROW_X if side > 0.0 else FIRST_ROW_X
	return side * (start + ROW_DEPTH * (float(row) + 0.5))


func _build_seating() -> void:
	# A school hall's steps are pale scuffed concrete under strip lights. An arena's are
	# dark, because the light is all on the court and the stands are meant to recede.
	var pale := tier == Venue.Tier.SCHOOL

	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.52, 0.51, 0.48) if pale else Color(0.20, 0.20, 0.23)
	concrete.roughness = 0.95

	var front := StandardMaterial3D.new()
	front.albedo_color = Color(0.42, 0.41, 0.39) if pale else Color(0.14, 0.14, 0.17)
	front.roughness = 0.95

	for side: float in SIDES:
		for row in ROWS:
			var height := ROW_RISE * float(row + 1)
			var x := _row_x(side, row)

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
			var x := _row_x(side, row)
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
	_seats = seats
	_jump.resize(_total)

	# One colour per person, decided once. The head and the body are drawn by two
	# separate MultiMeshes, and if each picked its own colour every spectator would
	# be wearing somebody else's head.
	var shirts: Array[Color] = []
	var textured := ResourceLoader.exists(CROWD_MODEL)
	for i in _total:
		if textured:
			# The downloaded model is painted, and instance colour multiplies what is
			# already there — so this is a gentle light-and-shade variation rather
			# than three hundred people in three hundred different shirts.
			var shade := randf_range(0.78, 1.18)
			shirts.append(Color(shade, shade, shade * randf_range(0.95, 1.05)))
		else:
			shirts.append(SHIRTS[randi() % SHIRTS.size()])

	# The head sits low enough to overlap the shoulders. Any higher and three hundred
	# people appear to be balancing their heads an inch above their necks.
	# A real person if the downloaded model is there, and the old boxes if it is not.
	# A seat bolted down for every person, at every venue but the school hall — which
	# has none, because a school hall does not have any.
	var stand_forward := 0.0
	if Venue.TIERS[tier]["seats"]:
		# The same half turn the people get. Without it the seats face the back wall:
		# this model looks down its own +Z, and both stands turn it away from the court.
		# The rows had their occupants right and their chairs backwards, which reads as
		# a hall where everybody is standing in front of a seat facing the wrong way.
		var chair := Props.merged(
			Props.SEAT, SEAT_HEIGHT, Props.turned(CROWD_FACING) * Props.z_up())
		if not chair.is_empty():
			var greys: Array[Color] = []
			for i in _total:
				var shade := randf_range(0.86, 1.14)
				greys.append(Color(shade, shade, shade))
			_make_crowd_mesh("Seats", chair[0], seats, greys, 0.0, chair[1])
			# The people move to the front edge of their seat, so they stand at it
			# rather than inside it.
			stand_forward = SEAT_DEPTH

	if stand_forward > 0.0:
		for i in seats.size():
			# Towards the court, which is the way they are facing — the other way walks
			# them into the riser of the row behind.
			seats[i].origin -= seats[i].basis.z.normalized() * stand_forward
	_seats = seats

	# The hall is dealt out between the three bodies. Contiguous slices of an already
	# shuffled list, so each kind of person is scattered through the stands rather than
	# sat together in a block, and thinning the crowd thins all three evenly.
	var dealt := 0
	for which in CROWD_MODELS.size():
		var kind: Dictionary = CROWD_MODELS[which]
		var take := _total - dealt if which == CROWD_MODELS.size() - 1 else roundi(_total * float(kind["share"]))
		if take <= 0:
			continue
		var correction := Props.turned(CROWD_FACING)
		match String(kind["stand"]):
			"up":
				correction = correction * Props.z_up()
			"down":
				correction = correction * Props.z_down()
		var built := Props.merged(kind["path"], kind["height"], correction)
		if built.is_empty():
			continue

		var slice: Array[Transform3D] = []
		var tint: Array[Color] = []
		for i in range(dealt, dealt + take):
			slice.append(seats[i])
			tint.append(shirts[i])
		dealt += take

		var shape: Transform3D = built[1]
		var instance := _make_crowd_mesh("Crowd%d" % which, built[0], slice, tint, 0.0, shape)
		_crowds.append(instance)
		_crowd_seats.append(slice)
		_crowd_shapes.append(shape)
		var jumps := PackedFloat32Array()
		jumps.resize(slice.size())
		_crowd_jumps.append(jumps)

	if not _crowds.is_empty():
		_heads = null
		return

	# No downloaded people at all, so the boxes this started as.
	_crowds.append(_make_crowd_mesh("Bodies", _body_mesh(), seats, shirts, 0.35))
	_heads = _make_crowd_mesh("Heads", _head_mesh(), seats, shirts, 0.78)


## `lift` raises the part above the step the person is sitting on, since both
## MultiMeshes work from the same seat positions. `shape` is the transform that makes
## the mesh stand up at the right size, when the mesh came from a downloaded model.
func _make_crowd_mesh(
	part: String,
	mesh: Mesh,
	seats: Array[Transform3D],
	shirts: Array[Color],
	lift: float,
	shape := Transform3D.IDENTITY
) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = seats.size()

	for i in seats.size():
		var seat := seats[i]
		seat.origin += Vector3(0.0, lift, 0.0)
		multi.set_instance_transform(i, seat * shape)
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
