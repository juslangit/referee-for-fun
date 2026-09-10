extends Node

## Does anybody walk through the table?
##
## Luqman found this by playing: the players had no collision with the table and went
## straight through it. They still have none — `Player extends Node3D` and is walked
## towards a destination, and no player in any sport in this game is a physics body,
## because the other four sports are played on the floor the players are standing on.
## Table tennis is the first with furniture in the playing area.
##
## So the table is kept clear by never sending anybody into it, and that is only true if
## **every** destination goes through `_off_the_table`. This watches the actual positions
## every physics frame for a whole match rather than reading the three call sites, which
## is the only way to catch the fourth one somebody adds later.
##
## The change of ends is the interesting moment and is checked deliberately: both players
## cross to the other side, and a straight line between the two homes goes through 2.74 m
## of tabletop.

## How far into the table's footprint counts as being in it. A person is not a point, so
## this allows a little less than the clearance the match aims for.
const BODY := 0.18


func _ready() -> void:
	var hall: Node = load("res://scenes/table_tennis.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.career.sport = Career.TABLE_TENNIS
	hall.settings.taught_table_tennis = true
	hall._on_match_requested()
	if hall.pressure.exists():
		hall.ui.hide_briefing()
	hall.begin_match()
	for f in 4:
		await get_tree().process_frame

	var watched := 0
	var worst := 0.0
	var offences := 0
	var changeovers := 0
	# Where it went wrong, not just that it did. The first version of this reported a
	# depth and a frame count and nothing else, and finding out which of four places was
	# responsible was guesswork.
	var worst_where := ""
	var caught := {}
	var games_before: int = hall.board.games[Sides.Team.RED] \
		+ hall.board.games[Sides.Team.BLUE]

	for r in 40:
		hall.start_rally()
		var w := 0
		while hall._phase != hall.Phase.AWAITING_CALL and w < 4000:
			await get_tree().physics_frame
			w += 1
			watched += 1
			var deepest := _deepest_intrusion(hall)
			if deepest > worst:
				worst = deepest
				worst_where = _who_and_where(hall)
			if deepest > BODY:
				offences += 1
				caught["during a point"] = int(caught.get("during a point", 0)) + 1
		if hall._phase != hall.Phase.AWAITING_CALL:
			break

		hall._awaiting_since = Time.get_ticks_msec()
		var rally: TableTennisRally = hall.rally
		if rally.is_a_let():
			hall.make_call(&"let", rally.served_by)
		elif rally.illegal_service:
			hall.make_call(&"illegal_service", rally.served_by)
		elif rally.volleyed_by != Sides.Team.NONE:
			hall.make_call(&"volley", rally.volleyed_by)
		elif rally.touched_the_table_by != Sides.Team.NONE:
			hall.make_call(&"touched_the_table", rally.touched_the_table_by)
		elif rally.double_bounce_by != Sides.Team.NONE:
			hall.make_call(&"double_bounce", rally.double_bounce_by)
		else:
			hall.make_call(&"in" if rally.rightful_winner() == rally.struck_by else &"out")

		# Between points, which is where the walk round the table happens. Watched for
		# the whole changeover rather than a couple of frames: the offence would be in
		# the middle of the walk, not at either end of it.
		var games_now: int = hall.board.games[Sides.Team.RED] \
			+ hall.board.games[Sides.Team.BLUE]
		var between := 40
		if games_now > games_before:
			changeovers += 1
			games_before = games_now
			between = int(TableTennisMatch.CHANGEOVER_SECONDS * 70.0)
		var moment := "changing ends" if between > 40 else "between points"
		for f in between:
			await get_tree().physics_frame
			watched += 1
			var deepest := _deepest_intrusion(hall)
			if deepest > worst:
				worst = deepest
				worst_where = _who_and_where(hall)
			if deepest > BODY:
				offences += 1
				caught[moment] = int(caught.get(moment, 0)) + 1
		if hall.board.is_over or hall._phase == hall.Phase.REMOVED:
			break

	print("watched %d physics frames of a real match, %d changes of ends in it"
		% [watched, changeovers])
	print("deepest anybody got into the table: %.3f m   (allowed: %.2f m)"
		% [worst, BODY])
	print("frames with somebody inside it: %d   (MUST BE 0)" % offences)
	if not worst_where.is_empty():
		print("  worst moment: %s" % worst_where)
	for moment in caught:
		print("  %d of them while %s" % [caught[moment], moment])
	get_tree().quit()


## Who was furthest into the table and exactly where they were standing.
func _who_and_where(hall: Node) -> String:
	var worst_player: Node3D = null
	var deepest := 0.0
	for player in hall.players:
		var into_x := TableTennisSpec.HALF_WIDTH - absf(player.position.x)
		var into_z := TableTennisSpec.HALF_LENGTH - absf(player.position.z)
		if into_x <= 0.0 or into_z <= 0.0:
			continue
		if minf(into_x, into_z) >= deepest:
			deepest = minf(into_x, into_z)
			worst_player = player
	if worst_player == null:
		return ""
	return "%s at x %.2f, z %.2f" % [
		worst_player.name, worst_player.position.x, worst_player.position.z]


## How far the worst-placed player is inside the table's footprint, in metres. Zero when
## everybody is clear of it.
func _deepest_intrusion(hall: Node) -> float:
	var deepest := 0.0
	for player in hall.players:
		var into_x := TableTennisSpec.HALF_WIDTH - absf(player.position.x)
		var into_z := TableTennisSpec.HALF_LENGTH - absf(player.position.z)
		# Inside only when it is inside on both axes. Standing level with the net but
		# out to the side of the table is beside it, not in it.
		if into_x <= 0.0 or into_z <= 0.0:
			continue
		deepest = maxf(deepest, minf(into_x, into_z))
	return deepest
