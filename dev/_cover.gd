extends Node

## Do the volleyball line judges give an official cover?
##
## Having them on court is the visible half. The half that matters is the pricing: in
## badminton, agreeing with a line judge who has just got one wrong halves what the
## mistake costs, and contradicting one costs 1.6 times. Both volleyballs were missing
## that entirely, so the same lie cost different amounts in different sports for no
## reason anybody had stated.
##
## Three officials tell the same lie under three different circumstances, and the only
## thing that differs is what the line judge said.

func _ready() -> void:
	print("%-34s %-10s %s" % ["the same wrong call, when...", "costs", "against a bare"])
	print()
	for sport in ["beach", "indoor"]:
		_three_ways(sport)
	get_tree().quit()


func _three_ways(sport: String) -> void:
	var alone := _cost(sport, false, false)
	var echoed := _cost(sport, true, true)
	var overruled := _cost(sport, true, false)

	print("=== %s" % sport)
	print("  %-32s %-10.3f" % ["nobody said anything", alone])
	print("  %-32s %-10.3f (%.2f of it — this is the cover)" % [
		"the line judge said the same", echoed, echoed / maxf(0.0001, alone)])
	print("  %-32s %-10.3f (%.2f of it)" % [
		"the line judge said otherwise", overruled, overruled / maxf(0.0001, alone)])
	print()


## One visibly wrong line call, priced by a fresh Suspicion so nothing carries over.
func _cost(sport: String, judge_called: bool, judge_agreed: bool) -> float:
	var rally: BeachRally = VolleyRally.new() if sport == "indoor" else BeachRally.new()
	rally.served_by = Sides.Team.RED
	rally.struck_by = Sides.Team.RED
	rally.receiving = Sides.Team.BLUE
	# A ball 60 cm past the end line, given IN. Plainly wrong, and nothing else about
	# the rally is unusual.
	rally.record_landing(Vector3(0.0, 0.0, 9.6 if sport == "indoor" else 8.6),
		Sides.Team.BLUE)
	rally.record_call(
		(VolleyCallBook if sport == "indoor" else BeachCallBook).get_call(&"in"))
	rally.line_judge_called = judge_called
	# The judge is asked about the same ball, so agreeing means saying OUT — which is
	# what the official then contradicted or echoed.
	rally.line_judge_said_in = judge_agreed

	var suspicion := Suspicion.new()
	suspicion.scrutiny = 1.0
	return suspicion.register_judgement(
		rally.verdict() as int,
		rally.visibility(),
		1.0,
		rally.call.severity,
		0.0,
		rally.echoes_line_judge(),
		rally.overrules_line_judge(),
		rally.changed_the_result())
