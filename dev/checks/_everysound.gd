extends Node

## Does everything that happens make its own sound, in all six sports?
##
## Asked on 2026-09-13, and the answer was no. Tennis and table tennis were silent between
## a stroke and the next, a serve clipping the net made no noise in the two sports whose
## lessons say that call is decided by a sound, a volleyball bump used the badminton
## racket, and the whistle and the line judge's shout were played in sports whose
## officials have neither.
##
## Nobody can listen from here, so this plays real rallies and counts what the hall was
## asked to play (`Sound.heard`), then asks the questions that have a right answer:
## is the ball heard bouncing, are the feet heard, is the whistle heard only in volleyball.
## It then reviews a call, wins a set and ends the match, and presses a menu button.
##
## `RALLIES=12` for more or fewer points a sport. Puts the career save back afterwards,
## because ending a match writes it.

var SAVE := Career.save_path()

const SPORTS := [
	["badminton", "res://scenes/match.tscn", Career.BADMINTON],
	["beach", "res://scenes/beach.tscn", Career.BEACH],
	["indoor", "res://scenes/volleyball.tscn", Career.INDOOR],
	["tennis", "res://scenes/tennis.tscn", Career.TENNIS],
	["table_tennis", "res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
	["takraw", "res://scenes/sepak_takraw.tscn", Career.TAKRAW],
]

var _problems: Array[String] = []


func _ready() -> void:
	_the_officials()
	var saved := _keep_the_save()
	for sport in SPORTS:
		await _listen_to(sport[0], sport[1], sport[2])
	_put_the_save_back(saved)

	print()
	if _problems.is_empty():
		print("PASS — every sport makes every sound it should, and none it should not")
	else:
		print("%d PROBLEM(S)" % _problems.size())
		for problem in _problems:
			print("   " + problem)
	get_tree().quit()


func _listen_to(sport: String, scene: String, career_sport: StringName) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	arena.career = Career.new()
	arena.career.sport = career_sport
	# The top of the ladder, where there are line judges and a challenge to hear.
	arena.career.tier = 2
	match career_sport:
		Career.BADMINTON: arena.settings.taught = true
		Career.BEACH: arena.settings.taught_beach = true
		Career.INDOOR: arena.settings.taught_indoor = true
		Career.TENNIS: arena.settings.taught_tennis = true
		Career.TABLE_TENNIS: arena.settings.taught_table_tennis = true
		Career.TAKRAW: arena.settings.taught_takraw = true

	# A menu button, pressed the way a player presses one.
	var clicks: UiSound = arena.ui.get_node("UiSound")
	for f in 2:
		await get_tree().process_frame
	var button := _first_button(arena.ui)
	if button == null:
		_problems.append("%s: no visible menu button to press" % sport)
	else:
		button.mouse_entered.emit()
		button.pressed.emit()

	arena._on_match_requested()
	if arena.pressure.exists():
		arena.ui.hide_briefing()
	arena.begin_match()
	for f in 4:
		await get_tree().process_frame

	var sound: Sound = arena.sound
	var rallies := int(OS.get_environment("RALLIES")) if OS.has_environment("RALLIES") else 12
	var played := 0
	var cords := 0
	var edges := 0
	for r in rallies:
		if arena._phase == arena.Phase.REMOVED or arena.board.is_over:
			break
		if arena._phase != arena.Phase.READY:
			await get_tree().process_frame
			continue
		arena.start_rally()
		var w := 0
		while arena._phase != arena.Phase.AWAITING_CALL and w < 4000:
			await get_tree().physics_frame
			w += 1
		if arena._phase != arena.Phase.AWAITING_CALL:
			break
		var rally = arena.current_rally()
		played += 1
		if "clipped_the_cord" in rally and rally.clipped_the_cord:
			cords += 1
		if "clipped_the_net" in rally and rally.clipped_the_net:
			cords += 1
		if "clipped_the_edge" in rally and rally.clipped_the_edge:
			edges += 1
		# Let the ball finish bouncing before the call, the way a real point sounds.
		for f in 45:
			await get_tree().physics_frame
		arena._awaiting_since = Time.get_ticks_msec()
		arena.make_call(&"in" if rally.was_in else &"out")
		var w2 := 0
		while arena._phase == arena.Phase.AWAITING_CALL and w2 < 900:
			await get_tree().process_frame
			w2 += 1

	# A review, straight after a call, as the venue would ask for one.
	if arena.current_rally() != null and arena._phase != arena.Phase.REMOVED:
		await arena.review(Sides.Team.RED)

	# A set, then the rest of the match, awarded straight to the board.
	var to := Sides.Team.RED
	var guard := 0
	while not arena.board.is_over and guard < 400:
		arena.award_the_point(to)
		if randf() < 0.3:
			to = Sides.opponent(to)
		guard += 1
		await get_tree().process_frame
	for f in 30:
		await get_tree().process_frame

	var heard: Dictionary = sound.heard
	print("=== %s   %d points played, %d net cords, %d edge balls" % [sport, played, cords, edges])
	var names := heard.keys()
	names.sort()
	var line := ""
	for name in names:
		line += "%s %d   " % [name, heard[name]]
	print("   " + line)
	print("   menu: hover %d  press %d" % [clicks.heard.get(&"hover", 0), clicks.heard.get(&"press", 0)])

	var volleyball := sport == "beach" or sport == "indoor"
	var ball_bounces := sport == "tennis" or sport == "table_tennis"
	_expect(sport, played > 0, "no point was played at all")
	_expect(sport, heard.get(&"strike", 0) > 0, "the ball was never heard being struck")
	if sport == "badminton" or volleyball or sport == "takraw":
		_expect(sport, heard.get(&"land", 0) > 0, "the ball was never heard landing")
	# Only with a few points to go on: a single point can be a serve fault that bounced once.
	if ball_bounces and played >= 4:
		# More bounces than points: the ball is heard between strokes, not only at the end.
		_expect(sport, heard.get(&"bounce", 0) > played,
			"%d bounces in %d points — the rally bounces are silent" % [heard.get(&"bounce", 0), played])
	_expect(sport, heard.get(&"step", 0) > 0, "nobody's feet were heard")
	if volleyball:
		_expect(sport, heard.get(&"whistle", 0) > 0, "a volleyball referee never whistled")
		_expect(sport, heard.get(&"judge_out", 0) == 0, "a volleyball line judge shouted")
	else:
		_expect(sport, heard.get(&"whistle", 0) == 0,
			"a whistle was blown %d times in a sport without one" % heard.get(&"whistle", 0))
	if sport == "table_tennis":
		_expect(sport, heard.get(&"judge_out", 0) == 0, "table tennis has no line judges to shout")
	if sport == "takraw":
		_expect(sport, heard.get(&"judge_out", 0) == 0, "a sepak takraw line judge shouted")
	if sport == "beach":
		_expect(sport, heard.get(&"squeak", 0) == 0, "a shoe squeaked on sand")
	if cords > 0:
		_expect(sport, heard.get(&"net", 0) > 0, "%d serves clipped the net and none was heard" % cords)
	if edges > 0:
		_expect(sport, heard.get(&"edge", 0) > 0, "%d edge balls and none was heard as one" % edges)
	_expect(sport, heard.get(&"scoreboard", 0) > 0, "the scoreboard never ticked")
	_expect(sport, heard.get(&"review", 0) > 0 and heard.get(&"review_answer", 0) > 0,
		"the review made no sound")
	_expect(sport, heard.get(&"set_won", 0) > 0, "a set was won in silence")
	_expect(sport, heard.get(&"match_over", 0) > 0, "the match ended in silence")
	_expect(sport, clicks.heard.get(&"hover", 0) > 0 and clicks.heard.get(&"press", 0) > 0,
		"a menu button made no sound")

	arena.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


## Who blows a whistle and who shouts, asked of each sport directly. A dozen rallies may
## never send a ball out near a line judge, so the rallies alone cannot prove the shout
## still works where it should.
func _the_officials() -> void:
	print("the officials   whistle   line judge shouts OUT")
	var rules := {
		&"badminton": [false, true], &"beach": [true, false], &"indoor": [true, false],
		&"tennis": [false, true], &"table_tennis": [false, false], &"takraw": [false, false],
	}
	for sport in rules:
		var hall := Sound.new()
		hall.kit = sport
		add_child(hall)
		hall.whistle()
		hall.judge_calls_out(Vector3.ZERO)
		var whistled: bool = hall.heard.get(&"whistle", 0) > 0
		var shouted: bool = hall.heard.get(&"judge_out", 0) > 0
		print("   %-13s %-9s %s" % [sport, "yes" if whistled else "no", "yes" if shouted else "no"])
		_expect(String(sport), whistled == rules[sport][0], "whistle should be %s" % rules[sport][0])
		_expect(String(sport), shouted == rules[sport][1], "OUT shout should be %s" % rules[sport][1])
		hall.free()
	print()


func _expect(sport: String, ok: bool, problem: String) -> void:
	if not ok:
		_problems.append("%s: %s" % [sport, problem])


## The first button a player could actually point at. A hidden one does not tick, on
## purpose, so a hidden one proves nothing.
func _first_button(root: Node) -> BaseButton:
	if root is BaseButton and (root as BaseButton).is_visible_in_tree():
		return root
	for child in root.get_children():
		var found := _first_button(child)
		if found != null:
			return found
	return null


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
