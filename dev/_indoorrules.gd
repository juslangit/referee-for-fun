extends Node

## The four positional calls, made and missed, one at a time.
##
## Waiting for a rotation fault to come up on its own takes about forty rallies for one,
## which is right for the game and useless for checking it. So each fault is built by
## hand and put to the rules three ways: called correctly, missed entirely, and invented
## out of nothing.
##
## The three answers matter in different directions. Called correctly must cost nothing.
## Missed must cost something, and be priced as a missed *rotation* rather than as
## whatever the ball happened to do. Invented must be the most expensive thing in the
## sport, because a lineup is a matter of record and both benches have it written down.

func _ready() -> void:
	print("%-16s %-22s %-9s %-8s %s" % [
		"the fault", "what the referee said", "verdict", "seen", "point to"])

	for kind in ["wrong_server", "rotation_fault", "libero_fault", "back_row_attack"]:
		_three_ways(kind)
		print()

	_and_when_nothing_happened()
	get_tree().quit()


func _three_ways(kind: String) -> void:
	# Called correctly.
	var right := _rally_with(kind)
	right.record_call(VolleyCallBook.get_call(StringName(kind)), Sides.Team.RED)
	_report(kind, kind.to_upper(), right)

	# Missed: the referee judges the ball and says nothing about the lineup.
	var missed := _rally_with(kind)
	missed.record_call(VolleyCallBook.get_call(&"in"))
	_report(kind, "IN — never noticed", missed)

	# Called against the wrong side, which is a different way of being wrong.
	var misdirected := _rally_with(kind)
	misdirected.record_call(
		VolleyCallBook.get_call(StringName(kind)), Sides.Team.BLUE)
	_report(kind, "%s on the other side" % kind.to_upper().substr(0, 10), misdirected)


## A rally that RED lost by a positional fault, with the ball landing cleanly in.
func _rally_with(kind: String) -> VolleyRally:
	var rally := VolleyRally.new()
	rally.served_by = Sides.Team.RED
	rally.struck_by = Sides.Team.RED
	rally.record_landing(Vector3(1.0, VolleyCourt.SURFACE_Y, 4.0), Sides.Team.BLUE)
	match kind:
		"wrong_server": rally.wrong_server_by = Sides.Team.RED
		"rotation_fault": rally.rotation_fault_by = Sides.Team.RED
		"libero_fault":
			rally.libero_fault_by = Sides.Team.RED
			rally.libero_did = &"attacked"
		"back_row_attack": rally.back_row_attack_by = Sides.Team.RED
	return rally


func _and_when_nothing_happened() -> void:
	var clean := VolleyRally.new()
	clean.served_by = Sides.Team.RED
	clean.struck_by = Sides.Team.RED
	clean.record_landing(Vector3(1.0, VolleyCourt.SURFACE_Y, 4.0), Sides.Team.BLUE)
	clean.record_call(VolleyCallBook.get_call(&"rotation_fault"), Sides.Team.BLUE)
	_report("nothing at all", "OUT OF ROTATION", clean)


func _report(kind: String, said: String, rally: VolleyRally) -> void:
	print("%-16s %-22s %-9s %-8.2f %s" % [
		kind, said,
		"correct" if rally.verdict() == BeachRally.Verdict.CORRECT else "WRONG",
		rally.visibility(),
		Sides.label(rally.point_goes_to())])
