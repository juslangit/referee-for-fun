extends Node

## Which sports quietly do not inherit what the spine gives them?
##
## This exists because the same bug has now been found three times in two days, by hand,
## each time by chasing something unrelated:
##
##   * badminton never overrode `current_rally()`, so for a fortnight `judge()` returned
##     at its null check and every call the game's first sport made was thrown away —
##     no verdict, no suspicion, no reputation, no point.
##   * `ui.chair_camera` was set in `OfficiatedMatch.begin_match()`, which badminton
##     never runs, so the crowd bubble worked in four sports and silently did nothing in
##     the fifth.
##   * and `net_height()` was read as an absolute height by four sports for whom the
##     playing surface *is* the ground, which hid the error until table tennis.
##
## Every one of them was invisible: no crash, no wrong number, just a feature that was
## not there. There are five sports and one spine, and until now nothing looked for the
## next one. This reads the source of all six files and reports two things.

const SPINE := "res://scripts/officiated_match.gd"
const SPORTS := {
	"badminton": "res://scripts/match.gd",
	"beach volleyball": "res://scripts/beach_match.gd",
	"indoor volleyball": "res://scripts/volley_match.gd",
	"tennis": "res://scripts/tennis_match.gd",
	"table tennis": "res://scripts/table_tennis_match.gd",
}

## Hooks a sport is free to leave alone, with the reason. A stub nobody overrides is
## usually a bug; these are the ones where it is the answer.
## Replacements that exist today, recorded so that a *new* one fails.
##
## This list is a baseline, not a review. Each of these was in the project on
## 2026-09-10 and the game works; the note beside it says what it is, not that somebody
## has checked it is right. What the list is for is the next one: a sport that starts
## replacing a piece of spine behaviour without saying so is exactly how
## `ui.chair_camera` came to work in four sports and not the fifth, and with this list
## in place that arrives as a failed check on the day it is written instead of as a
## puzzle three weeks later.
##
## Removing an entry is how you review one. If a sport no longer needs to replace the
## spine, delete the line and the check will tell you if you were wrong.
##
## All nine were reviewed on 2026-09-10 and three of them turned out to be duplication
## rather than difference. `indoor volleyball/nearest_of` was byte-identical to the
## spine's and is deleted. `badminton/_reckoning` differed from fifteen identical lines
## by one word — "games" where the spine says "sets" — and is now a two-line
## `score_line()` override, which is what that hook was put on the spine for.
## `badminton/_announce_after_a_beat` repeated seven lines so that one of them could read
## the judge's call off the rally instead of off the match; the spine asks
## `judge_said_in()` now and badminton answers it in two lines.
const REPLACEMENTS_UNDERSTOOD := {
	"badminton/_ready": "badminton owns the front of the game: title, sport menu, settings, lesson",
	"badminton/_on_match_requested": "the same — it is a match and a main menu at once",
	"badminton/set_line_judges_present": "keeps a full set in _all_line_judges and filters it; the spine's loop would find an empty list",
	"badminton/judge_watching": "adds the guard that nobody judges a shuttle that never crossed the net",
	"badminton/score_line": "badminton counts games where the spine counts sets; this is the hook working as intended",
	"badminton/price_the_call": "reaches the same arithmetic by suspicion.register(rally)",
	"badminton/who_would_challenge": "delegates to Challenge.challenger(); the spine computes closeness inline. Two implementations of one idea, and they could still converge",
}

## How many lines of spine behaviour count as worth inheriting. Below this it is a
## default or a one-liner, and replacing it wholesale is ordinary.
const SUBSTANTIAL := 2

const OPTIONAL := {
	"before_pricing": "only badminton keeps faults on the match",
	"build_the_venue": "badminton owns the front of the game and builds its hall in _ready",
	"dress_the_venue": "the same — badminton dresses its hall alongside building it",
	"record_the_line_judge": "badminton writes it at the landing instead",
	"line_judge_spots": "table tennis has no line judges at all",
	"the_stands": "a sport with no seating simply never has anybody speak",
	"enter_ready": "the prompt line, which some sports set elsewhere",
	"score_line": "only sports that call a game something else need it",
	"net_clearance": "most sports are happy with the default daylight",
}


func _ready() -> void:
	var spine := _functions(SPINE)
	var bad := 0
	bad += _stubs_nobody_fills(spine)
	bad += _replaced_without_super(spine)
	_odd_one_out(spine)
	print("")
	if bad == 0:
		print("every sport inherits what the spine gives it")
	else:
		print("%d PROBLEM(S) — see above" % bad)
	get_tree().quit()


## A stub on the spine that a sport never fills in. This is the `current_rally` bug: the
## spine answers null, null is a legitimate answer, and nothing anywhere says the sport
## meant to say something else.
func _stubs_nobody_fills(spine: Dictionary) -> int:
	print("stubs on the spine that a sport never fills in")
	var bad := 0
	var sports := {}
	for name: String in SPORTS:
		sports[name] = _functions(SPORTS[name])

	for fn: String in spine:
		if not spine[fn]["is_stub"]:
			continue
		var missing: Array[String] = []
		for name: String in sports:
			if not sports[name].has(fn):
				missing.append(name)
		if missing.is_empty():
			continue
		if OPTIONAL.has(fn):
			print("   %-24s not in %-46s (fine: %s)" % [
				fn, ", ".join(missing), OPTIONAL[fn]])
			continue
		print("   %-24s NOT OVERRIDDEN BY %s   <-- the current_rally shape" % [
			fn, ", ".join(missing)])
		bad += 1
	return bad


## A sport that redefines something the spine actually does, without calling super().
##
## Not wrong in itself — plenty of overrides mean to replace rather than extend — but it
## is the shape that hid `chair_camera`, because anything later added to the spine's
## version is added to a function that sport never runs. Every one of these is a place a
## future line will silently not apply.
func _replaced_without_super(spine: Dictionary) -> int:
	print("")
	print("sports that replace spine behaviour instead of extending it")
	var bad := 0
	for name: String in SPORTS:
		var mine := _functions(SPORTS[name])
		for fn: String in mine:
			if not spine.has(fn) or spine[fn]["is_stub"]:
				continue
			if mine[fn]["calls_super"]:
				continue
			# A one-line `return <value>` is a default, and overriding a default is the
			# whole point of having one — `net_height` is answered by five sports with
			# five numbers and none of them wants the spine's. Only a substantial
			# implementation being replaced is worth reporting, because only that has
			# room for a line somebody will add later and expect every sport to run.
			if spine[fn]["lines"] <= SUBSTANTIAL:
				continue
			var key := "%s/%s" % [name, fn]
			if REPLACEMENTS_UNDERSTOOD.has(key):
				print("   %-18s %-24s known: %s" % [
					name, fn, REPLACEMENTS_UNDERSTOOD[key]])
				continue
			print("   %-18s %-24s replaces %d lines of spine, no super()   <-- NEW" % [
				name, fn, spine[fn]["lines"]])
			bad += 1
	if bad == 0:
		print("   nothing new since the list above was written")
	return bad


## Every top-level function in a script, with what its body looks like.
func _functions(path: String) -> Dictionary:
	var out := {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("could not read %s" % path)
		return out

	var name := ""
	var body: Array[String] = []
	for raw: String in text.split("\n"):
		if raw.begins_with("func "):
			if name != "":
				out[name] = _describe(body)
			name = raw.substr(5, raw.find("(") - 5).strip_edges()
			body = []
			continue
		if raw.begins_with("#") or (not raw.is_empty() and not raw.begins_with("\t")):
			# Back at column zero: a constant, a var or a comment between functions.
			if name != "":
				out[name] = _describe(body)
				name = ""
			continue
		if name != "":
			body.append(raw)
	if name != "":
		out[name] = _describe(body)
	return out


func _describe(body: Array[String]) -> Dictionary:
	var real: Array[String] = []
	var calls_super := false
	for line: String in body:
		var bare := line.strip_edges()
		if bare.is_empty() or bare.begins_with("#"):
			continue
		if bare.contains("super"):
			calls_super = true
		real.append(bare)
	# A stub is `pass`, or a bare `return null` — the spine saying "a sport is meant to
	# answer this" and nothing else.
	#
	# `return <a real value>` is deliberately NOT a stub, and getting that wrong made the
	# first version of this scene useless: it read `func sport(): return Career.BADMINTON`
	# and `func net_height(): return 2.43` as unanswered hooks and reported fourteen
	# problems, most of them sports correctly accepting a working default. A default that
	# is right for four sports and wrong for the fifth is a different and quieter
	# problem, and it is reported separately below.
	var only := real[0] if real.size() == 1 else ""
	var is_stub := real.is_empty() or (real.size() == 1
		and (only == "pass" or only == "return null" or only == "return"))
	var is_default := real.size() == 1 and only.begins_with("return") and not is_stub
	return {
		"lines": real.size(), "is_stub": is_stub, "is_default": is_default,
		"calls_super": calls_super,
	}


## A one-line default on the spine that every sport but one overrides.
##
## Every row here is currently badminton, and that is by design rather than a finding:
## the spine grew out of badminton, so its defaults *are* badminton's answers and
## badminton is the one sport with no reason to restate them. The row worth reading is
## the day a different sport appears in this column.
##
## Reported rather than failed, because there is no way to tell from the source whether
## the odd one out is content with the default or has simply never asked for it. But it
## is the shape of the quietest bug in this project: `net_height()` returned indoor
## volleyball's 2.43 m and badminton was the only sport not overriding it, so badminton
## was carrying a volleyball net in a method nothing happened to call. Anything on this
## list is worth two minutes.
func _odd_one_out(spine: Dictionary) -> void:
	print("")
	print("defaults that all but one sport overrides")
	var sports := {}
	for name: String in SPORTS:
		sports[name] = _functions(SPORTS[name])

	var found := false
	for fn: String in spine:
		if not spine[fn]["is_default"]:
			continue
		var missing: Array[String] = []
		for name: String in sports:
			if not sports[name].has(fn):
				missing.append(name)
		if missing.size() != 1:
			continue
		found = true
		print("   %-24s every sport answers this except %s" % [fn, missing[0]])
	if not found:
		print("   none")
