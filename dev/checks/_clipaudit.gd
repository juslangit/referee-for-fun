extends Node

## Which animations does a player actually have, and which does the game ever ask for?
##
## A clip the game plays that the character does not carry fails silently — `_play`
## checks `has_animation` and returns — so a missing one looks exactly like a player
## who chose not to move. And a clip the character carries that nothing ever plays is
## work that was done and then never seen.

## Where the clip names are asked for. Read, not copied.
const PLAYER_SOURCE := "res://scripts/player.gd"


## Every clip name that appears in a `_play(...)` anywhere in player.gd, read out of the
## file itself.
##
## This used to be a hand-written list beside this comment, and it did exactly what a
## hand-written copy of the truth always does: a `nod` clip was authored, wired up and
## playing in a real match, and this harness — whose entire job is catching drift —
## reported it as NEVER PLAYED, because nobody had updated its own list.
##
## Every quoted string on a line containing `_play(` counts, which is what picks up the
## three names in `_play("run" if running else ("ready" if chasing else "idle"))`.
##
## The hand-written list was wrong in **both** directions, which is the argument for
## reading the source rather than describing it. It hid `nod`, and it also claimed
## `walk`, `tired` and `vb_ready` were played when nothing plays them — those three
## appear in `player.gd` only in `LOOPING`, which says how a clip repeats *if* it is
## played and not that anything ever does.
static func asked_for() -> Array:
	var source := FileAccess.get_file_as_string(PLAYER_SOURCE)
	if source.is_empty():
		push_error("cannot read %s — the audit has nothing to compare against" % PLAYER_SOURCE)
		return []
	var quoted := RegEx.create_from_string("\"([a-z_0-9]+)\"")
	var found := []
	for line in source.split("\n"):
		if not line.contains("_play("):
			continue
		for hit in quoted.search_all(line):
			var name := hit.get_string(1)
			if not found.has(name):
				found.append(name)
	return found


func _ready() -> void:
	var player := Player.new()
	player.volleyball = false
	add_child(player)
	player.setup(Sides.Team.RED, Vector3.ZERO)
	for f in 4:
		await get_tree().process_frame

	var animator := Models.animator(player)
	if animator == null:
		print("the player has no AnimationPlayer at all")
		get_tree().quit()
		return

	var asked := asked_for()
	print("player.gd asks for %d clips by name" % asked.size())
	print()

	var carried: Array[String] = []
	for clip in animator.get_animation_list():
		carried.append(String(clip))
	carried.sort()

	print("the character carries %d clips" % carried.size())
	for clip in carried:
		var seconds: float = animator.get_animation(clip).length
		var used := clip in asked
		print("   %-14s %5.2f s   %s" % [
			clip, seconds, "played" if used else "NEVER PLAYED"])

	print()
	print("clips the game asks for and the character does not have")
	var missing := 0
	for clip in asked:
		if not animator.has_animation(clip):
			print("   %-14s  asked for, not there — plays nothing, silently" % clip)
			missing += 1
	if missing == 0:
		print("   none")
	get_tree().quit()
