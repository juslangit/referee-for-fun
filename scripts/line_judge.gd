class_name LineJudge
extends Node3D

## The official in the corner whose only job is to watch the line and say what they
## saw. In a real match there are up to ten of them; here there is one, and their
## call appears in a bubble over their head a moment after the shuttle lands.
##
## They are usually right, and they are least reliable exactly when it matters most.
## That is the whole point of them. A line judge who was always correct would simply
## tell the player the answer on every rally and there would be nothing left to
## decide. One who is human gives the umpire two things instead:
##
##   Cover. Wait for a line judge to get one wrong, agree with them, and the mistake
##   is shared with an official standing in plain sight.
##
##   Exposure. Contradict them and the hall has just watched two officials disagree
##   in public, with only one call deciding the rally — yours.

## How close to the line a shuttle has to land before they start getting it wrong.
const DOUBT_RANGE := 0.25

## How often they are wrong on a shuttle landing exactly on the line. Near enough a
## coin toss, because from the corner of a court that genuinely is one.
const WORST_ERROR := 0.45

## How long the bubble stays up.
const BUBBLE_SECONDS := 2.4

## The OUT signal: both arms straight out to the sides, held, and then dropped.
##
## It is the real badminton signal, and it is a signal rather than a shout for a reason —
## it reads from the far end of a hall, which is where the umpire is. Posed in code
## rather than keyed in Blender because the officials are a downloaded model on a
## different rig from the athletes, so the clip pipeline that authored every other
## animation in this game does not reach them.
const SIGNAL_SECONDS := 2.1
const SIGNAL_RAISE := 0.22

## How far the upper arms swing out from where the idle clip left them, in degrees, and
## about which axis. Tuned by rendering it: see dev/looks/_judgesignal.
const SIGNAL_SWING := 78.0

## Which way the arms swing.
##
## A downloaded rig says nothing about how its bones rest, so this was found by rendering
## all six candidate axes side by side rather than guessed — see dev/looks/_judgesignal,
## which still does it and is the only honest way to answer the question. +Y puts both
## arms out to the sides and slightly up, which is the badminton signal. Every other axis
## folded them across his chest or waved one of them behind him.
var signal_axis := Vector3.UP

const BODY_HEIGHT := 1.34
const BODY_RADIUS := 0.24

## Whether they sit down. Badminton line judges sit on a folding chair for the whole
## match; volleyball line judges stand, at the corners, holding a flag. The difference
## is not decoration — a seated official at the corner of a volleyball court would be
## looking at the sand from below the height of the tape.
var seated := true

## Which half of the court this judge is responsible for. In a real match a line
## judge has their own lines and says nothing about anybody else's, which is why the
## two of them never end up contradicting each other in public.
var watches := Sides.Team.NONE

var _bubble: Node3D
var _label: Label3D
var _timer := 0.0

## The arms, for the OUT signal. The idle clip writes every bone every frame, so it has
## to be paused while the arms are held out or the pose is overwritten before it is seen.
var _skeleton: Skeleton3D
var _arms := {"right": -1, "left": -1}
var _animator: AnimationPlayer
var _signalling := 0.0


func _ready() -> void:
	_build_body()
	_build_bubble()


func _process(delta: float) -> void:
	_hold_the_signal(delta)
	if _timer <= 0.0:
		return
	_timer -= delta
	if _timer <= 0.0:
		_bubble.visible = false


## Both arms out to the sides for as long as the call lasts, then back to the idle.
func _hold_the_signal(delta: float) -> void:
	if _signalling <= 0.0:
		return
	_signalling -= delta
	if _signalling <= 0.0:
		_drop_the_arms()
		return
	# Eased in and out, so the arms go up and come down rather than snapping.
	var through := 1.0 - clampf(_signalling / SIGNAL_SECONDS, 0.0, 1.0)
	var swing := sin(clampf(through / SIGNAL_RAISE, 0.0, 1.0) * PI * 0.5)
	if _signalling < SIGNAL_SECONDS * SIGNAL_RAISE:
		swing = _signalling / (SIGNAL_SECONDS * SIGNAL_RAISE)
	_pose_arms(swing)


func _pose_arms(amount: float) -> void:
	if _skeleton == null:
		return
	for side in ["right", "left"]:
		var bone: int = _arms[side]
		if bone < 0:
			continue
		var rest := _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		var away := deg_to_rad(SIGNAL_SWING) * amount * (1.0 if side == "right" else -1.0)
		_skeleton.set_bone_pose_rotation(bone, rest * Quaternion(signal_axis, away))


func _drop_the_arms() -> void:
	_signalling = 0.0
	_pose_arms(0.0)
	if _animator != null and not _animator.current_animation.is_empty():
		# Back to whatever they were doing, which is standing there.
		_animator.play(_animator.current_animation)


## A line judge on their feet, which is what both volleyballs use.
func _build_standing() -> void:
	var standing := Node3D.new()
	standing.name = "Judge"
	standing.rotation.y = atan2(-position.x, -position.z)
	add_child(standing)

	var model := Models.official()
	if model == null:
		Figure.standing(standing, Color(0.93, 0.85, 0.30), false)
		return

	standing.add_child(model)
	var animator := Models.animator(model)
	var clip := Models.clip_named(animator, ["idle", "stand", "ready"])
	if animator != null and not clip.is_empty():
		Models.make_looping(animator, clip)
		animator.play(clip)
	if not Models.is_forged(model):
		_settle_when_posed(model)


## What they saw. Correct most of the time, and less and less reliable the closer the
## ball landed to the line.
##
## Written in terms of the two numbers rather than a rally, because three sports have
## three different rally classes and a line judge's job is the same in all of them:
## look at a line, and be least certain exactly when it matters most.
func decide(margin: float, was_in: bool) -> bool:
	var certainty := clampf(absf(margin) / DOUBT_RANGE, 0.0, 1.0)
	var chance_of_error := WORST_ERROR * (1.0 - certainty)
	if randf() < chance_of_error:
		return not was_in
	return was_in


func judge(rally: Rally) -> bool:
	return decide(rally.margin, rally.was_in)


## Puts their call in the air above their head, and — for an OUT — makes the signal
## with their arms.
##
## Only OUT is signalled with the body. A judge who thought the ball was good keeps their
## hands where they are, which is the real thing and which keeps the gesture meaning
## something: a pair of arms coming out is always the same news.
func announce(says_in: bool) -> void:
	_label.text = "IN" if says_in else "OUT"
	_label.modulate = Color(0.12, 0.30, 0.16) if says_in else Color(0.55, 0.10, 0.10)
	_bubble.visible = true
	_timer = BUBBLE_SECONDS
	if not says_in:
		signal_out()


## Both arms straight out to the sides. The idle clip is stopped for the duration —
## an AnimationPlayer writes every bone it owns every frame, so a pose set underneath
## one is overwritten before anybody sees it.
func signal_out() -> void:
	if _skeleton == null:
		_skeleton = Models.skeleton_of(self)
		_arms = Models.arms_of(_skeleton)
		_animator = Models.animator(self)
	if _skeleton == null or (_arms["right"] < 0 and _arms["left"] < 0):
		return
	if _animator != null:
		_animator.pause()
	_signalling = SIGNAL_SECONDS


func silence() -> void:
	_bubble.visible = false
	_timer = 0.0
	if _signalling > 0.0:
		_drop_the_arms()


func _build_body() -> void:
	if not seated:
		_build_standing()
		return

	# Seated, so shorter than the players, and in a kit that is nobody's team colour.
	# A real folding chair, which is what a line judge actually sits on. Under them
	# rather than beside them: it used to stand half a metre to one side, which was
	# invisible while they were a box and absurd the moment they were a man with a
	# seated pose, sitting in mid air next to his own chair.
	var real := Props.node(Props.FOLDING_CHAIR, 0.88)
	if real != null:
		real.rotation.y = atan2(-position.x, -position.z)
		_set_layer(real, Player.PEOPLE_LAYER)
		add_child(real)
	else:
		var chair := MeshInstance3D.new()
		chair.name = "Chair"
		var seat := BoxMesh.new()
		seat.size = Vector3(0.5, 0.42, 0.5)
		chair.mesh = seat
		chair.position = Vector3(0.0, 0.21, 0.0)
		chair.material_override = _material(Color(0.32, 0.30, 0.28))
		chair.layers = Player.PEOPLE_LAYER
		add_child(chair)

	var sitter := Node3D.new()
	sitter.name = "Judge"
	# Turned to face the middle of the court, which is a different angle for each of the
	# four corners a judge can be sat in. Choosing between a half turn and none was fine
	# while they sat square behind a baseline, and put both of them looking at a wall
	# once they were moved to diagonally opposite corners.
	sitter.rotation.y = atan2(-position.x, -position.z)
	add_child(sitter)

	# The official carries a seated clip, so the line judges sit down — which is what
	# they do for the whole of a real match. Every model before this one was a standing
	# figure that could not be posed, so they had to stand beside their chair instead.
	var model := Models.official()
	if model == null:
		Figure.seated(sitter, Color(0.93, 0.85, 0.30))
		return

	sitter.add_child(model)
	var animator := Models.animator(model)
	var clip := Models.clip_named(animator, ["sit", "idle", "stand"])
	if animator != null and not clip.is_empty():
		Models.make_looping(animator, clip)
		animator.play(clip)
	if not Models.is_forged(model):
		_settle_when_posed(model)


## Sized a frame later, once the skeleton has posed. See Player for why.
func _settle_when_posed(model: Node3D) -> void:
	await get_tree().process_frame
	if is_instance_valid(model):
		Models.settle(model)


func _build_bubble() -> void:
	_bubble = Node3D.new()
	_bubble.name = "Bubble"
	_bubble.position = Vector3(0.0, 2.05, 0.0)
	_bubble.visible = false
	add_child(_bubble)

	var back := MeshInstance3D.new()
	back.name = "Backing"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.78, 0.44)
	back.mesh = quad
	var paper := _material(Color(0.98, 0.98, 0.95))
	paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paper.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	back.material_override = paper
	back.layers = Player.PEOPLE_LAYER
	_bubble.add_child(back)

	_label = Label3D.new()
	_label.name = "Shout"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 128
	_label.pixel_size = 0.0024
	_label.outline_size = 0
	# Drawn over the backing rather than fighting it for depth.
	_label.no_depth_test = true
	_label.render_priority = 2
	_label.layers = Player.PEOPLE_LAYER
	_bubble.add_child(_label)


## Everything the line judge owns is drawn on the people layer, so the line camera can
## leave it out along with the people.
func _set_layer(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_layer(child, layer)


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	return material
