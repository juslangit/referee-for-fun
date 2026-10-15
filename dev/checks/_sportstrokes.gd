extends Node

## Does each situation in tennis, table tennis, volleyball and sepak takraw get its own
## stroke or touch? The badminton version is _bdstrokes; this is the other four sports
## (Luqman, 2026-10-15: "move on with other sports, do all sports").
##
## The situation is put to the choice directly — the ball at a place against the body, at a
## height — because a real match reaches some of them only now and then.
##
##     godot --headless --path . res://dev/checks/_sportstrokes.tscn
##
## Ends in PASS or FAIL.

# [scene, what, to their right (m), in front (m), height (m), overhead, how, expected]
# `how` is "" for a racket stroke, or the touch the sport asks for.
const CASES := [
	["tennis", "groundstroke to the right", 0.9, 0.5, 0.9, false, "", "tn_forehand"],
	["tennis", "groundstroke to the left", -0.9, 0.5, 0.9, false, "", "tn_backhand"],
	["tennis", "low ball to the right: slice", 0.9, 0.5, 0.35, false, "", "tn_slice_fh"],
	["tennis", "low ball to the left: slice", -0.9, 0.5, 0.35, false, "", "tn_slice_bh"],
	["tennis", "wide to the right: on the run", 1.6, 0.4, 0.9, false, "", "tn_run_fh"],
	["tennis", "wide to the left: on the run", -1.6, 0.4, 0.9, false, "", "tn_run_bh"],
	["tennis", "overhead", 0.4, 0.4, 2.2, true, "", "bd_smash"],
	["tennis", "at the net to the right: volley", 0.7, 0.4, 1.1, false, "net", "tn_volley_fh"],
	["tennis", "at the net to the left: volley", -0.7, 0.4, 1.1, false, "net", "tn_volley_bh"],
	["tennis", "return of serve, right", 0.8, 0.4, 0.9, false, "return", "tn_return_fh"],
	["tennis", "return of serve, left", -0.8, 0.4, 0.9, false, "return", "tn_return_bh"],
	["table_tennis", "to the right: drive", 0.4, 0.3, 0.95, false, "", "tt_fh_drive"],
	["table_tennis", "to the left: drive", -0.4, 0.3, 0.95, false, "", "tt_bh_drive"],
	["table_tennis", "short to the right: push", 0.4, 0.3, 0.85, false, "short", "tt_fh_push"],
	["table_tennis", "short to the left: push", -0.4, 0.3, 0.85, false, "short", "tt_bh_push"],
	["table_tennis", "high ball: smash", 0.3, 0.3, 1.3, true, "", "tt_smash"],
	["table_tennis", "far back: lob", 0.3, 0.3, 0.9, false, "far", "tt_lob"],
	["table_tennis", "right at the table: block", 0.3, 0.3, 0.95, false, "close", "tt_block"],
	["volleyball", "dig in front", 0.1, 0.6, 0.5, false, "vb_dig", "vb_dig"],
	["volleyball", "dig to the right", 0.7, 0.4, 0.5, false, "vb_dig", "vb_pass_right"],
	["volleyball", "dig to the left", -0.7, 0.4, 0.5, false, "vb_dig", "vb_pass_left"],
	["volleyball", "dig out of reach", 1.6, 0.4, 0.4, false, "vb_dig", "vb_dive"],
	["volleyball", "high reception", 0.1, 0.4, 2.0, false, "vb_dig", "vb_overhead_pass"],
	["beach", "dig out of reach, on sand", 1.6, 0.4, 0.4, false, "vb_dig", "vb_dive_sand"],
	["volleyball", "set with the hitter behind", 0.0, 0.4, 2.2, false, "vb_set:back", "vb_back_set"],
	["volleyball", "set with the hitter in front", 0.0, 0.4, 2.2, false, "vb_set", "vb_set"],
	["sepak_takraw", "receive low, in front", 0.1, 0.3, 0.45, false, "st_receive", "st_receive"],
	["sepak_takraw", "receive low, to the left", -0.6, 0.3, 0.45, false, "st_receive", "st_receive_left"],
	["sepak_takraw", "receive at the waist: thigh", 0.0, 0.3, 0.8, false, "st_receive", "st_thigh"],
	["sepak_takraw", "receive at the chest", 0.0, 0.3, 1.15, false, "st_receive", "st_chest"],
	["sepak_takraw", "set off a low ball: knee", 0.0, 0.3, 0.5, false, "st_set", "st_knee_set"],
	["sepak_takraw", "set at the waist", 0.0, 0.3, 0.85, false, "st_set", "st_set"],
]

var _problems: Array[String] = []


func _ready() -> void:
	var halls := {}
	for name in ["tennis", "table_tennis", "volleyball", "beach", "sepak_takraw"]:
		var hall: Node = load("res://scenes/%s.tscn" % name).instantiate()
		hall.print_truth_while_testing = false
		add_child(hall)
		halls[name] = hall
	for f in 150:
		await get_tree().process_frame

	for case in CASES:
		var player: Player = halls[case[0]].players[0]
		_try(player, case)

	print("PASS" if _problems.is_empty() else "FAIL:\n   " + "\n   ".join(_problems))
	get_tree().quit()


func _try(player: Player, case: Array) -> void:
	var what: String = case[1]
	var how: String = case[6]
	var expected: String = case[7]
	var half: float = Sides.half_sign(player.team)
	# Where they stand for the case: back in their half, at the net, or by the table.
	var depth := 6.0
	if player.racket_kind == &"bat" and not player.volleyball:
		depth = TableTennisSpec.HALF_LENGTH + 0.8
		if how == "far":
			depth = TableTennisSpec.HALF_LENGTH + 2.2
		elif how == "close":
			depth = TableTennisSpec.HALF_LENGTH + 0.1
	elif how == "net":
		depth = 2.5
	elif player.volleyball:
		depth = 4.0
	player.position = Vector3(0.0, 0.0, half * depth)
	player._destination = player.position
	player._reach_side = 1.0 if case[2] > -0.05 else -1.0
	player.returning_serve = how == "return"
	var forward := -player._away_from_the_net()
	var spot := player.position + player._right_of_net() * float(case[2]) + forward * float(case[3])
	spot.y = case[4]
	if how == "short":
		spot.z = half * (TableTennisSpec.HALF_LENGTH - 0.8)
	var got := ""
	if how.begins_with("vb_") or how.begins_with("st_"):
		var touch := how.split(":")[0]
		player.set_backwards = how.ends_with(":back")
		got = player._touch_variant(touch, spot, 0.0)
	elif player.racket_kind == &"tennis":
		got = player._tennis_stroke(spot, 0.0, case[5])
	else:
		got = player._table_tennis_stroke(spot, 0.0, case[5])
	player.returning_serve = false
	print("  %-14s %-40s %-18s %s" % [case[0], what, got, "ok" if got == expected else "WANTED " + expected])
	if got != expected:
		_problems.append("%s, %s: played %s, wanted %s" % [case[0], what, got, expected])
