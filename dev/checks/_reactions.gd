extends Node

## Does anything on court answer the official back?
##
## Three clips have been on the character since it was forged and only badminton ever
## played two of them, so in three sports out of four nobody reacted to anything. And the
## stands celebrated every point, honest or stolen, with no way at all to object.
##
## The two reactions are driven **directly** rather than by playing a match and watching.
## A reaction lasts a second and a half and a challenge takes four, so sampling around a
## real call means racing a coroutine — the first version of this did, and reported a
## working feature as dead in two sports out of three.

func _ready() -> void:
	for entry in [
		["beach", "res://scenes/beach.tscn", Career.BEACH],
		["indoor", "res://scenes/volleyball.tscn", Career.INDOOR],
		["tennis", "res://scenes/tennis.tscn", Career.TENNIS],
	]:
		await _check(entry[0], entry[1], entry[2])
	get_tree().quit()


func _check(name: String, scene: String, sport: StringName) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = sport
	arena.career.tier = 3
	arena.settings.taught_beach = true
	arena.settings.taught_indoor = true
	arena.settings.taught_tennis = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 4:
		await get_tree().process_frame

	# One rally, so there is a real rally object to hand the reactions.
	arena.start_rally()
	var waited := 0
	while arena._phase != arena.Phase.AWAITING_CALL and waited < 4000:
		await get_tree().physics_frame
		waited += 1
	if arena._phase != arena.Phase.AWAITING_CALL:
		print("%-10s no rally to react to" % name)
		arena.queue_free()
		return

	print("=== %s" % name)
	_a_point_to_red(arena)
	await get_tree().process_frame
	var clips := {}
	for player in arena.players:
		clips[Sides.label(player.team)] = clips.get(Sides.label(player.team), [])
		clips[Sides.label(player.team)].append(player._clip)
	print("   after a wrong call that gave RED the point:")
	for side in clips:
		print("      %-5s %s" % [side, ", ".join(clips[side])])
	print("   anybody on their feet in the stands: %s" % _standing(arena))

	arena.queue_free()
	await get_tree().process_frame


## A call the whole venue can see is wrong, giving the point to RED.
func _a_point_to_red(arena: Node) -> void:
	var rally = arena.rally
	# Every other truth cleared first, so the call is certainly wrong rather than
	# probably. A rolled positional fault decides the point before the landing does, and
	# a forged IN over one of those comes out CORRECT — which it did, and reported the
	# whole feature as dead in indoor on one run and alive on the next.
	for field in ["foot_fault", "handling_fault", "was_touched"]:
		if field in rally:
			rally.set(field, false)
	for field in ["net_toucher", "centre_line_crosser", "rotation_fault_by",
			"wrong_server_by", "libero_fault_by", "back_row_attack_by"]:
		if field in rally:
			rally.set(field, Sides.Team.NONE)
	# Tennis has neither of these, and `in` on a RefCounted answers true for a method as
	# well as a field, so they are guarded by what the sport actually carries.
	for field in ["not_up_by", "reached_over_by"]:
		if field in rally:
			rally.set(field, Sides.Team.NONE)
	if arena.sport() != Career.TENNIS:
		rally.inside_the_antennae = true
		rally.contacts = 3
	else:
		rally.is_a_serve = false
		rally.clipped_the_cord = false

	# Blatant: a metre outside, called in. Nobody in the building could miss it.
	rally.landing_point = Vector3(0.0, 0.02, 90.0)
	rally.was_in = false
	rally.margin = -1.4
	rally.struck_by = Sides.Team.RED
	rally.receiving = Sides.Team.BLUE
	rally.record_call(arena.fault_book()[0] if false else _in_call(arena))
	arena._the_players_react(Sides.Team.RED, rally)
	arena._the_room_reacts(rally)
	if rally.verdict() != Rally.Verdict.WRONG:
		print("   (the forged call came out %s, so nothing should react)" % [
			Rally.Verdict.keys()[rally.verdict()]])


func _in_call(arena: Node) -> CallType:
	if arena.sport() == Career.TENNIS:
		return TennisCallBook.get_call(&"in")
	if arena.sport() == Career.INDOOR:
		return VolleyCallBook.get_call(&"in")
	return BeachCallBook.get_call(&"in")


func _standing(arena: Node) -> bool:
	var stands = arena.court.stands
	if stands == null:
		return false
	for group in stands._crowd_holds.size():
		var holds: PackedFloat32Array = stands._crowd_holds[group]
		var jumps: PackedFloat32Array = stands._crowd_jumps[group]
		for i in holds.size():
			if holds[i] > 0.5 and jumps[i] > 0.0:
				return true
	return false
