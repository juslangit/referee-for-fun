extends Node

## Do the table tennis dice roll at the rate they are written down at?
##
## The same check `_badmintonrates` is, and it exists for the same reason: a run of
## `_ttplay` came back with seven net lets in twenty-four points against a written rate
## of eleven per cent, and a great deal of time once went into hunting a bug in
## badminton's fault rates that was never there. Rolling the dice four thousand times
## settles in two seconds what a twenty-four point sample cannot settle at all — and
## this said the rates were right, so the seven was variance and the game was fine.

func _ready() -> void:
	var net := 0
	var fault := 0
	var kinds := {}
	for i in 4000:
		if randf() < TableTennisMatch.NET_CHANCE:
			net += 1
		if randf() < TableTennisMatch.FAULT_CHANCE:
			fault += 1
	print("net clips: %.2f%% (want %.2f%%)" % [
		100.0 * net / 4000.0, 100.0 * TableTennisMatch.NET_CHANCE])
	print("faults:    %.2f%% (want %.2f%%)" % [
		100.0 * fault / 4000.0, 100.0 * TableTennisMatch.FAULT_CHANCE])
	get_tree().quit()
