extends Node

## Is more than one screen ever up at the same time?
##
##   godot --headless --path . res://dev/checks/_onescreen.tscn
##
## Every `show_*` in `RefereeUI` is supposed to put away whatever it is covering, and most
## of them do. The ones that forget are invisible in a still and obvious in motion: the
## trailer recorded on 2026-09-21 caught the **review card sitting on top of the
## end-of-match replay**, with the verdict of one call over the ball-tracking of another,
## and nobody had noticed in weeks of playing.
##
## So this plays a whole bent match — rallies, calls, a challenge, the removal, the
## replays and the result — and at every step lists which of the big panels are visible.
## Two of them at once is a failure, because each one is a full-screen answer to a
## different question.
##
## The score bug, the reputation meter and the caption are not in this list. They are
## meant to sit over the match.

const EXCLUSIVE := [
	"_main_menu", "_pause_menu", "_settings_menu", "_career_panel", "_history_panel",
	"_credits_panel", "_briefing", "_review", "_replay", "_ending", "_fault_panel",
]

## The line camera is not a screen, but it is a panel that covers part of one, and it has
## no business being up over a result. Checked separately so its failure reads plainly.
const OVER_THE_RESULT := ["_shuttle_cam_panel"]

var _failures: Array[String] = []


func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	arena.career = Career.new()
	arena.career.tier = 4
	arena.settings.taught_beach = true
	arena.settings.taught_indoor = true
	arena.settings.taught_tennis = true
	arena.settings.taught_table_tennis = true
	arena.settings.taught_takraw = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		_look(arena, "the briefing")
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()

	# Bent, because the interesting screens — the challenge, the removal, the replays —
	# only appear when the official is worth challenging.
	var steps := 0
	while steps < 4000:
		steps += 1
		if arena._phase == arena.Phase.READY:
			arena.start_rally()
		elif arena._phase == arena.Phase.AWAITING_CALL:
			var truth: bool = arena.rally.was_in if arena.rally != null else true
			arena.make_call(&"in" if not truth else &"out")
			for f in 12:
				await get_tree().physics_frame
			_look(arena, "after a call")
		elif arena._phase == arena.Phase.REMOVED:
			break
		await get_tree().physics_frame
		_look(arena, "mid-match")

	# And the whole tail: the replays and the result screen.
	for beat in 90:
		for f in 10:
			await get_tree().physics_frame
		_look(arena, "after the removal")

	print("")
	if _failures.is_empty():
		print("PASS  one screen at a time, all the way through a match")
	else:
		for failure in _failures:
			print("FAIL  %s" % failure)
	get_tree().quit()


var _last := ""


func _phase_name(arena: Node) -> String:
	match arena._phase:
		arena.Phase.MENU: return "menu"
		arena.Phase.READY: return "ready"
		arena.Phase.IN_PLAY: return "in play"
		arena.Phase.AWAITING_CALL: return "awaiting call"
		arena.Phase.REMOVED: return "removed"
	return "?"


func _look(arena: Node, when: String) -> void:
	var up: Array[String] = []
	for name in EXCLUSIVE:
		var panel: Control = arena.ui.get(name)
		if panel != null and panel.visible:
			up.append(name.trim_prefix("_"))

	# Every change, in order, with the phase it happened in. A poll that only samples
	# occasionally records which panels overlapped and not how they got there.
	var now := ", ".join(up) if not up.is_empty() else "the match"
	if now != _last:
		_last = now
		print("   %-18s %-16s %s" % [when, _phase_name(arena), now])

	if up.size() > 1:
		var problem := "%s: %s are up together" % [when, " and ".join(up)]
		if not problem in _failures:
			_failures.append(problem)

	# The line camera over the result screen.
	var ending: Control = arena.ui.get("_ending")
	if ending != null and ending.visible:
		for name in OVER_THE_RESULT:
			var panel: Control = arena.ui.get(name)
			if panel != null and panel.visible:
				var problem := "the %s is up over the result screen" % name.trim_prefix("_")
				if not problem in _failures:
					_failures.append(problem)
