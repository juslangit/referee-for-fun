extends Node

## Does a character actually know where its own racket, hands and feet are?
##
## `Player._measure_the_contacts` poses every stroke at its own contact frame and reads the
## racket head, the hitting hand, the forearm platform or the kicking foot off the rig. That
## measurement is what turns a player into a shot, decides which stroke can reach a ball, and
## puts the contact on the implement — so if it is wrong, every contact in the game is wrong
## and nothing else says so.
##
## It failed silently once, on 2026-09-17, and the shape of the failure is why this exists.
## The measurement was sped up by forcing the skeleton to update rather than waiting a frame
## per clip; forcing the update does not carry through to the bone attachments, so every clip
## came back holding **the same** offset. Seventeen strokes that all thought the racket was in
## one place. Three sports got quietly worse and the only visible symptom was a number in
## `_contact` drifting.
##
## So this checks the two things that failure could not have survived: that the strokes
## disagree with each other, and that each one is somewhere a body could put it.
##
##     godot --headless --path . res://dev/checks/_offsets.tscn --quit-after 4000
##
## Ends in PASS or FAIL.

## Two strokes whose contact points are within this of each other, in metres, are not two
## measurements. They are one measurement written down twice.
const APART_AT_LEAST := 0.02

## Where a contact can sensibly be, measured from the player's own feet: nothing further out
## than a fully stretched arm and a racket, nothing higher than a jumping spike's foot.
const FURTHEST_OUT := 1.6
const HIGHEST := 3.1

## Strokes played above the head, and strokes played low. A rig that has them the wrong way
## round, or has them all at one height, is not measuring anything.
const OVERHEAD := {"smash": 2.0, "vb_spike": 2.2, "vb_block": 2.2, "tn_serve": 2.0,
	"st_spike": 2.0}
const LOW := {"vb_dig": 1.2, "st_receive": 1.2, "serve": 1.2}

var _problems: Array[String] = []


func _ready() -> void:
	var player := Player.new()
	player.racket_kind = &"badminton"
	add_child(player)
	player.setup(Sides.Team.RED, Vector3.ZERO)
	# The measurement is a frame a clip and must be allowed to finish: a harness that reads
	# it early gets whatever had been filled in so far, which is how this check first came
	# out failing against perfectly good numbers.
	for frame in 400:
		await get_tree().process_frame
		if not player._measuring and not player._contact_offset.is_empty():
			break

	var measured: Dictionary = player._contact_offset
	if measured.size() < 5:
		print("only %d clips measured" % measured.size())
		_problems.append("only %d clips measured, too few to judge" % measured.size())
		_verdict()
		return

	for clip in measured:
		var at: Vector3 = measured[clip]
		var out := Vector2(at.x, at.z).length()
		print("  %-14s %v   %.2f m out, %.2f m up" % [clip, at, out, at.y])
		if out > FURTHEST_OUT:
			_problems.append("%s reaches %.2f m out, further than an arm and a racket"
				% [clip, out])
		if at.y > HIGHEST or at.y < 0.0:
			_problems.append("%s makes contact at %.2f m, which is not on a body"
				% [clip, at.y])
		if OVERHEAD.has(clip) and at.y < float(OVERHEAD[clip]):
			_problems.append("%s is played overhead and was measured at %.2f m"
				% [clip, at.y])
		if LOW.has(clip) and at.y > float(LOW[clip]):
			_problems.append("%s is played low and was measured at %.2f m" % [clip, at.y])

	# And the one the silent failure could not have survived: they must differ.
	var names: Array = measured.keys()
	var same := 0
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Vector3 = measured[names[i]]
			var b: Vector3 = measured[names[j]]
			if a.distance_to(b) < APART_AT_LEAST:
				same += 1
				if same <= 3:
					print("  %s and %s were measured in the same place" % [names[i], names[j]])
	print("%d clips measured, %d pairs share a contact point" % [measured.size(), same])
	if same > 0:
		_problems.append(
			"%d pairs of strokes were measured in the same place — the rig is not being posed"
			% same)
	_verdict()


func _verdict() -> void:
	print("PASS" if _problems.is_empty() else "FAIL:\n   " + "\n   ".join(_problems))
	get_tree().quit()
