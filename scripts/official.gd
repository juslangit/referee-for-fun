class_name Official
extends Node3D

## An official on their feet: the umpire walking on before the match, sat in the high
## chair after it, and the tournament referee coming to take them off.
##
## Only the cutscenes use one. During play the umpire is the camera and has no body, and
## the line judges are LineJudge, which never stands up. Same character as the line
## judges, so everybody in the building wearing the uniform is the same person.

## A walk, not a march. The players walking on behind the umpire are held to the same
## pace, or the file of them comes apart before it reaches the court.
const WALK_SPEED := 1.35

var speed := WALK_SPEED

var _destination := Vector3.ZERO
var _figure: Node3D
var _animator: AnimationPlayer
var _seated := false
var _gesturing := false


func _ready() -> void:
	_destination = position
	_figure = Models.official()
	if _figure == null:
		Figure.standing(self, Color(0.93, 0.85, 0.30), false)
		return
	add_child(_figure)
	if not Models.is_forged(_figure):
		await get_tree().process_frame
		if is_instance_valid(_figure):
			Models.settle(_figure)
	_animator = Models.animator(_figure)
	if _animator == null:
		return
	for clip in ["walk", "stand", "sit"]:
		if _animator.has_animation(clip):
			Models.make_looping(_animator, clip)
	_animator.animation_finished.connect(func(_clip: StringName) -> void: _gesturing = false)
	_animator.play("sit" if _seated else "stand")


## Puts the whole figure on one visual layer. The umpire's own body goes on the chair's
## layer, which the chair camera already leaves out.
func set_layer(layer: int) -> void:
	if _figure != null:
		Models.set_layer(_figure, layer)


func walk_to(point: Vector3) -> void:
	_seated = false
	_destination = Vector3(point.x, position.y, point.z)


func has_arrived(within := 0.08) -> bool:
	return Vector2(position.x, position.z).distance_to(
		Vector2(_destination.x, _destination.z)) <= within


## Stood exactly here, going nowhere — on their feet, until told to `sit()`.
func place(point: Vector3) -> void:
	_seated = false
	position = point
	_destination = point


func face(point: Vector3) -> void:
	var towards := point - position
	if Vector2(towards.x, towards.z).length() > 0.001:
		rotation.y = atan2(towards.x, towards.z)


## Turned so the right arm, held straight out, points along `direction`.
##
## The character looks down its own +Z with its left hand towards +X, so its right hand
## is along -X: turned by `a`, that is (-cos a, 0, sin a), and solving for the direction
## wanted gives the angle.
func right_arm_towards(direction: Vector3) -> void:
	rotation.y = atan2(direction.z, -direction.x)


func sit() -> void:
	_seated = true
	_destination = position
	_loop("sit")


## A one-shot clip. The figure goes back to standing, or sitting, when it ends.
func gesture(clip: String) -> void:
	if _animator == null or not _animator.has_animation(clip):
		return
	_gesturing = true
	_animator.play(clip, 0.12)
	_animator.seek(0.0, true)


## Where a bone of the figure is in the world — the right hand, for the coin.
func bone_position(bone: String) -> Vector3:
	var skeleton := Models.skeleton_of(_figure) if _figure != null else null
	if skeleton == null:
		return global_position + Vector3.UP * 1.1
	var index := skeleton.find_bone(bone)
	if index < 0:
		return global_position + Vector3.UP * 1.1
	return skeleton.global_transform * skeleton.get_bone_global_pose(index).origin


func _loop(clip: String) -> void:
	if _animator == null or _gesturing or not _animator.has_animation(clip):
		return
	if _animator.current_animation != clip:
		_animator.play(clip, 0.2)


func _physics_process(delta: float) -> void:
	var here := Vector2(position.x, position.z)
	var there := Vector2(_destination.x, _destination.z)
	var moved := here.move_toward(there, speed * delta)
	var walking := here.distance_to(moved) > 0.0001
	if walking:
		position = Vector3(moved.x, position.y, moved.y)
		var heading := moved - here
		rotation.y = atan2(heading.x, heading.y)
	if _seated:
		_loop("sit")
	else:
		_loop("walk" if walking else "stand")
