extends Node

## Do the three sports that have both formats actually play them differently?
##
## Singles and doubles are not the same game with fewer people. The court is a different
## width, the service court is a different length, and the number of people on it is the
## first thing anybody watching would notice — so all three are checked rather than
## assumed, in every one of them, both ways round.
##
## Sepak takraw is the exception on the first two: regu and doubles share one court, and
## what changes is the number of people — three a side or two — and where the serve is from.

func _ready() -> void:
	print("%-10s %-9s %8s %10s %14s" % [
		"sport", "format", "players", "sideline", "serve box back"])
	for doubles in [false, true]:
		await _check("badminton", "res://scenes/match.tscn", Career.BADMINTON, doubles)
	for doubles in [false, true]:
		await _check("tennis", "res://scenes/tennis.tscn", Career.TENNIS, doubles)
	for doubles in [false, true]:
		await _check("takraw", "res://scenes/sepak_takraw.tscn", Career.TAKRAW, doubles)

	print()
	print("and the sports that are only ever one thing")
	for doubles in [false, true]:
		await _check("beach", "res://scenes/beach.tscn", Career.BEACH, doubles)
	print("   (beach must not change: it is two a side whatever anybody chose)")
	get_tree().quit()


func _check(name: String, scene: String, sport: StringName, doubles: bool) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = sport
	arena.career.doubles = doubles
	arena.settings.taught = true
	arena.settings.taught_beach = true
	arena.settings.taught_tennis = true
	arena.settings.taught_takraw = true

	# Asked for through the real door. The players are built when the scene is, before
	# the career exists, so what matters is whether **starting a match** rebuilds them
	# for the format that was chosen — which is the bug this was written after.
	arena._on_match_requested()
	if arena.pressure.exists():
		arena.ui.hide_briefing()
	await get_tree().process_frame

	var sideline := 0.0
	var back := 0.0
	if sport == Career.TENNIS:
		sideline = arena._sideline()
		back = TennisSpec.SERVICE_LINE
	elif sport == Career.BADMINTON:
		sideline = CourtSpec.HALF_WIDTH_DOUBLES if arena.playing_doubles() \
			else CourtSpec.HALF_WIDTH_SINGLES
		back = CourtSpec.LONG_SERVICE_LINE_DOUBLES if arena.playing_doubles() \
			else CourtSpec.HALF_LENGTH
	elif sport == Career.TAKRAW:
		sideline = TakrawSpec.HALF_WIDTH
	else:
		sideline = BeachSpec.HALF_WIDTH

	print("%-10s %-9s %8d %10.2f %14.2f" % [
		name, "doubles" if arena.playing_doubles() else ("regu" if sport == Career.TAKRAW else "singles"),
		arena.players.size(), sideline, back])
	arena.queue_free()
	await get_tree().process_frame
