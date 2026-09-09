extends Node

## Plays a run of rallies as a bent umpire and prints what the game recorded.
##
## The umpire here has a simple policy: give RED the point whenever possible, but
## only lie when the shuttle was close enough to the line that nobody could be sure.
## That is exactly the decision the player will be making, so if these numbers do
## not read sensibly, the game does not work.

## Lies more visible than this are not worth telling.
const NERVE := 0.25

func _ready() -> void:
	seed(20260907)
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	arena._set_up_the_match(false)
	arena.begin_match()

	print("leaning towards RED, and lying only when the margin is under %.0f cm\n" % (Rally.BLATANT_MARGIN * NERVE * 100.0))
	print("%-4s %-7s %-26s %-6s %-11s %-6s %s" % ["#", "struck", "truth", "call", "verdict", "vis.", "score"])

	var lies := 0
	var stolen := 0
	var total_visibility := 0.0

	for i in range(16):
		arena.start_rally()
		while arena._phase != arena.Phase.AWAITING_CALL:
			await get_tree().physics_frame

		var rally: Rally = arena.rally
		var honest: StringName = &"in" if rally.was_in else &"out"
		var helps_red: StringName = &"in" if rally.struck_by == Sides.Team.RED else &"out"

		# Would the helpful call be a lie, and if so, how visible a one?
		var chosen := honest
		if helps_red != honest and absf(rally.margin) / Rally.BLATANT_MARGIN < NERVE:
			chosen = helps_red

		var truth := "%s by %.3f m at (%+.2f, %+.2f)" % [
			"IN" if rally.was_in else "OUT", absf(rally.margin), rally.landing_point.x, rally.landing_point.z
		]
		arena.make_call(chosen)

		if rally.verdict() == Rally.Verdict.WRONG:
			lies += 1
			total_visibility += rally.visibility()
			if rally.changed_the_result():
				stolen += 1

		print("%-4d %-7s %-26s %-6s %-11s %-6.3f %d-%d" % [
			i + 1,
			Sides.label(rally.struck_by),
			truth,
			rally.call.label,
			Rally.Verdict.keys()[rally.verdict()],
			rally.visibility(),
			arena.board.points[Sides.Team.RED],
			arena.board.points[Sides.Team.BLUE],
		])

	print("\nfinal  RED %d — %d BLUE" % [arena.board.points[Sides.Team.RED], arena.board.points[Sides.Team.BLUE]])
	print("told %d lies, %d of which stole the rally" % [lies, stolen])
	print("average visibility of a lie: %.3f  (1.0 would be blatant to the whole hall)" % [
		total_visibility / maxf(1.0, float(lies))
	])
	get_tree().quit()
