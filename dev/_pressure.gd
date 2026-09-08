extends Node

## Do the four reasons to lie actually behave like reasons?
##
## Three things to check. That a pressure turns up about as often as it should for the
## rung of the ladder you are on. That satisfying one does what it says it does to a
## career. And — the one that matters most — that the honest route is still open: an
## umpire who never cheats must be able to be thanked, promoted and left alone, because
## the whole design rests on the reward being for the result rather than for the lie.

func _ready() -> void:
	_how_often()
	print()
	_what_they_do()
	print()
	_honesty_still_pays()
	print()
	_the_grudge_comes_back()
	get_tree().quit()


## A pressure should be rare at the bottom and near-constant at the top.
func _how_often() -> void:
	print("how often a match comes with a reason attached")
	print("%-26s %-8s %s" % ["venue", "expected", "measured"])
	for tier in Career.LADDER.size():
		var seen := 0
		var kinds := {}
		for run in 400:
			var career := Career.new()
			career.tier = tier
			career.matches_at_tier = int(Career.LADDER[tier]["matches_needed"]) - 1
			var pressure := Pressure.for_match(career)
			if pressure.exists():
				seen += 1
				kinds[pressure.kind] = int(kinds.get(pressure.kind, 0)) + 1
		print("%-26s %-8.2f %.2f   %s" % [
			Career.LADDER[tier]["name"],
			Pressure.CHANCE_BY_TIER[tier],
			float(seen) / 400.0,
			_kind_counts(kinds),
		])


func _kind_counts(kinds: Dictionary) -> String:
	var parts: Array[String] = []
	for kind in kinds:
		parts.append("%s %d" % [_kind_name(kind), int(kinds[kind])])
	parts.sort()
	return ", ".join(parts)


func _kind_name(kind: int) -> String:
	match kind:
		Pressure.Kind.TOURNAMENT: return "tournament"
		Pressure.Kind.PROMOTION: return "promotion"
		Pressure.Kind.GRUDGE: return "grudge"
		Pressure.Kind.DEBT: return "debt"
	return "none"


## What each outcome costs or buys.
func _what_they_do() -> void:
	print("what each pressure does to a career")
	print("%-12s %-10s %-9s %-9s %-7s %s" % [
		"pressure", "outcome", "matches", "panel", "rep", "line"])

	for kind in [Pressure.Kind.TOURNAMENT, Pressure.Kind.PROMOTION, Pressure.Kind.GRUDGE,
			Pressure.Kind.DEBT]:
		for satisfied in [true, false]:
			var career := Career.new()
			career.tier = 2
			career.matches_at_tier = 2
			career.grudge_name = "Halim"
			career.grudge_reason = "Something happened."

			var pressure := Pressure.new()
			pressure.kind = kind
			pressure.who = "Halim"
			pressure.wants = Sides.Team.RED
			pressure.watched = Sides.Team.BLUE
			pressure.outcome = Pressure.Outcome.SATISFIED if satisfied else Pressure.Outcome.DEFIED
			# Worst case for the grudge: the umpire leaned the way the grudge wanted.
			pressure.leaned = Sides.Team.RED

			var lines: Array[String] = []
			var change: float = pressure.apply_to(career, lines)
			print("%-12s %-10s %-9d %-9s %+.2f   %s" % [
				_kind_name(kind),
				"satisfied" if satisfied else "defied",
				career.matches_at_tier,
				"yes" if career.panel_impressed else "no",
				change,
				lines[0].substr(0, 52) if lines.size() > 0 else "",
			])


## The point of the whole system: a spotless umpire is not being punished for it.
##
## Two careers, side by side, both refereeing perfectly. One is never leaned on; the
## other is leaned on every match and simply ignores it. If the second one climbs more
## slowly than the first, then the game is charging for honesty and the design is wrong.
func _honesty_still_pays() -> void:
	print("ten clean matches, refereed honestly")
	print("%-24s %-6s %-6s %s" % ["", "tier", "rep", "note"])

	for leaned_on in [false, true]:
		var career := Career.new()
		for match_number in 10:
			var pressures: Array = []
			if leaned_on:
				var pressure := Pressure.for_match(career)
				if pressure.exists():
					# An honest umpire, so the result is whatever it was going to be.
					pressure.outcome = (Pressure.Outcome.SATISFIED if randf() < 0.5
						else Pressure.Outcome.DEFIED)
					pressure.leaned = Sides.Team.NONE
					pressures.append(pressure)
			# Suspicion 0.02: a couple of close ones taken slowly. Nobody is perfect.
			# Nothing is saved: this harness must not overwrite a real career file.
			career.finish_match(0.02, false, pressures)

		print("%-24s %-6d %-6.2f %s" % [
			"leaned on" if leaned_on else "left alone",
			career.tier,
			career.reputation,
			"grudge: %s" % career.grudge_name if not career.grudge_name.is_empty() else "",
		])


## The loop that makes any of this more than flavour text.
##
## Referee one match badly enough and a player remembers your name. The next match you
## are handed them, with a reason to want them to lose, and if you take it you are
## charged for it and walk out with a fresh enemy. A bad night should be able to become
## a habit without anybody ever offering you money.
func _the_grudge_comes_back() -> void:
	print("does a bad match follow you into the next one")

	var career := Career.new()
	# One visibly bent match: three rallies taken off the same side.
	career.finish_match(0.30, false, [])
	career.remember_grudge("Wibowo", 4, 3, -0.62)
	print("  after a bent match, grudge: %s" % (
		career.grudge_name if not career.grudge_name.is_empty() else "none"))

	# It should now be the reason for the next match, every time, at any tier.
	var came_back := 0
	for run in 200:
		if Pressure.for_match(career).kind == Pressure.Kind.GRUDGE:
			came_back += 1
	print("  turns up as the next match's reason: %d of 200" % came_back)

	var pressure := Pressure.for_match(career)
	print("  reads as: %s" % pressure.detail)

	# Settle it by leaning on the match, and it should cost, clear, and be replaceable.
	pressure.outcome = Pressure.Outcome.SATISFIED
	pressure.leaned = pressure.wants
	var lines: Array[String] = []
	var change: float = pressure.apply_to(career, lines)
	career.remember_grudge("Larsen", 4, 3, -0.62)
	print("  settling it cost %+.2f, and left: %s" % [
		change, career.grudge_name if not career.grudge_name.is_empty() else "nobody"])

	# And an honest match against them should clear it with no charge at all.
	var clean := Career.new()
	clean.remember_grudge("Okafor", 4, 3, -0.62)
	var second := Pressure.for_match(clean)
	second.outcome = Pressure.Outcome.SATISFIED
	second.leaned = Sides.Team.NONE
	var clean_lines: Array[String] = []
	var clean_change: float = second.apply_to(clean, clean_lines)
	clean.remember_grudge("Kwan", 0, 0, 0.0)
	print("  beating them honestly cost %+.2f, and left: %s" % [
		clean_change, clean.grudge_name if not clean.grudge_name.is_empty() else "nobody"])
