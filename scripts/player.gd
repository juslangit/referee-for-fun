class_name Player
extends Node3D

## One athlete. Deliberately simple: they run to where they think the shuttle is
## going, and if they get there in time they hit it back.
##
## They are not trying to play good badminton. Their whole job is to produce rallies
## that end somewhere worth judging — which mostly means getting to the shuttle so
## the rally continues, and occasionally deciding a shot is going out and letting it
## drop. That last decision is the one that makes the umpire's job interesting: a
## player who stands and watches a shuttle land is staking the rally on your call.

const BODY_HEIGHT := 1.78
const BODY_RADIUS := 0.22

## People are drawn on their own visual layer so the line camera can leave them out.
## A camera at knee height on the line spends most of its life looking at somebody's
## legs, which is true to life and completely useless for judging a line.
const PEOPLE_LAYER := 2

## Everybody playing, so the hall can hear their feet. See Sound._physics_process.
const GROUP := &"athletes"

## Highest and lowest a shuttle can be and still be hit. The top of the range is an
## overhead smash; the bottom is a scrambling lift off the floor.
const HIGHEST_STRIKE := 2.85
const LOWEST_STRIKE := 0.28

## How fast they cover the court, in metres per second.
@export var speed := 4.0

## How far from the shuttle they can still reach it, racket included.
##
## It is a real measurement and not a difficulty knob: an arm is about 60 cm and a badminton
## racket 67, so a player who has stretched for one is about a metre and a quarter from it.
## It was 0.95 while nothing checked where the racket was, and the gap between the two — a
## third of a metre — was a third of a metre of shuttle struck by nothing at all.
@export var reach := 1.25

## How far the player has to move in a second before they look like they are running.
const MOVING_THRESHOLD := 0.35


# --- footwork ---------------------------------------------------------------------
#
# Nobody in a net sport turns their back on the ball. It is in front of you, your eyes
# stay on it, and so you go backwards on your toes with your chest square to the net and
# sideways on a chassé. Turning round to sprint is how you leave the court, not how you
# play a shot — and a player who did it looked, from the chair, like somebody running
# away from the rally and then changing their mind.
#
# So the body is turned off the net rather than at the run: square when going straight
# back, a shoulder's worth when going across. Going that way costs speed, which is the
# other half of why real players would rather not.

## How much slower they cover the ground going backwards and sideways than forwards.
const BACKWARD_PACE := 0.72
const SIDEWAYS_PACE := 0.88

## How far the shoulders turn into a run, in degrees: a short adjustment barely at all, a
## long chase most of the way round. Never a quarter turn past square, which is the angle
## at which the ball would be behind them.
const SHOULDER_TURN_NEAR := 30.0
const SHOULDER_TURN_FAR := 74.0

## How far they have left to run before the chase counts as a long one, in metres.
const LONG_CHASE := 4.0

## How fast the body comes round, in radians a second. Fast enough to keep up with a
## change of direction, slow enough that it is a turn and not a snap.
const TURN_SPEED := 8.0

## How far off square a run has to be before it is played as a backpedal or a shuffle.
## The first is how much of the run is straight at the net, the second how much across it.
const BACKWARDS_BEYOND := -0.35
const SIDEWAYS_BEYOND := 0.72

## How the players are animated.
##
## The models are static meshes, so this moves the whole figure rather than posing a
## skeleton: a run cycle's worth of bob and lean, and a racket swing when a shot is
## played. It is not a substitute for a rigged character — nobody's knees bend — but a
## figure that dips as it runs, leans into the run and swings when it hits reads as
## alive, and one that glides along at a constant height does not.
const BOB_HEIGHT := 0.055
const BOB_SPEED := 11.0
const RUN_LEAN := 0.17
const LEAN_SPEED := 2.4
const SWING_SECONDS := 0.34
const SWING_SWEEP := 2.3

var team := Sides.Team.NONE

## Whether this athlete plays a sport with a racket in it. Beach volleyball players
## carry nothing, and a volleyball player holding a badminton racket is a funnier bug
## than it is a small one.
var volleyball := false

## Which racket they carry. Tennis and badminton are near enough the same length and
## nothing else about them is alike, so the sport says which.
var racket_kind := &"badminton"

## Where they stand when the shuttle is not their problem.
var home := Vector3.ZERO

## Whether they are currently going after the shuttle.
var chasing := false

var _destination := Vector3.ZERO
## Walking rather than running, which only happens in the cutscenes: onto court behind the
## umpire, to the net to shake hands, to the chair. Kept to the officials' pace so the
## file of people walking on does not come apart.
var _walking := false
var _lunge_left := 0.0
var _lunge_spot := Vector3.ZERO
## How much longer they stay on the spot they are standing on, whatever `_destination`
## says. Only the volleyball serve uses it.
var _planted_left := 0.0

## The clips on the forged character, and which one is playing.
var _animator: AnimationPlayer
var _clip := ""
var _one_shot := false

## Clips that run until something else interrupts them, as opposed to shots.
const LOOPING := ["idle", "ready", "run", "walk", "tired", "argue", "vb_ready"]

## The figure and the racket in its hand.
var _figure: Node3D
var _racket: Node3D
var _racket_rest := Vector3.ZERO
var _bob := 0.0
var _lean := 0.0
var _swing_left := 0.0


func setup(for_team: Sides.Team, home_position: Vector3) -> void:
	team = for_team
	home = home_position
	position = home_position
	_destination = home_position
	add_to_group(GROUP)
	_build_body()


## Sized once it is in the tree, where a model's real dimensions are knowable, and
## dressed afterwards — the bib does not scale with the model, so measuring it as part
## of the figure set a floor the fit could never get under.
func _settle_when_posed(model: Node3D) -> void:
	await get_tree().process_frame
	if not is_instance_valid(model):
		return
	Models.settle(model)
	Models.dress_player(model, _carries())
	_take_up_racket(model)
	_measure_the_contacts()


## Picks up the racket, if this sport has one. Asking for the meta unconditionally is
## an error rather than a null once nobody is carrying anything.
## What goes in their hand, if anything.
func _carries() -> StringName:
	return &"" if volleyball else racket_kind


func _take_up_racket(model: Node3D) -> void:
	if not model.has_meta("racket"):
		return
	_racket = model.get_meta("racket")
	if _racket != null:
		_racket_rest = _racket.rotation


## Finds the clips and sets the looping ones to loop. Downloaded animations arrive
## set to play once, and so do these — the exporter has no way of knowing which of a
## run cycle and a smash is meant to repeat.
func _set_up_clips(model: Node3D) -> void:
	_animator = Models.animator(model)
	if _animator == null:
		return
	for clip in _animator.get_animation_list():
		if String(clip) in LOOPING:
			Models.make_looping(_animator, clip)
	_animator.animation_finished.connect(_on_clip_finished)
	_play("idle")


func _play(clip: String, one_shot := false, speed := 1.0) -> void:
	if _animator == null or clip.is_empty():
		return
	# A shot in progress is not interrupted by the player wandering back to position.
	if _one_shot and not one_shot:
		return
	if clip == _clip and not one_shot:
		return
	if not _animator.has_animation(clip):
		return
	if _measuring:
		# The rig is being posed clip by clip and cannot play anything yet. Remembered,
		# and played the moment the measurement finishes.
		_asked_for_while_measuring = clip
		return
	_clip = clip
	_one_shot = one_shot
	_holding_the_crouch = 0.0
	_animator.play(clip, 0.14, speed)


func _on_clip_finished(clip_name: StringName) -> void:
	# A crouch that finishes a moment before the strike holds its last pose rather than
	# standing up into `ready` and dropping straight back down into the smash.
	if clip_name == &"smash_windup":
		_holding_the_crouch = WIND_UP_HOLD
		return
	_one_shot = false
	_clip = ""


## The crouch and push-off before a smash, stretched or squeezed to end in
## `seconds_to_contact`, where `swing(true)` picks up from the pose it leaves. Nothing
## happens on a character without the clip, and a strike that comes sooner simply cuts it
## short.
func wind_up(seconds_to_contact: float) -> void:
	if _animator == null or not _animator.has_animation("smash_windup"):
		return
	var length := _animator.get_animation("smash_windup").length
	_play("smash_windup", true,
		clampf(length / maxf(seconds_to_contact, 0.01), WIND_UP_SLOWEST, WIND_UP_FASTEST))


## How long a finished wind-up may hold its pose waiting for the strike, in seconds.
const WIND_UP_HOLD := 0.3
var _holding_the_crouch := 0.0


## Where they will be in `seconds`, running at the spot they are already running to.
## Used to see a smash coming; ignores a lunge, which is never the shot being waited for.
func position_in(seconds: float) -> Vector3:
	var running_for := maxf(0.0, seconds - maxf(0.0, _planted_left))
	var here := Vector2(position.x, position.z)
	var going := Vector2(_destination.x, _destination.z)
	# At the pace they will actually go, which is not the same in every direction any
	# more. Predicting a backpedal at a forward run's speed puts them most of a metre
	# past where they will be, which is the whole width of a reach.
	var there := here.move_toward(going, speed * _footwork_pace(going - here) * running_for)
	return Vector3(there.x, 0.0, there.y)


## How far the wind-up may be slowed down or sped up to meet the strike before it stops
## looking like the same movement.
const WIND_UP_SLOWEST := 0.6
const WIND_UP_FASTEST := 1.6


## Takes a swing. `overhead` picks a smash over a groundstroke, so the shot on screen
## matches the shot the rally logic actually played.
func swing(overhead := false) -> void:
	if _stroke_under_way:
		# Already begun, and running so as to land on the ball. Playing it again here
		# would put the racket back at the top of the backswing on the frame of contact,
		# which is the fault `begin_stroke` exists to fix.
		_stroke_under_way = false
		_stroke_clip = ""
		_swing_left = SWING_SECONDS
		return
	_swing("smash" if overhead else ("forehand" if randf() < 0.65 else "backhand"), 0.0)


## The stroke itself. `in_seconds` stretches it so that its contact frame lands then;
## zero plays it at its own pace, which is what an untimed swing does.
## The three shot names are written out here rather than reached through a variable so that
## `dev/checks/_clipaudit` can still see them: it reads the quoted strings on every line
## that plays something, which is how it caught a clip nobody was playing.
func _swing(clip: String, in_seconds: float) -> void:
	_swing_left = SWING_SECONDS
	var pace := _pace_to_contact(clip, in_seconds)
	if clip == "smash":
		_play("smash", true, pace)
	elif clip == "backhand":
		_play("backhand", true, pace)
	else:
		_play("forehand", true, pace)


# --- volleyball ------------------------------------------------------------------
#
# The three touches of a rally, plus the block. They are one-shot clips like the
# badminton shots, and they carry the vb_ prefix so that the two sports can live in one
# exported character without arguing over the word "serve".

## The first touch: the ball is dug up off the sand, forearms together, low.
func dig() -> void:
	if _took_it_early("vb_dig"):
		return
	_play("vb_dig", true)


## The second: put up for somebody else to hit. Not called `set`, which is a keyword.
func set_the_ball() -> void:
	if _took_it_early("vb_set"):
		return
	_play("vb_set", true)


## The third, and the only one anybody watches.
func spike() -> void:
	if _took_it_early("vb_spike"):
		return
	_play("vb_spike", true)


## Both arms up over the net, which is where the touch call is decided.
func block() -> void:
	if _took_it_early("vb_block"):
		return
	_play("vb_block", true)


## When the hand meets the ball in `vb_serve`: frame 15 at 24 fps. Keyed in
## tools/meshy/volleyball_clips.py as SERVE_CONTACT_FRAME, and the two must agree —
## the match holds the ball in the air for exactly this long after the whistle.
const VB_SERVE_CONTACT := 15.0 / 24.0

## Where the hitting hand is at that frame, measured from the server's feet by
## dev/looks/_serveshot: this far in front, and this far out to the hitting side. The
## server stands that much behind and beside the ball, so it is struck by the hand and
## not by the top of their head. The height is 2.06 m to the wrist, about 2.15 m to the
## palm — the beach serve's height exactly, and ten centimetres under the indoor one.
const VB_SERVE_REACH := 0.22
const VB_SERVE_WIDE := 0.18


## Luqman's "volleyball 1": wind up, meet the ball, point the arm at the far court.
##
## Facing `toward` and planted on the spot for the whole clip. A server used to be put
## at the serving spot and then slide off towards their home position mid-swing, which a
## serve a third of this length hid and this one would not: the follow-through is held,
## and a held pose gliding across the floor is the first thing anybody would notice.
func serve_the_ball(toward: Vector3) -> void:
	var heading := Vector2(toward.x - position.x, toward.z - position.z)
	if heading.length() > 0.0005:
		rotation.y = atan2(heading.x, heading.y)
		# The match puts them where the ball will be struck; the hand meets it in front
		# and to one side.
		var facing := heading.normalized()
		var hitting_side := Vector2(-facing.y, facing.x)
		var step := facing * VB_SERVE_REACH + hitting_side * VB_SERVE_WIDE
		position -= Vector3(step.x, 0.0, step.y)
	_play("vb_serve", true)
	if _animator != null and _animator.has_animation("vb_serve"):
		_planted_left = _animator.get_animation("vb_serve").length


## A badminton serve: underarm, from below the waist, the shuttle dropped onto the racket.
##
## Every other sport in the game plays its serve — the two volleyballs, tennis and sepak
## takraw all have their own clip and time the ball to meet it. Badminton, the sport the
## whole game was built around, played none: the shuttle simply left a point in the air
## beside a player who never moved. The one exception was the illegal serve, which has had
## `serve_with_the_racket_up` since the service faults were built, so for a fortnight the
## only serve anybody was ever seen to play was a foul one.
##
## Planted for the whole delivery — the standing feet not moving is one of the three things
## this serve is judged on, and a server drifting back to position mid-swing would look
## exactly like the fault. Unless a step *is* the fault being staged, in which case the
## lunge already running is the whole point and is left alone.
##
## Where they stand is `stand_to_serve`, called before the fault is staged so that a foot
## fault steps off the spot they are actually going to serve from.
func serve_the_shuttle() -> void:
	_play("serve", true)
	if _lunge_left <= 0.0 and _animator != null and _animator.has_animation("serve"):
		_planted_left = _animator.get_animation("serve").length


## Stands where the racket can reach `contact`, facing across the net.
func stand_to_serve(contact: Vector3) -> void:
	place_to_serve(hitting_stance(contact))


## Stands exactly here to serve, going nowhere.
##
## Setting `position` on its own is not enough and never was: `_destination` still holds
## wherever they were last sent, so the next physics frame starts walking them back to it.
func place_to_serve(spot: Vector3) -> void:
	_walking = false
	chasing = false
	# Standing up to serve ends whatever stroke was still nominally running, so the serve
	# itself is free to be started early.
	_stroke_under_way = false
	_stroke_clip = ""
	position = Vector3(spot.x, 0.0, spot.z)
	_destination = position
	rotation.y = across_the_net()


## A tennis serve, which is its own action and not a smash.
##
## It was played with the badminton smash until now, and the two have almost nothing in
## common: a smash is a short flat strike from a square stance, and a serve is the
## slowest and largest movement in any of these five sports — the ball thrown up by the
## other hand, the racket dropped behind the back, contact at full stretch off the
## ground. It is also the only shot the umpire watches from beginning to end, because
## the foot fault is at the start of it and the net cord is at the end.
func serve_for_tennis() -> void:
	_play("tn_serve", true)
	# Planted, like the other three serves. A tennis server used to be put on the spot and
	# then walk back towards wherever they had last been sent while the ball was in the air,
	# so by the moment of contact they were nearly three metres from it.
	if _animator != null and _animator.has_animation("tn_serve"):
		_planted_left = _animator.get_animation("tn_serve").length


## A serve played with the racket head above the hand, which is a fault.
##
## The legal shape is the shaft pointing downwards at the moment of contact — so the
## illegal one is the racket turned up, and that is what this shows. It has to be
## visible from the chair or the call is a coin toss, so the turn is a large one and it
## is held for the whole of the delivery rather than flashed.
func serve_with_the_racket_up() -> void:
	_play("serve", true)
	if _racket == null:
		return
	_racket.rotation = _racket_rest + Vector3(PI * 0.72, 0.0, 0.0)
	_racket_upside_down = RACKET_UP_SECONDS


## How long the racket stays turned up: the whole service action.
const RACKET_UP_SECONDS := 1.1
var _racket_upside_down := 0.0


# --- sepak takraw ----------------------------------------------------------------
#
# Played with the feet, the knees, the chest and the head, and never the arms — so in
# every one of these the arms are out to the sides for balance, and the only clip with
# hands on the ball is the throw that starts a rally. They carry the st_ prefix, for the
# same reason the volleyball clips carry vb_.

## When the kicking foot meets the ball in `st_serve`: frame 13 at 24 fps. Keyed in
## tools/meshy/takraw_clips.py as ST_SERVE_CONTACT_FRAME, and the two must agree.
const ST_SERVE_CONTACT := 13.0 / 24.0

## When the foot meets the ball in `st_spike`, at the top of the jump: frame 14, keyed
## as ST_SPIKE_CONTACT_FRAME.
const ST_SPIKE_CONTACT := 14.0 / 24.0


## The tekong's serve: the top of the foot, at chest height, off one planted leg.
##
## Facing `toward` and planted for the whole clip, like `serve_the_ball`, and for a
## better reason than looks: the standing foot leaving the floor before the kick lands is
## the fault this serve is judged on, and a server sliding towards their home position
## mid-kick would look exactly like one.
func takraw_serve(toward: Vector3) -> void:
	face(toward)
	_play("st_serve", true)
	if _animator != null and _animator.has_animation("st_serve"):
		_planted_left = _animator.get_animation("st_serve").length


## Where the kicking foot will be when it meets the serve, so the throw can be sent there.
##
## The ball used to be thrown to a point straight above the tekong's feet, and the foot
## meets it two thirds of a metre in front of that — so the tekong kicked at a ball hanging
## over their own head. `height` is what to use on a character with no rig to measure.
func kicking_point(height: float) -> Vector3:
	if not _contact_offset.has("st_serve"):
		return position + Vector3(0.0, height, 0.0)
	return contact_point("st_serve", rotation.y)


## An inside player's underarm toss to the tekong, with both hands. The one time in the
## sport anybody is meant to touch the ball with them.
func takraw_throw() -> void:
	_play("st_throw", true)


## The first touch: sepak sila, the inside of the foot at knee height.
func takraw_receive() -> void:
	if _took_it_early("st_receive"):
		return
	_play("st_receive", true)


## Up onto the toes and through the ball with the forehead.
func takraw_header() -> void:
	if _took_it_early("st_header"):
		return
	_play("st_header", true)


## The feeder's set near the net: the same sila, with the foot up at the waist.
func takraw_set() -> void:
	if _took_it_early("st_set"):
		return
	_play("st_set", true)


## The roll spike: off one leg, over onto the back, and the other foot over the top.
func takraw_spike() -> void:
	if _took_it_early("st_spike"):
		return
	_play("st_spike", true)


## Back to the net and up, arched over the tape with the arms folded in. A blocker who
## puts a hand up has committed a fault, so nobody here does.
func takraw_block() -> void:
	if _took_it_early("st_block"):
		return
	_play("st_block", true)


## Sitting down, which is what players do at a changeover and nothing has ever asked
## them to do. The clip has been on the character all along.
func sit_down() -> void:
	_play("sit", true)


## Winning the point.
func celebrate() -> void:
	_play("celebrate", true)


## Turning on the chair after a call that went against them. The only time anybody in
## this game looks at the umpire.
func argue() -> void:
	_play("argue", true)


## A nod towards the chair: the official has got a run of them right after a bad patch.
##
## The counterpart to `argue`, and the only approving thing anybody on court ever does.
## It is not `celebrate` and must not become it — a celebration is about the rally and
## fires for whoever won the point, and this is about the person in the chair.
func acknowledge() -> void:
	_play("nod", true)


## Which clip is on the figure now, for the harnesses that assert somebody reacted.
##
## `_clip` is set by `_play` even when the clip turned out not to exist on the rig, so
## this reports what the animator is actually running rather than what was asked for —
## the whole point of asking is to catch a clip that silently is not there.
func playing_clip() -> String:
	if _animator == null:
		return ""
	return String(_animator.current_animation)


## Bob, lean and swing. All of it moves the whole figure, because the figure is a
## single static mesh with no skeleton to pose.
func _animate(delta: float, running: bool) -> void:
	if _figure == null:
		return
	# The forged characters have real animation. Bobbing and leaning them on top of
	# their own run cycle would just make them seasick.
	if _animator != null:
		return

	if running:
		_bob += delta * BOB_SPEED
	_figure.position.y = absf(sin(_bob)) * BOB_HEIGHT if running else 0.0

	_lean = move_toward(_lean, RUN_LEAN if running else 0.0, delta * LEAN_SPEED)
	_figure.rotation.x = -_lean

	if _racket != null and _racket_upside_down > 0.0:
		_racket_upside_down -= delta
		if _racket_upside_down <= 0.0:
			_racket.rotation = _racket_rest
		return

	if _swing_left <= 0.0 or _racket == null:
		return
	_swing_left -= delta
	# One smooth sweep through and back, rather than a snap.
	var through := 1.0 - clampf(_swing_left / SWING_SECONDS, 0.0, 1.0)
	_racket.rotation.x = _racket_rest.x - sin(through * PI) * SWING_SWEEP


func _physics_process(delta: float) -> void:
	if _holding_the_crouch > 0.0:
		_holding_the_crouch -= delta
		if _holding_the_crouch <= 0.0 and _clip == "smash_windup":
			_one_shot = false
			_clip = ""
	var aim := _destination
	if _lunge_left > 0.0:
		_lunge_left -= delta
		aim = _lunge_spot
	if _planted_left > 0.0:
		_planted_left -= delta
		aim = position

	var here := Vector2(position.x, position.z)
	var there := Vector2(aim.x, aim.z)
	var pace: float = Official.WALK_SPEED if _walking else speed * _footwork_pace(there - here)
	var moved := here.move_toward(there, pace * delta)
	position = Vector3(moved.x, 0.0, moved.y)

	var travelled := here.distance_to(moved) / maxf(delta, 0.0001)
	var running := travelled > MOVING_THRESHOLD
	var heading := moved - here
	if _stroke_under_way:
		rotation.y = rotate_toward(rotation.y, _stroke_facing, TURN_SPEED * 2.0 * delta)
	else:
		_turn_into_the_run(delta, heading, there.distance_to(moved))
	_animate(delta, running)
	if _animator != null:
		_play_footwork(running, heading)


## The way they face when they are not looking at anything in particular: across the net, at
## whoever they are playing. Every other angle in here is measured off it.
##
## Off the half they are **standing on**, not off their team. Tennis, table tennis and
## badminton all change ends, and a player whose square was decided by their team spent the
## second half of every match facing the back wall: the footwork read every run at the net
## as a retreat, backpedalled at three quarters speed towards the ball, and turned its back
## on the rally — which is the fault all of this exists to fix, reappearing at the changeover.
## `_contact` caught it at 178 degrees off square in tennis.
func across_the_net() -> float:
	var side := position.z
	if absf(side) < 0.05:
		# Standing on the net itself, which happens in a cutscene rather than a rally.
		side = Sides.half_sign(team)
	return PI if side > 0.0 else 0.0


## How far a heading is from square to the net, in radians. Zero is straight at the net,
## ±PI straight away from it, ±PI/2 along it.
func _off_square(towards: Vector2) -> float:
	if towards.length() < 0.0005:
		return 0.0
	return wrapf(atan2(towards.x, towards.y) - across_the_net(), -PI, PI)


## How much of their speed they have, going the way they are going. Full pace forwards,
## least of it backwards.
func _footwork_pace(towards: Vector2) -> float:
	if towards.length() < 0.0005:
		return 1.0
	var square := cos(_off_square(towards))
	var straight := BACKWARD_PACE if square < 0.0 else 1.0
	return lerpf(SIDEWAYS_PACE, straight, absf(square))


## Turns the body into the run, without ever turning it past the ball.
##
## The Meshy characters look down their own +Z, so a heading is an angle directly —
## measured off the rig's headfront bone rather than assumed, because the last two models
## faced the other way and everybody spent the match running backwards. What has changed
## is that the angle is no longer the heading itself: it is the heading squashed towards
## square, so that going straight backwards leaves them facing the net and going across
## it turns a shoulder.
func _turn_into_the_run(delta: float, heading: Vector2, still_to_go: float) -> void:
	if heading.length() < 0.0005:
		return
	var want := atan2(heading.x, heading.y)
	if _stroke_under_way:
		# Turned into the shot and staying turned. See `_turn_into_the_shot`.
		rotation.y = rotate_toward(rotation.y, _stroke_facing, TURN_SPEED * 2.0 * delta)
		return
	if not _walking:
		# `sin` is zero straight at the net and zero straight away from it, and largest
		# along it, which is exactly the shape the shoulders want.
		var shoulder := deg_to_rad(lerpf(SHOULDER_TURN_NEAR, SHOULDER_TURN_FAR,
			clampf(still_to_go / LONG_CHASE, 0.0, 1.0)))
		want = across_the_net() + shoulder * sin(_off_square(heading))
	rotation.y = rotate_toward(rotation.y, want, TURN_SPEED * delta)


## Which pair of legs is playing: a run, a backpedal, or a chassé across the court.
func _play_footwork(running: bool, heading: Vector2) -> void:
	if _walking:
		_play("walk" if running else "idle")
		return
	if not running:
		_play("ready" if chasing else "idle")
		return
	var off := _off_square(heading)
	if cos(off) < BACKWARDS_BEYOND:
		_play(_carried("backpedal", "run"))
	elif absf(sin(off)) > SIDEWAYS_BEYOND:
		_play(_carried("shuffle", "run"))
	else:
		_play("run")


## The first of two clips this character actually carries.
##
## A rig forged before the footwork clips existed still has `run`, and a player who backs
## off in a run cycle is a better answer than one whose legs stop moving entirely —
## `_play` returns silently on a clip that is not there, which would leave whatever was
## playing frozen on the spot.
func _carried(preferred: String, instead: String) -> String:
	if _animator != null and _animator.has_animation(preferred):
		return preferred
	return instead


## Walks somewhere, at an official's pace. See `_walking`.
func walk_to(point: Vector3) -> void:
	# Out of whatever they were doing on the spot — the slump at the end of a match loops
	# and never finishes, and would otherwise hold the walk off for good.
	_one_shot = false
	chasing = false
	_walking = true
	_planted_left = 0.0
	_destination = Vector3(point.x, 0.0, point.z)


## Turns to look at a point on the floor.
func face(point: Vector3) -> void:
	var towards := point - position
	if Vector2(towards.x, towards.z).length() > 0.001:
		rotation.y = atan2(towards.x, towards.z)


## Stood exactly here, going nowhere, facing across the net. Where a skipped cutscene
## leaves everybody.
func place(point: Vector3) -> void:
	_walking = false
	_one_shot = false
	chasing = false
	position = Vector3(point.x, 0.0, point.z)
	_destination = position
	rotation.y = across_the_net()


## A one-shot clip played on the spot: the handshake.
func gesture(clip: String) -> void:
	_play(clip, true)


## Hands on the knees. The losers at the end of a match.
func slump() -> void:
	_play("tired", true)


## Go after the shuttle, to the spot they believe it will land.
## `with_clip` is the stroke they are going there to play, when the sport already knows —
## which it usually does, because it decided who was playing the next ball at the same
## moment it decided where to put it.
func chase(point: Vector3, with_clip := "") -> void:
	_walking = false
	chasing = true
	_planted_left = 0.0
	_destination = hitting_stance(point, with_clip)


## Decide the shuttle is going out and stand and watch it. This is a gamble on the
## umpire, and the player has no idea who the umpire wants to win.
func stand_off() -> void:
	chasing = false
	_stroke_under_way = false
	_stroke_clip = ""


## Throws the player at a spot for a moment, overriding wherever they were going.
## Used to send them reaching over the net, which is what obstruction looks like.
##
## There is a `lunge` clip on the character and this never played it, so a player
## reaching over the net travelled there in their run cycle, upright, at a jog. The
## whole point of the movement is that it looks like somebody going where they should
## not, and a jog does not.
func lunge(spot: Vector3, seconds := 0.7) -> void:
	_lunge_spot = Vector3(spot.x, 0.0, spot.z)
	_lunge_left = seconds
	_play("lunge", true)


func go_home() -> void:
	_walking = false
	chasing = false
	_destination = home


## Whether they have reached wherever they were last sent.
##
## Anything that walks a player through a sequence of places needs this, because the legs
## are rarely the same length and a share-of-the-time-each split leaves the long one
## unfinished. Table tennis walks them round the table at a change of ends and found out.
func has_arrived(within := 0.15) -> bool:
	var here := Vector2(position.x, position.z)
	var there := Vector2(_destination.x, _destination.z)
	return here.distance_to(there) <= within


# --- meeting the ball -------------------------------------------------------------
#
# Two separate faults used to make every contact in this game look wrong, and they are
# worth stating apart because they have different fixes.
#
# The first is *when*. A stroke was started on the frame the ball was struck, and the
# shots are keyed with contact a third of the way in — so the ball left at the top of the
# backswing and the racket arrived a quarter of a second after it had gone. `begin_stroke`
# starts the swing early and stretches it so contact lands on the ball.
#
# The second is *where*. The ball was struck from wherever it happened to be when it came
# within reach of the player's **feet**, which for a badminton player is anywhere in a
# cylinder nearly two metres across and two and a half tall. `hitting_point` answers where
# the implement really is — read off the rig, because the racket hangs on the hand bone
# and the animation carries it — and `struck_from` brings the ball to it.

## How long into each shot the implement meets the ball, in seconds.
##
## Read off the keys in tools/meshy/*_clips.py, where the contact pose is the one the
## comment beside it calls contact. The two serves already had a constant each, because
## the ball is thrown up to meet them and the toss is timed off the same number; this is
## the same idea applied to every other stroke in the game.
const CONTACT_AT := {
	"smash": 6.0 / 24.0,
	"forehand": 6.0 / 24.0,
	"backhand": 6.0 / 24.0,
	"serve": 8.0 / 24.0,
	# Frame 22, not the middle key at 16: `tn_serve` tosses on 8 and strikes on 22, which
	# is what TennisMatch.TOSS_SECONDS is the gap between. Reading the middle key as the
	# contact put the measurement mid-swing, with the racket down by the hip, and the ball
	# was then tossed to meet it there.
	"tn_serve": 22.0 / 24.0,
	"vb_dig": 9.0 / 24.0,
	"vb_set": 10.0 / 24.0,
	"vb_spike": 9.0 / 24.0,
	"vb_block": 12.0 / 24.0,
	"vb_serve": VB_SERVE_CONTACT,
	"st_serve": ST_SERVE_CONTACT,
	"st_spike": ST_SPIKE_CONTACT,
	"st_receive": 9.0 / 24.0,
	"st_header": 11.0 / 24.0,
	"st_set": 10.0 / 24.0,
	"st_block": 14.0 / 24.0,
	"st_throw": 13.0 / 24.0,
}

## How far a stroke may be slowed down or sped up to land on the ball before it stops
## looking like the same movement. The same bracket the wind-up uses, and for the same
## reason: past it, a shot is a twitch or a mime.
const SWING_SLOWEST := 0.55
const SWING_FASTEST := 1.8

## How far the contact may drag the ball onto the implement, in metres.
##
## A cap rather than a snap. Standing off the ball by the implement's own reach and turning
## into the shot bring the two together in plan; what is left is mostly height, because a
## forehand meets the ball at the height a forehand meets it at, whatever the ball is doing.
## This closes that, and on a stroke that went wrong it closes what it can and leaves the
## rest — which is never worse than striking from wherever the ball happened to be.
const CONTACT_PULL := 0.7

## Where the feet go when the stroke that is coming has not been named, as a share of their
## reach: behind the ball and a little to the side the racket is on. `hitting_stance` uses
## the measured offset instead whenever it knows which stroke is being run to.
const STANCE_BEHIND := 0.62
const STANCE_ASIDE := 0.28

## Set when a stroke has been started early, so that the `swing` at the moment of contact
## lets the one already running finish instead of playing it again from the backswing.
var _stroke_under_way := false

## Which stroke is running, and which way the body was turned to play it. A stroke holds
## its own facing: a player turns into the shot and stays turned through it, rather than
## going on being steered by wherever their feet are still carrying them.
var _stroke_clip := ""
var _stroke_facing := 0.0

## Where the implement is at each stroke's own moment of contact, as an offset from the
## player's origin in the player's own frame.
##
## Measured on this character rather than written down: the clip is run to its contact
## frame and the racket head, the hand or the foot is read off the rig where it has ended
## up. It is the same measurement `VB_SERVE_REACH` and `VB_SERVE_WIDE` are, which were done
## by hand in `dev/looks/_serveshot` and then typed in — except that these are twenty
## numbers across seventeen clips, and a typed copy of twenty measurements is a copy that
## will be wrong the next time a clip is touched.
var _contact_offset := {}


## Runs every stroke to its moment of contact and writes down where the implement was.
##
## Once, when the body is built. A frame is waited on between clips because a bone
## attachment does not follow the skeleton until the skeleton has posed itself, so reading
## the racket in the same frame the pose was set reads the previous pose.
func _measure_the_contacts() -> void:
	if _animator == null or _figure == null:
		return
	# A frame per clip, and there is no way round it. Forcing the skeleton to update does
	# **not** carry through to the bone attachments the racket and the hands hang on: it was
	# tried on 2026-09-17 and every clip came back with the same stale offset — one pose,
	# seventeen times, which is worse than not measuring at all because it looks measured.
	# `dev/checks/_offsets` exists to catch exactly that.
	#
	# So the cost is paid instead: the figure is hidden, and anything that asks for a clip
	# while this is running is remembered and played the moment it finishes, because the
	# players are rebuilt at the start of every match and a serve landing inside this window
	# used to be played with no animation at all.
	_measuring = true
	_asked_for_while_measuring = ""
	var seen := _figure.visible
	_figure.visible = false
	for clip in CONTACT_AT:
		if not _animator.has_animation(clip):
			continue
		_animator.play(clip)
		_animator.seek(float(CONTACT_AT[clip]), true, true)
		await get_tree().process_frame
		if not is_instance_valid(self) or _animator == null or _figure == null:
			return
		_contact_offset[clip] = (hitting_point(clip) - global_position).rotated(
			Vector3.UP, -rotation.y)
	_animator.stop()
	_measuring = false
	_clip = ""
	_one_shot = false
	_holding_the_crouch = 0.0
	_figure.visible = seen
	if _asked_for_while_measuring.is_empty():
		_play("idle")
	else:
		# Whatever was wanted while this was running gets played now rather than lost.
		_play(_asked_for_while_measuring, true)
		_asked_for_while_measuring = ""


## Whether the character is being measured, and the last clip anything asked for while it
## was. See `_measure_the_contacts`.
var _measuring := false
var _asked_for_while_measuring := ""


## How high the implement is at this clip's moment of contact, or below zero when the clip
## was never measured — which is what a figure with no rig answers.
func contact_height(clip: String) -> float:
	return Vector3(_contact_offset[clip]).y if _contact_offset.has(clip) else -1.0


## Where the implement will be when `clip` reaches its moment of contact, standing where
## they are standing and facing `facing`. Falls back to wherever it is now on a clip that
## was never measured, which is what a figure with no rig at all answers with.
func contact_point(clip: String, facing: float) -> Vector3:
	if not _contact_offset.has(clip):
		return hitting_point()
	return global_position + Vector3(_contact_offset[clip]).rotated(Vector3.UP, facing)

## Whether this sport is played with the feet, which decides what `hitting_point` answers
## with. Sepak takraw is the only one, and its players carry nothing — so `volleyball`,
## which means "carries nothing", cannot tell the two apart on its own.
var plays_with_the_feet := false


## Where the thing they hit the ball with is at this instant, in world space.
##
## The head of the racket or the bat, measured when it was put in the hand and carried by
## the hand bone ever since; the hitting hand in the sports played without one; the kicking
## foot in sepak takraw. Falls back to a point at arm's length in front of the chest on a
## figure with no rig at all, which is the boxes in figure.gd.
## `for_clip` names the stroke being asked about, which decides which part of the body
## answers. It defaults to whatever is playing now; `_measure_the_contacts` has to say,
## because it poses the rig directly rather than through `_play` and so never sets `_clip`.
func hitting_point(for_clip := "") -> Vector3:
	var clip := _clip if for_clip.is_empty() else for_clip
	if _racket != null and is_instance_valid(_racket):
		if _racket.has_meta("head"):
			return _racket.global_transform * Vector3(_racket.get_meta("head"))
		return _racket.global_position
	# Three of volleyball's touches are made with both hands at once and the ball meets them
	# in the middle: the forearm platform of a dig, the two hands of a set, the two arms of a
	# block. Answering with the right hand alone puts the contact a forearm's width off every
	# one of them, which is most of what indoor volleyball's remaining error was.
	if TWO_HANDED.has(clip):
		var right := _socket(&"hand")
		var left := _socket(&"other_hand")
		if right != null and left != null:
			return (right.global_position + left.global_position) * 0.5

	# Sepak takraw's header is the one contact in any of these sports made with a forehead,
	# and answering with the kicking foot for it puts the contact on the floor.
	var part := &"hand"
	if clip == "st_header":
		part = &"head"
	elif plays_with_the_feet:
		part = &"foot"
	var socket := _socket(part)
	if socket != null:
		return socket.global_position
	var facing := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	return global_position + Vector3(0.0, BARE_SHOULDER, 0.0) + facing * BARE_REACH


## The touches made with both hands, which are met in the middle of the two.
const TWO_HANDED := ["vb_dig", "vb_set", "vb_block"]


## Where a figure with no skeleton hits from: shoulder height, at arm's length in front.
const BARE_SHOULDER := 1.42
const BARE_REACH := 0.55


## A socket the rig was fitted with when it was dressed. See Models.dress_player.
func _socket(which: StringName) -> Node3D:
	if _figure == null or not _figure.has_meta(which):
		return null
	var node = _figure.get_meta(which)
	return node as Node3D if node is Node3D and is_instance_valid(node) else null


## Where the ball is actually struck from: on the implement when it is anywhere near, and
## drawn towards it by no more than `CONTACT_PULL` when the stroke has been mistimed.
##
## Never dragged far *down*, whatever the implement is doing. A shot struck a metre lower
## than the ball really was has a metre less of net to play with, and badminton found out:
## letting the contact fall all the way to a groundstroke's own height cost the better part
## of a stroke a rally in shots that could no longer be got over the tape.
func struck_from(ball_spot: Vector3) -> Vector3:
	var point := ball_spot.move_toward(hitting_point(), CONTACT_PULL)
	point.y = maxf(point.y, ball_spot.y - MOST_OF_A_DROP)
	return point


## How far below the ball the contact may be brought, in metres.
const MOST_OF_A_DROP := 0.3


## Where the feet belong so that a ball arriving at `ball_spot` arrives on the implement.
##
## Running the feet to the landing spot itself — which is what `chase` used to be handed —
## puts the ball on the top of the player's head, and no shot in any of these sports is
## played from there. They stand off it by however far the implement reaches, which is a
## measured number when the stroke that is coming is known: a dig reaches half a metre in
## front of the knees and a smash reaches most of a metre out and up, and standing the same
## distance off the ball for both is wrong for both.
##
## Without a named stroke it falls back to a share of their reach, which is what every chase
## in the game did before any of this was measured — and which is what the three racket
## sports still use. Their implements reach further than `reach` allows them to strike from,
## so standing at the racket's own length costs more rallies than it buys contacts: badminton
## went from five and a half strokes a rally to two and a half. The volleyballs and sepak
## takraw are the other way round, reaching well inside their own, and there it is the
## measurement that puts the hands on the ball.
func hitting_stance(ball_spot: Vector3, clip := "") -> Vector3:
	var flat := Vector3(ball_spot.x, 0.0, ball_spot.z)
	if _walking:
		return flat
	var away := _away_from_the_net()
	var forward := -away
	var aside := forward.cross(Vector3.UP)
	if _contact_offset.has(clip):
		# The rig's own axes: the model's +X is the player's left, its +Z is in front.
		var offset: Vector3 = _contact_offset[clip]
		var out := Vector2(offset.x, offset.z)
		# Never further off the ball than they are allowed to strike from. A badminton
		# backhand puts the racket head a metre and a third out — further than `reach`,
		# which is what decides whether a shuttle counts as reached at all — so standing
		# at the racket's full length is standing outside their own strike zone, and
		# every rally died on the first shot when this was first tried without the cap.
		if out.length() > reach * MOST_OF_A_REACH:
			out = out.normalized() * (reach * MOST_OF_A_REACH)
		return flat + aside * out.x - forward * out.y
	return flat + away * (reach * STANCE_BEHIND) + aside * (reach * STANCE_ASIDE)


## How much of their reach they may stand off the ball by. Short of all of it, so that a
## ball arriving a little differently from the way it was read is still inside it.
const MOST_OF_A_REACH := 0.85


## Whether `clip` was already started early, and so should be left to finish rather than
## played again from its first frame — which would put the hands back behind the ball on
## the very frame they are supposed to be on it.
##
## The clip is named because what is wanted is not always known in advance: sepak takraw
## decides between a sila and a header on how high the ball still is when it arrives, so a
## receive can be started early and a header played instead. Then the early one is
## abandoned and the right clip plays, late, exactly as it used to.
func _took_it_early(clip: String) -> bool:
	if not _stroke_under_way:
		return false
	_stroke_under_way = false
	_stroke_clip = ""
	return _clip == clip


## Starts the stroke now so the implement is on the ball at `meeting` in `in_seconds`.
##
## Answers whether it started one, so a match can stop asking. The `swing` that follows at
## the moment of contact finds the stroke already running and leaves it alone.
func begin_stroke(in_seconds: float, meeting: Vector3, overhead := false) -> bool:
	if _stroke_under_way:
		return false
	var clip := _stroke_for(meeting, in_seconds, overhead)
	_stroke_under_way = true
	_stroke_clip = clip
	_turn_into_the_shot(clip, meeting, in_seconds)
	_swing(clip, in_seconds)
	return true


## Starts a named touch now so that its own moment of contact lands on the ball at
## `meeting` in `in_seconds`.
func begin_touch(clip: String, in_seconds: float, meeting: Vector3) -> bool:
	if _stroke_under_way or _animator == null or not _animator.has_animation(clip):
		return false
	_stroke_under_way = true
	_stroke_clip = clip
	_turn_into_the_shot(clip, meeting, in_seconds)
	_play(clip, true, _pace_to_contact(clip, in_seconds))
	return true


## Which stroke reaches this ball: the one whose own contact point best fits where the ball
## will be, seen from where the player will be standing by then.
##
## A smash when the ball is up overhead and the rally asked for one; otherwise the
## groundstroke that fits. A backhand on this character is played at nearly full stretch and
## a forehand closer in, so a ball that arrives wide is a backhand and one that arrives on
## top of somebody is a forehand — which is what a player does, and which is what puts the
## racket where the shuttle is instead of a metre from it. It used to be a coin weighted
## 65:35, with no reference to where the shuttle was at all.
func _stroke_for(meeting: Vector3, in_seconds: float, overhead: bool) -> String:
	if overhead or _contact_offset.is_empty():
		return "smash" if overhead else ("forehand" if randf() < 0.65 else "backhand")
	var standing := position_in(in_seconds)
	var want := Vector2(meeting.x - standing.x, meeting.z - standing.z).length()
	var best := "forehand"
	var closest := INF
	for clip in ["forehand", "backhand"]:
		if not _contact_offset.has(clip):
			continue
		var offset: Vector3 = _contact_offset[clip]
		var miss := absf(Vector2(offset.x, offset.z).length() - want) \
			+ absf(offset.y - meeting.y)
		if miss < closest:
			closest = miss
			best = clip
	return best


## Turns the body so that this stroke's implement points at the ball.
##
## This is the half of the fix the timing alone could not do. A forehand puts the racket
## head a fixed distance out on the player's racket side at a fixed height, wherever the
## ball happens to be — so a contact only looks like one if the player has turned that side
## of themselves towards the ball. They were not turning at all: they ran to the spot the
## shuttle was going to land on, stood on it, and swung at a point a metre from their
## racket.
##
## The turn is capped at `MOST_OF_A_TURN` for the same reason the footwork is: a shot
## reached by turning your back on the net is not a shot anybody plays.
func _turn_into_the_shot(clip: String, meeting: Vector3, in_seconds: float) -> void:
	if not _contact_offset.has(clip):
		return
	var offset: Vector3 = _contact_offset[clip]
	var out := Vector2(offset.x, offset.z)
	var standing := position_in(in_seconds)
	var towards := Vector2(meeting.x - standing.x, meeting.z - standing.z)
	if out.length() < 0.01 or towards.length() < 0.01:
		return
	var want := atan2(towards.x, towards.y) - atan2(out.x, out.y)
	var off := wrapf(want - across_the_net(), -PI, PI)
	_stroke_facing = across_the_net() + clampf(off, -MOST_OF_A_TURN, MOST_OF_A_TURN)


## How far the body may be turned to play a shot. Under a quarter turn past square, which
## is where the ball would start being behind them.
const MOST_OF_A_TURN := deg_to_rad(85.0)


## How fast to play a clip so its contact lands in `in_seconds`. One when nothing is being
## timed, and clamped, for the same reason the wind-up is.
func _pace_to_contact(clip: String, in_seconds: float) -> float:
	if in_seconds <= 0.0 or not CONTACT_AT.has(clip):
		return 1.0
	return clampf(float(CONTACT_AT[clip]) / in_seconds, SWING_SLOWEST, SWING_FASTEST)


## Whether the shuttle is close enough, and at a sensible height, to be hit.
func can_strike(shuttle_position: Vector3) -> bool:
	if not chasing:
		return false
	if shuttle_position.y > HIGHEST_STRIKE or shuttle_position.y < LOWEST_STRIKE:
		return false
	var gap := Vector2(shuttle_position.x - position.x, shuttle_position.z - position.z)
	return gap.length() <= reach


## Which way their own baseline is. The half they are standing on, for the reason
## `across_the_net` gives.
func _away_from_the_net() -> Vector3:
	return Vector3(0.0, 0.0, -1.0 if across_the_net() < PI * 0.5 else 1.0)


## How far they still have to run to reach a point.
func distance_to(point: Vector3) -> float:
	return Vector2(point.x - position.x, point.z - position.z).length()


## Set before the body is built, and only for volleyball's libero. It picks a different
## character file rather than recolouring this one, because a material put onto a built
## figure does not draw — the whole reason `tools/meshy/bake_kit.py` exists.
var is_libero := false

## Set alongside `is_libero`, from the settings, before the body is built. Like the
## libero's kit it chooses a character file rather than recolouring one.
var clear_kit := false


func _build_body() -> void:
	# A real athlete if the downloaded assets are there, and the boxes in figure.gd
	# if they are not. The fallback is not decoration: a game that will not start
	# because a model is missing is worse than a game with a box in it.
	var model := Models.player(team, is_libero, clear_kit)
	if model != null:
		add_child(model)
		_figure = model
		# On the people layer, so the camera on the line can leave them out.
		#
		# Only the boxes in figure.gd were ever put there. The downloaded characters
		# never were, so the overhead camera — whose entire job is to show the landing
		# against the line — would photograph whoever happened to be standing over it.
		# Rare in badminton, where the view is a metre across; constant in volleyball,
		# where six people share a court and the ball lands at somebody's feet.
		Models.set_layer(model, PEOPLE_LAYER)
		if Models.is_forged(model):
			# Already the right size and the right way up. Dress it and go.
			Models.dress_player(model, _carries())
			_take_up_racket(model)
			_set_up_clips(model)
			_measure_the_contacts()
		else:
			_settle_when_posed(model)
	else:
		Figure.standing(self, Sides.colour(team), true)

	# Facing across the net, towards whoever they are playing.
	rotation.y = across_the_net()
