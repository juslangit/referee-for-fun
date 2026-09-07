class_name RefereeUI
extends CanvasLayer

## Everything the player sees that is not the court.
##
## One rule governs this whole file: it is never told where the shuttle landed. It
## shows the score, the call that was made, and who got the point — all things the
## hall can see. Whether the call was true is not among them. The moment this screen
## can tell the player they got it right, the game stops being about judgement.

signal length_chosen(quick: bool)
signal favour_chosen(team: Sides.Team)
signal punishment_chosen(id: StringName, team: Sides.Team)
signal match_requested()
signal career_restart_requested()
signal continue_requested()
signal new_career_requested()
signal career_screen_requested()
signal resume_requested()
signal walk_out_requested()
signal quit_requested()

const TITLE_SIZE := 34
const BUTTON_SIZE := 22
const SCORE_SIZE := 30
const MESSAGE_SIZE := 40
const PROMPT_SIZE := 17
const REACTION_SIZE := 19
const BANNER_SIZE := 24

var _main_menu: Control
var _main_menu_column: VBoxContainer
var _pause_menu: Control
var _career_panel: Control
var _career_column: VBoxContainer
var _ending_button: Button
var _length_panel: Control
var _pre_match: Control
var _ending: Control
var _ending_headline: Label
var _ending_detail: Label
var _score_label: Label
var _prompt_label: Label
var _message_label: Label
var _reaction_label: Label
var _banner_label: Label
var _fault_panel: Control
var _fault_rows: VBoxContainer
var _shuttle_cam_panel: Control
var _shuttle_cam_view: TextureRect
var _message_timer := 0.0
var _reaction_timer := 0.0
var _banner_timer := 0.0


func _ready() -> void:
	layer = 10
	# Keeps running while the game is paused, or nothing could unpause it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_main_menu()
	_build_pause_menu()
	_build_career_panel()
	_build_length_panel()
	_build_pre_match()
	_build_hud()
	_build_ending()
	_build_shuttle_cam()
	_build_fault_panel()
	_pre_match.visible = false
	_length_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# Escape closes the pause menu. It has to be handled here rather than in the
	# match, because the match is paused and is not being given input at all.
	if not _pause_menu.visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_message_timer = _tick(delta, _message_timer, _message_label)
	_reaction_timer = _tick(delta, _reaction_timer, _reaction_label)
	_banner_timer = _tick(delta, _banner_timer, _banner_label)


func _tick(delta: float, timer: float, label: Label) -> float:
	if timer <= 0.0:
		return 0.0
	timer -= delta
	if timer <= 0.0:
		label.text = ""
	return timer


# --- pre-match -----------------------------------------------------------------

# --- the front of the game -----------------------------------------------------

## The panels all share a shape: a dark sheet over the court with a column of things
## in the middle of it. This builds that much, and the caller fills in the column.
func _build_sheet(sheet_name: String, shade := Color(0.05, 0.06, 0.08, 0.95)) -> Array:
	var sheet := Control.new()
	sheet.name = sheet_name
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.visible = false
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = shade
	sheet.add_child(backdrop)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 9)
	sheet.add_child(column)

	return [sheet, column]


func _build_main_menu() -> void:
	var built := _build_sheet("MainMenu", Color(0.04, 0.05, 0.07, 0.97))
	_main_menu = built[0]
	_main_menu_column = built[1]


## The title screen. Whether there is a career to go back to decides what it offers.
func show_main_menu(career: Career) -> void:
	for child in _main_menu_column.get_children():
		child.queue_free()

	_main_menu_column.add_child(_make_label("REFEREE FOR FUN", TITLE_SIZE + 16, Color(0.96, 0.96, 0.94)))
	_main_menu_column.add_child(_make_label(
		"You are the umpire. The game knows the truth. You do not have to tell it.",
		PROMPT_SIZE + 2, Color(0.62, 0.64, 0.68)
	))
	_main_menu_column.add_child(_gap(26))

	var underway := career.matches_refereed > 0 and not career.is_over
	if underway:
		_main_menu_column.add_child(_centred(_make_wide_button(
			"CONTINUE CAREER",
			func() -> void:
				_main_menu.visible = false
				career_screen_requested.emit()
		)))
		_main_menu_column.add_child(_make_label(
			"%s        reputation %d / 100" % [
				career.venue()["name"], roundi(career.reputation * 100.0)
			],
			PROMPT_SIZE, Color(0.58, 0.60, 0.64)
		))
		_main_menu_column.add_child(_gap(6))

	_main_menu_column.add_child(_centred(_make_wide_button(
		"NEW CAREER" if underway or career.is_over else "START A CAREER",
		func() -> void:
			_main_menu.visible = false
			new_career_requested.emit()
	)))
	_main_menu_column.add_child(_gap(6))
	_main_menu_column.add_child(_centred(_make_wide_button("QUIT", func() -> void: quit_requested.emit())))

	_main_menu.visible = true


func _build_pause_menu() -> void:
	var built := _build_sheet("PauseMenu", Color(0.04, 0.05, 0.07, 0.86))
	_pause_menu = built[0]
	var column: VBoxContainer = built[1]

	column.add_child(_make_label("PAUSED", TITLE_SIZE, Color(0.96, 0.96, 0.94)))
	column.add_child(_gap(22))
	column.add_child(_centred(_make_wide_button("RESUME", func() -> void: resume_requested.emit())))
	column.add_child(_gap(6))
	column.add_child(_centred(_make_wide_button("WALK OUT", func() -> void: walk_out_requested.emit())))
	column.add_child(_make_label(
		"Walking out counts the same as being removed.",
		PROMPT_SIZE - 1, Color(0.60, 0.55, 0.55)
	))
	column.add_child(_gap(6))
	column.add_child(_centred(_make_wide_button("QUIT", func() -> void: quit_requested.emit())))


func show_pause_menu() -> void:
	# Whatever was still fading in the middle of the screen would otherwise sit
	# straight across the RESUME button.
	clear_messages()
	_pause_menu.visible = true


## Wipes the announcement, the crowd's line and the banner immediately.
func clear_messages() -> void:
	_message_label.text = ""
	_reaction_label.text = ""
	_banner_label.text = ""
	_message_timer = 0.0
	_reaction_timer = 0.0
	_banner_timer = 0.0


func hide_pause_menu() -> void:
	_pause_menu.visible = false


func is_paused_menu_open() -> bool:
	return _pause_menu.visible


func _centred(control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(control)
	return row


# --- the career ----------------------------------------------------------------

func _build_career_panel() -> void:
	_career_panel = Control.new()
	_career_panel.name = "CareerPanel"
	_career_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_career_panel.visible = false
	_career_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_career_panel)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.05, 0.06, 0.08, 0.95)
	_career_panel.add_child(backdrop)

	_career_column = VBoxContainer.new()
	_career_column.set_anchors_preset(Control.PRESET_CENTER)
	_career_column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_career_column.grow_vertical = Control.GROW_DIRECTION_BOTH
	_career_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_career_column.add_theme_constant_override("separation", 7)
	_career_panel.add_child(_career_column)


## Draws the ladder, with where you are on it and what that is worth.
func show_career(career: Career) -> void:
	for child in _career_column.get_children():
		child.queue_free()

	_career_panel.visible = true

	if career.is_over:
		_career_column.add_child(_make_label("YOUR CAREER IS OVER", TITLE_SIZE, Color(0.96, 0.42, 0.36)))
		_career_column.add_child(_make_label(
			"%d matches, thrown off %d of them." % [career.matches_refereed, career.times_removed],
			PROMPT_SIZE + 2, Color(0.78, 0.78, 0.80)
		))
		_career_column.add_child(_gap(18))
		_career_column.add_child(_centred(_make_wide_button("START AGAIN", func() -> void:
			career_restart_requested.emit()
		)))
		return

	_career_column.add_child(_make_label("YOUR CAREER", TITLE_SIZE - 4, Color(0.95, 0.95, 0.93)))
	_career_column.add_child(_gap(8))

	for i in Career.LADDER.size():
		var rung: Dictionary = Career.LADDER[i]
		var text := "%s" % rung["name"]
		var tint := Color(0.36, 0.38, 0.42)
		if i < career.tier:
			text = "%s        cleared" % rung["name"]
			tint = Color(0.55, 0.62, 0.55)
		elif i == career.tier:
			text = "▸  %s" % rung["name"]
			tint = Color(0.98, 0.94, 0.72)
		_career_column.add_child(_make_label(text, PROMPT_SIZE + 3, tint))

	_career_column.add_child(_gap(10))
	_career_column.add_child(_make_label(
		str(career.venue()["blurb"]), PROMPT_SIZE, Color(0.70, 0.72, 0.76)
	))
	_career_column.add_child(_make_label(
		"Reputation %d / 100          %s" % [
			roundi(career.reputation * 100.0),
			"best of three to 21" if not career.venue()["quick"] else "one game to 11",
		],
		PROMPT_SIZE + 2,
		Color(0.88, 0.90, 0.93)
	))
	_career_column.add_child(_gap(16))
	# The button only reports the choice; the match decides what happens to the
	# screen. Hiding it in here means the flow only works when a human clicks.
	_career_column.add_child(_make_wide_button("REFEREE THIS MATCH", func() -> void:
		match_requested.emit()
	))


func hide_career() -> void:
	_career_panel.visible = false


## Clears every front-of-game screen. Called wherever a match begins, so that no
## route in can leave a menu sitting over the court — which each of these panels has
## managed to do in turn.
func hide_menus() -> void:
	_main_menu.visible = false
	_career_panel.visible = false
	_pause_menu.visible = false
	_length_panel.visible = false


func _gap(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _make_wide_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 52)
	button.add_theme_font_size_override("font_size", BUTTON_SIZE - 2)
	button.pressed.connect(on_press)
	var row := button
	return row


func _build_length_panel() -> void:
	_length_panel = Control.new()
	_length_panel.name = "MatchLength"
	_length_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_length_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_length_panel)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.05, 0.06, 0.08, 0.94)
	_length_panel.add_child(backdrop)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	_length_panel.add_child(column)

	column.add_child(_make_label("HOW LONG HAVE YOU GOT?", TITLE_SIZE, Color(0.95, 0.95, 0.93)))
	column.add_child(_make_label(
		"A longer match gives you more chances, and more chances to be caught taking them.",
		PROMPT_SIZE,
		Color(0.62, 0.64, 0.68)
	))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	column.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)

	row.add_child(_make_length_button("QUICK GAME\nfirst to 11", true))
	row.add_child(_make_length_button("FULL MATCH\nbest of 3 to 21", false))


func _make_length_button(text: String, quick: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(210, 66)
	button.add_theme_font_size_override("font_size", BUTTON_SIZE - 4)
	# The button only reports the choice. Which screen comes next is the match's
	# decision, not this file's — otherwise the flow only works when a human clicks.
	button.pressed.connect(func() -> void: length_chosen.emit(quick))
	return button


func _build_pre_match() -> void:
	_pre_match = Control.new()
	_pre_match.name = "PreMatch"
	_pre_match.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pre_match.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pre_match)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.05, 0.06, 0.08, 0.94)
	_pre_match.add_child(backdrop)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	_pre_match.add_child(column)

	column.add_child(_make_label("WHO DO YOU WANT TO WIN?", TITLE_SIZE, Color(0.95, 0.95, 0.93)))
	column.add_child(_make_label(
		"Nobody will ever know you chose. Pick nobody to referee honestly.",
		PROMPT_SIZE,
		Color(0.62, 0.64, 0.68)
	))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	column.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)

	for team in [Sides.Team.RED, Sides.Team.BLUE, Sides.Team.NONE]:
		row.add_child(_make_choice_button(team))


func _make_choice_button(team: Sides.Team) -> Button:
	var button := Button.new()
	button.text = "  %s  " % Sides.label(team)
	button.custom_minimum_size = Vector2(150, 52)
	button.add_theme_font_size_override("font_size", BUTTON_SIZE)
	button.add_theme_color_override("font_color", Sides.colour(team))
	button.pressed.connect(func() -> void: favour_chosen.emit(team))
	return button


## Moves on from the match-length question to the one that matters.
func show_favour_choice() -> void:
	_length_panel.visible = false
	_pre_match.visible = true


func show_pre_match() -> void:
	_pre_match.visible = true


func hide_pre_match() -> void:
	_pre_match.visible = false


# --- in-match ------------------------------------------------------------------

func _build_hud() -> void:
	var hud := Control.new()
	hud.name = "Hud"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	# The score and the prompt sit on plates. White text over a lit green court is
	# legible about half the time, which for the one line telling you the score is
	# half the time too little.
	_score_label = _make_label("", SCORE_SIZE, Color(0.96, 0.96, 0.94))
	hud.add_child(_plate_for(_score_label, Control.PRESET_CENTER_TOP, Vector2(0, 18)))

	_message_label = _make_label("", MESSAGE_SIZE, Color(0.98, 0.94, 0.72))
	_message_label.set_anchors_preset(Control.PRESET_CENTER)
	_message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_message_label.position = Vector2(0, -70)
	hud.add_child(_message_label)

	_prompt_label = _make_label("", PROMPT_SIZE, Color(0.88, 0.90, 0.93))
	hud.add_child(_plate_for(_prompt_label, Control.PRESET_CENTER_BOTTOM, Vector2(0, -34)))

	# What the hall is doing. This is the only feedback the player ever gets about
	# how much trouble they are in — there is no suspicion bar anywhere, on purpose.
	_reaction_label = _make_label("", REACTION_SIZE, Color(0.86, 0.80, 0.66))
	_reaction_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_reaction_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_reaction_label.position = Vector2(0, -110)
	hud.add_child(_reaction_label)

	_banner_label = _make_label("", BANNER_SIZE, Color(0.96, 0.42, 0.36))
	_banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner_label.position = Vector2(0, 76)
	hud.add_child(_banner_label)


func set_score(board: Scoreboard, serving: Sides.Team) -> void:
	var red_mark := "•" if serving == Sides.Team.RED else " "
	var blue_mark := "•" if serving == Sides.Team.BLUE else " "
	var games := ""
	if board.games_needed > 1:
		games = "        games  %d — %d" % [
			board.games[Sides.Team.RED], board.games[Sides.Team.BLUE]
		]
	_score_label.text = "%s RED  %d  —  %d  BLUE %s%s" % [
		red_mark, board.points[Sides.Team.RED], board.points[Sides.Team.BLUE], blue_mark, games
	]


func set_prompt(text: String) -> void:
	_prompt_label.text = text


## Shows what the umpire announced. Deliberately says nothing about whether it was
## true — only what was said, and what it did to the score.
func announce(text: String, tint: Color, seconds := 1.8) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", tint)
	_message_timer = seconds


## What the hall did in response to the call. Says nothing about whether the call
## was right — only what the people watching thought of it.
func react(line: String, seconds := 2.6) -> void:
	if line.is_empty():
		return
	_reaction_label.text = line
	_reaction_timer = seconds


func show_banner(text: String, seconds := 5.0) -> void:
	_banner_label.text = text
	_banner_timer = seconds


# --- accusing somebody ---------------------------------------------------------
#
# Every one of these calls has to name a side, which is the awkward part: IN and OUT
# are about the shuttle, but a fault is about a person. Rather than invent a key
# combination for "net touch, against blue", the umpire points — and pointing at
# somebody is exactly the gesture being made.

func _build_fault_panel() -> void:
	_fault_panel = Control.new()
	_fault_panel.name = "FaultPanel"
	_fault_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fault_panel.visible = false
	_fault_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fault_panel)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.05, 0.07, 0.82)
	_fault_panel.add_child(backdrop)

	_fault_rows = VBoxContainer.new()
	_fault_rows.set_anchors_preset(Control.PRESET_CENTER)
	_fault_rows.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fault_rows.grow_vertical = Control.GROW_DIRECTION_BOTH
	_fault_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_fault_rows.add_theme_constant_override("separation", 10)
	_fault_panel.add_child(_fault_rows)


## Builds the list fresh each time, because between rallies there is no rally to
## fault anybody over — only misconduct, which can be punished whenever you like.
func show_fault_panel(cards_only: bool) -> void:
	for child in _fault_rows.get_children():
		child.queue_free()

	_fault_rows.add_child(_make_label(
		"CARDS" if cards_only else "FAULT — AGAINST WHOM?", TITLE_SIZE - 6, Color(0.95, 0.95, 0.93)
	))
	_fault_rows.add_child(_make_label(
		"BLUE is on your left, RED on your right.        ESC to say nothing.",
		PROMPT_SIZE, Color(0.62, 0.64, 0.68)
	))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	_fault_rows.add_child(spacer)

	if not cards_only:
		for call in CallBook.faults():
			_fault_rows.add_child(_make_accusation_row(call.label, call.id, Color(0.90, 0.88, 0.84)))

	_fault_rows.add_child(_make_accusation_row("YELLOW CARD", &"yellow", Color(0.95, 0.85, 0.30)))
	_fault_rows.add_child(_make_accusation_row("RED CARD", &"red", Color(0.94, 0.36, 0.32)))

	_fault_panel.visible = true


func _make_accusation_row(label: String, id: StringName, tint: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	var name_label := _make_label(label, PROMPT_SIZE + 3, tint)
	name_label.custom_minimum_size = Vector2(220, 40)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_label)

	for team in [Sides.Team.BLUE, Sides.Team.RED]:
		var button := Button.new()
		button.text = Sides.label(team)
		button.custom_minimum_size = Vector2(110, 40)
		button.add_theme_font_size_override("font_size", BUTTON_SIZE - 5)
		button.add_theme_color_override("font_color", Sides.colour(team))
		button.pressed.connect(func() -> void: punishment_chosen.emit(id, team))
		row.add_child(button)

	return row


func hide_fault_panel() -> void:
	_fault_panel.visible = false


func is_fault_panel_open() -> bool:
	return _fault_panel.visible


# --- the shuttle camera --------------------------------------------------------

func _build_shuttle_cam() -> void:
	_shuttle_cam_panel = Control.new()
	_shuttle_cam_panel.name = "ShuttleCam"
	_shuttle_cam_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_shuttle_cam_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_shuttle_cam_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_shuttle_cam_panel.position = Vector2(-ShuttleCam.WIDTH - 26, -ShuttleCam.HEIGHT - 52)
	_shuttle_cam_panel.custom_minimum_size = Vector2(ShuttleCam.WIDTH, ShuttleCam.HEIGHT + 24)
	_shuttle_cam_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shuttle_cam_panel.visible = false
	add_child(_shuttle_cam_panel)

	var frame := ColorRect.new()
	frame.color = Color(0.04, 0.05, 0.06, 0.9)
	frame.position = Vector2(-3, -3)
	frame.size = Vector2(ShuttleCam.WIDTH + 6, ShuttleCam.HEIGHT + 6)
	_shuttle_cam_panel.add_child(frame)

	_shuttle_cam_view = TextureRect.new()
	_shuttle_cam_view.size = Vector2(ShuttleCam.WIDTH, ShuttleCam.HEIGHT)
	_shuttle_cam_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shuttle_cam_view.stretch_mode = TextureRect.STRETCH_SCALE
	_shuttle_cam_panel.add_child(_shuttle_cam_view)

	var caption := _make_label("SHUTTLE CAM", PROMPT_SIZE - 3, Color(0.72, 0.74, 0.78))
	caption.position = Vector2(0, ShuttleCam.HEIGHT + 4)
	caption.size = Vector2(ShuttleCam.WIDTH, 18)
	_shuttle_cam_panel.add_child(caption)


## Shows the line camera's view of where the shuttle came down. The picture is
## deliberately small: it settles the obvious ones and settles nothing else, which
## is the only way it can exist without answering the question for the player.
func show_shuttle_cam(view: Texture2D) -> void:
	if _shuttle_cam_view.texture != view:
		_shuttle_cam_view.texture = view
	_shuttle_cam_panel.visible = true


func hide_shuttle_cam() -> void:
	_shuttle_cam_panel.visible = false


# --- the end of the match ------------------------------------------------------

func _build_ending() -> void:
	_ending = Control.new()
	_ending.name = "Ending"
	_ending.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ending.visible = false
	_ending.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_ending)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.03, 0.04, 0.96)
	_ending.add_child(backdrop)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 22)
	_ending.add_child(column)

	_ending_headline = _make_label("", TITLE_SIZE, Color(0.96, 0.42, 0.36))
	column.add_child(_ending_headline)

	_ending_detail = _make_label("", PROMPT_SIZE + 2, Color(0.80, 0.80, 0.82))
	column.add_child(_ending_detail)

	column.add_child(_gap(18))
	_ending_button = _make_wide_button("CONTINUE", func() -> void: continue_requested.emit())
	var centred := HBoxContainer.new()
	centred.alignment = BoxContainer.ALIGNMENT_CENTER
	centred.add_child(_ending_button)
	column.add_child(centred)


## The reckoning. Once the match is over the truth is finally allowed on screen —
## this is the only place in the whole game where that is true.
func show_ending(headline: String, detail: String, tint := Color(0.96, 0.42, 0.36)) -> void:
	_ending.visible = true
	_ending_headline.text = headline
	_ending_headline.add_theme_color_override("font_color", tint)
	_ending_detail.text = detail
	_ending.visible = true


## Wraps a label in a dark plate and anchors the pair where it belongs.
func _plate_for(label: Label, preset: int, offset: Vector2, alpha := 0.55) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _plate_style(alpha))
	plate.set_anchors_preset(preset)
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.grow_vertical = Control.GROW_DIRECTION_BOTH
	plate.position = offset
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	return plate


func _plate_style(alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.06, 0.08, alpha)
	box.set_corner_radius_all(7)
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	box.content_margin_top = 7.0
	box.content_margin_bottom = 7.0
	return box


func _make_label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label
