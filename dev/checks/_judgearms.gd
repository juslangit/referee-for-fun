extends Node

## Can the line judge's arms be found and posed — and do they come back down afterwards?
##
##   godot --headless --path . res://dev/checks/_judgearms.tscn
##
## The first half of that question is the older one. The officials are a downloaded model
## on a different rig from the athletes, so the clip pipeline that authored the badminton
## and volleyball animations does not reach them, and their OUT signal is posed in code
## instead — which only works if the arm bones can be found under one of the names some
## rig somewhere uses for them.
##
## The second half was added on 2026-09-20, because finding the arms turned out not to be
## enough.
##
## Luqman on 2026-09-20: "after they said out, their hand do not return back to normal,
## it stays up awkwardly."
##
## The signal is posed in code rather than keyed in Blender, because the officials are a
## downloaded model on a different rig from the athletes. Posing a bone under a playing
## AnimationPlayer does nothing — the player writes every bone it owns every frame — so
## `signal_out()` pauses the idle for the duration and `_drop_the_arms()` is supposed to
## start it again. If it does not, the skeleton is left frozen on whatever was posed last,
## and a skeleton with nothing driving it sits in its **rest pose**, which on this rig is
## arms out to the sides. That is exactly the awkward hold.
##
## So this measures three moments and asks for one number each:
##
##   idle     — how far the arms sit from rest while the idle clip is running
##   signal   — how far they swing at the peak of the OUT
##   after    — how far they sit once the signal is over
##
## `after` must come back to `idle`, and the pose must still be *moving*, because a frozen
## pose at the right angle is still a frozen pose and the next thing the judge does will
## not happen either.

## Measured against the clock, not against a frame count.
##
## Headless Godot runs as fast as the machine lets it, so `delta` is a fraction of a
## millisecond and a hundred process frames is a blink. The signal counts down in seconds,
## so a check that waits frames is still watching the arms go up when it believes it is
## watching them come down — which is how the first version of this check reported the bug
## as still present after it was fixed.
const SWING_MUST_REACH := 40.0
const BACK_WITHIN := 12.0
## Degrees a second. A seated idle barely stirs, so this only has to tell moving from dead.
const STILL_ALIVE := 0.5


## Both postures, because they are built by different halves of `_build_body` and only one
## of them was looked at. Badminton, tennis and table tennis sit their line judges down;
## both volleyballs stand theirs up at the corners with a flag.
func _ready() -> void:
	var failures := 0
	for seated in [true, false]:
		print("")
		print("=== %s line judge ===" % ("seated" if seated else "standing"))
		failures += await _one(seated)
	print("")
	if failures == 0:
		print("PASS  the arms go out for the call and come back to a moving idle, sitting and standing")
	else:
		print("FAIL  %d of the two postures leaves the arms stuck" % failures)
	get_tree().quit()


func _one(seated: bool) -> int:
	var world := Node3D.new()
	add_child(world)

	var judge := LineJudge.new()
	judge.seated = seated
	judge.position = Vector3(3.0, 0.0, 3.0)
	world.add_child(judge)

	for f in 20:
		await get_tree().physics_frame

	var skeleton: Skeleton3D = Models.skeleton_of(judge)
	if skeleton == null:
		print("  no skeleton on the line judge — the signal will have to stay a bubble")
		world.queue_free()
		return 1

	# Which bones the signal is going to move, named. Kept from the first version of this
	# check: the arm bones are found by guessing at names, because every rig calls them
	# something different, and the guess list is the first thing to look at when a new
	# model arrives and the signal does nothing.
	print("the official's skeleton has %d bones" % skeleton.get_bone_count())
	var arms: Dictionary = Models.arms_of(skeleton)
	for side in ["right", "left"]:
		var at: int = arms[side]
		print("   %-6s arm: %s" % [
			side, skeleton.get_bone_name(at) if at >= 0 else "NOT FOUND"])

	if int(arms["right"]) < 0 and int(arms["left"]) < 0:
		print("")
		print("  neither arm bone found. Names this rig actually uses:")
		for i in skeleton.get_bone_count():
			var bone_name := skeleton.get_bone_name(i)
			if "arm" in bone_name.to_lower() or "shoulder" in bone_name.to_lower():
				print("   %s" % bone_name)
		world.queue_free()
		return 1

	var idle := await _watch(skeleton, arms, 0.6)
	judge.announce(false)
	# Long enough for the arms to be all the way out, short of the drop.
	var during := await _watch(skeleton, arms, 0.9)
	var settling := await _watch(skeleton, arms, LineJudge.SIGNAL_SECONDS)
	var after := await _watch(skeleton, arms, 0.8)

	print("how far the arms sit from the rig's rest pose, in degrees")
	print("                     furthest   degrees a second")
	for row in [["idle", idle], ["signalling", during], ["settling", settling], ["after", after]]:
		print("%-20s %7.1f %17.3f" % [row[0], row[1]["furthest"], row[1]["movement"]])

	var problems: Array[String] = []
	if float(during["furthest"]) < SWING_MUST_REACH:
		problems.append("the arms never went out: %.1f deg, wanted %.0f" % [
			during["furthest"], SWING_MUST_REACH])
	var drift: float = absf(float(after["furthest"]) - float(idle["furthest"]))
	if drift > BACK_WITHIN:
		problems.append("the arms did not come back: %.1f deg from where they idle, allowed %.0f" % [
			drift, BACK_WITHIN])
	if float(after["movement"]) < STILL_ALIVE:
		problems.append("the pose is frozen after the call: it moves %.2f deg a second" % [
			after["movement"]])

	for problem in problems:
		print("  %s" % problem)
	world.queue_free()
	await get_tree().process_frame
	return 1 if not problems.is_empty() else 0


## Watches the arms for a number of frames: how far they get from rest, and how much the
## pose changes from one frame to the next. The second number is what tells a live idle
## from a skeleton nobody is driving.
func _watch(skeleton: Skeleton3D, arms: Dictionary, seconds: float) -> Dictionary:
	var furthest := 0.0
	var movement := 0.0
	var previous := {}
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		for side in ["right", "left"]:
			var bone: int = arms[side]
			if bone < 0:
				continue
			var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
			var now := skeleton.get_bone_pose_rotation(bone)
			furthest = maxf(furthest, rad_to_deg(rest.angle_to(now)) * 2.0)
			if previous.has(side):
				movement += rad_to_deg((previous[side] as Quaternion).angle_to(now)) * 2.0
			previous[side] = now
	return {
		"furthest": furthest,
		"movement": movement / maxf(0.001, seconds),
	}
