extends Node

## Does the umpire's chair face the court?
##
##   godot --headless --path . res://dev/checks/_chair.tscn
##
## It did not, from the day the model went in until 2026-09-18, and nothing noticed —
## because the chair is on `CHAIR_LAYER`, which the umpire's own camera leaves out. The
## player sits in it, so it is never in their view during a match; it is only ever seen
## during a cutscene. A thing the game draws but the player cannot normally see is exactly
## the kind of thing that stays wrong, so it gets a check.
##
## The seat direction is measured rather than the rotation compared to a number, so that
## the check still means something if the chair is ever moved, re-modelled or re-scaled.

var _failures: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame

	var chair := hall.court.find_child("UmpireChair", true, false) as Node3D
	_expect(chair != null, "there is an umpire's chair")
	if chair == null:
		_finish()
		return

	print("=== where it stands")
	var out := chair.global_position.x
	_expect(out > CourtSpec.HALF_WIDTH_DOUBLES,
		"it stands outside the doubles sideline (%.2f m out, sideline at %.2f)" % [
			out, CourtSpec.HALF_WIDTH_DOUBLES])
	_expect(absf(chair.global_position.z) < 0.5,
		"and level with the net (%.2f m off it)" % chair.global_position.z)

	print("=== which way it looks")
	var model: Node3D = null
	for child in chair.get_children():
		if child is Node3D and child.get_child_count() > 0:
			model = child as Node3D
			break
	_expect(model != null, "the chair has a model on it")
	if model == null:
		_finish()
		return

	# The seat looks along the model's own -Z once it has been turned. What matters is
	# that whatever it looks along points back across the court, towards x = 0.
	var facing := -model.global_transform.basis.z.normalized()
	var to_court := (Vector3(0.0, chair.global_position.y, 0.0) - chair.global_position).normalized()
	var agreement := facing.dot(to_court)
	print("   faces (%+.2f, %+.2f, %+.2f), court lies (%+.2f, %+.2f, %+.2f)" % [
		facing.x, facing.y, facing.z, to_court.x, to_court.y, to_court.z])
	_expect(agreement > 0.7,
		"the seat looks across the court rather than at the back wall (agreement %+.2f)" % agreement)

	_finish()


func _finish() -> void:
	print("")
	if _failures.is_empty():
		print("PASS  the umpire's chair stands where it should and looks at the court")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()
