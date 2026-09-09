extends Node

## Can a legal serve still be played?
##
## The serve used to leave the racket at 2.45 m, which is a smash rather than a serve
## and made the whole service law unbuildable. It is now struck at 1.02 m, under the
## 1.15 m limit — so the first question is whether a shuttle hit from below the waist
## can still clear a 1.524 m net from three metres away and land in the service box.
##
## Then the law itself: an umpire who calls every service fault correctly must pay
## nothing, and one who invents them must pay a great deal.

## The badminton match has no class_name, so its constants are read off an instance
## rather than referenced statically.
var _serve_height := 1.02
var _serve_distance := 3.0


func _ready() -> void:
	_can_it_even_be_served()
	print()
	_three_ways()
	print()
	await _a_match_of_it()
	get_tree().quit()


## Each service fault called correctly, missed, and invented.
##
## The middle one is the one worth having: a harness that only checks the honest case is
## satisfied by a rulebook that charges nothing for anything, which is how both
## volleyballs went their whole lives without pricing a single lie.
func _three_ways() -> void:
	print("%-22s %-24s %-9s %s" % ["what happened", "what the umpire said", "verdict", "seen"])
	for kind in [Incident.Kind.SERVICE_TOO_HIGH, Incident.Kind.SERVICE_RACKET_UP,
			Incident.Kind.SERVICE_FEET]:
		_one_way(kind, _call_for(kind), "called it")
		_one_way(kind, &"in", "said IN, never saw it")
		_one_way(Incident.Kind.NONE, _call_for(kind), "invented it")
		print()


func _one_way(happened: Incident.Kind, said: StringName, what: String) -> void:
	var rally := Rally.new(Sides.Team.RED, true)
	rally.record_landing(Vector3(1.0, Court.SURFACE_Y, 4.0))
	if happened != Incident.Kind.NONE:
		rally.incident = Incident.new(happened, Sides.Team.RED, 0.6, Vector3.ZERO)
	rally.record_call(CallBook.get_call(said), Sides.Team.RED)
	print("%-22s %-24s %-9s %.2f" % [
		Incident.label(happened), what,
		"correct" if rally.verdict() == Rally.Verdict.CORRECT else "WRONG",
		rally.visibility()])


func _can_it_even_be_served() -> void:
	print("a serve struck at %.2f m, against a net %.3f m high" % [
		_serve_height, CourtSpec.NET_HEIGHT_CENTRE])
	print("%-10s %-12s %-10s %-12s %s" % [
		"angle", "target z", "speed", "at the net", "clears?"])

	var from := Vector3(0.0, _serve_height, -_serve_distance)
	for angle in [20.0, 30.0, 40.0, 50.0]:
		for target_z in [2.6, 4.2, 5.8]:
			var to := Vector3(0.5, Court.SURFACE_Y, target_z)
			var velocity := ShotSolver.solve(from, to, angle, Court.SURFACE_Y)
			if velocity == Vector3.ZERO:
				print("%-10.0f %-12.1f %-10s %-12s %s" % [
					angle, target_z, "-", "-", "UNSOLVED"])
				continue
			var flat := Vector2(to.x - from.x, to.z - from.z).length()
			var to_the_net: float = flat * (_serve_distance / absf(to.z - from.z))
			var at_net := ShotSolver.height_after(
				from.y - Court.SURFACE_Y, velocity.length(), angle, to_the_net)
			print("%-10.0f %-12.1f %-10.1f %-12.2f %s" % [
				angle, target_z, velocity.length(), at_net,
				"yes" if at_net > CourtSpec.NET_HEIGHT_CENTRE else "no"])


## An umpire who knows the service law, playing a match.
func _a_match_of_it() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	_serve_height = arena.SERVE_HEIGHT
	_serve_distance = arena.SERVE_DISTANCE
	arena.begin_match()

	var judged := 0
	var serves_that_died := 0
	var service_faults := 0
	var called := 0
	var wrong := 0

	for frame in 60000:
		await get_tree().process_frame
		if arena._phase == arena.Phase.READY:
			arena._start_rally()
			continue
		if arena._phase != arena.Phase.AWAITING_CALL:
			continue

		var rally: Rally = arena.rally
		if not rally.crossed_the_net and arena._shots_this_rally <= 1:
			serves_that_died += 1

		arena._awaiting_since = Time.get_ticks_msec()
		if rally.incident.is_a_service_fault():
			service_faults += 1
			called += 1
			arena._make_call(_call_for(rally.incident.kind), rally.incident.by)
		elif rally.incident.happened():
			arena._make_call(_call_for(rally.incident.kind), rally.incident.by)
		else:
			arena._make_call(
				&"in" if CourtSpec.is_in(rally.landing_point, rally.doubles) else &"out")

		if rally.verdict() == Rally.Verdict.WRONG:
			wrong += 1
			print("   WRONG: %s" % rally.describe())

		judged += 1
		for f in 14:
			await get_tree().process_frame
		if judged >= 40 or arena.board.is_over:
			break

	print("rallies judged:            %d" % judged)
	print("serves that died at once:  %d  (a serve that cannot clear the net)" % serves_that_died)
	print("service faults committed:  %d, all called" % service_faults)
	print("scored WRONG:              %d  (must be 0)" % wrong)
	print("suspicion:                 %.3f" % arena.suspicion.level)


func _call_for(kind: Incident.Kind) -> StringName:
	match kind:
		Incident.Kind.NET_TOUCH: return &"net_touch"
		Incident.Kind.CARRY: return &"carry"
		Incident.Kind.DOUBLE_HIT: return &"double_hit"
		Incident.Kind.OBSTRUCTION: return &"obstruction"
		Incident.Kind.SERVICE_TOO_HIGH: return &"serve_too_high"
		Incident.Kind.SERVICE_RACKET_UP: return &"serve_racket_up"
		Incident.Kind.SERVICE_FEET: return &"serve_feet"
	return &"in"
