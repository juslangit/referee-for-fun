extends Node

## Does each platform ship as one thing a player can be handed?
##
##   godot --headless --path . res://dev/checks/_packaging.tscn
##
## macOS has shipped as a drag-to-Applications disk image since 2026-09-17. Windows
## shipped as an .exe **plus a 303 MB .pck that had to travel beside it** — send somebody
## the .exe on its own and it does not start, which is the easiest possible way to hand
## out a broken game. Embedding the pack makes it one file, and this makes sure it stays
## one: a preset flag is exactly the kind of thing that gets lost when export settings are
## touched in the editor, and nothing else in the project would notice.
##
## The settings are read rather than the build, because a check that needs a build to have
## been made already can only ever run after the mistake has shipped.

var _failures: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _ready() -> void:
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_expect(not presets.is_empty(), "the export presets can be read")

	print("=== Windows is one file")
	var windows := _preset(presets, "Windows")
	_expect(not windows.is_empty(), "there is a Windows preset")
	_expect(windows.contains("binary_format/embed_pck=true"),
		"its pack is embedded in the executable, so nothing has to travel beside it")

	print("=== macOS is one file")
	var mac := _preset(presets, "macOS")
	_expect(not mac.is_empty(), "there is a macOS preset")
	_expect(FileAccess.file_exists("res://tools/build/make_dmg.sh"),
		"and a script that wraps it in a disk image")

	print("=== nothing loose left in the build folder")
	# A .pck beside a Windows build means either an old build or the flag having been
	# turned off again; either way somebody is one copy away from shipping half a game.
	var loose := 0
	var dir := DirAccess.open("res://build/windows")
	if dir != null:
		for file in dir.get_files():
			if file.ends_with(".pck"):
				print("      %s is still there" % file)
				loose += 1
	_expect(loose == 0, "no stray .pck beside the Windows executable (%d found)" % loose)

	print("")
	if _failures.is_empty():
		print("PASS  both platforms ship as a single file")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()


## Everything belonging to one preset, by its name — both its own block and the options
## block that follows it.
##
## A preset is written as `[preset.1]` with the name in it and `[preset.1.options]` with
## the settings, so splitting on `[preset.` and taking the block that holds the name gets
## the name and none of the settings. The first version of this did exactly that and
## reported the embedded pack missing while it was sitting in the file two blocks down.
func _preset(presets: String, wanted: String) -> String:
	var blocks := presets.split("[preset.")
	for i in blocks.size():
		if not blocks[i].contains('name="%s"' % wanted):
			continue
		var whole := blocks[i]
		if i + 1 < blocks.size() and blocks[i + 1].begins_with("%d.options" % _number(blocks[i])):
			whole += blocks[i + 1]
		return whole
	return ""


## The number a preset block starts with, so its options block can be recognised.
func _number(block: String) -> int:
	var digits := ""
	for letter in block:
		if letter.is_valid_int():
			digits += letter
		else:
			break
	return int(digits) if not digits.is_empty() else -1
