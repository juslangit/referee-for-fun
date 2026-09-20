extends Node

## One official, several ladders.
##
## The rule Luqman chose: your reputation is yours and follows you everywhere, but you
## climb each sport separately. So a disaster at the beach should be waiting for you at
## the badminton hall, while the rung you had reached in badminton should be untouched.
## And an old save, from before there was more than one sport, has to come back as a
## badminton career rather than as an empty one.
##
## All of that was printed and none of it was asserted, so the numbers that prove the rule
## sat in a column for a reader to check by eye. They are checked here now.

var _failures: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)

func _ready() -> void:
	_one_reputation_many_ladders()
	print()
	_the_old_save_still_opens()
	print()
	_each_ladder_is_its_own()
	print("")
	if _failures.is_empty():
		print("PASS  one reputation, and a ladder each")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()


func _one_reputation_many_ladders() -> void:
	print("refereeing badminton badly, then turning up at the beach")
	var career := Career.new()

	career.sport = Career.BADMINTON
	var started_with := career.reputation
	for i in 3:
		career.finish_match(0.42, false, [])
	var after_badminton := career.reputation
	var badminton_tier := career.tier
	var badminton_matches := career.matches_at_tier
	print("  after three bad badminton matches: reputation %.2f, badminton tier %d" % [
		after_badminton, badminton_tier])
	_expect(after_badminton < started_with,
		"refereeing badly costs reputation (%.2f from %.2f)" % [after_badminton, started_with])

	career.sport = Career.BEACH
	print("  switching to beach:                reputation %.2f, beach tier %d" % [
		career.reputation, career.tier])
	print("  the beach venue is:                %s" % career.venue()["name"])
	_expect(is_equal_approx(career.reputation, after_badminton),
		"and the reputation follows you to the beach — one name, not one per sport")
	_expect(career.tier == 0,
		"while the beach ladder starts at the bottom whatever badminton did (tier %d)" % career.tier)

	career.sport = Career.BADMINTON
	print("  and badminton is where it was:     tier %d, %d matches at it" % [
		career.tier, career.matches_at_tier])
	_expect(career.tier == badminton_tier and career.matches_at_tier == badminton_matches,
		"and going back to badminton finds its rung untouched")


func _the_old_save_still_opens() -> void:
	print("a save written before there was a second sport")
	# Exactly the shape the game used to write.
	var old := {
		"tier": 2,
		"reputation": 0.71,
		"matches_at_tier": 1,
		"matches_refereed": 8,
		"times_removed": 0,
		"is_over": false,
		"grudge_name": "Wibowo",
		"grudge_reason": "Something happened.",
		"panel_impressed": true,
	}
	var file := FileAccess.open(Career.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old, "\t"))
	file = null

	var career := Career.load_or_start()
	print("  sport %s, tier %d, matches %d, panel %s, reputation %.2f, grudge %s" % [
		career.sport, career.tier, career.matches_at_tier,
		"yes" if career.panel_impressed else "no", career.reputation, career.grudge_name])
	print("  beach, untouched:  tier %d" % _tier_of(career, Career.BEACH))
	_expect(career.sport == Career.BADMINTON,
		"a save from before the second sport opens as badminton, not as nothing")
	_expect(_tier_of(career, Career.BEACH) == 0,
		"and the sports it never knew about start at the bottom")

	# And it must survive a round trip in the new format.
	career.sport = Career.BEACH
	career.tier = 1
	career.save()
	var again := Career.load_or_start()
	print("  saved and reopened: badminton tier %d, beach tier %d, sport %s" % [
		_tier_of(again, Career.BADMINTON), _tier_of(again, Career.BEACH), again.sport])
	_expect(_tier_of(again, Career.BEACH) == 1 and again.sport == Career.BEACH,
		"and a round trip through the new format keeps both ladders and which sport you are in")

	# Leave nothing behind: this harness must not overwrite a real career.
	Career.start_again()


func _tier_of(career: Career, which: StringName) -> int:
	var was := career.sport
	career.sport = which
	var found := career.tier
	career.sport = was
	return found


func _each_ladder_is_its_own() -> void:
	print("the two ladders")
	print("%-6s %-26s %-9s %-7s %s" % ["rung", "badminton", "scrutiny", "|", "beach"])
	for i in Career.BADMINTON_LADDER.size():
		print("%-6d %-26s %-9.2f %-7s %s" % [
			i + 1,
			Career.BADMINTON_LADDER[i]["name"],
			Career.BADMINTON_LADDER[i]["scrutiny"],
			"|",
			Career.BEACH_LADDER[i]["name"],
		])
