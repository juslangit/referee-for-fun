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
## These are the badminton hall's numbers and they are the defaults, but they are
## variables rather than constants because a second sport is played on a different
## rectangle. Everything below this — the seats, the crowd, the density, the cheering —
## is about people in rows and does not care how far out the rows are, so beach
## volleyball builds the same Stands with its own geometry rather than a second copy of
## four hundred lines of MultiMesh.
var near_row_x := 6.55
var far_row_x := 20.4
var row_depth := 0.85
var row_rise := 0.38
var rows := 6

## How far the seating runs along the hall, and how far apart people sit.
var half_length := 10.4
var seat_spacing := 0.80

## Temporary scaffold seating on sand rather than concrete steps in a building.
var outdoors := false

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
## Two people, each baked twice: sitting in their seat, and on their feet with their arms
## up. A MultiMesh draws one mesh many times and has no skeleton, so a spectator cannot be
## posed — they have to arrive already in the pose, and standing up means being swapped for
## a different mesh. `tools/blender/crowd_poses.py` bakes all six.
##
## The two are the forge's own spectator at two heights and two builds, which replaced two
## unrelated downloaded models on 2026-09-20. That trade is worth naming: the downloaded
## pair were genuinely different people and these two are the same person twice, but the
## downloaded pair could only ever stand, and a hall of three hundred people standing to
## attention through a rally is a worse lie than a hall where some of them have the same
## face. `crowd_b` sits leaning forward rather than upright, so the two halves of the hall
## still do not sit the same way.
##
## `height` is zero on purpose: these are authored at true scale and must not be fitted to
## anything. A seated figure's own height is 1.2 m and the person is 1.74 m, so scaling by
## height would make every seated spectator a giant. See `Props.merged`.
const CROWD_MODELS := [
	{"sitting": "res://assets/characters/crowd_a_sit.glb",
		"standing": "res://assets/characters/crowd_a_stand.glb",
		"height": 0.0, "share": 0.55},
	{"sitting": "res://assets/characters/crowd_b_lean.glb",
		"standing": "res://assets/characters/crowd_b_stand.glb",
		"height": 0.0, "share": 0.45},
]

## Kept for the check that decides between painted people and the fallback boxes.
const CROWD_MODEL := "res://assets/characters/crowd_a_sit.glb"

## How big a seat is, and how far in front of it its occupant stands.
const SEAT_HEIGHT := 0.86
const SEAT_DEPTH := 0.34

## How much of the downloaded seat's detail is kept. All of it, since 2026-09-20: the seat
## is 80 triangles as it comes and there is nothing to save. The one before it was 7,404,
## which at 312 seats a hall was most of the reason badminton ran at twenty-odd frames a
## second, and had to be thrown away down to 12% of itself — at which point it was a white
## lump with no seat and no back. Simplifying is still there for the next heavy prop; see
## `Props.simplified`.
const SEAT_DETAIL := 1.0

## A yaw put on the seat model so that it faces the way the row is turned. Which
## direction a model calls forward is a decision its author made and did not write
## down, so this is set by looking at the hall rather than worked out.
##
## **90, since 2026-09-21.** It was 180, which was the number the *old* downloaded seat
## wanted, and it stayed at 180 when the crowd became the forge's spectator on 2026-09-20
## and the people were given a separate `PERSON_FACING`. A quarter turn out puts the chair
## side-on: a tall red panel beside each spectator instead of behind them, which is what
## Luqman was looking at when he said *"the audience bench is not right, rotate it so it
## facing camera"*.
##
## Found by rendering the front row at 0, 90, 180 and 270 from the court and looking at
## all four — see `dev/looks/_seatfacing` and `_seat`. At 0 and 180 the chair is side-on,
## at 270 its back is to the court and hides the person, and at 90 the back is behind the
## person where a back belongs. Reasoning about the model's axes got it wrong twice before
## the pictures settled it.
const CROWD_FACING := 90.0

## The same, for the people. A separate number since 2026-09-20, because the crowd stopped
## being downloaded models and became the forge's own spectator, which faces its own way.
const PERSON_FACING := 0.0

## The only part of a spectator that instance colour is allowed to touch. The shirt is
## baked almost white so that the tint *is* the shirt; the face, hair and shoes keep what
## the forge painted. Before this the colour covered the whole person at once, so it could
## only ever produce light and shade and a hall of three hundred people came out grey.
const TINTED := ["kit"]

## How far a spectator comes off their seat when the hall reacts, and how long the
## reaction takes to die down.
const CHEER_HEIGHT := 0.22
const CHEER_SECONDS := 0.9

## Standing up, which is a different thing from cheering and reads as one.
##
## A cheer is an arc — up and straight back down, everybody landing before the shout
## finishes. Getting to your feet over a call you did not like is a rise, a long hold and
## a grudging sit, and the hold is the whole of it: a hall that bobs is pleased, a hall
## that is **still standing** four seconds later is not.
##
## This is the only thing on screen that answers the official back rather than the
## rally. Until now the stands celebrated every point, honest or stolen, and had no
## way at all to express what they made of the person awarding it.
const STAND_HEIGHT := 0.30
const STAND_SECONDS := 4.2
const STAND_RISE := 0.16

## What fraction of the hall bothers to get up for any one rally.
const CHEER_SHARE := 0.45

## How far above a seated spectator's own origin the bubble's tail points. A little
## over the 0.78 the head mesh is lifted by, so the tail lands just clear of the hair
## rather than through it.
const MOUTH_HEIGHT := 1.02

var _heads: MultiMeshInstance3D
var _total := 0

## One MultiMesh per kind of person, each with its own slice of the seats and its own
## record of who is out of their chair.
var _crowds: Array[MultiMeshInstance3D] = []
var _crowd_seats: Array = []
var _crowd_shapes: Array[Transform3D] = []
var _crowd_jumps: Array = []

## The same people again, on their feet. Every spectator has a slot in both of these and
## is drawn by exactly one of them at a time; the other holds a zero-sized transform,
## which is how a MultiMesh hides an instance — there is no per-instance visibility.
var _standers: Array[MultiMeshInstance3D] = []
var _stander_shapes: Array[Transform3D] = []

## How far clear of the chair somebody steps when they get to their feet.
var _stand_forward := 0.0

## Which of the two reactions each seat is in the middle of. Parallel to `_crowd_jumps`,
## a flag per instance rather than a second timer, because a spectator is doing one or
## the other and never both.
var _crowd_holds: Array = []

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
	_standers.clear()
	_stander_shapes.clear()
	_crowd_shapes.clear()
	_crowd_jumps.clear()
	_crowd_holds.clear()
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
	_react(CHEER_SHARE, CHEER_SECONDS, false)


## A share of the hall gets to its feet over a call, and stays up.
##
## `share` is how much of the room bothered, which is what the visibility of a bad call
## buys: a shaved line nobody could see moves nobody, and a ball given three feet out
## empties the seats.
func jeer(share: float) -> void:
	_react(clampf(share, 0.0, 1.0), STAND_SECONDS, true)


## Somebody in the stands to put a shout in the mouth of, as a world point just above
## their head. Returns `Vector3.INF` when there is nobody to pick.
##
## Chosen from whoever is actually in front of the umpire rather than uniformly, which
## matters more than it sounds. The chair faces -X and the near stand is deliberately
## the closest thing in the hall to it, so a uniform pick would put most shouts behind
## the player's head, where a bubble is either invisible or — worse — drags the camera
## round to look for it. Everybody still in the running is weighted the same, so the
## same person does not get every line.
##
## `facing` is the direction the umpire is looking. A spectator counts as in front if
## they are anywhere in the forward half, which is wide on purpose: narrowing it to what
## is strictly on screen made the hall feel like it only contained the four people the
## player happened to be looking at.
func somebody_to_shout(from: Vector3, facing: Vector3) -> Vector3:
	if _crowd_seats.is_empty():
		return Vector3.INF

	var flat := Vector3(facing.x, 0.0, facing.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD
	flat = flat.normalized()

	var in_front: Array[Vector3] = []
	var anybody: Array[Vector3] = []
	for group in _crowd_seats.size():
		var seats: Array[Transform3D] = _crowd_seats[group]
		for i in seats.size():
			var head := to_global(seats[i].origin) + Vector3(0.0, MOUTH_HEIGHT, 0.0)
			anybody.append(head)
			var towards := head - from
			towards.y = 0.0
			if towards.length_squared() > 0.01 and towards.normalized().dot(flat) > 0.0:
				in_front.append(head)

	var pool := in_front if not in_front.is_empty() else anybody
	if pool.is_empty():
		return Vector3.INF
	return pool[randi() % pool.size()]


func _react(share: float, seconds: float, standing: bool) -> void:
	for group in _crowd_jumps.size():
		var jumps: PackedFloat32Array = _crowd_jumps[group]
		var holds: PackedFloat32Array = _crowd_holds[group]
		for i in jumps.size():
			if jumps[i] <= 0.0 and randf() < share:
				jumps[i] = seconds
				holds[i] = 1.0 if standing else 0.0
		_crowd_jumps[group] = jumps
		_crowd_holds[group] = holds
	_cheering = not _crowds.is_empty()
	_draw_the_risen(_cheering)


func _process(delta: float) -> void:
	if not _cheering:
		return

	var still_going := false
	for group in _crowds.size():
		var jumps: PackedFloat32Array = _crowd_jumps[group]
		var holds: PackedFloat32Array = _crowd_holds[group]
		var seats: Array[Transform3D] = _crowd_seats[group]
		for i in jumps.size():
			if jumps[i] <= 0.0:
				continue
			jumps[i] = maxf(jumps[i] - delta, 0.0)
			if jumps[i] <= 0.0:
				# The reaction is over: back into the chair.
				_sit_down(group, i, seats[i])
				continue
			still_going = true
			var seat := seats[i]
			if holds[i] > 0.5:
				# On their feet: up quickly, held for as long as it lasts, and back
				# down at the end. Nothing in the middle, which is the point of it.
				var left := jumps[i] / STAND_SECONDS
				var up := 1.0
				if left > 1.0 - STAND_RISE:
					up = (1.0 - left) / STAND_RISE
				elif left < STAND_RISE:
					up = left / STAND_RISE
				seat.origin.y += clampf(up, 0.0, 1.0) * STAND_HEIGHT
			else:
				# One arc up and back down, so nobody lands before the shout is over.
				var through := 1.0 - jumps[i] / CHEER_SECONDS
				seat.origin.y += sin(through * PI) * CHEER_HEIGHT
			_stand_up(group, i, seat)
		_crowd_jumps[group] = jumps
	if not still_going:
		_draw_the_risen(false)
	_cheering = still_going


## Drawn sitting in the chair, and not drawn standing.
##
## A MultiMesh has no per-instance visibility, so the one that is not wanted is given a
## transform with no size. It is still counted, still uploaded and still costs a slot —
## it simply has no volume to rasterise.
func _sit_down(group: int, i: int, seat: Transform3D) -> void:
	if group < 0 or group >= _crowds.size() or group >= _standers.size():
		return
	var shape: Transform3D = _crowd_shapes[group]
	_crowds[group].multimesh.set_instance_transform(i, seat * shape)
	_standers[group].multimesh.set_instance_transform(i, _nowhere(seat))


## Drawn on their feet, a step clear of the chair, and not drawn sitting.
func _stand_up(group: int, i: int, seat: Transform3D) -> void:
	if group < 0 or group >= _crowds.size() or group >= _standers.size():
		return
	var risen := seat
	# Towards the court, which is the way they are facing — the other way walks them into
	# the riser of the row behind.
	risen.origin -= risen.basis.z.normalized() * _stand_forward
	var shape: Transform3D = _stander_shapes[group]
	_standers[group].multimesh.set_instance_transform(i, risen * shape)
	_crowds[group].multimesh.set_instance_transform(i, _nowhere(seat))


## Whether the standing copy of the hall is drawn at all.
##
## Every spectator occupies a slot in two MultiMeshes and the unused one is a zero-sized
## transform. Those cost nothing to rasterise — a triangle with no area is thrown away —
## but they are still transformed, and between reactions that is three hundred people's
## worth of vertices for a hall where nobody is standing. A hall is seated most of the
## time, so the standing copy is switched off entirely until somebody gets up.
func _draw_the_risen(shown: bool) -> void:
	for group in _standers.size():
		var up: MultiMesh = _standers[group].multimesh
		if not shown:
			up.visible_instance_count = 0
			continue
		if group < _crowds.size():
			up.visible_instance_count = _crowds[group].multimesh.visible_instance_count


## The same place, with nothing there. Keeping the position rather than moving the
## instance to the origin matters: a MultiMesh's bounding box is grown by every instance
## it holds, and one parked at 0,0,0 stretches the box across the hall and back.
func _nowhere(seat: Transform3D) -> Transform3D:
	return Transform3D(Basis().scaled(Vector3.ZERO), seat.origin)


## How full the hall is, from empty to packed. A school hall has a handful of
## parents in it; an international final does not have a spare seat.
func set_density(density: float) -> void:
	# Thinned further when the player has asked for a lighter hall. The rung decides how
	# full the venue is and this decides how much of it is drawn; a school hall at the
	# lightest setting is still a school hall, with fewer people in the back rows.
	var kept: float = Settings.QUALITY_CROWD[int(Settings.drawing)]
	var part := clampf(density, 0.0, 1.0) * kept
	# Thinned out evenly across all three kinds of person, or a half-empty hall would
	# be a hall containing only the first of them.
	for group in _crowds.size():
		var multi: MultiMesh = _crowds[group].multimesh
		multi.visible_instance_count = roundi(float(multi.instance_count) * part)
		# Both halves of every spectator, or a thinned hall keeps the people who are on
		# their feet and loses only the ones sitting down. Only while somebody is
		# actually up — see `_draw_the_risen`.
		if group < _standers.size():
			var up: MultiMesh = _standers[group].multimesh
			up.visible_instance_count = multi.visible_instance_count if _cheering else 0
	if _heads != null:
		_heads.multimesh.visible_instance_count = roundi(_total * part)


## Where one row of one side sits. The near side is pushed out past the second court,
## so the two sides cannot share a number any more.
## Where `count` of the people actually in the stands are sitting, spread through the crowd,
## in this node's space: for the flags and banners somebody holds up. Only the people shown at
## the present density are counted, so a thin crowd never holds a flag over an empty seat.
func held_up_spots(count: int) -> Array[Transform3D]:
	var present: Array[Transform3D] = []
	for group in _crowds.size():
		var shown: int = _crowds[group].multimesh.visible_instance_count
		var slice: Array = _crowd_seats[group]
		for i in mini(shown, slice.size()):
			present.append(slice[i])
	var spots: Array[Transform3D] = []
	if present.is_empty() or count <= 0:
		return spots
	var step := maxf(1.0, float(present.size()) / float(count))
	var i := 0.0
	while int(i) < present.size() and spots.size() < count:
		spots.append(present[int(i)])
		i += step
	return spots


func _row_x(side: float, row: int) -> float:
	var start := far_row_x if side > 0.0 else near_row_x
	return side * (start + row_depth * (float(row) + 0.5))


func _build_seating() -> void:
	# A school hall's steps are pale scuffed concrete under strip lights. An arena's are
	# dark, because the light is all on the court and the stands are meant to recede.
	var pale := tier == Venue.Tier.SCHOOL

	var concrete := StandardMaterial3D.new()
	var front := StandardMaterial3D.new()
	if outdoors:
		# Scaffold decking put up for the weekend: pale boards on a dark frame, and
		# bleached rather than the grey of a room that never sees the sun.
		concrete.albedo_color = Color(0.78, 0.72, 0.62)
		front.albedo_color = Color(0.34, 0.33, 0.33)
	else:
		concrete.albedo_color = Color(0.52, 0.51, 0.48) if pale else Color(0.20, 0.20, 0.23)
		front.albedo_color = Color(0.42, 0.41, 0.39) if pale else Color(0.14, 0.14, 0.17)
	concrete.roughness = 0.95
	front.roughness = 0.95

	for side: float in SIDES:
		for row in rows:
			var height := row_rise * float(row + 1)
			var x := _row_x(side, row)

			var step := MeshInstance3D.new()
			step.name = "Step"
			var box := BoxMesh.new()
			box.size = Vector3(row_depth, height, half_length * 2.0)
			step.mesh = box
			step.position = Vector3(x, height * 0.5, 0.0)
			step.material_override = concrete if row % 2 == 0 else front
			add_child(step)


func _build_crowd() -> void:
	var seats: Array[Transform3D] = []
	# Where the chair is, as opposed to where the person in it is. A chair is bolted to
	# the concrete: square to the row, evenly spaced, and identical to its neighbour. The
	# slouch below belongs to the person and not to the furniture — while the seats were
	# a white lump nobody could tell, and the moment they became recognisable chairs a
	# stand full of them sitting at slightly different angles read as a badly built set.
	var bolted: Array[Transform3D] = []
	for side: float in SIDES:
		for row in rows:
			var height := row_rise * float(row + 1)
			var x := _row_x(side, row)
			var z := -half_length + seat_spacing * 0.5
			while z < half_length:
				var bolt := Transform3D.IDENTITY
				bolt.basis = Basis(Vector3.UP, PI * 0.5 * side)
				bolt.origin = Vector3(x, height, z)
				bolted.append(bolt)

				var seat := Transform3D.IDENTITY
				# Turned to face the court, with a little slouch either way.
				seat.basis = Basis(Vector3.UP, (PI * 0.5 * side) + randf_range(-0.18, 0.18))
				seat.origin = Vector3(x + randf_range(-0.12, 0.12), height, z)
				seats.append(seat)
				z += seat_spacing

	# Shuffled as pairs. Shuffling matters: a half-empty hall is drawn by showing only the
	# first so many instances, and unshuffled that would seat everybody in one solid block
	# at one end. Shuffling the two lists separately would sit each person in somebody
	# else's chair.
	var order: Array[int] = []
	for i in seats.size():
		order.append(i)
	order.shuffle()
	var people: Array[Transform3D] = []
	var chairs: Array[Transform3D] = []
	for i in order:
		people.append(seats[i])
		chairs.append(bolted[i])
	seats = people
	bolted = chairs

	_total = seats.size()
	_seats = seats
	_jump.resize(_total)

	# One colour per person, decided once. The head and the body are drawn by two
	# separate MultiMeshes, and if each picked its own colour every spectator would
	# be wearing somebody else's head.
	var shirts: Array[Color] = []
	for i in _total:
		# A real colour per person, not a shade of one. See TINTED.
		var shirt: Color = SHIRTS[randi() % SHIRTS.size()]
		var shade := randf_range(0.86, 1.14)
		shirts.append(Color(shirt.r * shade, shirt.g * shade, shirt.b * shade))

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
		# No quarter turn: this model is authored standing up already, unlike the one it
		# replaced. It is authored a long way from its own origin, though, which is what
		# the last argument is for.
		var chair := Props.merged(
			Props.SEAT, SEAT_HEIGHT, Props.turned(CROWD_FACING), SEAT_DETAIL, true)
		if not chair.is_empty():
			var greys: Array[Color] = []
			for i in _total:
				var shade := randf_range(0.86, 1.14)
				greys.append(Color(shade, shade, shade))
			_make_crowd_mesh("Seats", chair[0], bolted, greys, 0.0, chair[1])
			# How far forward somebody steps when they get out of the chair. A real
			# tip-up seat folds up behind them; here they simply move clear of it, which
			# from the court is the same picture.
			stand_forward = SEAT_DEPTH

	# Nobody is moved off their seat any more. A spectator sits **in** the chair now, and
	# the shift forward only applies to the moment they are on their feet — see
	# `_stand_up`, which is where SEAT_DEPTH went.
	_stand_forward = stand_forward
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
		var correction := Props.turned(PERSON_FACING)
		var sitting := Props.merged(String(kind["sitting"]), float(kind["height"]),
			correction, 1.0, false, TINTED)
		var standing := Props.merged(String(kind["standing"]), float(kind["height"]),
			correction, 1.0, false, TINTED)
		if sitting.is_empty() or standing.is_empty():
			continue

		var slice: Array[Transform3D] = []
		var tint: Array[Color] = []
		for i in range(dealt, dealt + take):
			slice.append(seats[i])
			tint.append(shirts[i])
		dealt += take

		var shape: Transform3D = sitting[1]
		var instance := _make_crowd_mesh("Crowd%d" % which, sitting[0], slice, tint, 0.0, shape)
		_crowds.append(instance)
		_crowd_seats.append(slice)
		_crowd_shapes.append(shape)

		# The same people standing up, every one of them hidden to begin with. Built from
		# the same slice so instance i is the same person in both.
		var up_shape: Transform3D = standing[1]
		var risen := _make_crowd_mesh("Crowd%dUp" % which, standing[0], slice, tint, 0.0, up_shape)
		_standers.append(risen)
		_stander_shapes.append(up_shape)
		var group := _crowds.size() - 1
		for i in slice.size():
			_sit_down(group, i, slice[i])
		risen.multimesh.visible_instance_count = 0

		var jumps := PackedFloat32Array()
		jumps.resize(slice.size())
		_crowd_jumps.append(jumps)
		var holds := PackedFloat32Array()
		holds.resize(jumps.size())
		holds.fill(0.0)
		_crowd_holds.append(holds)

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
	# No shadows from the stands. Every shadow-casting light draws its casters again —
	# the hall light several times over, once per shadow cascade — so three hundred seats
	# and the people in them were being drawn seven or eight times a frame, for shadows
	# that fall on the steps behind them where nobody in the chair is looking.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
