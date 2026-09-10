extends Node

## Does each sport now sound like itself?
##
## Every sport shared one set of files until now, so a shuttlecock landing was also a
## volleyball dropping into sand and a tennis ball off a hard court. The surface is half
## of what a landing tells you, and this game is about judging landings.

func _ready() -> void:
	print("%-12s %-34s %-34s %s" % ["sport", "a soft contact", "a hard one", "the landing"])
	for sport in [&"badminton", &"beach", &"indoor", &"tennis", &"table_tennis"]:
		var hall := Sound.new()
		hall.kit = sport
		add_child(hall)
		print("%-12s %-34s %-34s %s" % [
			sport, _name(hall, "soft"), _name(hall, "hard"), _name(hall, "land")])
		hall.queue_free()

	print()
	var missing := 0
	for sport in Sound.KITS:
		for which in ["soft", "hard", "land"]:
			var path: String = Sound.KITS[sport][which]
			if not ResourceLoader.exists(path):
				print("   MISSING  %s / %s  ->  %s" % [sport, which, path])
				missing += 1
	print("files that do not exist: %d   (must be 0)" % missing)

	print()
	print("and the match tells the hall which sport it is:")
	for entry in [
		["beach", "res://scenes/beach.tscn"],
		["indoor", "res://scenes/volleyball.tscn"],
		["tennis", "res://scenes/tennis.tscn"],
		["table tennis", "res://scenes/table_tennis.tscn"],
	]:
		var arena: Node = load(entry[1]).instantiate()
		arena.print_truth_while_testing = false
		add_child(arena)
		await get_tree().process_frame
		print("   %-8s hall kit is %s" % [entry[0], arena.sound.kit])
		arena.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _name(hall: Sound, which: String) -> String:
	return hall._from_kit(which).get_file()
