extends Node

## Which animations does a player actually have, and which does the game ever ask for?
##
## A clip the game plays that the character does not carry fails silently — `_play`
## checks `has_animation` and returns — so a missing one looks exactly like a player
## who chose not to move. And a clip the character carries that nothing ever plays is
## work that was done and then never seen.

## Every clip name that appears in a `_play(...)` anywhere in player.gd.
const ASKED_FOR := [
	"idle", "ready", "vb_ready", "run", "walk", "tired", "argue",
	"smash", "forehand", "backhand", "celebrate", "serve",
	"vb_dig", "vb_set", "vb_spike", "vb_block", "vb_serve",
	"tn_serve", "lunge", "sit",
]


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

	var carried: Array[String] = []
	for clip in animator.get_animation_list():
		carried.append(String(clip))
	carried.sort()

	print("the character carries %d clips" % carried.size())
	for clip in carried:
		var seconds: float = animator.get_animation(clip).length
		var used := clip in ASKED_FOR
		print("   %-14s %5.2f s   %s" % [
			clip, seconds, "played" if used else "NEVER PLAYED"])

	print()
	print("clips the game asks for and the character does not have")
	var missing := 0
	for clip in ASKED_FOR:
		if not animator.has_animation(clip):
			print("   %-14s  asked for, not there — plays nothing, silently" % clip)
			missing += 1
	if missing == 0:
		print("   none")
	get_tree().quit()
