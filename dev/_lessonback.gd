extends Node

## Can a player read the rules again, in every sport?
##
## The lesson used to be shown once on the way into a first match and then be
## unreachable: the title screen's HOW TO REFEREE only ever had badminton's. Worst for
## indoor volleyball, whose lesson is the only one explaining something the player has
## to carry in their head rather than look at.

func _ready() -> void:
	for scene in ["res://scenes/match.tscn", "res://scenes/beach.tscn",
			"res://scenes/volleyball.tscn", "res://scenes/tennis.tscn"]:
		await _check(scene)
	get_tree().quit()


func _check(scene: String) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	var badminton: bool = scene.ends_with("match.tscn")
	if badminton:
		arena.ui._main_menu.visible = false
		arena._on_career_screen_requested()
	else:
		arena.settings.taught_beach = true
		arena.settings.taught_indoor = true
		arena.settings.taught_tennis = true
		arena.ui.show_career(arena.career)
	await get_tree().process_frame

	var sport := "badminton"
	if scene.ends_with("beach.tscn"):
		sport = "beach"
	elif scene.ends_with("volleyball.tscn"):
		sport = "indoor"
	elif scene.ends_with("tennis.tscn"):
		sport = "tennis"

	print("=== %s" % sport)
	print("   the ladder offers HOW TO REFEREE: %s" % (
		"yes" if _has_button(arena.ui, "HOW TO REFEREE") else "NO"))

	arena.ui.teaching_requested.emit()
	await get_tree().process_frame
	print("   pressing it opens a lesson: %s, %d pages, first page %s" % [
		"yes" if arena.ui._teaching != null and arena.ui._teaching.visible else "NO",
		arena.ui._lessons.size(),
		arena.ui._lessons[0]["title"]])

	# GOT IT, from the last page.
	arena.ui._lesson = arena.ui._lessons.size() - 1
	arena.ui.teaching_finished.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	print("   and it comes back to the ladder: %s" % (
		"yes" if arena.ui.career_is_showing() else "NO"))

	arena.queue_free()
	await get_tree().process_frame


func _has_button(node: Node, text: String) -> bool:
	if node is Button and (node as Button).text == text:
		return true
	for child in node.get_children():
		if _has_button(child, text):
			return true
	return false
