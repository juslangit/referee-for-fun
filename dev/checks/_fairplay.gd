extends Node

## Play a long match calling nothing but the truth, and see what the game thinks of you.
##
## The bounds this run is judged against. They are wide on purpose: this scene is not
## trying to pin down the game's balance, it is trying to notice when the game has
## stopped working at all — a match with one stroke a rally is not being played, and a
## match with no offences in it has nothing to referee.

## How many rallies a run needs before its rates mean anything.
const ENOUGH_RALLIES := 15

## Strokes a rally, at the extremes. `_badmintonplay` sits between 5.6 and 7.2.
const FEWEST_STROKES := 3.0
const MOST_STROKES := 12.0

## Where an umpire who called everything correctly must still be, comfortably short of
## the warning at 0.80. Not zero: the LINES-ONLY umpire deliberately does not call
## offences or service court errors and is charged lightly for sitting through them.
const HONEST_UMPIRE_CEILING := 0.40

## And where the PERFECT umpire must be, which is a harder bar because that umpire calls
## the lines, every offence and every service court error.
##
## Not zero, and the reason is the most interesting number this scene produces. A perfect
## umpire finishes a full match at about 0.12, and every bit of it is
## `OVERRULE_ON_ITS_OWN` — 0.03 a time for contradicting a line judge who was wrong, in
## front of a hall that cannot see you were right. That is designed (see the constant's
## own note) rather than a fault in the scoring: an umpire who is correct about
## everything still ends the night roughly a seventh of the way to a warning for being
## publicly correct, and recovers it over the following match.
##
## The bar sits at 0.25 so that the designed cost passes and a doubling of it does not.
const PERFECT_UMPIRE_CEILING := 0.25

## How often even the perfect umpire may be scored wrong. Not zero, because a shuttle
## that never crossed the net is a fault whatever the lines say and this umpire calls
## the lines.
const PERFECT_MAY_BE_WRONG := 2
##
## Luqman reports being marked unfair while calling every in and out correctly. This
## makes exactly that umpire — one who looks at where the shuttle landed, says so, and
## never lies — and reports every rally the game scored as WRONG, with the reason.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	arena.ui.career_screen_requested.emit()
	await get_tree().process_frame
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	arena.begin_match()

	var judged := 0
	var wrong := 0
	var recorded_nothing := 0
	var with_offence := 0
	var strokes := 0
	var reasons := {}
	# Where the suspicion came from, so a number that looks bad can be read rather than
	# argued about. This harness runs far slower than real time, so without accounting
	# for it separately the game's hesitation charge — which is measured on the wall
	# clock — turns up in the total and looks like a rules bug.
	var dithered := 0.0
	var missed_courts := 0
	# How often the umpire's own eyes disagreed with a line judge in public. This is the
	# whole of what a perfect umpire is still charged, and without counting it the
	# residual looks like an unexplained penalty for doing the job correctly.
	var overruled := 0
	for frame in 60000:
		await get_tree().process_frame
		if arena._phase == arena.Phase.READY:
			arena.start_rally()
			continue
		if arena._phase != arena.Phase.AWAITING_CALL:
			continue

		var rally: Rally = arena.rally
		if arena.service_error != Sides.Team.NONE:
			# The perfect umpire calls this too, which it did not until now, and that
			# omission was most of what this scene could not certify. A service court
			# error is priced at 0.05 for sitting through, so a run where the AI lined
			# up wrong eight times charged an umpire who was right about everything
			# 0.40 and a run where it did it once charged 0.05 — and the "perfect"
			# umpire's final suspicion was mostly a measure of how often the players
			# stood in the wrong box. Three runs came back at 0.081, 0.218 and 0.405
			# before this line existed.
			if OS.get_environment("UMPIRE") == "perfect":
				arena._call_service_court(arena._phase == arena.Phase.READY)
			else:
				missed_courts += 1
		var landed_inside := CourtSpec.is_in(rally.landing_point, rally.doubles)
		strokes += arena._shots_this_rally
		if rally.incident.happened():
			with_offence += 1

		# Two umpires, chosen by an environment switch. LINES calls only what it sees
		# on the floor. PERFECT also spots every offence, correctly, every time — an
		# impossible standard, and the point: if even that umpire accrues suspicion,
		# the fault is in the scoring rather than in the player.
		if OS.get_environment("UMPIRE") == "perfect" and rally.incident.happened():
			# Every offence in the book, including the three service faults. A
			# dictionary that only knew the original four crashed the moment one of the
			# new ones came up — an umpire who does not know a rule cannot be the
			# yardstick for whether the rules are fair.
			var names := {
				Incident.Kind.NET_TOUCH: &"net_touch",
				Incident.Kind.CARRY: &"carry",
				Incident.Kind.DOUBLE_HIT: &"double_hit",
				Incident.Kind.OBSTRUCTION: &"obstruction",
				Incident.Kind.SERVICE_TOO_HIGH: &"serve_too_high",
				Incident.Kind.SERVICE_RACKET_UP: &"serve_racket_up",
				Incident.Kind.SERVICE_FEET: &"serve_feet",
			}
			var fault: StringName = names.get(rally.incident.kind, &"in")
			arena.make_call(fault, rally.incident.by)
		else:
			arena.make_call(&"in" if landed_inside else &"out")
		judged += 1
		if rally.line_judge_called and rally.line_judge_said_in != landed_inside:
			overruled += 1
		dithered += Suspicion.hesitation_cost(rally.seconds_to_call) * arena.suspicion.scrutiny
		# A call that reached nothing. This is the shape of the bug that let badminton
		# throw away every call it made for a fortnight while a harness printed a clean
		# sheet, and it costs one line to refuse to repeat it.
		if rally.verdict() == Rally.Verdict.NO_CALL:
			recorded_nothing += 1

		if rally.verdict() == Rally.Verdict.WRONG:
			wrong += 1
			var why := "landed %s, called %s" % [
				"IN" if landed_inside else "OUT", "IN" if landed_inside else "OUT"]
			if not rally.crossed_the_net:
				why = "shuttle never crossed the net (landed inside: %s)" % landed_inside
			elif rally.incident.happened():
				why = "an offence had already happened: %s" % rally.incident.kind
			reasons[why] = int(reasons.get(why, 0)) + 1

		for f in 18:
			await get_tree().process_frame
		if judged >= 45 or arena.board.is_over:
			break

	print("umpire: %s" % ("PERFECT (calls every fault too)" if OS.get_environment("UMPIRE") == "perfect" else "LINES ONLY (calls in and out correctly)"))
	print("rallies judged: %d   (%.1f strokes each on average)" % [
		judged, float(strokes) / maxf(1.0, float(judged))])
	print("rallies with an offence in them: %d  (%.0f%%)" % [
		with_offence, 100.0 * float(with_offence) / maxf(1.0, float(judged))])
	print("scored WRONG:   %d  (%.0f%%)" % [wrong, 100.0 * float(wrong) / maxf(1.0, float(judged))])
	print("suspicion:      %.3f   (warning at %.2f, removed at %.2f)" % [
		arena.suspicion.level, Suspicion.WARNING_LEVEL, Suspicion.REMOVAL_LEVEL])
	# Gross charges and the recovery separately, never subtracted from each other.
	#
	# The old breakdown took the components off `suspicion.level` and called the
	# remainder "what the rules actually charged" — but `level` is a **net** figure:
	# every correct call hands some of it back, and the total is floored at zero. So a
	# perfect umpire who was charged 0.098 for three service court errors and then
	# recovered all of it printed a left-over of **-0.098**, which is not a number
	# suspicion can hold and told the reader something false about a run that was fine.
	var sat_through: float = (float(missed_courts) * Suspicion.MISSED_SERVICE_COURT
		* arena.suspicion.scrutiny)
	print("   charged along the way")
	print("      the harness's own slowness (hesitation)      %.3f" % dithered)
	print("      service court errors it sat through          %.3f  (%d of them)" % [
		sat_through, missed_courts])
	print("      line judges overruled in public               %.3f  (%d of them)" % [
		float(overruled) * Suspicion.OVERRULE_ON_ITS_OWN * arena.suspicion.scrutiny,
		overruled])
	print("   handed back by correct calls, up to             %.3f  (%d of them, at %.3f each)" % [
		float(judged - wrong) * Suspicion.RECOVERY_PER_CORRECT_CALL,
		judged - wrong, Suspicion.RECOVERY_PER_CORRECT_CALL])
	print("   the level above is what is left of that, floored at zero")
	for why in reasons:
		print("   %-58s %d" % [why, reasons[why]])

	print("")
	print(_verdict(arena, judged, wrong, with_offence, strokes, recorded_nothing))
	get_tree().quit()


## Whether this run proves anything, which until now it did not.
##
## This scene has always printed numbers and left the reader to decide, and it was
## recorded in the project notes on 2026-09-10 as unable to certify anything — it had
## reported 1.0, 3.0, 8.0 and 10.0 strokes a rally from identical code inside an hour,
## and zero offences over forty-five rallies at a rate that should have produced nine.
##
## That pathology does **not** reproduce on today's code: five consecutive runs came back
## at 5.6 to 7.1 strokes a rally with offences at 5 to 11 per cent, and deliberately
## putting back the `begin_match` that was fixed the same morning did not bring it back
## either. So the cause is unknown and may already be gone. What is certain is that a
## scene which only prints cannot tell anybody when it returns, which is the half of the
## problem that can be fixed by writing it down. Every number the old report left to
## judgement is now a stated bound, and a run outside one says so.
func _verdict(arena: Node, judged: int, wrong: int, with_offence: int,
		strokes: int, recorded_nothing: int) -> String:
	var perfect := OS.get_environment("UMPIRE") == "perfect"
	var failures: Array[String] = []

	if judged < ENOUGH_RALLIES:
		failures.append("only %d rallies were judged; %d are needed to mean anything"
			% [judged, ENOUGH_RALLIES])

	if recorded_nothing > 0:
		failures.append("%d call(s) recorded nothing at all" % recorded_nothing)

	var per_rally := float(strokes) / maxf(1.0, float(judged))
	if per_rally < FEWEST_STROKES or per_rally > MOST_STROKES:
		failures.append("%.1f strokes a rally is outside %.0f-%.0f; the rallies are not being played"
			% [per_rally, FEWEST_STROKES, MOST_STROKES])

	# Zero offences over a full match is the specific number this scene once reported and
	# nobody could act on. An offence is meant to be a notable event rather than a
	# twice-a-game occurrence (D-027), so the bar is one, not a rate.
	if judged >= ENOUGH_RALLIES and with_offence == 0:
		failures.append("not one offence in %d rallies; either the rate is broken or nothing is detecting them"
			% judged)

	# The question the scene exists to answer. An umpire who calls everything correctly
	# must not be run towards the warning by the scoring itself.
	var ceiling := PERFECT_UMPIRE_CEILING if perfect else HONEST_UMPIRE_CEILING
	if arena.suspicion.level >= ceiling:
		failures.append("a%s umpire finished on %.3f, at or past the ceiling of %.2f"
			% [" perfect" if perfect else "n honest", arena.suspicion.level, ceiling])

	# And the perfect umpire, who also calls every offence, is held to the harder bar.
	if perfect and wrong > PERFECT_MAY_BE_WRONG:
		failures.append("the perfect umpire was scored WRONG %d times; at most %d is expected"
			% [wrong, PERFECT_MAY_BE_WRONG])

	if failures.is_empty():
		return "PASS — an honest umpire was not punished, and the match was really played"
	var out := "%d PROBLEM(S)" % failures.size()
	for line: String in failures:
		out += "\n   %s" % line
	return out
