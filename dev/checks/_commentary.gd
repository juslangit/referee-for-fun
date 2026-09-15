extends Node

## Does the broadcast keep the game's one rule, remember the career, and turn up at all?
##
## Three halves. The lines are read for any word that talks about the ball or the verdict
## rather than the person in the chair — only the review banks may, because the screen
## has already told everybody. The choosing is driven directly, including the case that
## matters most: a wrong call nobody could see must draw exactly what a right one does.
## And a real match is started in every sport, to see the opening go up on screen.

## Words that are about the ball or about whether a call was right. "line judge" is a
## person and is allowed; a "line" on its own is paint.
const FORBIDDEN := [
	"\\bout\\b", "\\bwide\\b", "\\blanded\\b", "\\bline\\b(?! judge)", "\\blines\\b",
	"\\bcorrect\\b", "\\bwrong\\b", "\\bmistake", "\\berror", "\\bgood call\\b",
	"\\bbad call\\b", "\\bright call\\b", "\\bin or out\\b", "\\bwas in\\b",
]

var _problems: Array[String] = []


func _ready() -> void:
	_read_the_lines()
	_choose()
	for entry in [
		["badminton", "res://scenes/match.tscn", Career.BADMINTON],
		["beach", "res://scenes/beach.tscn", Career.BEACH],
		["indoor", "res://scenes/volleyball.tscn", Career.INDOOR],
		["tennis", "res://scenes/tennis.tscn", Career.TENNIS],
		["table tennis", "res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
	]:
		await _on_air(entry[0], entry[1], entry[2])
	print("PASS" if _problems.is_empty() else "FAIL:\n   " + "\n   ".join(_problems))
	get_tree().quit()


# --- the lines ---------------------------------------------------------------------

func _read_the_lines() -> void:
	var patterns: Array[RegEx] = []
	for word in FORBIDDEN:
		var re := RegEx.new()
		re.compile("(?i)" + word)
		patterns.append(re)

	var guarded := {
		"OPENING": Commentary.OPENING, "CALL": Commentary.CALL, "DELAY": Commentary.DELAY,
		"OVERRULE": Commentary.OVERRULE, "RECOVERY": Commentary.RECOVERY,
		"CARD": Commentary.CARD, "WARNING": Commentary.WARNING,
		"SMALL_TALK": Commentary.SMALL_TALK, "LAST_WORD": Commentary.LAST_WORD,
	}
	var read := 0
	for bank in guarded:
		for line in _every_line(guarded[bank]):
			read += 1
			for re in patterns:
				if re.search(line) != null:
					_problems.append("%s says something about the ball: \"%s\" (%s)" % [
						bank, line, re.get_pattern()])
	print("lines read for the rule: %d" % read)

	for tone in [Commentary.Tone.WATCHFUL, Commentary.Tone.DOUBTING, Commentary.Tone.DAMNING]:
		if not Commentary.CALL.has(tone):
			_problems.append("CALL has no bank for tone %d" % tone)
	var by_tone := {"DELAY": Commentary.DELAY, "SMALL_TALK": Commentary.SMALL_TALK}
	for tone in Commentary.Tone.values():
		for bank in by_tone:
			if not by_tone[bank].has(tone):
				_problems.append("%s has no bank for tone %d" % [bank, tone])
	for kind in ["first", "promoted", "removed_last_time", "low_reputation", "good_record", "ordinary"]:
		if not Commentary.OPENING.has(kind):
			_problems.append("no opening for %s" % kind)

	# Every placeholder filled, in every sport, with a career that has a past.
	var box := Commentary.new()
	add_child(box)
	for sport_name in [Career.BADMINTON, Career.BEACH, Career.INDOOR, Career.TENNIS, Career.TABLE_TENNIS]:
		var career := _career_with_a_past(sport_name, false, 0.9)
		box.open_match(career, sport_name, "State open")
		var all := {}
		all.merge(guarded)
		all["REVIEW_OVERTURNED"] = Commentary.REVIEW_OVERTURNED
		all["REVIEW_UPHELD"] = Commentary.REVIEW_UPHELD
		for bank in all:
			for line in _every_line(all[bank]):
				var filled: String = box._fill(line)
				if filled.contains("{") or filled.contains("}"):
					_problems.append("%s in %s leaves a blank: \"%s\"" % [bank, sport_name, filled])
				if filled.contains("an referee") or filled.contains("a umpire"):
					_problems.append("%s in %s: \"%s\"" % [bank, sport_name, filled])
				if sport_name != Career.BADMINTON and filled.contains("badminton"):
					_problems.append("%s in %s talks about badminton: \"%s\"" % [bank, sport_name, filled])
	box.queue_free()


func _every_line(bank) -> Array[String]:
	var out: Array[String] = []
	if bank is String:
		out.append(bank)
	elif bank is Dictionary:
		for key in bank:
			out.append_array(_every_line(bank[key]))
	elif bank is Array:
		# A [speaker, line] pair is two strings; only the second is said.
		if bank.size() == 2 and bank[0] is String and bank[1] is String \
				and (bank[0] == Commentary.DAN or bank[0] == Commentary.AISHA):
			out.append(String(bank[1]))
		else:
			for item in bank:
				out.append_array(_every_line(item))
	return out


# --- the choosing ------------------------------------------------------------------

func _choose() -> void:
	var fresh := Career.new()
	_expect(Commentary.tone_from_career(fresh) == Commentary.Tone.WARM, "a new career starts WARM")
	_expect(Commentary.opening_for(fresh, "School hall", Career.BADMINTON) == "first",
		"a new career gets the first-match opening")
	var thrown_off := _career_with_a_past(Career.BADMINTON, true, 0.9)
	_expect(Commentary.tone_from_career(thrown_off) == Commentary.Tone.DOUBTING,
		"taken off last time starts DOUBTING")
	_expect(Commentary.opening_for(thrown_off, "District championship", Career.BADMINTON)
		== "removed_last_time", "taken off last time is mentioned")
	var middling := _career_with_a_past(Career.BADMINTON, false, 0.7)
	_expect(Commentary.tone_from_career(middling) == Commentary.Tone.WATCHFUL,
		"reputation 70 starts WATCHFUL")
	var up := _career_with_a_past(Career.TENNIS, false, 0.9)
	_expect(Commentary.opening_for(up, "State open", Career.TENNIS) == "promoted",
		"a new venue in the same sport is a promotion")
	_expect(Commentary.tone_for(Commentary.Tone.WARM, Suspicion.Mood.HOSTILE)
		== Commentary.Tone.DAMNING, "a hostile hall makes them DAMNING")
	_expect(Commentary.tone_for(Commentary.Tone.DOUBTING, Suspicion.Mood.SETTLED)
		== Commentary.Tone.DOUBTING, "a settled hall does not wipe their memory")

	# The rule, as behaviour. Over many tries, a wrong call nobody could see must draw what
	# a right call draws, whatever else is the same — here, nothing at all.
	var box := Commentary.new()
	add_child(box)
	var said := {"n": 0}
	box.spoke.connect(func(_s: String, _l: String) -> void: said.n += 1)
	for i in 200:
		box.stop()
		box.on_call(0.05, Suspicion.Mood.SETTLED, true, 0.5, false, false)
	var invisible_lie: int = said.n
	said.n = 0
	for i in 200:
		box.stop()
		box.on_call(0.05, Suspicion.Mood.SETTLED, false, 0.5, false, false)
	var honest: int = said.n
	said.n = 0
	for i in 200:
		box.stop()
		box.on_call(0.9, Suspicion.Mood.SETTLED, false, 0.5, false, false)
	var plain_and_right: int = said.n
	said.n = 0
	for i in 20:
		box.stop()
		box.on_call(0.9, Suspicion.Mood.SETTLED, true, 0.5, false, false)
	var plain_lie: int = said.n
	print("said something: invisible lie %d/200, honest %d/200, plain and right %d/200, plain lie %d/20"
		% [invisible_lie, honest, plain_and_right, plain_lie])
	_expect(invisible_lie == 0 and honest == 0 and plain_and_right == 0,
		"nothing is said about a call the hall had no complaint about")
	_expect(plain_lie == 20, "a call the whole hall saw is always remarked on")

	# Coming round softens them by a step.
	box.base_tone = Commentary.Tone.DOUBTING
	box.stop()
	box.on_call(0.0, Suspicion.Mood.SETTLED, false, 0.5, false, true)
	_expect(box.base_tone == Commentary.Tone.WATCHFUL, "the room coming round softens them a step")
	box.queue_free()


func _career_with_a_past(sport_name: StringName, removed: bool, reputation: float) -> Career:
	var career := Career.new()
	career.sport = sport_name
	career.reputation = reputation
	career.matches_refereed = 4
	career.times_removed = 1 if removed else 0
	career.history = [{
		"sport": String(sport_name), "venue": "Club courts" if sport_name == Career.TENNIS else "School hall",
		"removed": removed, "reputation": reputation,
	}]
	return career


func _expect(ok: bool, what: String) -> void:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_problems.append(what)


# --- on air ------------------------------------------------------------------------

func _on_air(name: String, scene: String, sport_name: StringName) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = _career_with_a_past(sport_name, true, 0.6)
	for flag in ["taught", "taught_beach", "taught_indoor", "taught_tennis", "taught_table_tennis"]:
		arena.settings.set(flag, true)
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		arena.ui.hide_briefing()
		await get_tree().process_frame
	arena.begin_match()
	for f in 3:
		await get_tree().process_frame
	var showing: String = arena.ui.commentary_showing()
	print("=== %s: %s" % [name, showing])
	if showing.is_empty():
		_problems.append("%s: nothing on air when the match began" % name)
	elif not (showing.contains("remember") or showing.contains("last match")):
		_problems.append("%s: the opening forgot the umpire was taken off: %s" % [name, showing])
	var caption: Control = arena.ui._commentary
	if caption == null or not arena.ui._hud.is_ancestor_of(caption):
		_problems.append("%s: the caption is not on the HUD" % name)
	else:
		# Headless windows are 64 px square, so "on screen" cannot be asked here; that is
		# what dev/looks/_commentaryshot is for. What can be asked is that the caption hangs
		# off the bottom-left corner of the HUD, whatever size the HUD turns out to be.
		var hud: Rect2 = arena.ui._hud.get_global_rect()
		var box: Rect2 = caption.get_global_rect()
		var bottom_ok := is_equal_approx(box.end.y, hud.end.y - RefereeUI.COMMENTARY_LIFT)
		var left_ok := is_equal_approx(box.position.x, hud.position.x + RefereeUI.REASON_INSET)
		if not (bottom_ok and left_ok):
			_problems.append("%s: the caption is not hung from the bottom-left corner: %s in %s" % [name, box, hud])
	var official: String = Commentary.official_for(sport_name)
	# Two lines of an exchange: wait for the second and see it is the other speaker.
	var first_speaker := showing.get_slice(":", 0)
	var since := Time.get_ticks_msec()
	var second := ""
	while Time.get_ticks_msec() - since < 9000:
		await get_tree().process_frame
		var now: String = arena.ui.commentary_showing()
		if not now.is_empty() and now.get_slice(":", 0) != first_speaker:
			second = now
			break
	print("    then %s" % second)
	if second.is_empty():
		_problems.append("%s: the opening never got its second voice" % name)
	if (showing + second).contains("an referee") or ((showing + second).contains("umpire") and official == "referee"):
		_problems.append("%s: the wrong title for the official: %s / %s" % [name, showing, second])
	var word: String = arena.commentary.last_word(true, Suspicion.Mood.WARNED)
	if not word.contains("Aisha Karim"):
		_problems.append("%s: the last word is unsigned: %s" % [name, word])
	arena.queue_free()
	await get_tree().process_frame
