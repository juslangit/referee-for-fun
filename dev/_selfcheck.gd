extends Node

## Does every scene in here still load? Moving forty-six of them into a folder is exactly
## the sort of change that breaks a path silently, and some of these were written weeks
## ago against APIs that have since moved on.

func _ready() -> void:
	var broken: Array[String] = []
	var ok := 0
	for name in DirAccess.get_files_at("res://dev"):
		if not name.ends_with(".tscn"):
			continue
		var scene = ResourceLoader.load("res://dev/" + name, "", ResourceLoader.CACHE_MODE_IGNORE)
		if scene == null:
			broken.append(name)
		else:
			ok += 1
	print("scenes that load: %d" % ok)
	print("scenes that do not: %d" % broken.size())
	for name in broken:
		print("   %s" % name)
	get_tree().quit()
