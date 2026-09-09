extends Node

## The reputation meter: does it say the truth, and does it show only when it moves?
##
## Two things are worth asserting and neither is visual.
##
## The meter and the ending screen are two views of one number, so the arithmetic is
## shared rather than copied. If they ever drift the player reads it as the game lying
## to them, which is fatal for the one readout in this project that claims to be the
## truth about your name.
##
## And it must be **news**. A meter that appears on every rally is a suspicion bar with
## a fade on it, and this game spent four lessons promising it would never have one.

func _ready() -> void:
	_the_meter_agrees_with_the_ending_screen()
	print()
	await _it_only_shows_when_it_moves()
	get_tree().quit()


func _the_meter_agrees_with_the_ending_screen() -> void:
	print("what the meter says during the match, and where it actually lands")
	print("%10s %14s %14s %14s" % ["suspicion", "meter says", "ends at", "finish_match"])
	for level in [0.0, 0.05, 0.13, 0.30, 0.60, 1.00]:
		var career := Career.new()
		career.reputation = 0.72
		var standing := career.reputation_as_it_stands(level, false)
		var projected := career.reputation_if_it_ended(level, false)
		career.finish_match(level, false, [])
		var actual := career.reputation
		var agrees := "" if is_equal_approx(projected, actual) else "   <-- DISAGREES"
		print("%10.2f %14d %14d %14d%s" % [
			level, roundi(standing * 100.0), roundi(projected * 100.0),
			roundi(actual * 100.0), agrees])

	print("")
	print("the meter starts exactly where the career screen left it")
	var fresh := Career.new()
	fresh.reputation = 0.61
	print("  career screen says %d, meter opens at %d" % [
		roundi(fresh.reputation * 100.0),
		roundi(fresh.reputation_as_it_stands(0.0, false) * 100.0)])

	print("")
	print("being taken off, priced live")
	var removed := Career.new()
	removed.reputation = 0.80
	print("  before %d, thrown off at 0.55 suspicion -> meter reads %d" % [
		80, roundi(removed.reputation_as_it_stands(0.55, true) * 100.0)])


## Runs two beach referees past the same meter and counts how often it appeared.
##
## The honest one has to be honest about **everything** — the faults as well as the line.
## A referee who gives only the line is not being honest, they are ignoring half the
## rulebook, and reading their suspicion as unfairness has been a mistake here once
## already.
func _it_only_shows_when_it_moves() -> void:
	var honest := await _referee(true)
	var liar := await _referee(false)
	print("how often the meter appeared")
	print("  an honest referee:  %d appearances in %d calls" % [honest[0], honest[1]])
	print("  one who lies about every close ball: %d in %d" % [liar[0], liar[1]])
	print("")
	print("  the honest number is the one that matters. A meter that appears on every")
	print("  rally is a suspicion bar with a fade on it.")


## Returns [meter appearances, calls made].
func _referee(tells_the_truth: bool) -> Array:
	var sand: Node = load("res://scenes/beach.tscn").instantiate()
	sand.print_truth_while_testing = false
	add_child(sand)
	await get_tree().physics_frame

	sand.career = Career.new()
	sand.career.sport = Career.BEACH
	sand.settings.taught_beach = true
	sand.ui.match_requested.emit()
	await get_tree().process_frame
	if sand.pressure.exists():
		sand.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	sand.begin_match()
	for f in 3:
		await get_tree().process_frame

	var appearances := 0
	var was_up := false
	var calls := 0

	for frame in 40000:
		await get_tree().process_frame
		var up: bool = sand.ui._meter != null and sand.ui._meter.visible
		if up and not was_up:
			appearances += 1
		was_up = up

		if sand._phase == sand.Phase.READY:
			sand.start_rally()
			continue
		if sand._phase != sand.Phase.AWAITING_CALL:
			continue

		var rally = sand.rally
		sand._awaiting_since = Time.get_ticks_msec()
		if tells_the_truth:
			if rally.foot_fault:
				sand.make_call(&"foot_fault", sand.serving)
			elif rally.handling_fault:
				sand.make_call(&"double_contact", rally.struck_by)
			elif sand.net_toucher != Sides.Team.NONE:
				sand.make_call(&"net_touch", sand.net_toucher)
			elif sand.centre_line_crosser != Sides.Team.NONE:
				sand.make_call(&"centre_line", sand.centre_line_crosser)
			elif rally.was_in:
				sand.make_call(&"in")
			elif rally.was_touched:
				sand.make_call(&"touch")
			else:
				sand.make_call(&"out")
		else:
			sand.make_call(&"in" if not rally.was_in else &"out")
		calls += 1

		var waited := 0
		while sand._phase == sand.Phase.AWAITING_CALL and waited < 900:
			await get_tree().process_frame
			waited += 1
		if calls >= 20 or sand._phase == sand.Phase.REMOVED:
			break

	sand.queue_free()
	await get_tree().process_frame
	return [appearances, calls]
