extends Node

## Can a player actually get from the title screen to a beach volleyball rally?
##
## Two halves, because the hand-off between the sports is a scene change and a harness
## that lives inside the scene being changed does not survive it.
##
## First half: in the badminton scene, is there a beach card, is it enabled, and does
## pressing it write the sport into the career? Second half: in the beach scene, does
## the career screen lead to a briefing and then a rally that can be
## called — pressing only things a player can press.

func _ready() -> void:
	_the_card()
	print()
	await _the_beach_flow()
	get_tree().quit()


func _the_card() -> void:
	print("the sport menu")
	var found := {}
	for sport in RefereeUI.SPORTS:
		found[sport["id"]] = sport
		print("  %-18s %-22s %s" % [
			sport["id"], sport["name"],
			"playable" if sport["ready"] else "not built yet"])

	var beach: Dictionary = found.get(&"beach", {})
	print("  beach card present: %s, playable: %s, has its own art: %s" % [
		"yes" if not beach.is_empty() else "NO",
		"yes" if beach.get("ready", false) else "NO",
		"yes" if ResourceLoader.exists(String(beach.get("art", ""))) else "NO",
	])


func _the_beach_flow() -> void:
	print("from the career screen to a call, pressing only what a player can press")
	var arena: Node = load("res://scenes/beach.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	arena.career = Career.new()
	arena.career.sport = Career.BEACH
	arena.career.tier = 3  # a venue with a briefing worth showing
	arena.career.matches_at_tier = 2

	print("  venue: %s   (scrutiny %.2f)" % [
		arena.career.venue()["name"], arena.career.venue()["scrutiny"]])

	# REFEREE THIS MATCH.
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	var briefed: bool = arena.pressure.exists()
	print("  a reason to lean this match: %s" % (
		arena.pressure.ask if briefed else "none, a quiet appointment"))
	if briefed:
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame

	# WHO DO YOU WANT TO WIN.
	arena.begin_match()
	await get_tree().process_frame
	print("  phase once the match has begun: %s (READY is %d)" % [
		arena._phase, arena.Phase.READY])

	# SPACE.
	arena.start_rally()
	var waited := 0
	while arena._phase != arena.Phase.AWAITING_CALL and waited < 4000:
		await get_tree().physics_frame
		waited += 1
	print("  a rally played and came down: %s" % ("yes" if waited < 4000 else "NO"))

	arena._awaiting_since = Time.get_ticks_msec()
	arena.make_call(&"in" if arena.rally.was_in else &"out")
	print("  the call was taken, score is now RED %d - %d BLUE" % [
		arena.board.points[Sides.Team.RED], arena.board.points[Sides.Team.BLUE]])
	print("  suspicion after one honest call: %.3f" % arena.suspicion.level)
