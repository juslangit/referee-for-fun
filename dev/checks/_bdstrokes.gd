extends Node

## Does each badminton situation get its own stroke?
##
## Luqman, 2026-10-15: "when red team smash to the right side of the court, the blue team will
## take the shuttle with they hand going right. if red team smash to the left, the blue team
## athlete will take the ball from the left". A real match plays only a handful of smashes, so
## the situations are put to the stroke choice directly: a shuttle at a place against the body,
## at a height, with the shot that is coming and whether a smash is on its way in.
##
##     godot --headless --path . res://dev/checks/_bdstrokes.tscn
##
## Ends in PASS or FAIL.

# [what, shuttle to their right (m), in front (m), height (m), shot, smash coming, expected]
const CASES := [
	["smash to the right, at the hip", 0.6, 0.4, 0.9, "lift", true, "bd_block_fh"],
	["smash to the left, at the hip", -0.6, 0.4, 0.9, "lift", true, "bd_block_bh"],
	["smash at the chest", 0.05, 0.3, 1.2, "lift", true, "bd_body"],
	["smash wide to the right", 1.1, 0.3, 0.8, "lift", true, "bd_lift_fh_wide"],
	["smash wide to the left", -1.1, 0.3, 0.8, "lift", true, "bd_lift_bh_wide"],
	["smash out of reach to the right, low", 1.4, 0.3, 0.4, "lift", true, "bd_dive"],
	["high to the right: smash", 0.5, 0.3, 2.3, "smash", false, "bd_smash"],
	["high, jumped smash", 0.5, 0.3, 2.7, "jump_smash", false, "bd_jump_smash"],
	["high to the left: round the head smash", -0.6, 0.2, 2.3, "smash", false, "bd_rth_smash"],
	["high to the right: clear", 0.4, 0.3, 2.3, "clear", false, "bd_clear"],
	["high to the left: round the head clear", -0.6, 0.2, 2.3, "clear", false, "bd_rth_clear"],
	["high to the left and behind: backhand clear", -0.6, -0.5, 2.3, "clear", false, "bd_bh_clear"],
	["high to the right: drop", 0.4, 0.3, 2.3, "drop", false, "bd_drop"],
	["high to the left and behind: backhand drop", -0.6, -0.5, 2.3, "drop", false, "bd_bh_drop"],
	["chest height to the right: drive", 0.8, 0.6, 1.4, "lift", false, "bd_drive_fh"],
	["chest height to the left: drive", -0.8, 0.6, 1.4, "lift", false, "bd_drive_bh"],
]
# The same, at the net: [what, right, height, shot, expected]
const AT_THE_NET := [
	["low at the net, right: net shot", 0.6, 0.5, "net", "bd_net_fh"],
	["low at the net, left: net shot", -0.6, 0.5, "net", "bd_net_bh"],
	["low at the net, right: lift", 0.6, 0.5, "lift", "bd_lift_fh"],
	["low at the net, left: lift", -0.6, 0.5, "lift", "bd_lift_bh"],
	["above the tape: kill", 0.3, 1.85, "lift", "bd_kill"],
]

var _problems: Array[String] = []


func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	for f in 120:
		await get_tree().process_frame
	var player: Player = hall.players[0]
	player.go_home()

	for case in CASES:
		player.position = Vector3(0.0, 0.0, -Sides.half_sign(player.team) * 4.0)
		_try(player, case[0], case[1], case[2], case[3], case[4], case[5], case[6])
	for case in AT_THE_NET:
		player.position = Vector3(0.0, 0.0, -Sides.half_sign(player.team) * 1.4)
		_try(player, case[0], case[1], 0.4, case[2], case[3], false, case[4])

	print("PASS" if _problems.is_empty() else "FAIL:\n   " + "\n   ".join(_problems))
	get_tree().quit()


func _try(player: Player, what: String, right: float, ahead: float, height: float,
		shot: String, smash_coming: bool, expected: String) -> void:
	player._destination = player.position
	# The side they set up for, as the chase would have decided it.
	player._reach_side = 1.0 if right > -Player.BACKHAND_BEYOND else -1.0
	var forward := -player._away_from_the_net()
	var spot := player.position + player._right_of_net() * right + forward * ahead
	spot.y = height
	var got := player._badminton_stroke(spot, 0.0, height > 1.95, shot, smash_coming)
	print("  %-46s %-16s %s" % [what, got, "ok" if got == expected else "WANTED " + expected])
	if got != expected:
		_problems.append("%s: played %s, wanted %s" % [what, got, expected])
