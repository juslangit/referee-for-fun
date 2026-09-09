extends Node

## Does every scene in here still load?
##
## Sorting a hundred of them into folders is exactly the sort of change that breaks a
## path silently — each scene names its script by path, so moving the pair without
## moving the reference leaves a scene that loads to nothing and says nothing about it.
## Some of these were also written weeks ago against APIs that have since moved on.

## Where the harnesses live: the ones that print numbers, and the ones that take
## pictures. `shots/` is where the pictures land and holds no scenes.
const FOLDERS := ["res://dev/checks", "res://dev/looks"]


func _ready() -> void:
	var broken: Array[String] = []
	var ok := 0
	for folder in FOLDERS:
		for name in DirAccess.get_files_at(folder):
			if not name.ends_with(".tscn"):
				continue
			var scene = ResourceLoader.load(
				"%s/%s" % [folder, name], "", ResourceLoader.CACHE_MODE_IGNORE)
			if scene == null:
				broken.append("%s/%s" % [folder.get_file(), name])
			else:
				ok += 1
	print("scenes that load: %d" % ok)
	print("scenes that do not: %d" % broken.size())
	for name in broken:
		print("   %s" % name)
	print()
	_settings_the_build_depends_on()
	get_tree().quit()


## Project settings that nothing in the game reads but a build cannot do without.
##
## This is here because **a comment cannot protect them**. `project.godot` is rewritten
## by Godot every time the editor opens — the keys are reordered and every `;` line is
## deleted — so the four lines explaining why `import_etc2_astc` had to be turned on
## survived exactly until the next editor run, and the setting was left sitting there
## looking like something nobody meant. The next person to tidy it away would find out
## when the macOS build failed.
##
## A test cannot be silently reformatted, and it can say why.
func _settings_the_build_depends_on() -> void:
	print("settings the build depends on")
	var astc := bool(ProjectSettings.get_setting(
		"rendering/textures/vram_compression/import_etc2_astc", false))
	if astc:
		print("   import_etc2_astc: on   (the macOS universal export needs it)")
	else:
		push_error("import_etc2_astc is off, so the macOS export will fail")
		print("   import_etc2_astc: OFF  <-- the macOS preset is a universal binary and")
		print("                          Apple Silicon needs ASTC textures. Godot refuses")
		print("                          a universal or arm64 export without this on. The")
		print("                          alternative is an Intel-only build under Rosetta")
		print("                          on the machine this game is developed on, which")
		print("                          is the wrong way round. Turn it back on.")
