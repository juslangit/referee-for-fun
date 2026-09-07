extends Node

## Walks a career forward under a few different umpires and prints what happens to
## them. No physics — this is only about what a match does to a reputation.

func _ready() -> void:
	_run("straight as a die", func(_i: int) -> Array: return [0.02, false])
	_run("shaves the close ones", func(_i: int) -> Array: return [randf_range(0.15, 0.30), false])
	_run("greedy, caught every third match", func(i: int) -> Array:
		return [0.9, true] if i % 3 == 2 else [0.55, false])
	get_tree().quit()


func _run(label: String, umpire: Callable) -> void:
	seed(7)
	print("\n--- %s ---" % label)
	print("%-4s %-26s %-6s %-5s %s" % ["#", "venue", "susp.", "rep.", "what happened"])

	var career := Career.new()
	for i in range(14):
		if career.is_over:
			break
		var venue := career.venue()
		var outcome: Array = umpire.call(i)
		var suspicion: float = outcome[0]
		var removed: bool = outcome[1]
		var before: String = venue["name"]
		var note := career.finish_match(suspicion, removed)
		print("%-4d %-26s %-6.2f %-5.0f %s" % [
			i + 1, before, suspicion, career.reputation * 100.0, note.replace("\n", "  ")
		])

	print("     reached: %s   %d matches, thrown off %d times%s" % [
		career.venue()["name"], career.matches_refereed, career.times_removed,
		"   CAREER OVER" if career.is_over else "",
	])
