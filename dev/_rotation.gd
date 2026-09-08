extends Node

## Does the serve come from the right court and cross the right diagonal?
##
## The rule is the whole of doubles service rotation: serve from your right when your
## score is even and from your left when it is odd, always into the receiver's matching
## court — which is the opposite side of the centre line, because the two of you face
## each other.
##
## This checks where the serve is aimed rather than where the shuttle finishes up. The
## first version of this test waited for the shuttle to land and reported every serve
## wrong, because the receiver returns the serve: it was measuring the end of a rally.
## Whether the shuttle arrives where it was aimed is a different question, and
## _aimcheck.tscn already answers it to a millimetre.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	arena._on_favour_chosen(Sides.Team.NONE)
	for f in 4:
		await get_tree().process_frame

	print("%-6s %-6s %-7s %-14s %-16s %s" % [
		"serves", "score", "court", "serves from", "aims at", "verdict"])

	var wrong := 0
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		for score in [0, 1, 2, 3]:
			arena.serving = team
			arena.board.points[team] = score
			var court: float = arena.service_court(team)
			var their_right := -1.0 if team == Sides.Team.RED else 1.0

			# Fifty of each, because the positions are drawn from a range.
			var bad := 0
			var shown_from := Vector3.ZERO
			var shown_at := Vector3.ZERO
			for attempt in 50:
				arena._stand_for_serve(court)
				var server: Player = _server(arena, team, court)
				var at: Vector3 = arena._pick_serve_target(
					Sides.half_sign(Sides.opponent(team)), -court)
				if attempt == 0:
					shown_from = server.home
					shown_at = at
				var stands_right: bool = signf(server.home.x) == court
				var crosses: bool = signf(at.x) == -court
				var in_box: bool = absf(at.z) > CourtSpec.SHORT_SERVICE_LINE \
					and absf(at.z) < CourtSpec.LONG_SERVICE_LINE_DOUBLES \
					and Sides.half_containing(at.z) != team
				var solvable: bool = ShotSolver.solve(
					Vector3(server.home.x, arena.SERVE_HEIGHT, Sides.half_sign(team) * arena.SERVE_DISTANCE),
					at, 34.0, Court.SURFACE_Y) != Vector3.ZERO
				if not (stands_right and crosses and in_box and solvable):
					bad += 1
			wrong += bad
			print("%-6s %-6d %-7s %-14s %-16s %s" % [
				Sides.label(team), score,
				"right" if court == their_right else "left",
				"x %+.2f" % shown_from.x, "x %+.2f, z %+.2f" % [shown_at.x, shown_at.z],
				"ok" if bad == 0 else "%d of 50 WRONG" % bad])

	print()
	print("serves that broke the rule: %d of 400" % wrong)
	get_tree().quit()


func _server(arena: Node, team: Sides.Team, court: float) -> Player:
	for player in arena.players:
		if player.team == team and signf(player.home.x) == court:
			return player
	return arena.players[0]
