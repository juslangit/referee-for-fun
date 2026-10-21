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

## A stadium bowl to seat people in, round all four sides, instead of two straight banks of
## steps. The bowl's steps are a model of their own (see `Bowl`), so none are built here.
var bowl: Bowl

## How much of each spectator's mesh to keep. A bowl seats thousands rather than three
## hundred, and from the umpire's chair the nearest of them is twenty metres away.
var crowd_detail := 1.0

## How much of each spectator to keep at each distance from the court: [metres, keep]
## pairs, nearest first. A bowl's back rows are thirty metres from the chair, where a
## sixteenth of a person cannot be told from a quarter of one, and there are thousands of
## them. Empty means `crowd_detail` for everybody. See `Props.simplified` for the steps a
## mesh can actually be cut to: a quarter, an eighth and a sixteenth.
var detail_bands: Array = []

## Where the distance for `detail_bands` is measured from: the middle of the court, at the
## height of the umpire's eye.
const BAND_FROM := Vector3(0.0, 2.5, 0.0)

static var _crowd_meshes := {}

## Multiplies every seat's colour. White leaves a hall's seats as they were; a bowl sets
## the stadium's own colour, and its seats take nothing else (see `_build_crowd`).
var seat_colour := Color.WHITE

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

## The realistic crowd, drawn to go with the realistic players (2026-10-15): a Malay uncle
## in batik and a songkok, a young woman in a tudung, a teenager in a striped football shirt,
## and a dad in a polo and a cap. Built by Tripo, rigged by Meshy and frozen into their poses
## by `tools/tripo/bake_crowd_poses.py`. Four people dressed as themselves beat two dressed
## by instance colour, so none of them is tinted — their materials are not called `kit`,
## which is the only thing TINTED lets the colour touch. Half the uncles and dads lean
## forward, the same trick as before, so a row does not all sit the same way. Used when every
## file is there; otherwise CROWD_MODELS, as before.
const REAL_CROWD_MODELS := [
	{"sitting": "res://assets/characters/fan_uncle_sit.glb",
		"standing": "res://assets/characters/fan_uncle_stand.glb", "height": 0.0, "share": 0.14},
	{"sitting": "res://assets/characters/fan_uncle_lean.glb",
		"standing": "res://assets/characters/fan_uncle_stand.glb", "height": 0.0, "share": 0.12},
	{"sitting": "res://assets/characters/fan_tudung_sit.glb",
		"standing": "res://assets/characters/fan_tudung_stand.glb", "height": 0.0, "share": 0.24},
	{"sitting": "res://assets/characters/fan_teen_lean.glb",
		"standing": "res://assets/characters/fan_teen_stand.glb", "height": 0.0, "share": 0.24},
	{"sitting": "res://assets/characters/fan_dad_sit.glb",
		"standing": "res://assets/characters/fan_dad_stand.glb", "height": 0.0, "share": 0.13},
	{"sitting": "res://assets/characters/fan_dad_lean.glb",
		"standing": "res://assets/characters/fan_dad_stand.glb", "height": 0.0, "share": 0.13},
]


## The crowd this hall is built from: the realistic one if all of it is on disk.
static func crowd_models() -> Array:
	for kind in REAL_CROWD_MODELS:
		if not (ResourceLoader.exists(kind["sitting"]) and ResourceLoader.exists(kind["standing"])):
			return CROWD_MODELS
	return REAL_CROWD_MODELS


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
##
## **180, since 2026-09-21.** It was 0, which sat the whole hall with its back to the court
## — invisible while the seats were also a quarter turn out and obvious the moment they
## were put right. The two numbers are a pair and were wrong together; see `CROWD_FACING`.
const PERSON_FACING := 180.0

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

## Everybody used to do exactly the same thing at exactly the same moment: the same arc,
## the same height, the same 0.9 seconds, three hundred people landing in one frame.
## Luqman on 2026-10-21, after watching the trailer: "the audience movement is all the
## same. i want a randomize movement, make it more like real life." So each person now
## brings their own timing to every reaction, and these are the spreads they are dealt
## from.
##
## How late somebody is to react. Most of a hall goes within a quarter of a second; a few
## were looking at their phone.
const REACT_LATE := 0.45
const STRAGGLER_SHARE := 0.12
const STRAGGLER_LATE := 1.1

## How a cheer is done. Some people jump once, some bounce two or three times, and some
## just get up, clap for a moment and sit down — that last kind has no arc at all.
const CHEER_RISERS := 0.3
const CHEER_BOUNCE := Vector2(0.5, 0.85)
const CHEER_LIFT := Vector2(0.45, 1.4)
const CHEER_RISE_HOLD := Vector2(1.1, 2.4)

## How long somebody stays on their feet over a bad call, as a share of STAND_SECONDS:
## the first to sit back down gives up at a little over half of it, the most stubborn
## outlast it by half again.
const STAND_HOLD := Vector2(0.55, 1.5)

## Nobody stands perfectly still, so the risen sway and turn to the people beside them.
const STAND_SWAY := 0.14
const REACT_TURN := 0.3

## Between reactions a seated hall is still never frozen: somebody turns to the person
## next to them, somebody leans forward, somebody sits back. On average each person does
## something every this many seconds, for a second or three.
const FIDGET_EVERY := 7.0
const FIDGET_SECONDS := Vector2(1.2, 3.2)
const FIDGET_TURN := 0.45
const FIDGET_LEAN := 0.08

## How many people in the whole hall may be fidgeting at once. A school hall never gets
## near it; a six-thousand-seat bowl would otherwise have two thousand people moving every
## frame, which cost the international final six frames a second. Nobody counts the
## people turning their heads in the back rows.
const FIDGET_MOST := 450

## How far above a seated spectator's own origin the bubble's tail points. A little
## over the 0.78 the head mesh is lifted by, so the tail lands just clear of the hair
## rather than through it.
## The hall clapping in time while a review plays (2026-10-21). A clap every 0.21 s,
## the tempo of the recording under it (`Sound.REVIEW_CLAPPING`); the share of the seated
## hall that joins in; how far each one is off the beat, so it reads as a room and not a
## machine; and how much a clap moves somebody, which from the court is a small dip and
## lean forward.
const CLAP_EVERY := 0.21
const CLAP_SHARE := 0.5
const CLAP_SLOP := 0.035
const CLAP_DIP := 0.03
const CLAP_LEAN := 0.11
## A ceiling on how many clap at once, for the same reason as `FIDGET_MOST`: every one is
## a transform written every frame.
const CLAP_MOST := 1400

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

## Each person's own version of the reaction they are in, dealt when it starts. Parallel to
## `_crowd_jumps`: how long the moving part lasts (the rest of the timer is the wait before
## they move), how high they go, how many times they bounce (none for somebody who only
## stands), which way they turn, and where in their sway they start.
var _crowd_lengths: Array = []
var _crowd_lifts: Array = []
var _crowd_bounces: Array = []
var _crowd_turns: Array = []
var _crowd_phases: Array = []

## The seated fidgets, kept apart from the reactions so the checks that count people out
## of their seats are not fooled by somebody turning to talk to a neighbour. Only the
## people fidgeting right now are visited each frame, which keeps a big bowl cheap.
var _fidgeters: Array = []
var _fidget_clocks: Array = []
var _fidget_lengths: Array = []
var _fidget_turns: Array = []
var _fidget_leans: Array = []
var _fidget_due: PackedFloat32Array = PackedFloat32Array()

## The crowd's own dice. Every frame of a reaction or a fidget rolls some, and drawn from
## the global generator they would change every rally that comes after them — the trailer
## records rallies by what the game does with a given run of numbers.
var _dice := RandomNumberGenerator.new()

## Who is clapping along, per group, and how far off the beat each is. Empty when the
## hall is not.
var _clappers: Array = []
var _clap_offsets: Array = []
var _clap_clock := 0.0

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
	_clappers.clear()
	_clap_offsets.clear()
	_crowds.clear()
	_crowd_seats.clear()
	_standers.clear()
	_stander_shapes.clear()
	_crowd_shapes.clear()
	_crowd_jumps.clear()
	_crowd_holds.clear()
	for moves: Array in [_crowd_lengths, _crowd_lifts, _crowd_bounces, _crowd_turns,
			_crowd_phases, _fidgeters, _fidget_clocks, _fidget_lengths, _fidget_turns,
			_fidget_leans]:
		moves.clear()
	_fidget_due.clear()
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
		var lengths: PackedFloat32Array = _crowd_lengths[group]
		var lifts: PackedFloat32Array = _crowd_lifts[group]
		var bounces: PackedFloat32Array = _crowd_bounces[group]
		var turns: PackedFloat32Array = _crowd_turns[group]
		var phases: PackedFloat32Array = _crowd_phases[group]
		for i in jumps.size():
			if jumps[i] > 0.0 or _dice.randf() >= share:
				continue
			# Squared, so most of the hall goes almost together and only a tail is late.
			var late := pow(_dice.randf(), 2.0) * REACT_LATE
			if _dice.randf() < STRAGGLER_SHARE:
				late += _dice.randf_range(0.3, STRAGGLER_LATE)
			var length := 0.0
			if standing:
				length = seconds * _dice.randf_range(STAND_HOLD.x, STAND_HOLD.y)
				bounces[i] = 0.0
				lifts[i] = _dice.randf_range(0.85, 1.05)
			elif _dice.randf() < CHEER_RISERS:
				length = _dice.randf_range(CHEER_RISE_HOLD.x, CHEER_RISE_HOLD.y)
				bounces[i] = 0.0
				lifts[i] = _dice.randf_range(0.8, 1.0)
			else:
				# One jump for most, two or three for the excited few.
				var roll := _dice.randf()
				bounces[i] = 1.0 if roll < 0.6 else (2.0 if roll < 0.9 else 3.0)
				length = bounces[i] * _dice.randf_range(CHEER_BOUNCE.x, CHEER_BOUNCE.y) \
						* (seconds / CHEER_SECONDS)
				lifts[i] = _dice.randf_range(CHEER_LIFT.x, CHEER_LIFT.y)
			lengths[i] = length
			jumps[i] = late + length
			holds[i] = 1.0 if standing else 0.0
			turns[i] = _dice.randf_range(-REACT_TURN, REACT_TURN)
			phases[i] = _dice.randf() * TAU
		_crowd_jumps[group] = jumps
		_crowd_holds[group] = holds
		_crowd_lengths[group] = lengths
		_crowd_lifts[group] = lifts
		_crowd_bounces[group] = bounces
		_crowd_turns[group] = turns
		_crowd_phases[group] = phases
	_cheering = not _crowds.is_empty()
	_draw_the_risen(_cheering)


## The hall claps in time, or stops.
func clap_along(on: bool) -> void:
	for group in _clappers.size():
		var seats: Array[Transform3D] = _crowd_seats[group]
		var jumps: PackedFloat32Array = _crowd_jumps[group]
		for i in _clappers[group]:
			if jumps[i] <= 0.0:
				_sit_down(group, i, seats[i])
	_clappers.clear()
	_clap_offsets.clear()
	_clap_clock = 0.0
	if not on:
		return
	for group in _crowds.size():
		var multi: MultiMesh = _crowds[group].multimesh
		var shown := multi.visible_instance_count
		if shown < 0:
			shown = multi.instance_count
		var most := ceili(CLAP_MOST * float(_crowd_seats[group].size()) / maxf(_total, 1.0))
		var who := PackedInt32Array()
		var off := PackedFloat32Array()
		for i in shown:
			if who.size() >= most:
				break
			if _dice.randf() < CLAP_SHARE:
				who.append(i)
				off.append(_dice.randf_range(-CLAP_SLOP, CLAP_SLOP))
		_clappers.append(who)
		_clap_offsets.append(off)


func _clap(delta: float) -> void:
	if _clappers.is_empty():
		return
	_clap_clock += delta
	for group in _clappers.size():
		var who: PackedInt32Array = _clappers[group]
		var off: PackedFloat32Array = _clap_offsets[group]
		var seats: Array[Transform3D] = _crowd_seats[group]
		var jumps: PackedFloat32Array = _crowd_jumps[group]
		var clocks: PackedFloat32Array = _fidget_clocks[group]
		for k in who.size():
			var i := who[k]
			# Somebody on their feet or mid-fidget is being moved by that instead.
			if jumps[i] > 0.0 or clocks[i] > 0.0:
				continue
			# Sharp on the beat and easing back: the hands meet, and the body follows.
			var beat := fposmod((_clap_clock + off[k]) / CLAP_EVERY, 1.0)
			var pulse := exp(-beat * 6.0)
			var seat := seats[i]
			seat.origin.y -= pulse * CLAP_DIP
			seat.basis = seat.basis * Basis(Vector3.RIGHT, -pulse * CLAP_LEAN)
			_sit_down(group, i, seat)


func _process(delta: float) -> void:
	_fidget(delta)
	_clap(delta)
	if not _cheering:
		return

	var still_going := false
	for group in _crowds.size():
		var jumps: PackedFloat32Array = _crowd_jumps[group]
		var holds: PackedFloat32Array = _crowd_holds[group]
		var lengths: PackedFloat32Array = _crowd_lengths[group]
		var lifts: PackedFloat32Array = _crowd_lifts[group]
		var bounces: PackedFloat32Array = _crowd_bounces[group]
		var turns: PackedFloat32Array = _crowd_turns[group]
		var phases: PackedFloat32Array = _crowd_phases[group]
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
			if jumps[i] > lengths[i]:
				# Not moved yet. Still in the chair while the people round them go.
				continue
			var through := 1.0 - jumps[i] / lengths[i]
			var into := lengths[i] - jumps[i]
			var seat := seats[i]
			var lift := 0.0
			var turn := turns[i]
			if bounces[i] <= 0.0:
				# On their feet: up quickly, held for as long as it lasts, and back down at
				# the end. Rising takes the same fraction of a second for everyone, which
				# is why it is measured in seconds and not as a share of the hold.
				var rise := minf(into / (STAND_RISE * STAND_SECONDS * 0.5), 1.0)
				var fall := minf(jumps[i] / (STAND_RISE * STAND_SECONDS * 0.6), 1.0)
				lift = minf(rise, fall) * STAND_HEIGHT * lifts[i]
				# Never quite still while up: a slow sway, and the angrier half of a
				# jeering hall bouncing on the spot as they shout.
				turn += sin(into * 1.3 + phases[i]) * STAND_SWAY
				if holds[i] > 0.5 and phases[i] < PI:
					lift += absf(sin(into * 5.0 + phases[i])) * 0.035
				elif holds[i] <= 0.5:
					# Clapping, which from the court is a small quick bob.
					lift += absf(sin(into * 7.0 + phases[i])) * 0.02
			else:
				# A jump per bounce, each lower than the last, so nobody lands before
				# their own shout is over.
				var bounce := minf(floorf(through * bounces[i]), bounces[i] - 1.0)
				var arc := through * bounces[i] - bounce
				lift = sin(arc * PI) * CHEER_HEIGHT * lifts[i] * pow(0.7, bounce)
			seat.origin.y += lift
			seat.basis = seat.basis.rotated(Vector3.UP, turn * minf(through * 4.0, 1.0))
			_stand_up(group, i, seat)
		_crowd_jumps[group] = jumps
	if not still_going:
		_draw_the_risen(false)
	_cheering = still_going


## The seated hall between reactions: a few people at a time turning to a neighbour or
## leaning in, so nobody in the stands is a statue.
##
## Starts are spread by a running total rather than rolled per person per frame, so a
## hall of two thousand costs a handful of picks a frame rather than two thousand rolls.
func _fidget(delta: float) -> void:
	for group in _crowds.size():
		var multi: MultiMesh = _crowds[group].multimesh
		var shown := multi.visible_instance_count
		if shown < 0:
			shown = multi.instance_count
		var seats: Array[Transform3D] = _crowd_seats[group]
		var jumps: PackedFloat32Array = _crowd_jumps[group]
		var who: PackedInt32Array = _fidgeters[group]
		var clocks: PackedFloat32Array = _fidget_clocks[group]
		var lengths: PackedFloat32Array = _fidget_lengths[group]
		var turns: PackedFloat32Array = _fidget_turns[group]
		var leans: PackedFloat32Array = _fidget_leans[group]

		_fidget_due[group] += float(shown) * delta / FIDGET_EVERY
		while _fidget_due[group] >= 1.0:
			_fidget_due[group] -= 1.0
			if shown <= 0:
				continue
			if who.size() >= ceili(FIDGET_MOST * float(seats.size()) / maxf(_total, 1.0)):
				continue
			var i := _dice.randi() % shown
			if jumps[i] > 0.0 or clocks[i] > 0.0:
				continue
			clocks[i] = 0.0001
			lengths[i] = _dice.randf_range(FIDGET_SECONDS.x, FIDGET_SECONDS.y)
			turns[i] = _dice.randf_range(-FIDGET_TURN, FIDGET_TURN)
			leans[i] = _dice.randf_range(-FIDGET_LEAN, FIDGET_LEAN)
			who.append(i)

		var kept := PackedInt32Array()
		for i in who:
			if jumps[i] > 0.0:
				# Caught up in a reaction, which moves them itself.
				clocks[i] = 0.0
				continue
			clocks[i] += delta
			var seat := seats[i]
			if clocks[i] >= lengths[i]:
				clocks[i] = 0.0
				_sit_down(group, i, seat)
				continue
			kept.append(i)
			# Turn, hold the look, turn back.
			var t := clocks[i] / lengths[i]
			var w := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.7, 1.0, t))
			seat.basis = seat.basis.rotated(Vector3.UP, turns[i] * w)
			seat.basis = seat.basis * Basis(Vector3.RIGHT, leans[i] * w)
			_sit_down(group, i, seat)
		_fidgeters[group] = kept
		_fidget_clocks[group] = clocks
		_fidget_lengths[group] = lengths
		_fidget_turns[group] = turns
		_fidget_leans[group] = leans


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
	if bowl != null:
		return
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
	if bowl != null:
		for bolt in bowl.seats():
			bolted.append(bolt)
			var seat := bolt
			seat.basis = bolt.basis.rotated(Vector3.UP, randf_range(-0.18, 0.18))
			seat.origin += bolt.basis.z * randf_range(-0.06, 0.06)
			seats.append(seat)
	for side: float in (SIDES if bowl == null else []):
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
	# Nobody bolts a seat to a bench: a venue whose rows are planks (`Bowl.benches`) has them
	# modelled in, and its people sit straight on them.
	if bowl != null and bowl.benches():
		stand_forward = SEAT_DEPTH
	elif Venue.TIERS[tier]["seats"]:
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
				greys.append(Color(seat_colour.r * shade, seat_colour.g * shade, seat_colour.b * shade))
			var seats_mesh := _make_crowd_mesh("Seats", chair[0], bolted, greys, 0.0, chair[1])
			if bowl != null:
				# A stadium's seats are moulded plastic in the stadium's colour, not this
				# model's own red, so the instance colour is the whole of the colour.
				var plastic := StandardMaterial3D.new()
				plastic.vertex_color_use_as_albedo = true
				plastic.roughness = 0.55
				seats_mesh.material_override = plastic
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
	var models := crowd_models()
	var bands: Array = detail_bands
	if bands.is_empty() and bowl != null:
		bands = bowl.data.get("detail_bands", [])
	if bands.is_empty():
		bands = [[INF, crowd_detail]]
	for which in models.size():
		var kind: Dictionary = models[which]
		var take := _total - dealt if which == models.size() - 1 else roundi(_total * float(kind["share"]))
		if take <= 0:
			continue
		var whole: Array[int] = []
		for i in range(dealt, dealt + take):
			whole.append(i)
		dealt += take

		# Each kind of person once per distance band, from the most detailed near the court to
		# the least in the back rows. Still contiguous runs of the shuffled list within a band,
		# so thinning the crowd thins every band evenly too.
		var nearer := 0.0
		for band: Array in bands:
			var limit: float = band[0]
			var keep: float = band[1]
			var slice: Array[Transform3D] = []
			var tint: Array[Color] = []
			for i in whole:
				var far := seats[i].origin.distance_to(BAND_FROM)
				if far > nearer and far <= limit or (nearer == 0.0 and far <= limit):
					slice.append(seats[i])
					tint.append(shirts[i])
			nearer = limit
			if slice.is_empty():
				continue
			_add_crowd_group(kind, which, keep, slice, tint)

	if not _crowds.is_empty():
		_heads = null
		return

	# No downloaded people at all, so the boxes this started as.
	_crowds.append(_make_crowd_mesh("Bodies", _body_mesh(), seats, shirts, 0.35))
	_heads = _make_crowd_mesh("Heads", _head_mesh(), seats, shirts, 0.78)


## `lift` raises the part above the step the person is sitting on, since both
## MultiMeshes work from the same seat positions. `shape` is the transform that makes
## the mesh stand up at the right size, when the mesh came from a downloaded model.
## One kind of person at one level of detail: the sitting MultiMesh, the standing one
## hidden behind it, and the bookkeeping for their reactions.
func _add_crowd_group(kind: Dictionary, which: int, keep: float, slice: Array[Transform3D],
		tint: Array[Color]) -> void:
	var correction := Props.turned(PERSON_FACING)
	var sitting := _crowd_mesh(String(kind["sitting"]), float(kind["height"]), correction, keep)
	var standing := _crowd_mesh(String(kind["standing"]), float(kind["height"]), correction, keep)
	if sitting.is_empty() or standing.is_empty():
		return

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
	for moves: Array in [_crowd_lengths, _crowd_lifts, _crowd_bounces, _crowd_turns,
			_crowd_phases, _fidget_clocks, _fidget_lengths, _fidget_turns, _fidget_leans]:
		var each := PackedFloat32Array()
		each.resize(slice.size())
		each.fill(0.0)
		moves.append(each)
	_fidgeters.append(PackedInt32Array())
	# Started part of the way to the first fidget, so a hall does not sit still for its
	# opening second and then all start at once.
	_fidget_due.append(_dice.randf())


## A spectator's mesh at one level of detail, made once per game. Simplifying a person is
## the slow part of building a hall, and a bowl asks for each of them three times.
static func _crowd_mesh(path: String, height: float, correction: Transform3D, keep: float) -> Array:
	var key := "%s|%.3f|%.3f" % [path, height, keep]
	if not _crowd_meshes.has(key):
		_crowd_meshes[key] = Props.merged(path, height, correction, keep, false, TINTED)
	return _crowd_meshes[key]


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
