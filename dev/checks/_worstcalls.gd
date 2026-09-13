extends Node

## Does the replay of the worst calls keep the right calls, and does the paper come out
## when it should?
##
## Four questions, in every sport:
##
##   1. Is a lie kept, with a flight that ends exactly where the ball came down and never
##      goes through the floor on the way?
##   2. Are at most three kept, the plainest first — and exactly as many as were wrong
##      when fewer than three were? A replay that quietly shows nothing looks exactly like
##      a match with nothing worth showing, which is the shape of every silent bug this
##      project has had.
##   3. Does the final whistle put the replay up with the result held back behind it, and
##      does skipping it reach the result?
##   4. Is the paper queued when, and only when, the umpire was taken off or the career
##      ended — and is it the front page for the second?
##
## Plus two with no sport in them: a match with nothing wrong goes straight to the result,
## and nothing the paper can print guesses at the umpire's pronouns or uses a trademark.
##
## The career save is put back afterwards. Every harness that finishes a match writes it,
## and this one finishes six.

const SAVE := "user://career.json"

## How many blatant lies each sport is fed. Four, so that one sport keeps fewer than
## it saw and the cap is exercised, without so many that the hall throws the umpire out
## before the ending can be checked on purpose.
const LIES := 4

var problems: Array[String] = []


func _ready() -> void:
	var saved := _keep_the_save()
	_check_the_paper()
	await _nothing_to_show()

	print("")
	print("%-13s %5s %5s %7s  %-9s %-9s  %s" % [
		"sport", "wrong", "kept", "points", "replay", "paper", "worst"])
	for entry in [
		# name, scene, sport, starting reputation, how the match ends
		["badminton", "res://scenes/match.tscn", Career.BADMINTON, 0.80, "taken off"],
		["beach", "res://scenes/beach.tscn", Career.BEACH, 0.80, "finished"],
		["indoor", "res://scenes/volleyball.tscn", Career.INDOOR, 0.80, "finished"],
		["tennis", "res://scenes/tennis.tscn", Career.TENNIS, 0.05, "taken off"],
		["table tennis", "res://scenes/table_tennis.tscn", Career.TABLE_TENNIS, 0.80, "finished"],
	]:
		await _check(entry[0], entry[1], entry[2], entry[3], entry[4])

	_put_the_save_back(saved)
	print("")
	if problems.is_empty():
		print("PASS")
	else:
		print("%d PROBLEM(S)" % problems.size())
		for problem in problems:
			print("   " + problem)
	get_tree().quit()


func _check(name: String, scene: String, sport: StringName, reputation: float,
		ending: String) -> void:
	var arena: OfficiatedMatch = await _open(scene, sport, reputation)
	var badminton := sport == Career.BADMINTON

	# 1 and 2: lie, and see what was kept.
	var wrong := 0
	for r in LIES:
		if arena._phase == arena.Phase.REMOVED:
			break
		arena.start_rally()
		if not await _until(func() -> bool: return arena._phase == arena.Phase.AWAITING_CALL, 30.0):
			problems.append("%s: rally %d never reached a call" % [name, r])
			break
		var rally = arena.current_rally()
		arena._awaiting_since = Time.get_ticks_msec()
		arena.make_call(&"in" if not rally.was_in else &"out")
		if rally.verdict() == Rally.Verdict.WRONG:
			wrong += 1
		await _until(func() -> bool: return arena._phase != arena.Phase.AWAITING_CALL, 10.0)

	var kept: Array = arena.worst_calls.moments
	if kept.size() != mini(wrong, WorstCalls.KEPT):
		problems.append("%s: %d wrong calls, %d kept — expected %d" % [
			name, wrong, kept.size(), mini(wrong, WorstCalls.KEPT)])
	if wrong == 0:
		problems.append("%s: not one of %d blatant lies was scored WRONG" % [name, LIES])
	var points := 0
	for i in kept.size():
		var moment: Dictionary = kept[i]
		var path: PackedVector3Array = moment["path"]
		var landing: Vector3 = moment["landing"]
		points = maxi(points, path.size())
		if i > 0 and moment["seen"] > kept[i - 1]["seen"] + 0.000001:
			problems.append("%s: kept calls are not plainest first" % name)
		if path.size() < 8:
			problems.append("%s: a replay path has only %d points" % [name, path.size()])
			continue
		if path[path.size() - 1].distance_to(landing) > 0.001:
			problems.append("%s: a replay path does not end at the landing" % name)
		# How far the flight ever gets from the landing, not where it starts. A short last
		# shot is replayed with the one before it, and in table tennis that one is struck
		# from right above the landing: a full two-shot rally started 17 cm from where it
		# came down, and read as a path that never moved.
		var farthest := 0.0
		for point in path:
			farthest = maxf(farthest, point.distance_to(landing))
		if farthest < 0.3:
			problems.append("%s: a replay path barely moves (%.2f m)" % [name, farthest])
		var lowest := INF
		for point in path:
			lowest = minf(lowest, point.y)
		if lowest < landing.y - 0.25:
			problems.append("%s: a replay path goes %.2f m through the floor" % [
				name, landing.y - lowest])
		if not String(moment["said_line"]).begins_with("YOU CALLED"):
			problems.append("%s: caption reads '%s'" % [name, moment["said_line"]])
		var truth := String(moment["truth_line"])
		if truth.is_empty() or "->" in truth or "(" in truth:
			problems.append("%s: truth line reads '%s'" % [name, truth])

	# 3: the final whistle.
	var already_over: bool = arena._phase == arena.Phase.REMOVED
	if not already_over:
		if ending == "taken off":
			arena.suspicion.is_removed = true
			if badminton:
				arena._on_removed_from_match()
			else:
				arena.finish("TAKEN OFF THE MATCH", Color(0.96, 0.42, 0.36), true)
		elif badminton:
			arena._finish_match("TEST FINISH", Color.WHITE, false)
		else:
			arena.finish("TEST FINISH", Color.WHITE, false)

	var replayed := await _until(func() -> bool: return arena.ui._replay.visible, 2.0)
	if not kept.is_empty() and not replayed:
		problems.append("%s: the match ended with %d calls kept and no replay" % [name, kept.size()])
	# What the replay says it is showing, against what was kept. Counting what was kept
	# alone could not see the lie that got an umpire thrown off going missing: it was
	# kept, but only after the replay had already started without it.
	if replayed and not arena.ui._replay_count.text.ends_with("OF %d" % kept.size()):
		problems.append("%s: the replay is showing '%s' of %d kept calls" % [
			name, arena.ui._replay_count.text, kept.size()])
	if replayed and arena.ui._ending.visible:
		problems.append("%s: the result came up underneath the replay" % name)
	arena.ui.replay_skip_all.emit()
	if not await _until(func() -> bool: return arena.ui._ending.visible, 3.0):
		problems.append("%s: skipping the replay never reached the result" % name)

	# 4: the paper.
	var removed: bool = arena.suspicion.is_removed
	var expected: bool = removed or arena.career.is_over
	var queued: bool = arena.ui.has_newspaper_waiting()
	var paper := "none"
	if queued != expected:
		problems.append("%s: paper queued %s, expected %s (removed %s, career over %s)" % [
			name, queued, expected, removed, arena.career.is_over])
	if queued:
		var front: bool = arena.ui._paper_story["front_page"]
		paper = "front" if front else "inside"
		if front != arena.career.is_over:
			problems.append("%s: %s page for a career that is %s" % [
				name, paper, "over" if arena.career.is_over else "not over"])
		arena.ui._after_the_result()
		await get_tree().process_frame
		if not arena.ui._paper.visible:
			problems.append("%s: CONTINUE on the result did not open the paper" % name)
		elif not arena.ui._ending.visible:
			pass

	print("%-13s %5d %5d %7d  %-9s %-9s  %s" % [
		name, wrong, kept.size(), points, "yes" if replayed else "no", paper,
		kept[0]["truth_line"] if not kept.is_empty() else "-"])
	if queued:
		print("%-13s headline: %s" % ["", arena.ui._paper_story["headline"]])

	arena.queue_free()
	await get_tree().process_frame


## A match with nothing wrong in it goes straight to the result. No booth, no wait.
func _nothing_to_show() -> void:
	var arena: OfficiatedMatch = await _open("res://scenes/match.tscn", Career.BADMINTON, 0.80)
	arena._finish_match("NOTHING TO SHOW", Color.WHITE, false)
	for f in 3:
		await get_tree().process_frame
	if not arena.ui._ending.visible:
		problems.append("a match with no wrong calls did not go straight to the result")
	if arena.replay_booth != null:
		problems.append("a match with no wrong calls built a replay booth")
	if arena.ui.has_newspaper_waiting():
		problems.append("a match finished cleanly queued a newspaper")
	print("no wrong calls: straight to the result %s, booth %s" % [
		arena.ui._ending.visible, "none" if arena.replay_booth == null else "BUILT"])
	arena.queue_free()
	await get_tree().process_frame


## Every combination of facts the paper can be handed, and what it must never print.
func _check_the_paper() -> void:
	var pronouns := RegEx.create_from_string("(?i)\\b(he|she|him|her|his|hers|himself|herself)\\b")
	var written := 0
	var sample_front := {}
	var sample_inside := {}
	for career_over in [false, true]:
		for how in ["finished", "thrown", "walked"]:
			for wrong in [0, 1, 2, 5]:
				for helped in ["", "RED"]:
					for mentioned in [false, true]:
						for truth in ["", "IT WAS OUT BY 34 cm", "NET TOUCH BY RED"]:
							var facts := {
								"sport": "BEACH VOLLEYBALL", "venue": "Regional beach open",
								"thrown_off": how == "thrown", "walked_out": how == "walked",
								"career_over": career_over, "wrong": wrong,
								"stolen": mini(wrong, 3), "helped": helped,
								"mentioned": mentioned, "matches": 14, "removals": 2,
								"worst_truth": truth, "worst_called": "IN" if truth != "" else "",
							}
							var story := Newspaper.story(facts)
							var due: bool = career_over or how != "finished"
							if story.is_empty() == due:
								problems.append("paper: %s for %s, career over %s" % [
									"nothing" if story.is_empty() else "a story", how, career_over])
							if story.is_empty():
								continue
							written += 1
							if story["front_page"] != career_over:
								problems.append("paper: front page %s with career over %s" % [
									story["front_page"], career_over])
							var every_word: String = " ".join([story["kicker"], story["headline"],
								story["standfirst"], "\n".join(story["body"]), story["caption"]])
							var found := pronouns.search(every_word)
							if found != null:
								problems.append("paper: says '%s' in: %s" % [
									found.get_string(), every_word])
							if "hawk" in every_word.to_lower():
								problems.append("paper: names a trademark")
							if story["headline"] != String(story["headline"]).to_upper():
								problems.append("paper: headline not in capitals: %s" % story["headline"])
							if story["front_page"] and truth != "" and mentioned and helped != "":
								sample_front = story
							if not story["front_page"] and how == "thrown" and wrong == 5 and helped != "" \
									and truth != "":
								sample_inside = story
	print("the paper: %d stories written, checked for pronouns, trademarks and capitals" % written)
	for sample in [sample_front, sample_inside]:
		if sample.is_empty():
			continue
		print("   [%s] %s" % [sample["kicker"], sample["headline"]])
		for line in sample["body"]:
			print("      " + line)


func _open(scene: String, sport: StringName, reputation: float) -> OfficiatedMatch:
	var arena: OfficiatedMatch = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	arena.career = Career.new()
	arena.career.sport = sport
	arena.career.reputation = reputation
	arena.settings.taught = true
	arena.settings.taught_beach = true
	arena.settings.taught_indoor = true
	arena.settings.taught_tennis = true
	arena.settings.taught_table_tennis = true
	if sport == Career.BADMINTON:
		arena._on_match_requested()
		if arena.pressure.exists():
			arena.ui.hide_briefing()
	else:
		arena.ui.match_requested.emit()
		await get_tree().process_frame
		if arena.pressure.exists():
			arena.ui.briefing_acknowledged.emit()
			await get_tree().process_frame
	arena.begin_match()
	for f in 4:
		await get_tree().process_frame
	return arena


## Waits until `done` says so, or `seconds` pass. Returns whether it happened.
func _until(done: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true


func _keep_the_save() -> String:
	if not FileAccess.file_exists(SAVE):
		return ""
	return FileAccess.get_file_as_string(SAVE)


func _put_the_save_back(saved: String) -> void:
	if saved.is_empty():
		if FileAccess.file_exists(SAVE):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
		return
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	if file != null:
		file.store_string(saved)
