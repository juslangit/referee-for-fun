extends Node

## Does a table tennis lie actually cost anything?
##
## The same negative assertion `_tennisfair` makes, and it exists for the same reason:
## both volleyballs priced every wrong call as a correct one for a fortnight while the
## fair-play harnesses stayed green, because all those asserted was that an honest
## official pays nothing — which a completely dead pricing system also satisfies.
##
## The interesting rows here are the two edge balls. A ball a hair off the corner is
## nobody's to know and must be nearly free to get wrong; the same lie about a ball
## plainly on the table must not be. If those two come back the same number, the edge —
## which is the whole reason this sport is in the game — is not being priced at all.

func _ready() -> void:
	print("what a lie costs, priced eight ways")
	print("%-38s %10s %10s %8s" % ["the lie", "visibility", "charged", "verdict"])

	_price("calling a good serve a fault", _good_serve_called_out())
	_price("calling a fault a good serve", _fault_called_in())
	_price("denying a net let (plain)", _let_denied(0.88))
	_price("denying a net let (a graze)", _let_denied(0.05))
	_price("inventing a net let", _let_invented())
	_price("inventing an illegal service", _service_invented())
	_price("inventing two bounces", _double_bounce_invented())
	_price("inventing a hand on the table", _table_touch_invented())
	print("")
	print("the edge, which is what this sport is")
	_price("an edge ball called out (plain)", _edge_called_out(0.019))
	_price("an edge ball called out (on the corner)", _edge_called_out(0.0008))
	_price("a ball plainly on called out", _ball_called_out(0.40))

	print("")
	print("and the honest umpire, for comparison")
	_price("calling a fault a fault", _fault_called_out())
	_price("calling an edge ball in", _edge_called_in())
	get_tree().quit()


func _price(what: String, rally: TableTennisRally) -> void:
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
	print("%-38s %10.3f %10.3f %8s" % [what, rally.visibility(), charged, name])


## A serve from RED, given where its second bounce came down.
func _serve(x: float, z: float) -> TableTennisRally:
	var rally := TableTennisRally.new()
	rally.is_a_serve = true
	rally.served_by = Sides.Team.RED
	rally.struck_by = Sides.Team.RED
	rally.record_landing(Vector3(x, TableTennisSpec.HEIGHT, z), Sides.Team.BLUE)
	rally.serve_was_good = rally.was_in
	return rally


## A rally ball from RED, landing `inside` metres in from the nearest edge.
func _rally_ball(inside: float) -> TableTennisRally:
	var rally := TableTennisRally.new()
	rally.struck_by = Sides.Team.RED
	rally.record_landing(
		Vector3(0.0, TableTennisSpec.HEIGHT,
			-(TableTennisSpec.HALF_LENGTH - inside)),
		Sides.Team.BLUE)
	return rally


func _good_serve_called_out() -> TableTennisRally:
	var rally := _serve(0.0, -0.8)
	rally.record_call(TableTennisCallBook.get_call(&"out"))
	return rally


func _fault_called_out() -> TableTennisRally:
	var rally := _serve(0.0, -1.55)
	rally.record_call(TableTennisCallBook.get_call(&"out"))
	return rally


func _fault_called_in() -> TableTennisRally:
	var rally := _serve(0.0, -1.55)
	rally.record_call(TableTennisCallBook.get_call(&"in"))
	return rally


func _let_denied(seen: float) -> TableTennisRally:
	var rally := _serve(0.0, -0.8)
	rally.clipped_the_net = true
	rally.net_visibility = seen
	rally.record_call(TableTennisCallBook.get_call(&"in"))
	return rally


func _let_invented() -> TableTennisRally:
	var rally := _serve(0.0, -0.8)
	rally.record_call(TableTennisCallBook.get_call(&"let"), Sides.Team.RED)
	return rally


func _service_invented() -> TableTennisRally:
	var rally := _serve(0.0, -0.8)
	rally.record_call(TableTennisCallBook.get_call(&"illegal_service"), Sides.Team.RED)
	return rally


func _double_bounce_invented() -> TableTennisRally:
	var rally := _rally_ball(0.40)
	rally.record_call(TableTennisCallBook.get_call(&"double_bounce"), Sides.Team.BLUE)
	return rally


func _table_touch_invented() -> TableTennisRally:
	var rally := _rally_ball(0.40)
	rally.record_call(TableTennisCallBook.get_call(&"touched_the_table"), Sides.Team.BLUE)
	return rally


## An edge ball, `inside` metres onto the top of the table — called out.
func _edge_called_out(inside: float) -> TableTennisRally:
	var rally := _rally_ball(inside)
	rally.record_call(TableTennisCallBook.get_call(&"out"))
	return rally


func _edge_called_in() -> TableTennisRally:
	var rally := _rally_ball(0.012)
	rally.record_call(TableTennisCallBook.get_call(&"in"))
	return rally


func _ball_called_out(inside: float) -> TableTennisRally:
	var rally := _rally_ball(inside)
	rally.record_call(TableTennisCallBook.get_call(&"out"))
	return rally
