extends Node

## Does the game credit the people whose work is in it?
##
##   godot --headless --path . res://dev/checks/_credits.tscn
##
## Every 3D model here is Creative Commons Attribution: free to use, including
## commercially, on the single condition that the author is named. On 2026-09-20 an audit
## found **fifteen** models in the game and not in `CREDITS.md`, and `CREDITS.md` itself
## was shown nowhere the player could reach. That is a licence breach twice over, and the
## kind that nobody notices until somebody does.
##
## So this asks three things, and the first is the one that matters:
##
##   Every model the code loads has its author named in the text the game shows.
##   The credits screen can be reached from the title screen.
##   The text is not empty in a build — it is a GDScript constant rather than a loose
##   file, so this fails loudly if that ever changes.

const MODELS := "res://assets/sketchfab"


func _ready() -> void:
	var problems: Array[String] = []
	var text := Credits.TEXT

	print("the credits the game shows are %d characters long" % text.length())
	if text.strip_edges().length() < 200:
		problems.append("the credits text is empty or a stub")

	# Every model folder the game's own scripts name, against the names in that text.
	var wanted := _models_the_game_loads()
	print("")
	print("models the code loads, and whether their author is named")
	for folder in wanted:
		var author := _author_of(folder)
		var named := not author.is_empty() and text.contains(author)
		print("   %-44s %-22s %s" % [folder, author, "named" if named else "NOT NAMED"])
		if author.is_empty():
			problems.append("%s has no ATTRIBUTION.md to credit from" % folder)
		elif not named:
			problems.append("%s is in the game and its author is not credited" % folder)

	# And the way in.
	var ui := RefereeUI.new()
	add_child(ui)
	await get_tree().process_frame
	var reachable := ui.has_signal("credits_requested")
	ui.show_credits()
	await get_tree().process_frame
	var opens: bool = ui.get_node_or_null("%s" % "Root/Credits") != null or _panel_shown(ui)
	print("")
	print("a CREDITS button exists on the title screen: %s" % reachable)
	print("the credits screen opens: %s" % opens)
	if not reachable:
		problems.append("there is no way to ask for the credits screen")
	if not opens:
		problems.append("the credits screen does not open")
	ui.queue_free()

	print("")
	if problems.is_empty():
		print("PASS  every model in the game names its author, on a screen the player can reach")
	else:
		for problem in problems:
			print("FAIL  %s" % problem)
	get_tree().quit()


func _panel_shown(ui: Node) -> bool:
	for node in _every(ui):
		if node is Control and node.name == "Credits":
			return (node as Control).visible
	return false


func _models_the_game_loads() -> Array[String]:
	var found: Array[String] = []
	for path in ["res://scripts", "res://tools"]:
		_scan(path, found)
	found.sort()
	return found


func _scan(where: String, into: Array[String]) -> void:
	var directory := DirAccess.open(where)
	if directory == null:
		return
	for name in directory.get_files():
		if not (name.ends_with(".gd") or name.ends_with(".py")):
			continue
		var file := FileAccess.open("%s/%s" % [where, name], FileAccess.READ)
		if file == null:
			continue
		var text := file.get_as_text()
		var at := text.find("assets/sketchfab/")
		while at >= 0:
			var rest := text.substr(at + 17)
			var cut := rest.find("/")
			if cut > 0:
				var folder := rest.substr(0, cut)
				# Only something that is actually a folder on disk. `build_credits.py`
				# contains the regular expression `assets/sketchfab/([^/]+)/`, and a
				# plain text scan reads "([^" out of it as a model name.
				if not folder in into and DirAccess.dir_exists_absolute(
						"%s/%s" % [MODELS, folder]):
					into.append(folder)
			at = text.find("assets/sketchfab/", at + 1)
	for sub in directory.get_directories():
		_scan("%s/%s" % [where, sub], into)


func _author_of(folder: String) -> String:
	var path := "%s/%s/ATTRIBUTION.md" % [MODELS, folder]
	if not FileAccess.file_exists(path):
		return ""
	for line in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n"):
		if line.begins_with("- Author:"):
			return line.substr(9).strip_edges()
	return ""


func _every(node: Node) -> Array[Node]:
	var all: Array[Node] = []
	for child in node.get_children():
		all.append(child)
		all.append_array(_every(child))
	return all
