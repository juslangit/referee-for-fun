extends Node

## The overlay screens photographed one after another over the badminton hall, opened
## directly rather than reached by playing: the review card before and after its answer,
## the fault panel, a lesson page, the settings, the briefing, and the career screen.
## Made for the broadcast redesign of 2026-09-15, after the older looks that reached these
## by playing had stopped running.
##
##     godot --path . res://dev/looks/_screens.tscn
##
## Saves dev/shots/screen_<name>.png.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.tier = 3
	arena.career.matches_refereed = 6
	arena.career.reputation = 0.58
	var ui: RefereeUI = arena.ui

	ui.hide_menus()
	arena.begin_match()
	for f in 20:
		await get_tree().process_frame

	var view := ImageTexture.create_from_image(Image.load_from_file(
		ProjectSettings.globalize_path("res://dev/shots/badminton_replay_close.png")))
	ui.show_review(Sides.Team.BLUE, 1, view)
	await _shot("review_waiting")
	ui.set_review_verdict("Out", UiTheme.BAD)
	ui.set_review_hint("SPACE  wave it on")
	await _shot("review_answer")
	ui.hide_review()

	ui.show_fault_panel(false)
	await _shot("faults")
	ui.hide_fault_panel()

	ui.show_teaching(Career.BADMINTON)
	await _shot("lesson")
	ui.hide_teaching()

	ui.show_settings(arena.settings)
	await _shot("settings")
	ui.hide_settings()

	var pressure := Pressure.new()
	pressure.headline = "A word before you go out"
	pressure.detail = "The coach of the red pair caught you in the corridor. He did not ask for anything. He said the sponsors are in the front row tonight, and that a final is a final."
	pressure.ask = "Nobody will notice one close call."
	pressure.wants = Sides.Team.RED
	ui.show_briefing(pressure)
	await _shot("briefing")
	ui.hide_briefing()

	ui.show_career(arena.career)
	await _shot("career")
	ui.hide_career()

	ui.show_ending("RED WIN THE MATCH", "BADMINTON  ·  National championship\n\nFinal score  RED 21 — 18 BLUE     games 2 — 1\n\nReputation  58 / 100")
	await _shot("ending")
	print("saved screens")
	get_tree().quit()


func _shot(name: String) -> void:
	for f in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/screen_%s.png" % name)
