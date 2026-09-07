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

const TITLE_SIZE := 34
const BUTTON_SIZE := 22
const SCORE_SIZE := 30
const MESSAGE_SIZE := 40
const PROMPT_SIZE := 17
const REACTION_SIZE := 19
const BANNER_SIZE := 24

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
var _shuttle_cam_panel: Control
var _shuttle_cam_view: TextureRect
var _message_timer := 0.0
var _reaction_timer := 0.0
var _banner_timer := 0.0


func _ready() -> void:
	layer = 10
	_build_length_panel()
	_build_pre_match()
	_build_hud()
	_build_ending()
	_build_shuttle_cam()
	_pre_match.visible = false
	_length_panel.visible = true


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

	_score_label = _make_label("", SCORE_SIZE, Color(0.96, 0.96, 0.94))
	_score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_score_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_score_label.position = Vector2(0, 26)
	hud.add_child(_score_label)

	_message_label = _make_label("", MESSAGE_SIZE, Color(0.98, 0.94, 0.72))
	_message_label.set_anchors_preset(Control.PRESET_CENTER)
	_message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_message_label.position = Vector2(0, -70)
	hud.add_child(_message_label)

	_prompt_label = _make_label("", PROMPT_SIZE, Color(0.88, 0.90, 0.93))
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_label.position = Vector2(0, -66)
	hud.add_child(_prompt_label)

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


## The reckoning. Once the match is over the truth is finally allowed on screen —
## this is the only place in the whole game where that is true.
func show_ending(headline: String, detail: String, tint := Color(0.96, 0.42, 0.36)) -> void:
	_ending_headline.text = headline
	_ending_headline.add_theme_color_override("font_color", tint)
	_ending_detail.text = detail
	_ending.visible = true


func _make_label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label
