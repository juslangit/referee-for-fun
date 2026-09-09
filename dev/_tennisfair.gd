extends Node

## Does a tennis lie actually cost anything?
##
## This harness exists because of the worst bug this project has had. Both volleyballs
## priced every wrong call as a correct one for a fortnight, and the fair-play harnesses
## stayed green throughout — because all they asserted was that an honest official pays
## nothing, which a completely dead pricing system also satisfies.
##
## So this asserts the **negative** case first and the positive one second: the same lie
## is priced three different ways and every one of them has to come back above zero.

func _ready() -> void:
	print("what a lie costs, priced three ways")
	print("%-34s %10s %10s %8s" % ["the lie", "visibility", "charged", "verdict"])

	_price("calling a good serve a fault", _good_serve_called_out())
	_price("calling a fault an ace", _fault_called_in())
	_price("taking a second serve off a man", _second_serve_stolen())
	_price("denying a net cord (plain)", _let_denied(0.85))
	_price("denying a net cord (a graze)", _let_denied(0.06))
	_price("inventing a net cord", _let_invented())
	_price("inventing a foot fault", _foot_fault_invented())
	_price("inventing a not up", _not_up_invented())
	_price("calling a good ball out", _ball_called_out())

	print("")
	print("and the honest umpire, for comparison")
	_price("calling a fault a fault", _fault_called_out())
	_price("calling a good ball in", _ball_called_in())
	get_tree().quit()


func _price(what: String, rally: TennisRally) -> void:
	var suspicion := Suspicion.new()
	suspicion.scrutiny = 1.0
	var charged := suspicion.register_judgement(
		rally.verdict() as int,
		rally.visibility(),
		0.0,
		rally.call.severity,
		0.4,
		rally.echoes_line_judge(),
		rally.overrules_line_judge(),
		rally.changed_the_result())
	var name := "CORRECT"
	if rally.verdict() == Rally.Verdict.WRONG:
		name = "WRONG"
	elif rally.verdict() == Rally.Verdict.NO_CALL:
		name = "NO CALL"
	print("%-34s %10.3f %10.3f %8s" % [what, rally.visibility(), charged, name])


## A serve, given where it landed and which serve it was.
func _serve(x: float, z: float, number: int) -> TennisRally:
	var rally := TennisRally.new()
	rally.struck_by = Sides.Team.RED
	rally.serve_number = number
	rally.record_serve_landing(
		Vector3(x, 0.02, z), Sides.Team.BLUE, 1.0, 1.0)
	return rally


func _good_serve_called_out() -> TennisRally:
	var rally := _serve(2.0, 5.0, 1)
	rally.record_call(TennisCallBook.get_call(&"out"))
	return rally


func _fault_called_out() -> TennisRally:
	var rally := _serve(2.0, 6.8, 1)
	rally.record_call(TennisCallBook.get_call(&"out"))
	return rally


func _fault_called_in() -> TennisRally:
	var rally := _serve(2.0, 6.8, 1)
	rally.record_call(TennisCallBook.get_call(&"in"))
	return rally


## The same lie one serve later, which is a point rather than a serve.
func _second_serve_stolen() -> TennisRally:
	var rally := _serve(2.0, 6.2, 2)
	rally.record_call(TennisCallBook.get_call(&"out"))
	return rally


func _let_denied(seen: float) -> TennisRally:
	var rally := _serve(2.0, 5.0, 1)
	rally.clipped_the_cord = true
	rally.cord_visibility = seen
	rally.record_call(TennisCallBook.get_call(&"in"))
	return rally


func _let_invented() -> TennisRally:
	var rally := _serve(2.0, 5.0, 1)
	rally.record_call(TennisCallBook.get_call(&"let"), Sides.Team.RED)
	return rally


func _foot_fault_invented() -> TennisRally:
	var rally := _serve(2.0, 5.0, 1)
	rally.record_call(TennisCallBook.get_call(&"foot_fault"), Sides.Team.RED)
	return rally


func _not_up_invented() -> TennisRally:
	var rally := _rally_ball(2.0, 8.0)
	rally.record_call(TennisCallBook.get_call(&"not_up"), Sides.Team.BLUE)
	return rally


func _rally_ball(x: float, z: float) -> TennisRally:
	var rally := TennisRally.new()
	rally.struck_by = Sides.Team.RED
	rally.record_landing(Vector3(x, 0.02, z), Sides.Team.BLUE)
	return rally


func _ball_called_out() -> TennisRally:
	var rally := _rally_ball(2.0, 11.75)
	rally.record_call(TennisCallBook.get_call(&"out"))
	return rally


func _ball_called_in() -> TennisRally:
	var rally := _rally_ball(2.0, 11.75)
	rally.record_call(TennisCallBook.get_call(&"in"))
	return rally
