class_name RefereeUI
extends CanvasLayer

## Everything the player sees that is not the court.
##
## One rule governs this whole file: it is never told where the shuttle landed. It
## shows the score, the call that was made, and who got the point — all things the
## hall can see. Whether the call was true is not among them. The moment this screen
## can tell the player they got it right, the game stops being about judgement.

signal briefing_acknowledged()
signal punishment_chosen(id: StringName, team: Sides.Team)
signal match_requested()
signal play_requested()
signal sport_chosen(id: StringName)
signal format_chosen(doubles: bool)
signal settings_requested()

## BACK, when the settings were opened from a paused match rather than from the title
## screen. The two go to different places and the sheet is the same sheet.
signal settings_closed()
signal main_menu_requested()
signal look_speed_changed(radians_per_pixel: float)
signal teaching_requested()
signal teaching_finished()
signal career_restart_requested()
signal continue_requested()
signal new_career_requested()
signal career_screen_requested()
signal history_requested()
signal resume_requested()
signal walk_out_requested()
signal quit_requested()

## Sizes live in UiTheme so the whole interface grows together. It used to be a list
## of numbers here, each one adjusted separately, which is how it ended up too small to
## read from where the player is actually sitting.
const TITLE_SIZE := UiTheme.TITLE
const BUTTON_SIZE := UiTheme.HEADING
const SCORE_SIZE := UiTheme.TITLE
const MESSAGE_SIZE := UiTheme.HUGE
const PROMPT_SIZE := UiTheme.BODY
const REACTION_SIZE := UiTheme.BODY
const BANNER_SIZE := UiTheme.HEADING

## The reputation meter: how long it fades in, how long it stays, how long it fades out.
## Three seconds all told, which is long enough to read and short enough that it is gone
## again before the next serve.
const METER_FADE_IN := 0.4
const METER_HOLD := 2.2
const METER_FADE_OUT := 0.4

## How wide the bar is, and where the colour of the fill changes.
## How wide the reason note on the left is allowed to be before it wraps, and how far
## in from the edge of the screen it sits. Narrow on purpose: it is read at a glance
## out of the corner of the eye while the next serve is being walked back to.
## The bubble over a spectator's head: how wide it may get before it wraps, how far
## its point sits above their hair, and how big the tail is.
const BUBBLE_MAX_WIDTH := 360
const BUBBLE_LIFT := 14
const BUBBLE_TAIL := 11
const BUBBLE_FADE := 0.25
const BUBBLE_HOLD := 2.4

const REASON_WIDTH := 380
const REASON_INSET := 44

const METER_WIDTH := 520
const METER_HEIGHT := 26
const METER_SAFE := 0.60
const METER_SHAKY := 0.30

## Everything is parented to this rather than to the layer, because a Theme travels
## down a Control tree and a CanvasLayer is not a Control. One assignment here styles
## every button, label and panel in the game.
var _root: Control
var _hud: Control

## The sports, in the order they appear. Five of them are games; the last one is here
## because saying out loud what is coming is more honest than pretending it is finished.
##
## The finished sports are photographs of this game, rendered by dev/looks/_cards.gd. The
## one that is not built yet is a public-domain Olympic pictogram — see
## assets/ui/ATTRIBUTION.md. That split is the whole point of the row: a real picture
## means a sport you can actually walk into.
const SPORTS := [
	{"id": &"badminton", "name": "Badminton", "art": "res://assets/ui/card_badminton.png",
		"tint": Color(0.16, 0.44, 0.30), "ready": true},
	{"id": &"beach", "name": "Beach Volleyball",
		"art": "res://assets/ui/card_beachvolleyball.png",
		"tint": Color(0.78, 0.52, 0.20), "ready": true},
	{"id": &"indoor", "name": "Volleyball", "art": "res://assets/ui/card_volleyball.png",
		"tint": Color(0.44, 0.24, 0.52), "ready": true},
	{"id": &"tennis", "name": "Tennis", "art": "res://assets/ui/card_tennis.png",
		"tint": Color(0.20, 0.38, 0.58), "ready": true},
	{"id": &"table_tennis", "name": "Table Tennis",
		"art": "res://assets/ui/card_tabletennis.png",
		"tint": Color(0.60, 0.34, 0.16), "ready": true},
	{"id": &"basketball", "name": "Basketball", "art": "res://assets/ui/sport_basketball.png",
		"tint": Color(0.56, 0.22, 0.24), "ready": false},
]

## How big one card is. Tall, like the reference — a sport reads better as a portrait of
## somebody playing it than as a square.
const CARD := Vector2(232.0, 330.0)

var _main_menu: Control
var _main_menu_column: VBoxContainer
var _sport_menu: Control
var _format_menu: Control
var _format_column: VBoxContainer
var _settings_menu: Control
var _pause_menu: Control
var _career_panel: Control
var _career_column: VBoxContainer
var _ending_button: Button

## The screen that gives you a reason before it asks you the question.
var _close_cam_caption: Label
var _briefing: Control
var _briefing_headline: Label
var _briefing_detail: Label
var _briefing_ask: Label
var _ending: Control
var _ending_headline: Label
var _ending_detail: Label
var _score_points: Label
var _score_games: Label
var _score_reviews: Label
var _serve_red: Label
var _serve_blue: Label
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

## What the line judge called, and how long it stays up.
var _judge_label: Label
var _judge_plate: PanelContainer
var _judge_timer := 0.0

## The reputation meter, and where it is in its three seconds. `_meter_left` counts down
## through fade-in, hold and fade-out together, so re-triggering it while it is already
## up simply refills the clock rather than starting the fade again — which matters,
## because calls come close together and a meter that re-faded would flicker.
var _meter: PanelContainer
var _meter_bar: ProgressBar
var _meter_value: Label
var _meter_fill: StyleBoxFlat
var _meter_left := 0.0
var _meter_shown := 0.0

var _reason: PanelContainer
var _reason_label: Label
var _reason_left := 0.0
var _reason_shown := 0.0

## What the note said when the match was paused, so it can be put back afterwards.
##
## Pausing takes it down, because a sentence in the corner sitting across the RESUME
## button is worse than no sentence. But the note has no clock and comes down only when
## the umpire whistles the next rally, so a pause that simply deleted it threw away the
## one thing the player had not finished reading — and a player who opens the settings
## to turn the crowd down is exactly the player who was still looking at it.
var _reason_paused := ""

## Whether the note is sitting there waiting to be read rather than counting down.
var _reason_holding := false

## The pause menu's free exit, and the line under it. Both hidden once the match has
## begun to matter.
var _leave_button: Button
var _leave_note: Label


func _ready() -> void:
	layer = 10
	# Keeps running while the game is paused, or nothing could unpause it.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.name = "Screen"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.build()
	add_child(_root)

	_build_main_menu()
	_build_sport_menu()
	_build_format_menu()
	_build_review()
	_build_pause_menu()
	_build_career_panel()
	_build_history_panel()
	_build_briefing()
	_build_hud()
	_build_ending()
	_build_shuttle_cam()
	_build_fault_panel()
	_briefing.visible = false


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
	_judge_timer = _tick(delta, _judge_timer, _judge_label)
	if _judge_plate != null and _judge_timer <= 0.0:
		_judge_plate.visible = false
	_tick_the_meter(delta)
	_tick_the_reason(delta)
	_tick_the_bubble(delta)


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
## `shade` is the sheet drawn over the hall behind a menu. It is deliberately light now:
## the arena it covers is already a dark room, and stacking a heavy black sheet on top
## of it turned the backdrop to mud. The card itself is opaque, so the sheet only has to
## settle the surroundings, not hide them.
func _build_sheet(sheet_name: String, shade := Color(0.03, 0.04, 0.06, 0.45)) -> Array:
	var sheet := Control.new()
	sheet.name = sheet_name
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.visible = false
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(sheet)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = shade
	sheet.add_child(backdrop)

	# The contents sit on a card rather than floating on the dimmed court. A broadcast
	# graphic is always a solid shape with an edge on it; text alone over a photograph
	# is what a placeholder looks like.
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	sheet.add_child(card)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	column.custom_minimum_size = Vector2(UiTheme.BUTTON_WIDTH + 90, 0)
	card.add_child(column)

	return [sheet, column]


func _build_main_menu() -> void:
	var built := _build_sheet("MainMenu", Color(0.03, 0.04, 0.06, 0.40))
	_main_menu = built[0]
	_main_menu_column = built[1]


## The title screen. Whether there is a career to go back to decides what it offers.
##
## The score bug goes away with it. It is a broadcast graphic for a match in progress,
## and leaving it up over the title read as though a game were already running.
func show_main_menu(career: Career) -> void:
	if _hud != null:
		_hud.visible = false
	for child in _main_menu_column.get_children():
		child.queue_free()

	_main_menu_column.add_child(_make_label("REFEREE FOR FUN", TITLE_SIZE + 16, Color(0.96, 0.96, 0.94)))
	_main_menu_column.add_child(_make_label(
		"You are the umpire. The game knows the truth. You do not have to tell it.",
		PROMPT_SIZE + 2, Color(0.62, 0.64, 0.68)
	))
	_main_menu_column.add_child(_gap(26))

	# Three buttons and nothing else. Whether there is a career to go back to is a
	# question for after the sport has been chosen, not for the title screen — it used to
	# be answered here, and the front of the game read as a save-game manager.
	var underway := career.matches_refereed > 0 and not career.is_over
	if underway:
		_main_menu_column.add_child(_make_label(
			"%s in progress        reputation %d / 100" % [
				career.venue()["name"], roundi(career.reputation * 100.0)
			],
			PROMPT_SIZE, Color(0.58, 0.60, 0.64)
		))
		_main_menu_column.add_child(_gap(10))

	_main_menu_column.add_child(_centred(_make_wide_button(
		"PLAY", func() -> void: play_requested.emit()
	)))
	_main_menu_column.add_child(_gap(6))
	_main_menu_column.add_child(_centred(_make_wide_button(
		"HOW TO REFEREE", func() -> void: teaching_requested.emit()
	)))
	_main_menu_column.add_child(_gap(6))
	_main_menu_column.add_child(_centred(_make_wide_button(
		"SETTINGS", func() -> void: settings_requested.emit()
	)))
	_main_menu_column.add_child(_gap(6))
	_main_menu_column.add_child(_centred(_make_wide_button("QUIT", func() -> void: quit_requested.emit())))

	_main_menu.visible = true


# --- choosing a sport -----------------------------------------------------------

## The row of sports. One card each: a picture, and the name under it.
##
## Only badminton opens. The rest are drawn dim with COMING SOON across them, which is
## the honest version of a full screen — the alternative was one card on its own, and a
## menu that asks you to choose between one thing is not really asking.
func _build_sport_menu() -> void:
	var built := _build_sheet("SportMenu", Color(0.03, 0.04, 0.06, 0.55))
	_sport_menu = built[0]
	var column: VBoxContainer = built[1]
	column.custom_minimum_size = Vector2(0, 0)

	column.add_child(_make_label("WHICH SPORT?", TITLE_SIZE, UiTheme.CHALK))
	column.add_child(_gap(6))
	column.add_child(_make_label(
		"Five of them are ready. The last is on its way.",
		PROMPT_SIZE, UiTheme.MUTED
	))
	column.add_child(_gap(22))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	for sport in SPORTS:
		row.add_child(_sport_card(sport))

	column.add_child(_gap(22))
	column.add_child(_centred(_make_wide_button("BACK", func() -> void:
		main_menu_requested.emit())))


# --- one a side or two ----------------------------------------------------------

## Asked only for the two sports that have both, and asked rather than assumed.
##
## Singles and doubles are not the same game with fewer people in it. The court is a
## different width — badminton's singles sidelines are 42 cm inside the doubles ones, and
## a shuttle landing between them is in for one game and out for the other. The service
## court is a different length. And in badminton the serving order changes completely:
## in doubles the side keeps the serve and the two of them alternate courts, in singles
## the server's own score decides which box they serve from.
##
## So the referee's job is different, and being asked which job it is belongs at the
## front of the game rather than in a settings screen somewhere.
func _build_format_menu() -> void:
	var built := _build_sheet("FormatMenu", Color(0.03, 0.04, 0.06, 0.55))
	_format_menu = built[0]
	_format_column = built[1]


## `sport` names the game so the question reads as a question about that sport.
func show_format_menu(sport: StringName) -> void:
	for child in _format_column.get_children():
		child.queue_free()
	if _hud != null:
		_hud.visible = false
	hide_sport_menu()

	_format_column.add_child(_make_label(
		"%s" % Career.name_of(sport).to_upper(), TITLE_SIZE, UiTheme.CHALK))
	_format_column.add_child(_gap(6))
	_format_column.add_child(_make_label(
		"One a side or two? They are different jobs.", PROMPT_SIZE, UiTheme.MUTED))
	_format_column.add_child(_gap(20))

	var singles := "the narrow court, and the server's score says which box"
	var doubles := "the full width, and a serving order to keep track of"
	if sport == Career.TENNIS:
		singles = "the narrow court — the tramlines are out"
		doubles = "the tramlines are live, except on the serve"

	_format_column.add_child(_centred(_make_wide_button("SINGLES", func() -> void:
		format_chosen.emit(false))))
	_format_column.add_child(_make_label(singles, PROMPT_SIZE - 2, UiTheme.MUTED))
	_format_column.add_child(_gap(10))
	_format_column.add_child(_centred(_make_wide_button("DOUBLES", func() -> void:
		format_chosen.emit(true))))
	_format_column.add_child(_make_label(doubles, PROMPT_SIZE - 2, UiTheme.MUTED))

	_format_column.add_child(_gap(20))
	_format_column.add_child(_centred(_make_wide_button("BACK", func() -> void:
		hide_format_menu()
		show_sport_menu())))
	_format_menu.visible = true


func hide_format_menu() -> void:
	if _format_menu != null:
		_format_menu.visible = false


func _sport_card(sport: Dictionary) -> Button:
	var ready: bool = sport["ready"]
	var card := Button.new()
	card.custom_minimum_size = CARD
	card.disabled = not ready
	card.tooltip_text = "" if ready else "Not built yet"
	if ready:
		card.pressed.connect(func() -> void: sport_chosen.emit(sport["id"]))

	# The card's own colour shows through behind the picture, which is what makes the
	# row read as a set rather than as five unrelated photographs.
	var face := StyleBoxFlat.new()
	var tint: Color = sport["tint"]
	face.bg_color = tint if ready else tint.darkened(0.55)
	face.set_content_margin_all(0)
	face.border_width_left = 0
	face.corner_radius_top_left = 4
	face.corner_radius_top_right = 4
	card.add_theme_stylebox_override("normal", face)
	card.add_theme_stylebox_override("disabled", face)
	var lit := face.duplicate()
	lit.bg_color = tint.lightened(0.16)
	lit.border_width_top = 5
	lit.border_color = UiTheme.ACCENT
	card.add_theme_stylebox_override("hover", lit)
	card.add_theme_stylebox_override("focus", lit)
	card.add_theme_stylebox_override("pressed", lit)

	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 0)
	card.add_child(stack)

	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(CARD.x, CARD.y - 62.0)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# The badminton card is a photograph and should fill the space; the pictograms are
	# silhouettes on nothing and have to keep their shape or they turn into smears.
	picture.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_COVERED if ready
		else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	if ResourceLoader.exists(sport["art"]):
		picture.texture = load(sport["art"])
	if not ready:
		picture.modulate = Color(1.0, 1.0, 1.0, 0.34)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(picture)

	var name_plate := PanelContainer.new()
	name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Takes whatever height the picture left, so the plate reaches the bottom edge. Sized
	# to its text instead, it stopped short and left a stripe of the card's own colour
	# under the name.
	name_plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.05, 0.06, 0.08, 0.92)
	plate.content_margin_top = 8
	plate.content_margin_bottom = 8
	name_plate.add_theme_stylebox_override("panel", plate)
	stack.add_child(name_plate)

	var caption := _make_label(
		sport["name"] if ready else "%s\nCOMING SOON" % sport["name"],
		UiTheme.SMALL if ready else UiTheme.SMALL - 4,
		UiTheme.CHALK if ready else UiTheme.MUTED
	)
	name_plate.add_child(caption)
	return card


func show_sport_menu() -> void:
	if _hud != null:
		_hud.visible = false
	_sport_menu.visible = true


func hide_sport_menu() -> void:
	_sport_menu.visible = false


# --- the review ------------------------------------------------------------------

## The Hawk-Eye panel: the one place the game shows the player what really happened.
##
## Everything else here is built on never telling them. The rule is stated at the top of
## this file and it holds — but a review is not the game confessing, it is the hall
## finding out, and the umpire is simply in the room when it does. That is the whole
## point of the feature: the truth arriving in public, at a size nobody can argue with,
## whether or not the umpire wanted it.
var _review: Control
var _review_headline: Label
var _review_note: Label
var _review_view: TextureRect
var _review_verdict: Label
var _review_hint: Label


func _build_review() -> void:
	var built := _build_sheet("Review", Color(0.02, 0.03, 0.05, 0.66))
	_review = built[0]
	var column: VBoxContainer = built[1]

	_review_headline = _make_label("", TITLE_SIZE, UiTheme.ACCENT)
	column.add_child(_review_headline)
	_review_note = _make_label("", UiTheme.SMALL, UiTheme.MUTED)
	column.add_child(_review_note)
	column.add_child(_gap(16))

	_review_view = TextureRect.new()
	_review_view.custom_minimum_size = Vector2(400, 400)
	_review_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_review_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_centred(_review_view))

	column.add_child(_gap(16))
	_review_verdict = _make_label("", UiTheme.HEADING, UiTheme.CHALK)
	column.add_child(_review_verdict)

	# Only filled once the answer is up. Before that there is nothing to wave on.
	_review_hint = _make_label("", UiTheme.SMALL, UiTheme.MUTED)
	column.add_child(_review_hint)


## Opens the review. The verdict is deliberately not filled in yet — the pause between
## the challenge and the answer is the whole of the drama, and an umpire who has just
## lied should have to sit through it.
func show_review(team: Sides.Team, reviews_left: int, view: Texture2D) -> void:
	_review_headline.text = "CHALLENGE  ·  %s" % Sides.label(team)
	_review_headline.add_theme_color_override("font_color", Sides.colour(team))
	_review_note.text = "%s has %d review%s left" % [
		Sides.label(team), reviews_left, "" if reviews_left == 1 else "s"]
	_review_view.texture = view
	_review_verdict.text = "reviewing…"
	_review_verdict.add_theme_color_override("font_color", UiTheme.MUTED)
	_review_hint.text = ""
	_review.visible = true


## The line under the verdict telling the official they may wave it on. Set only once
## the answer is up: the wait before that is the whole point of a review.
func set_review_hint(text: String) -> void:
	_review_hint.text = text


func set_review_verdict(text: String, tint: Color) -> void:
	_review_verdict.text = text
	_review_verdict.add_theme_color_override("font_color", tint)


func hide_review() -> void:
	if _review != null:
		_review.visible = false


# --- teaching -------------------------------------------------------------------

## What the game never told anybody.
##
## Everything this game asks of you is invisible unless somebody says it out loud. It
## wants you to spot a carry, which is a hesitation in a stroke lasting a fifth of a
## second; it wants you to know that a shuttle failing to cross the net is called OUT
## however far inside the lines it lands; and it wants all of that from a player who may
## never have watched a badminton match, let alone refereed one.
##
## Until this screen existed the entire instruction was a single line of key bindings.
## Luqman could not tell whether the game was scoring him unfairly or whether he was
## simply missing things — and it turned out to be both, which is exactly the confusion
## that not explaining yourself produces.
const BADMINTON_LESSONS := [
	{
		"title": "THE JOB",
		"body": "You are the umpire, and you never leave the chair.\n\n"
			+ "The game plays a real rally and records exactly where the shuttle came "
			+ "down, to the millimetre. Nobody else in the building will say what "
			+ "happened. You will.\n\n"
			+ "You can tell the truth. Nothing here requires you to.",
		"keys": [
			["SPACE", "whistle the rally in"],
			["LEFT CLICK", "in"],
			["RIGHT CLICK", "out"],
			["L", "let — play it again"],
			["W", "service court error"],
			["F", "a fault, or a card"],
			["ESC", "pause"],
		],
	},
	{
		"title": "IN AND OUT",
		"art": "res://assets/ui/court_map.png",
		"body": "Green is the court. A shuttle landing anywhere on it is IN — including "
			+ "on a line, because the lines belong to the court. Red is outside it.\n\n"
			+ "The narrow strips down each side are in play too. This is doubles.\n\n"
			+ "And the one that catches people out: a shuttle that never gets over the "
			+ "net is a fault against whoever hit it. Call OUT — however far inside the "
			+ "lines it landed.",
	},
	{
		"title": "THE FAULTS",
		"body": "Press F, then point at whoever did it.\n\n"
			+ "NET TOUCH   the net shakes. Somebody was touching it with the shuttle "
			+ "still live.\n\n"
			+ "CARRY   the shuttle hesitates on the racket instead of leaving it "
			+ "cleanly. Easy to miss. That is the point of it.\n\n"
			+ "DOUBLE HIT   the same side strikes it twice in a row.\n\n"
			+ "OBSTRUCTION   a player reaches over the net.\n\n"
			+ "Missing one is not free. If the point then goes to the side that cheated, "
			+ "the hall saw what you did not.",
	},
	{
		"title": "THE SERVE",
		"body": "A serve is the one moment in badminton when everything stops. Both "
			+ "players are still, nobody is scrambling, and the whole hall is watching "
			+ "one person do one thing slowly. Three things can be wrong with it, and "
			+ "all three are on the F panel.\n\n"
			+ "ABOVE 1.15   the whole shuttle must be below 1.15 metres when it is "
			+ "struck. Not the server's waist — a fixed height, measured, since 2018. A "
			+ "waist is an argument; a number is a fact.\n\n"
			+ "RACKET UP   the shaft must be pointing downwards at the moment of "
			+ "contact. If the head is up, it is a fault however good the serve was.\n\n"
			+ "FOOT MOVED   both feet stay still, and on the floor, from the start of "
			+ "the service until it is delivered.\n\n"
			+ "A real match gives these their own official, sitting at the side of the "
			+ "court with nothing else to look at. You do not get one. But you also have "
			+ "nowhere to hide: everybody was watching the same thing you were, which "
			+ "makes a service fault you invent the least deniable call in the sport.",
	},
	{
		"title": "THE SERVICE COURTS",
		"body": "Before every serve, look at where the four of them are standing.\n\n"
			+ "The server's own score decides which box they serve from. An EVEN score "
			+ "— nought, two, four — and they serve from their RIGHT-hand court. An ODD "
			+ "score, and they serve from their LEFT. The receiver stands diagonally "
			+ "opposite them, and the two partners keep out of it.\n\n"
			+ "The quick way to see it from the chair: server and receiver should be "
			+ "DIAGONAL — one of them near you, one of them away from you. If the two of "
			+ "them are level with each other, somebody is in the wrong box, and the "
			+ "server's score tells you which.\n\n"
			+ "When somebody gets that wrong, press W.\n\n"
			+ "Say it before you whistle and the serve is simply taken again. Say it "
			+ "after the rally and it is too late to undo anything: the error is "
			+ "corrected and the score stands, exactly as the law has it.\n\n"
			+ "This one cannot win anybody a point, which makes it the only call here "
			+ "you have nothing to gain by lying about — and the only one whose answer "
			+ "was in front of you the whole time, if you were looking.",
	},
	{
		"title": "WHO IS WATCHING",
		"body": "Two line judges sit at opposite corners. They call their own lines, and "
			+ "on the close ones they are wrong about as often as a coin. Agree with a "
			+ "mistake and it is shared with an official in plain sight. Overrule them "
			+ "and the hall has just watched two officials disagree, with only your call "
			+ "left standing.\n\n"
			+ "The shuttle cam shows you the landing from directly overhead once it is "
			+ "down.\n\n"
			+ "At the bigger tournaments the players can challenge you. Each side gets "
			+ "two reviews a game, and a successful one is handed back. The hall watches "
			+ "the landing on a screen and then everybody knows — including about the "
			+ "close ones you were relying on nobody being sure about. Being caught that "
			+ "way costs far more than the same call going unchallenged.",
	},
	{
		"title": "YOUR NAME",
		"body": "Nothing in this game counts your mistakes for you. What you get while "
			+ "you referee is the room — how it sounds, and whether it comes out of its "
			+ "seat — and one number, which is this one.\n\n"
			+ "REPUTATION is your name, out of a hundred, and it follows you from match "
			+ "to match and from sport to sport. It is the only thing here that outlives "
			+ "the match it happened in.\n\n"
			+ "The bar appears at the bottom of the screen ONLY WHEN IT MOVES, for about "
			+ "three seconds, and then it is gone. So it is never something to stare at. "
			+ "It catches your eye at the moment a call has just cost you something, "
			+ "which is the only moment worth knowing about.\n\n"
			+ "It falls when you are wrong, and it creeps back up when you referee "
			+ "cleanly. It does not tell you whether anybody BELIEVED a particular call "
			+ "— nothing will ever tell you that. It tells you what the night has cost "
			+ "you so far.\n\n"
			+ "A quiet match repairs a little of it. A match with three invented cards in it does not.\n\n"
			+ "Run it down to nothing and nobody will appoint you again.",
	},
]


## Beach volleyball's own lesson.
##
## It needs one for the same reason badminton did, and more urgently: this sport's
## signature call is a thing nobody can see, made with a key nobody would guess. A
## player who picks beach volleyball and is never told what TOUCH means is being asked
## to judge the one call the whole design rests on with no idea it exists — which is
## exactly the shape of the bug that made fair play feel unfair before.
const BEACH_LESSONS := [
	{
		"title": "THE JOB",
		"body": "You are the first referee, up on the stand beside the net.\n\n"
			+ "Two a side, on sand, in the open air. The game plays a real rally and "
			+ "records exactly where the ball came down, to the millimetre. Nobody else "
			+ "here will say what happened. You will.\n\n"
			+ "You can tell the truth. Nothing here requires you to.",
		"keys": [
			["SPACE", "whistle the serve"],
			["LEFT CLICK", "in"],
			["RIGHT CLICK", "out"],
			["T", "touched — see page three"],
			["F", "a fault"],
			["ESC", "pause"],
		],
	},
	{
		"title": "IN AND OUT",
		"body": "The court is sixteen metres by eight, and the tape lying on the sand "
			+ "is part of it. A ball touching any part of a line is IN.\n\n"
			+ "There are no service courts. A serve may land anywhere in the other "
			+ "half, so there is nothing to remember about who serves from where.\n\n"
			+ "The sand outside the lines is still in play. A player may chase a ball "
			+ "five metres past the tape and put it back, and the rally goes on — being "
			+ "outside the court is only the ball's problem, never the player's.",
	},
	{
		"title": "THE TOUCH",
		"body": "This is the call this sport is about, and it is worth reading twice.\n\n"
			+ "The ball is attacked, it flies out past the block, and it lands well "
			+ "outside the court. Everybody saw that. What nobody saw is whether it "
			+ "grazed a blocker's fingers on the way.\n\n"
			+ "If it did, the blockers touched it last, so going out is their mistake: "
			+ "press T for TOUCH and the point goes to the attackers. If it did not, "
			+ "the attackers hit it out: call OUT and the point goes to the blockers.\n\n"
			+ "The same ball, the same landing, and two opposite points — decided by "
			+ "you. Nobody in this venue is in any position to argue, which cuts both "
			+ "ways: it is the easiest call in the game to get away with, and the one "
			+ "that costs the most when a slow-motion camera disagrees with you.",
	},
	{
		"title": "FAULTS, AND WHO IS WATCHING",
		"body": "Press F, then point at whoever did it.\n\n"
			+ "OUTSIDE THE ANTENNA   the ball crossed the net outside one of the two "
			+ "rods standing on the tape. It is out however cleanly it then lands, and "
			+ "it is the only boundary in this sport that is vertical — so it is the "
			+ "only one that leaves nothing in the sand to walk over and argue about "
			+ "afterwards. You are level with the rod. Nobody else is.\n"
			+ "NET TOUCH   somebody touched the net while the ball was live.\n"
			+ "CENTRE LINE   a foot went fully under the net into the other court.\n"
			+ "FOUR HITS   one side touched it four times. Three is the limit.\n"
			+ "DOUBLE and LIFT   the set came off two hands unevenly, or rested in them "
			+ "a moment too long. Judged far more tightly here than indoors, and two "
			+ "honest referees genuinely disagree about it.\n"
			+ "FOOT FAULT   the server stood on or over the end line.\n\n"
			+ "When the ball comes down you get an overhead view of it against the tape, "
			+ "in the corner of the screen. Use it. It is the only thing in this sport "
			+ "that will ever tell you something you could not see from the stand.\n\n"
			+ "From the world tour up, both sides carry two challenges a set. They can "
			+ "put your line calls and your touches on a screen, and a successful one is "
			+ "handed back — so a pair with one left is still dangerous.",
	},
	{
		"title": "YOUR NAME",
		"body": "Nothing in this game counts your mistakes for you. What you get while "
			+ "you referee is the room — how it sounds, and whether it comes out of its "
			+ "seat — and one number, which is this one.\n\n"
			+ "REPUTATION is your name, out of a hundred, and it follows you from match "
			+ "to match and from sport to sport. It is the only thing here that outlives "
			+ "the match it happened in.\n\n"
			+ "The bar appears at the bottom of the screen ONLY WHEN IT MOVES, for about "
			+ "three seconds, and then it is gone. So it is never something to stare at. "
			+ "It catches your eye at the moment a call has just cost you something, "
			+ "which is the only moment worth knowing about.\n\n"
			+ "It falls when you are wrong, and it creeps back up when you referee "
			+ "cleanly. It does not tell you whether anybody BELIEVED a particular call "
			+ "— nothing will ever tell you that. It tells you what the night has cost "
			+ "you so far.\n\n"
			+ "Denying a touch nobody could see is the cheapest thing you can do here. It is still not free, and it adds up.\n\n"
			+ "Run it down to nothing and nobody will appoint you again.",
	},
]

## Indoor volleyball's lesson, and the longest of the three, because this is the only
## sport in the game that asks the referee to know something before the ball is served.
const INDOOR_LESSONS := [
	{
		"title": "THE JOB",
		"body": "You are the first referee, on the stand beside the net.\n\n"
			+ "Six a side, indoors. Everything beach volleyball asks of you it asks of "
			+ "you here too — where the ball landed, whether a block touched it, whether "
			+ "a set was clean.\n\n"
			+ "And one thing more, which is the reason this is the hardest chair in the "
			+ "game to sit in.",
		"keys": [
			["SPACE", "whistle the serve"],
			["LEFT CLICK", "in"],
			["RIGHT CLICK", "out"],
			["T", "touched"],
			["F", "a fault, including the rotation"],
			["ESC", "pause"],
		],
	},
	{
		"title": "THE ROTATION",
		"body": "Six players stand in six positions, numbered the way the sport numbers "
			+ "them — anticlockwise from the server's corner:\n\n"
			+ "        4    3    2      the front row, nearest the net\n"
			+ "        5    6    1      the back row; 1 serves\n\n"
			+ "Whoever is in position 1 serves. When a side wins the serve back, all six "
			+ "move one place clockwise, so 2 goes to 1 and everybody follows. A side "
			+ "that keeps serving does NOT rotate — that is the part most people get "
			+ "wrong.\n\n"
			+ "At the moment the serve is struck, each front-row player must be nearer "
			+ "the net than the back-row player behind them, and within each row they "
			+ "must be in left, centre, right order across the court. After the ball is "
			+ "struck they may go anywhere.\n\n"
			+ "Get this wrong and it is OUT OF ROTATION, or WRONG SERVER if the ball was "
			+ "hit by somebody who was not in position 1.",
	},
	{
		"title": "WHAT THAT MEANS FOR YOU",
		"body": "Every other call in this game is about something you can see happening. "
			+ "This one is about something you had to be watching for twenty seconds "
			+ "before it mattered.\n\n"
			+ "So it cuts both ways. If you were paying attention, a rotation fault is "
			+ "the most certain call in the sport — six people were in their order or "
			+ "they were not, and both benches know which.\n\n"
			+ "Which is exactly why inventing one is the least deniable thing you can "
			+ "do. There is no close call to hide behind. A lineup is written down.\n\n"
			+ "BACK ROW ATTACK is the same rule in the air: a back-row player may hit "
			+ "the ball down from above the net, but only if they took off from behind "
			+ "the attack line, three metres back. In front of it, it is a fault — and "
			+ "unlike the rest of this, everybody in the hall is looking at it.",
	},
	{
		"title": "THE LIBERO",
		"body": "One player on each side wears a different shirt. That is not decoration "
			+ "— it is so that you can pick them out without thinking, because there are "
			+ "three things they alone may not do.\n\n"
			+ "They may not attack the ball above the net.\n"
			+ "They may not serve.\n"
			+ "They may not set the ball overhand from in front of the attack line for "
			+ "somebody else to attack.\n\n"
			+ "They also never leave the back court. If the rotation would carry them to "
			+ "the front row they come off, and somebody else comes on.\n\n"
			+ "Press F and point at them for LIBERO.",
	},
	{
		"title": "FAULTS, AND WHO IS WATCHING",
		"body": "Press F, then point at whoever did it.\n\n"
			+ "NET TOUCH, CENTRE LINE, FOUR HITS, DOUBLE, LIFT and FOOT FAULT are the "
			+ "same as they are on the sand, and so is OUTSIDE THE ANTENNA — the ball "
			+ "crossing the net outside one of the rods, which is out however cleanly it "
			+ "lands and leaves no mark on the floor for anybody to check.\n\n"
			+ "When the ball lands you get an overhead view of it against the line. That "
			+ "settles where it came down; nothing settles where six people were "
			+ "standing except you.\n\n"
			+ "From the champions cup up, both sides carry challenges. They can put your "
			+ "line calls and your touches on a screen — but NOT your rotation calls. A "
			+ "camera looks at the ball. Where six people were standing is settled by "
			+ "the scoresheet, which means a rotation call is your word and stays your "
			+ "word.",
	},
	{
		"title": "YOUR NAME",
		"body": "Nothing in this game counts your mistakes for you. What you get while "
			+ "you referee is the room — how it sounds, and whether it comes out of its "
			+ "seat — and one number, which is this one.\n\n"
			+ "REPUTATION is your name, out of a hundred, and it follows you from match "
			+ "to match and from sport to sport. It is the only thing here that outlives "
			+ "the match it happened in.\n\n"
			+ "The bar appears at the bottom of the screen ONLY WHEN IT MOVES, for about "
			+ "three seconds, and then it is gone. So it is never something to stare at. "
			+ "It catches your eye at the moment a call has just cost you something, "
			+ "which is the only moment worth knowing about.\n\n"
			+ "It falls when you are wrong, and it creeps back up when you referee "
			+ "cleanly. It does not tell you whether anybody BELIEVED a particular call "
			+ "— nothing will ever tell you that. It tells you what the night has cost "
			+ "you so far.\n\n"
			+ "A rotation you invented costs more of it than any line call ever will, because a lineup is written down.\n\n"
			+ "Run it down to nothing and nobody will appoint you again.",
	},
]


## Tennis's lesson, and the only one in the game that has to teach a *scoring system*
## before it can teach a call — because in this sport what a call costs depends entirely
## on what the score was when you made it.
const TENNIS_LESSONS := [
	{
		"title": "THE JOB",
		"body": "You are the chair umpire, at the net, on the high seat.\n\n"
			+ "Singles. The game plays a real point and records exactly where the ball "
			+ "came down, to the millimetre. There are line judges below you and they "
			+ "are often right.\n\n"
			+ "You are not asked about every ball. A serve down the middle of the box is "
			+ "played and nobody says a word. You are asked when there is a question — "
			+ "and when there is one, everybody in the place turns and looks at you.",
		"keys": [
			["SPACE", "call the players to play"],
			["LEFT CLICK", "in"],
			["RIGHT CLICK", "out, or a fault on a serve"],
			["L", "let — see page three"],
			["F", "a fault"],
			["ESC", "pause"],
		],
	},
	{
		"title": "THE SCORE, AND WHY IT MATTERS TO YOU",
		"body": "Points are called 15, 30, 40, and then the game. Three each is DEUCE, "
			+ "and from there somebody has to win two in a row. Six games win a set, by "
			+ "two; at six-all they play a tiebreak to seven.\n\n"
			+ "Read that again, because it is the whole reason this sport is in this "
			+ "game.\n\n"
			+ "**A point is not a point.** A wrong call at 40-0 costs somebody a point "
			+ "they were never going to miss. The same call at deuce in a tiebreak is "
			+ "the match, and the player, the crowd and you all know it while it is "
			+ "happening.\n\n"
			+ "Nothing in the game charges you extra for the second one. Everybody in "
			+ "the stadium does.",
	},
	{
		"title": "THE SERVE — AND THE FIRST AND SECOND",
		"body": "A point starts with a first serve. If it misses, the server gets a "
			+ "second. If that misses too it is a double fault and the point is gone.\n\n"
			+ "So the same call costs two completely different things:\n\n"
			+ "On a FIRST serve, calling a fault takes a serve away. No point changes "
			+ "hands. Nobody argues much.\n"
			+ "On a SECOND serve, calling a fault is the point.\n\n"
			+ "That gap is the most useful thing in this sport to a bent umpire, and the "
			+ "easiest thing to spot on a scoresheet afterwards. A careful one shades "
			+ "first serves all afternoon. A greedy one takes a second, once, and it is "
			+ "the only call anybody remembers.\n\n"
			+ "A serve must land in the box diagonally opposite the server, short of the "
			+ "service line and inside the SINGLES sideline — even in doubles. The "
			+ "tramlines are never part of a service box.",
	},
	{
		"title": "THE NET CORD",
		"body": "This is the call this sport is about, and it is decided by a sound.\n\n"
			+ "If a serve touches the top of the net on its way over and still lands in "
			+ "the box, it is a LET: nothing happened, and the serve is played again at "
			+ "the same number. If it touches and misses the box, it is simply a fault.\n\n"
			+ "Press L to call it.\n\n"
			+ "You are a metre from the tape. Nobody else in the building is. A ball that "
			+ "grazes the cord and carries on unchanged made a noise that you heard and "
			+ "they did not — which cuts both ways: it is the easiest call in tennis to "
			+ "invent, and denying a real one quietly takes a first serve off a man who "
			+ "was entitled to it again.\n\n"
			+ "Watch the net as well as listen. A cord that was really clipped shivers.",
	},
	{
		"title": "FAULTS, AND WHO IS WATCHING",
		"body": "Press F, then point at whoever did it.\n\n"
			+ "FOOT FAULT   the server's foot on or over the baseline at contact. You "
			+ "are looking down the length of that line from the chair, which is the "
			+ "worst angle in the sport for it.\n"
			+ "NOT UP   the ball bounced twice before they reached it.\n"
			+ "TOUCHED THE NET   a player or a racket touched the net while the ball was "
			+ "live. They lose the point whatever the ball then did.\n"
			+ "THROUGH THE NET   they played the ball before it had crossed to their "
			+ "side.\n\n"
			+ "The line judges below you call the lines they are responsible for. Agree "
			+ "with one who has just got it wrong and the mistake is shared with an "
			+ "official standing in plain sight. Contradict one and the court has "
			+ "watched two officials disagree in public, with only your call counting.\n\n"
			+ "From the tour main draw up, both players carry challenges, and a screen "
			+ "will draw your line calls to the millimetre in front of everybody.",
	},
	{
		"title": "YOUR NAME",
		"body": "Nothing in this game counts your mistakes for you. What you get while "
			+ "you referee is the room — how it sounds, and whether it comes out of its "
			+ "seat — and one number, which is this one.\n\n"
			+ "REPUTATION is your name, out of a hundred, and it follows you from match "
			+ "to match and from sport to sport. It is the only thing here that outlives "
			+ "the match it happened in.\n\n"
			+ "The bar appears at the bottom of the screen ONLY WHEN IT MOVES, for about "
			+ "three seconds, and then it is gone. So it is never something to stare at. "
			+ "It catches your eye at the moment a call has just cost you something, "
			+ "which is the only moment worth knowing about.\n\n"
			+ "It falls when you are wrong, and it creeps back up when you referee "
			+ "cleanly. It does not tell you whether anybody BELIEVED a particular call "
			+ "— nothing will ever tell you that. It tells you what the night has cost "
			+ "you so far.\n\n"
			+ "Shading a first serve is cheap, because it only costs a serve. Taking a second is not.\n\n"
			+ "Run it down to nothing and nobody will appoint you again.",
	},
]

var _lesson := 0
var _lessons: Array = BADMINTON_LESSONS

const TABLE_TENNIS_LESSONS := [
	{
		"title": "THE JOB",
		"body": "You are the umpire, in a chair beside the net, level with the top of "
			+ "the table.\n\n"
			+ "Singles, to eleven. The game plays a real point and records exactly where "
			+ "the ball came down, to the millimetre.\n\n"
			+ "There are no line judges. Not at this level, not at the World "
			+ "Championships, not anywhere — the table is 2.74 metres long and there is "
			+ "nowhere to put a second official that you cannot already see. Every truth "
			+ "in this match goes through you and nobody else. There is nobody to agree "
			+ "with, and nobody to blame.",
		"keys": [
			["SPACE", "call the score and start the point"],
			["LEFT CLICK", "in"],
			["RIGHT CLICK", "out, or a fault on a serve"],
			["L", "let — see page four"],
			["F", "a fault"],
			["ESC", "pause"],
		],
	},
	{
		"title": "THE SCORE, AND WHOSE SERVE IT IS",
		"body": "Games are to eleven, and you must win by two. From ten-all it goes on "
			+ "until somebody is two clear.\n\n"
			+ "The serve changes hands EVERY TWO POINTS. From ten-all it changes every "
			+ "single point.\n\n"
			+ "That second sentence is your job. Nobody else in the hall is keeping "
			+ "track of it — the players are playing, and the crowd is watching the ball "
			+ "— and everybody will notice the instant you get it wrong. You call the "
			+ "score out before every point, server's number first, and that call is the "
			+ "official record of it.\n\n"
			+ "Nothing in this game charges you for losing count. The hall does.",
	},
	{
		"title": "THE SERVE, AND THE STRICTEST LAW IN THIS GAME",
		"body": "There is no second serve. A serve that misses is the point, gone.\n\n"
			+ "The ball must sit on an open FLAT PALM, be thrown up at least 16 "
			+ "centimetres, and stay VISIBLE TO THE RECEIVER from the moment it leaves "
			+ "the hand until it is struck. Then it must bounce once on the server's own "
			+ "half and once on the receiver's.\n\n"
			+ "Press F and call ILLEGAL SERVICE.\n\n"
			+ "Look at who that law protects. The receiver cannot possibly see a serve "
			+ "hidden behind the server's own shoulder — that is what hiding it means. "
			+ "You are the only person in the building placed to check any of it, on "
			+ "every single point, for the whole match.\n\n"
			+ "Which is also to say: you are the only person who can quietly stop "
			+ "checking.",
	},
	{
		"title": "THE NET, AND THE EDGE",
		"body": "TWO calls, and they are what this sport is.\n\n"
			+ "THE NET. A serve that touches the net and still lands good is a LET and "
			+ "is played again. Press L. It costs nobody anything, which makes it the "
			+ "cheapest thing here to invent — and watch the net as well as listen, "
			+ "because a net that was really clipped shivers.\n\n"
			+ "THE EDGE. A ball that clips the TOP EDGE of the table is IN. A ball that "
			+ "clips the vertical SIDE, a centimetre lower, is OUT. Two centimetres "
			+ "apart. They sound almost the same. They happen at twenty metres a "
			+ "second.\n\n"
			+ "You are sitting level with the surface, which is the only place in the "
			+ "hall the difference between them can be seen from at all. Both players "
			+ "will be certain, and one of them will be wrong.",
	},
	{
		"title": "THE OTHER FAULTS",
		"body": "Press F, then point at whoever did it.\n\n"
			+ "TWO BOUNCES   the ball bounced twice on their half before they got to "
			+ "it.\n"
			+ "FREE HAND ON THE TABLE   the hand not holding the bat touched the "
			+ "playing surface while the ball was live. They lose the point whatever "
			+ "happened next.\n"
			+ "STRUCK IN THE AIR   they hit the ball before it had bounced on their "
			+ "side.\n\n"
			+ "All three happen at the table, a metre and a half from your chair, and "
			+ "all three are gone in a fifth of a second. Nobody is going to hand you a "
			+ "replay at the community centre.\n\n"
			+ "From the world tour up there is a match referee sitting two metres away "
			+ "who can come to the table, and at the Worlds there are eight cameras on a "
			+ "ball 40 millimetres across.",
	},
	{
		"title": "YOUR NAME",
		"body": "Nothing in this game counts your mistakes for you. What you get while "
			+ "you referee is the room — how it sounds, and whether it comes out of its "
			+ "seat — and one number, which is this one.\n\n"
			+ "REPUTATION is your name, out of a hundred, and it follows you from match "
			+ "to match and from sport to sport. It is the only thing here that outlives "
			+ "the match it happened in.\n\n"
			+ "The bar appears at the bottom of the screen ONLY WHEN IT MOVES, for about "
			+ "three seconds, and then it is gone. So it is never something to stare "
			+ "at.\n\n"
			+ "It falls when you are wrong, and it creeps back up when you referee "
			+ "cleanly. It does not tell you whether anybody BELIEVED a particular call "
			+ "— nothing will ever tell you that.\n\n"
			+ "In every other sport in this game you can hide a bad call behind a line "
			+ "judge who said the same thing. Here you cannot. Everything the hall "
			+ "believes about this match is something you told them.\n\n"
			+ "Run it down to nothing and nobody will appoint you again.",
	},
]

var _teaching: Control
var _lesson_buttons: HBoxContainer


## `sport` picks which lesson. The two sports share the screen and share nothing else
## about what they need explaining.
func show_teaching(sport := Career.BADMINTON) -> void:
	match sport:
		Career.BEACH: _lessons = BEACH_LESSONS
		Career.INDOOR: _lessons = INDOOR_LESSONS
		Career.TENNIS: _lessons = TENNIS_LESSONS
		Career.TABLE_TENNIS: _lessons = TABLE_TENNIS_LESSONS
		_: _lessons = BADMINTON_LESSONS
	if _hud != null:
		_hud.visible = false
	_lesson = 0
	_draw_lesson()
	_teaching.visible = true


func hide_teaching() -> void:
	if _teaching != null:
		_teaching.visible = false


func _draw_lesson() -> void:
	if _teaching != null:
		_teaching.queue_free()
	var built := _build_sheet("Teaching", Color(0.03, 0.04, 0.06, 0.66))
	_teaching = built[0]
	var column: VBoxContainer = built[1]

	# The page goes inside a scroll view rather than being trimmed to fit. Tuning the
	# picture and the type until it happened to fit a 900-pixel window worked twice and
	# broke twice, and it would break again on somebody else's screen — a page whose only
	# job is to be read must not be able to put its own title above the top edge.
	var card := column.get_parent()
	card.remove_child(column)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	card.add_child(stack)

	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.custom_minimum_size = Vector2(
		720, minf(660.0, get_viewport().get_visible_rect().size.y * 0.66))
	stack.add_child(scroller)
	scroller.add_child(column)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# The buttons live outside the scroll view. Inside it, NEXT sat below the fold on the
	# longer pages and the reader had to scroll to find out there was a next page.
	_lesson_buttons = HBoxContainer.new()
	_lesson_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_lesson_buttons.add_theme_constant_override("separation", 14)
	stack.add_child(_lesson_buttons)
	# Sized to fit a 900-pixel-tall window with the buttons still on screen. The first
	# attempt ran off both ends of the display: the title was above the top edge and GOT
	# IT was below the bottom one, which on a page whose whole job is to be read is not a
	# small mistake.
	column.custom_minimum_size = Vector2(700, 0)

	var lesson: Dictionary = _lessons[_lesson]
	column.add_child(_make_label(lesson["title"], TITLE_SIZE, UiTheme.CHALK))
	column.add_child(_gap(4))
	column.add_child(_make_label(
		"%d of %d" % [_lesson + 1, _lessons.size()], UiTheme.SMALL, UiTheme.MUTED))
	column.add_child(_gap(14))

	if lesson.has("art") and ResourceLoader.exists(lesson["art"]):
		var picture := TextureRect.new()
		picture.texture = load(lesson["art"])
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(520, 288)
		column.add_child(picture)
		column.add_child(_gap(14))

	var body := _make_label(lesson["body"], UiTheme.SMALL, UiTheme.CHALK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(660, 0)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(body)

	if lesson.has("keys"):
		column.add_child(_gap(14))
		for pair in lesson["keys"]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 20)
			var key := _make_label(pair[0], UiTheme.SMALL, UiTheme.ACCENT)
			key.custom_minimum_size = Vector2(200, 0)
			key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(key)
			var meaning := _make_label(pair[1], UiTheme.SMALL, UiTheme.MUTED)
			meaning.custom_minimum_size = Vector2(420, 0)
			meaning.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.add_child(meaning)
			column.add_child(row)

	var buttons := _lesson_buttons
	if _lesson > 0:
		var back := Button.new()
		back.text = "BACK"
		back.custom_minimum_size = Vector2(200, UiTheme.BUTTON_HEIGHT)
		back.pressed.connect(func() -> void:
			_lesson -= 1
			_draw_lesson()
			_teaching.visible = true)
		buttons.add_child(back)

	var onward := Button.new()
	onward.text = "NEXT" if _lesson < _lessons.size() - 1 else "GOT IT"
	onward.custom_minimum_size = Vector2(280, UiTheme.BUTTON_HEIGHT)
	onward.pressed.connect(func() -> void:
		if _lesson < _lessons.size() - 1:
			_lesson += 1
			_draw_lesson()
			_teaching.visible = true
		else:
			teaching_finished.emit())
	buttons.add_child(onward)


# --- settings -------------------------------------------------------------------

## Volume, mouse speed and the window. Everything takes effect as it is dragged and is
## written to disk straight away — a setting you have to confirm, or restart for, is one
## people assume is broken.
func _build_settings_menu(settings: Settings) -> void:
	if _settings_menu != null:
		_settings_menu.queue_free()
	var built := _build_sheet("Settings", Color(0.03, 0.04, 0.06, 0.60))
	_settings_menu = built[0]
	var column: VBoxContainer = built[1]

	column.add_child(_make_label("SETTINGS", TITLE_SIZE, UiTheme.CHALK))
	column.add_child(_gap(18))

	column.add_child(_slider_row("Overall volume", settings.master, 0.0, 1.0,
		func(value: float) -> void:
			settings.master = value
			settings.apply()
			settings.save()))
	column.add_child(_slider_row("Crowd", settings.crowd, 0.0, 1.0,
		func(value: float) -> void:
			settings.crowd = value
			settings.apply()
			settings.save()))
	column.add_child(_slider_row("Whistle and play", settings.effects, 0.0, 1.0,
		func(value: float) -> void:
			settings.effects = value
			settings.apply()
			settings.save()))

	column.add_child(_gap(14))
	column.add_child(_slider_row("Mouse look speed", settings.sensitivity,
		Settings.SENSITIVITY_MIN, Settings.SENSITIVITY_MAX,
		func(value: float) -> void:
			settings.sensitivity = value
			settings.save()
			look_speed_changed.emit(value)))

	column.add_child(_gap(14))
	var window := CheckButton.new()
	window.text = "Fullscreen"
	window.button_pressed = settings.fullscreen
	window.toggled.connect(func(pressed: bool) -> void:
		settings.fullscreen = pressed
		settings.apply()
		settings.save())
	column.add_child(_centred(window))

	column.add_child(_gap(22))
	if _settings_over_a_match:
		column.add_child(_centred(_make_wide_button("BACK TO THE MATCH", func() -> void:
			settings_closed.emit())))
	else:
		column.add_child(_centred(_make_wide_button("BACK", func() -> void:
			main_menu_requested.emit())))


## One labelled slider, with the value written out beside it. The number matters: a bare
## slider tells you where the handle is and nothing about what it means.
func _slider_row(label: String, value: float, lowest: float, highest: float,
		on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var name_label := _make_label(label, UiTheme.BODY, UiTheme.MUTED)
	name_label.custom_minimum_size = Vector2(300, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = lowest
	slider.max_value = highest
	slider.step = (highest - lowest) / 40.0
	slider.value = value
	slider.custom_minimum_size = Vector2(330, 40)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var readout := _make_label("", UiTheme.BODY, UiTheme.CHALK)
	readout.custom_minimum_size = Vector2(90, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(readout)

	var show_value := func(current: float) -> void:
		readout.text = "%d%%" % roundi((current - lowest) / maxf(0.0001, highest - lowest) * 100.0)
	show_value.call(value)
	slider.value_changed.connect(func(current: float) -> void:
		show_value.call(current)
		on_change.call(current))
	return row


## Where BACK goes: the title screen, or the pause menu it was opened over.
var _settings_over_a_match := false


## `over_a_match` is whether this was opened from the pause menu.
##
## Settings used to be reachable only from the title screen, which meant the one moment
## a player actually discovers the crowd is too loud — halfway through a match, with a
## hall roaring at them — was the one moment they could not do anything about it. The
## only way out was to walk out, and walking out counts the same as being thrown off.
func show_settings(settings: Settings, over_a_match := false) -> void:
	_settings_over_a_match = over_a_match
	if _hud != null:
		_hud.visible = false
	_build_settings_menu(settings)
	_settings_menu.visible = true


func hide_settings() -> void:
	if _settings_menu != null:
		_settings_menu.visible = false


func is_settings_open() -> bool:
	return _settings_menu != null and _settings_menu.visible


func _build_pause_menu() -> void:
	var built := _build_sheet("PauseMenu", Color(0.04, 0.05, 0.07, 0.86))
	_pause_menu = built[0]
	var column: VBoxContainer = built[1]

	column.add_child(_make_label("PAUSED", TITLE_SIZE, Color(0.96, 0.96, 0.94)))
	column.add_child(_gap(22))
	column.add_child(_centred(_make_wide_button("RESUME", func() -> void: resume_requested.emit())))

	# The volume, from inside the match rather than only from the title screen.
	column.add_child(_gap(6))
	column.add_child(_centred(_make_wide_button("SETTINGS", func() -> void:
		settings_requested.emit())))

	# A way out that costs nothing, offered only before the match has begun to matter.
	#
	# Until now the only exits were WALK OUT, which counts the same as being thrown off,
	# and QUIT, which closes the game — so somebody who opened the wrong sport had to
	# damage a career to get out of it. This appears only while no call has been made
	# yet, because a free exit from a match already going badly would be a way to dodge
	# every consequence in the game.
	column.add_child(_gap(6))
	_leave_button = _make_wide_button("BACK TO THE MENU", func() -> void:
		main_menu_requested.emit())
	column.add_child(_centred(_leave_button))
	_leave_note = _make_label(
		"Nothing has happened yet. Leaving now costs nothing.",
		PROMPT_SIZE - 1, Color(0.55, 0.62, 0.55)
	)
	column.add_child(_leave_note)

	column.add_child(_gap(6))
	column.add_child(_centred(_make_wide_button("WALK OUT", func() -> void: walk_out_requested.emit())))
	column.add_child(_make_label(
		"Walking out counts the same as being removed.",
		PROMPT_SIZE - 1, Color(0.60, 0.55, 0.55)
	))
	column.add_child(_gap(6))
	column.add_child(_centred(_make_wide_button("QUIT", func() -> void: quit_requested.emit())))


## `can_leave_freely` is whether the match has yet cost anybody anything — in practice,
## whether a single call has been made.
func show_pause_menu(can_leave_freely := false) -> void:
	# Whatever was still fading in the middle of the screen would otherwise sit
	# straight across the RESUME button.
	clear_messages()
	hide_reputation()
	if _reason != null and _reason.visible and _reason_holding:
		_reason_paused = _reason_label.text
	hide_reason()
	hide_bubble()
	if _leave_button != null:
		_leave_button.visible = can_leave_freely
		_leave_note.visible = can_leave_freely
	_pause_menu.visible = true



# --- the reputation meter -------------------------------------------------------
#
# It shows only when it moves, for three seconds, and then it is gone.
#
# This is a change of mind about something the game used to say in every lesson: that
# there is no meter anywhere and the crowd is the only thing telling you how much
# trouble you are in. The crowd is still there and still does that job — it is the
# only thing that answers you *back*. What the meter adds is the other half: what a
# night of small lies has actually cost your name, at the moment it costs it, rather
# than as a number on a screen after there is nothing left to decide.
#
# It shows a projection rather than a stored value. Reputation still settles once, when
# the match ends; this is where it would land if you walked off now.

func _build_reputation_meter() -> PanelContainer:
	_meter = PanelContainer.new()
	_meter.name = "ReputationMeter"
	_meter.add_theme_stylebox_override("panel", UiTheme.plate(UiTheme.ACCENT, 0.86))
	# Above the prompt line and above the crowd's line, which is the order they belong
	# in: what you must do, what the room thinks, and what it has cost you.
	#
	# It grows upwards from its anchor rather than both ways. Growing both ways put
	# half the panel below the bottom of the screen, so the bar was cut in two and the
	# whole thing sat on top of the reaction line.
	_meter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_meter.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_meter.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_meter.position = Vector2(0, -158)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.modulate = Color(1, 1, 1, 0)
	_meter.visible = false

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_meter.add_child(column)

	var heading := _make_label("REPUTATION", UiTheme.SMALL, UiTheme.MUTED)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(heading)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)

	_meter_bar = ProgressBar.new()
	_meter_bar.custom_minimum_size = Vector2(METER_WIDTH, METER_HEIGHT)
	_meter_bar.min_value = 0.0
	_meter_bar.max_value = 100.0
	_meter_bar.show_percentage = false

	var track := StyleBoxFlat.new()
	track.bg_color = UiTheme.INK
	track.border_width_left = 2
	track.border_width_right = 2
	track.border_width_top = 2
	track.border_width_bottom = 2
	track.border_color = UiTheme.EDGE
	_meter_bar.add_theme_stylebox_override("background", track)

	_meter_fill = StyleBoxFlat.new()
	_meter_fill.bg_color = UiTheme.CHALK
	_meter_bar.add_theme_stylebox_override("fill", _meter_fill)
	row.add_child(_meter_bar)

	# The number and which way it just went, which is the part that is actually news.
	_meter_value = _make_label("", UiTheme.HEADING, UiTheme.CHALK)
	_meter_value.custom_minimum_size = Vector2(150, 0)
	_meter_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_meter_value)

	return _meter


## Puts the meter up, or refills its clock if it is already up.
##
## `value` is where reputation stands from nought to one; `moved` is how far it just
## went, in the same units, signed. A move of zero is not shown at all — the meter is
## only ever news.
## `regardless` shows it even though nothing has moved, which is how the start of a
## match and the end of a set put it up. Everywhere else a move of nothing is not news
## and the meter stays down.
func show_reputation(value: float, moved: float, regardless := false) -> void:
	if _meter == null or _hud == null or not _hud.visible:
		return
	if is_zero_approx(moved) and not regardless:
		return

	var out_of_100 := roundi(clampf(value, 0.0, 1.0) * 100.0)
	var band := _meter_colour(value)
	_meter_fill.bg_color = band
	_meter_bar.value = float(out_of_100)
	_meter.add_theme_stylebox_override("panel", UiTheme.plate(band, 0.86))

	# Down is the news, so down is the colour the eye goes to.
	# No arrow when nothing moved: this is where you stand, not news about a change.
	if is_zero_approx(moved):
		_meter_value.text = "%d" % out_of_100
		_meter_value.add_theme_color_override("font_color", band)
	else:
		var arrow := "\u25b2" if moved > 0.0 else "\u25bc"
		_meter_value.text = "%s %d" % [arrow, out_of_100]
		_meter_value.add_theme_color_override("font_color",
			Color(0.55, 0.85, 0.60) if moved > 0.0 else Color(0.96, 0.42, 0.36))

	_meter.visible = true
	# Refilled rather than restarted: if it is already showing, it stays showing and
	# simply gets its full hold back.
	_meter_left = METER_FADE_IN + METER_HOLD + METER_FADE_OUT
	if _meter_shown < 1.0 and _meter.modulate.a > 0.0:
		# Already part way in. Keep the opacity it has rather than snapping back to
		# nothing, which is what a restart would look like.
		_meter_left -= METER_FADE_IN * _meter_shown


## The bar's colour, which is the whole of what it says at a glance.
func _meter_colour(value: float) -> Color:
	if value >= METER_SAFE:
		return Color(0.55, 0.85, 0.60)
	if value >= METER_SHAKY:
		return UiTheme.ACCENT
	return Color(0.96, 0.42, 0.36)


func _tick_the_meter(delta: float) -> void:
	if _meter == null or _meter_left <= 0.0:
		return
	_meter_left -= delta
	if _meter_left <= 0.0:
		_meter.visible = false
		_meter.modulate.a = 0.0
		_meter_shown = 0.0
		return

	# Fade out at the end, fade in at the start, and full opacity in between.
	if _meter_left <= METER_FADE_OUT:
		_meter_shown = _meter_left / METER_FADE_OUT
	else:
		var since := (METER_FADE_IN + METER_HOLD + METER_FADE_OUT) - _meter_left
		_meter_shown = clampf(since / METER_FADE_IN, 0.0, 1.0)
	_meter.modulate.a = _meter_shown


func hide_reputation() -> void:
	if _meter == null:
		return
	_meter.visible = false
	_meter.modulate.a = 0.0
	_meter_left = 0.0
	_meter_shown = 0.0

# --- why it moved ----------------------------------------------------------------

## The note on the left that says what the hall is reacting to.
##
## It exists because the meter on its own is a number that moves for no stated cause,
## and a player who cannot tell what cost them cannot referee any differently next
## time. It never says whether the call was right — see the note over the strings in
## `Suspicion`, which is where the wording is kept and where that rule is enforced.
##
## On the left rather than under the meter for two reasons. The middle of the screen
## is where the game announces things to the hall, and this is not addressed to the
## hall. And the eye that has just gone to the bottom centre for the number should
## find the sentence somewhere else, so the two are read as two facts rather than one
## caption.
func _build_reason_note() -> PanelContainer:
	_reason = PanelContainer.new()
	_reason.name = "ReasonNote"
	_reason.add_theme_stylebox_override("panel", UiTheme.plate(UiTheme.ACCENT, 0.86))
	_reason.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_reason.grow_horizontal = Control.GROW_DIRECTION_END
	_reason.grow_vertical = Control.GROW_DIRECTION_BOTH
	_reason.position = Vector2(REASON_INSET, 0)
	_reason.custom_minimum_size = Vector2(REASON_WIDTH, 0)
	_reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reason.modulate = Color(1, 1, 1, 0)
	_reason.visible = false

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_reason.add_child(column)

	var heading := _make_label("THE HALL", UiTheme.SMALL, UiTheme.MUTED)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(heading)

	_reason_label = _make_label("", UiTheme.BODY, UiTheme.CHALK)
	_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason_label.custom_minimum_size = Vector2(REASON_WIDTH, 0)
	column.add_child(_reason_label)

	return _reason


## Puts the note up and leaves it up.
##
## Unlike the meter it has no clock. The meter is a number and is read in a glance; a
## sentence is not, and three seconds is the wrong amount of time for one — long enough
## to be distracting during the next rally and short enough to be missed by anybody who
## happened to be watching the court. So it waits, and the umpire dismisses it by
## whistling the next rally, which is the one gesture that already means "I have
## finished with the last one".
##
## An empty reason puts nothing on screen rather than an empty box: not every route
## into the meter has something to say, and a blank panel would look like a bug.
func show_reason(text: String) -> void:
	if _reason == null or _hud == null or not _hud.visible:
		return
	if text.strip_edges().is_empty():
		return
	_reason_label.text = text
	_reason.visible = true
	_reason_holding = true


## The whistle has gone, so the note goes with it.
##
## It fades from wherever it had got to rather than from full, so dismissing one that
## is still fading in does not make it brighten first and then leave.
func dismiss_reason() -> void:
	if _reason == null or not _reason.visible or not _reason_holding:
		return
	_reason_holding = false
	_reason_left = METER_FADE_OUT * _reason_shown


func _tick_the_reason(delta: float) -> void:
	if _reason == null or not _reason.visible:
		return

	if _reason_holding:
		_reason_shown = minf(1.0, _reason_shown + delta / METER_FADE_IN)
		_reason.modulate.a = _reason_shown
		return

	_reason_left -= delta
	if _reason_left <= 0.0:
		hide_reason()
		return
	_reason_shown = _reason_left / METER_FADE_OUT
	_reason.modulate.a = _reason_shown


# --- what one person in the stands says ------------------------------------------

## The camera the bubble is measured against, set once when the match builds its hall.
##
## The UI is a CanvasLayer and knows nothing about the 3D world, which is right for
## everything else on it — the score, the prompt, the meter and the note are all in
## screen space and stay where they are put. The bubble is the one thing that has to
## follow a place in the hall, so it gets the one reference it needs and nothing more.
var chair_camera: Camera3D

## Three of them, not one.
##
## A hall that has made its mind up about you is not one person shouting: it is several,
## from different parts of the stand, over each other. One bubble at a time made the
## loudest moment in the game look like the quietest, because a room of three hundred
## people produced exactly as many voices as a school gym with nine.
const VOICES := 3

var _bubbles: Array[PanelContainer] = []
var _bubble_labels: Array[Label] = []
var _bubble_tails: Array[Polygon2D] = []
var _bubble_ats: Array[Vector3] = []
var _bubble_lefts: Array[float] = []
var _bubble_showns: Array[float] = []


## The bubble over a spectator's head, and the tail that points at them.
##
## Screen space rather than a Label3D in the hall, and that is the whole reason this
## reads at all. The stands are dark and a long way off — the far one is twenty metres
## from the chair — so text drawn in the world arrives four pixels high and edge-on. A
## panel that merely *follows* the head keeps a size a person can read from any seat in
## the room while still belonging to somebody.
func _build_bubbles() -> Control:
	var holder := Control.new()
	holder.name = "CrowdBubbles"
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in VOICES:
		holder.add_child(_build_bubble(i))
	return holder


func _build_bubble(index: int) -> PanelContainer:
	var bubble := PanelContainer.new()
	bubble.name = "CrowdBubble%d" % index
	# A white bubble with dark type in it, which is not what anything else on this
	# interface looks like and is deliberate. Every other panel is a dark plate with a
	# coloured edge, because every other panel is the game talking to the umpire. This
	# is a person in the hall talking, it is read against a dark room from twenty metres
	# away, and the first version — a dark plate with ink text on it, from reusing the
	# house style without thinking — was very nearly invisible in the frame.
	var skin := StyleBoxFlat.new()
	skin.bg_color = UiTheme.CHALK
	skin.set_corner_radius_all(14)
	skin.set_border_width_all(2)
	skin.border_color = UiTheme.INK
	skin.content_margin_left = 18
	skin.content_margin_right = 18
	skin.content_margin_top = 10
	skin.content_margin_bottom = 10
	bubble.add_theme_stylebox_override("panel", skin)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.modulate = Color(1, 1, 1, 0)
	bubble.visible = false
	bubble.z_index = 1

	var label := _make_label("", UiTheme.HEADING, UiTheme.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(BUBBLE_MAX_WIDTH, 0)
	bubble.add_child(label)

	# Drawn as a child of the bubble so it moves with it and inherits its fade, and
	# pointing straight down because the bubble is always directly over the head.
	var tail := Polygon2D.new()
	tail.color = UiTheme.CHALK
	tail.polygon = PackedVector2Array([
		Vector2(-BUBBLE_TAIL, 0.0), Vector2(BUBBLE_TAIL, 0.0),
		Vector2(0.0, BUBBLE_TAIL * 1.5),
	])
	bubble.add_child(tail)

	_bubbles.append(bubble)
	_bubble_labels.append(label)
	_bubble_tails.append(tail)
	_bubble_ats.append(Vector3.INF)
	_bubble_lefts.append(0.0)
	_bubble_showns.append(0.0)
	return bubble


## Puts a line in somebody's mouth. `at` is the world point just above their head.
##
## An empty line or a speaker off in the infinite distance both mean "nobody said
## anything", which is a real answer — a quiet lie draws no shout at all, and the hall
## is only allowed to be certain about the things it could actually see.
##
## Takes the quietest slot when all three are busy, so a fourth voice replaces the one
## that has been on screen longest rather than being dropped. In practice three is
## enough: the hall only ever speaks with more than one voice when it is hostile.
func say_from_the_crowd(line: String, at: Vector3) -> void:
	if _bubbles.is_empty() or _hud == null or not _hud.visible:
		return
	if line.is_empty() or at == Vector3.INF:
		return

	var slot := 0
	var quietest := INF
	for i in _bubbles.size():
		if _bubble_lefts[i] <= 0.0:
			slot = i
			break
		if _bubble_lefts[i] < quietest:
			quietest = _bubble_lefts[i]
			slot = i

	_bubble_labels[slot].text = line
	_bubble_ats[slot] = at
	_bubbles[slot].visible = true
	_bubble_lefts[slot] = BUBBLE_FADE + BUBBLE_HOLD + BUBBLE_FADE
	_follow_the_bubble(slot)


func hide_bubble() -> void:
	for i in _bubbles.size():
		_bubbles[i].visible = false
		_bubbles[i].modulate.a = 0.0
		_bubble_lefts[i] = 0.0
		_bubble_showns[i] = 0.0
		_bubble_ats[i] = Vector3.INF


## Keeps a bubble over its speaker while the umpire looks around.
##
## Hidden rather than clamped when the speaker goes off screen or behind the chair. A
## bubble pinned to the edge of the screen claims somebody is shouting from a place
## nobody is sitting, and the player turning their head is exactly the moment they
## would notice.
func _follow_the_bubble(i: int) -> void:
	var bubble := _bubbles[i]
	if not bubble.visible:
		return
	if chair_camera == null or not is_instance_valid(chair_camera):
		return
	if chair_camera.is_position_behind(_bubble_ats[i]):
		bubble.modulate.a = 0.0
		return

	var point := chair_camera.unproject_position(_bubble_ats[i])
	var size := bubble.get_combined_minimum_size()
	var screen := get_viewport().get_visible_rect().size
	var place := Vector2(point.x - size.x * 0.5, point.y - size.y - BUBBLE_LIFT)

	if (point.x < 0.0 or point.x > screen.x or place.y < 0.0
			or point.y > screen.y):
		bubble.modulate.a = 0.0
		return

	bubble.position = place
	bubble.size = size
	_bubble_tails[i].position = Vector2(size.x * 0.5, size.y)
	bubble.modulate.a = _bubble_showns[i]


func _tick_the_bubble(delta: float) -> void:
	for i in _bubbles.size():
		if _bubble_lefts[i] <= 0.0:
			continue
		_bubble_lefts[i] -= delta
		if _bubble_lefts[i] <= 0.0:
			_bubbles[i].visible = false
			_bubbles[i].modulate.a = 0.0
			_bubble_showns[i] = 0.0
			_bubble_ats[i] = Vector3.INF
			continue

		if _bubble_lefts[i] <= BUBBLE_FADE:
			_bubble_showns[i] = _bubble_lefts[i] / BUBBLE_FADE
		else:
			var since := (BUBBLE_FADE + BUBBLE_HOLD + BUBBLE_FADE) - _bubble_lefts[i]
			_bubble_showns[i] = clampf(since / BUBBLE_FADE, 0.0, 1.0)
		_follow_the_bubble(i)


func hide_reason() -> void:
	if _reason == null:
		return
	_reason.visible = false
	_reason.modulate.a = 0.0
	_reason_left = 0.0
	_reason_shown = 0.0
	_reason_holding = false



## Wipes the announcement, the crowd's line and the banner immediately.
func clear_messages() -> void:
	_message_label.text = ""
	_reaction_label.text = ""
	_banner_label.text = ""
	_message_timer = 0.0
	_reaction_timer = 0.0
	_banner_timer = 0.0
	hide_line_judge()
	hide_reputation()
	hide_reason()
	hide_bubble()


func hide_pause_menu() -> void:
	_pause_menu.visible = false
	# Back to whatever the umpire was still reading when they paused. The shout is not
	# put back with it: a bubble is somebody speaking at a moment, and that moment has
	# gone, whereas the note is a standing fact about what the last call cost.
	if _reason_paused != "":
		show_reason(_reason_paused)
		_reason_paused = ""


func _centred(control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(control)
	return row


# --- what the number is made of --------------------------------------------------

## Every match this official has refereed, newest first.
##
## Reputation is one figure standing for a whole career, and it was the only record there
## was: somebody who had climbed to a national championship and somebody who had been
## thrown off two beach matches could arrive at the same 62 with nothing to tell them
## apart. This is the difference between them.
##
## It states the truth, which almost nothing else in this game does — but only about
## matches that are over. Nothing here can help you with a call you have not made yet.
var _history_panel: Control
var _history_column: VBoxContainer


func _build_history_panel() -> void:
	var built := _build_sheet("History", Color(0.04, 0.05, 0.07, 0.95))
	_history_panel = built[0]
	_history_column = built[1]


func show_history(career: Career) -> void:
	for child in _history_column.get_children():
		child.queue_free()
	if _hud != null:
		_hud.visible = false
	hide_career()

	_history_column.add_child(_make_label(
		"EVERY MATCH SO FAR", TITLE_SIZE - 4, UiTheme.CHALK))
	_history_column.add_child(_make_label(
		"%d refereed, %d walked away from." % [
			career.matches_refereed, career.times_removed],
		PROMPT_SIZE, UiTheme.MUTED))
	_history_column.add_child(_gap(14))

	var heading := _make_label(
		"%-18s %-24s %-9s %8s %7s" % ["sport", "venue", "format", "cost", "left"],
		PROMPT_SIZE - 3, UiTheme.MUTED)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_history_column.add_child(heading)

	for row in career.history:
		_history_column.add_child(_history_row(row))

	_history_column.add_child(_gap(18))
	_history_column.add_child(_centred(_make_wide_button("BACK", func() -> void:
		hide_history()
		career_screen_requested.emit()
	)))
	_history_panel.visible = true


## One match. The cost is what it did to your name, which is the only number here that
## is about you rather than about the match.
func _history_row(row: Dictionary) -> Label:
	var change := float(row.get("change", 0.0))
	var removed := bool(row.get("removed", false))
	var format := "—"
	if bool(row.get("asked", false)):
		format = "doubles" if bool(row.get("doubles", true)) else "singles"

	var text := "%-18s %-24s %-9s %+8.2f %7d" % [
		Career.name_of(StringName(row.get("sport", ""))),
		String(row.get("venue", "")),
		format,
		change,
		roundi(float(row.get("reputation", 0.0)) * 100.0),
	]
	if removed:
		text += "   thrown off"

	var tint := Color(0.74, 0.77, 0.82)
	if removed:
		tint = Color(0.96, 0.42, 0.36)
	elif change > 0.0:
		tint = Color(0.62, 0.82, 0.66)
	elif change < -0.05:
		tint = Color(0.92, 0.72, 0.50)
	var label := _make_label(text, PROMPT_SIZE - 3, tint)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


func hide_history() -> void:
	if _history_panel != null:
		_history_panel.visible = false


# --- the career ----------------------------------------------------------------

func _build_career_panel() -> void:
	_career_panel = Control.new()
	_career_panel.name = "CareerPanel"
	_career_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_career_panel.visible = false
	_career_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_career_panel)

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

	var rungs := career.ladder()
	for i in rungs.size():
		var rung: Dictionary = rungs[i]
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
			Career.format_of(career.sport, career.venue()["quick"]),
		],
		PROMPT_SIZE + 2,
		Color(0.88, 0.90, 0.93)
	))

	# Anybody out there who has not forgotten you. This is the only place a grudge
	# shows up before you are standing in front of it, and it is here rather than on
	# the briefing alone because the point of a grudge is that you carry it between
	# matches — knowing it is coming is most of what it does.
	if not career.grudge_name.is_empty():
		_career_column.add_child(_gap(8))
		_career_column.add_child(_make_label(
			"%s is still in this draw." % career.grudge_name,
			PROMPT_SIZE, Color(0.90, 0.62, 0.44)
		))

	_add_the_other_ladders(career)

	_career_column.add_child(_gap(16))
	# The button only reports the choice; the match decides what happens to the
	# screen. Hiding it in here means the flow only works when a human clicks.
	_career_column.add_child(_make_wide_button("REFEREE THIS MATCH", func() -> void:
		match_requested.emit()
	))
	# And a way back to the rules of whichever sport this is.
	#
	# The lesson used to be shown once, on the way into a first match, and then be
	# unreachable — the title screen's HOW TO REFEREE only ever had badminton's. That is
	# worst for indoor volleyball, whose lesson is the only one in the game explaining
	# something the player has to carry in their head rather than look at.
	_career_column.add_child(_gap(6))
	_career_column.add_child(_make_wide_button("HOW TO REFEREE", func() -> void:
		teaching_requested.emit()
	))
	# And what the reputation at the top of this screen is actually made of.
	if not career.history.is_empty():
		_career_column.add_child(_gap(6))
		_career_column.add_child(_make_wide_button("EVERY MATCH SO FAR", func() -> void:
			history_requested.emit()
		))


## All five ladders at once, under the one you are standing on.
##
## You are one official with one name and five separate licences, and until now there
## was nowhere that said so — each sport's screen showed its own ladder and the fact
## that a disaster at the beach is waiting for you at the badminton hall was something
## the player had to work out. The reputation at the top of this screen is the shared
## number; these are the four things it is spent on.
func _add_the_other_ladders(career: Career) -> void:
	_career_column.add_child(_gap(14))
	_career_column.add_child(_make_label(
		"ONE NAME, FIVE LADDERS", PROMPT_SIZE, UiTheme.MUTED))
	_career_column.add_child(_gap(4))

	for which in Career.IN_ORDER:
		var standing := career.standing_in(which)
		var rungs := Career.ladder_for(which)
		var here := int(standing["tier"])
		var line := ""
		var tint := Color(0.50, 0.53, 0.58)
		if not standing["started"]:
			line = "%-20s not started yet" % Career.name_of(which)
		else:
			var played := int(standing["matches_at_tier"])
			line = "%-20s %-26s %s" % [
				Career.name_of(which),
				String(rungs[clampi(here, 0, rungs.size() - 1)]["name"]),
				"%d at this rung" % played if played > 0 else "just arrived",
			]
			tint = Color(0.74, 0.77, 0.82)
		if which == career.sport:
			line = "▸ " + line
			tint = Color(0.98, 0.94, 0.72)
		else:
			line = "   " + line
		var label := _make_label(line, PROMPT_SIZE - 2, tint)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_career_column.add_child(label)


## Whether the career ladder is the screen currently showing.
func career_is_showing() -> bool:
	return _career_panel != null and _career_panel.visible


func hide_career() -> void:
	_career_panel.visible = false


## Clears every front-of-game screen. Called wherever a match begins, so that no
## route in can leave a menu sitting over the court — which each of these panels has
## managed to do in turn.
## Shows or hides the score bug and the prompts.
##
## `hide_menus` turns the HUD on, because it is what a match beginning calls. A scene
## that opens *into* a menu has to say so, or it draws a 0-0 score over the career
## ladder before a ball has been served.
func show_hud(shown: bool) -> void:
	if _hud != null:
		_hud.visible = shown


func hide_menus() -> void:
	_reason_paused = ""
	if _hud != null:
		_hud.visible = true
	hide_sport_menu()
	hide_format_menu()
	hide_settings()
	hide_teaching()
	hide_history()
	_main_menu.visible = false
	_career_panel.visible = false
	_pause_menu.visible = false
	_briefing.visible = false


func _gap(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _make_wide_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(UiTheme.BUTTON_WIDTH, UiTheme.BUTTON_HEIGHT)
	button.pressed.connect(on_press)
	var row := button
	return row


# --- the reason ----------------------------------------------------------------
#
# The screen that turns "pick a side" into a decision. Everything on it is something
# somebody said to the umpire in a corridor, and none of it is an instruction. The
# player is left to draw the conclusion, which is exactly the position the real job
# puts you in.

func _build_briefing() -> void:
	_briefing = Control.new()
	_briefing.name = "Briefing"
	_briefing.set_anchors_preset(Control.PRESET_FULL_RECT)
	_briefing.mouse_filter = Control.MOUSE_FILTER_STOP
	_briefing.visible = false
	_root.add_child(_briefing)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.05, 0.72)
	_briefing.add_child(backdrop)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_briefing.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	# Wide enough that a paragraph is a paragraph rather than a column of two words.
	column.custom_minimum_size = Vector2(720, 0)
	card.add_child(column)

	_briefing_headline = _make_label("", TITLE_SIZE, Color(0.96, 0.94, 0.88))
	column.add_child(_briefing_headline)

	# The body is the only long prose in the game, so it wraps and is left-aligned.
	# Centred ragged text reads as a poster; this is meant to read as somebody talking.
	_briefing_detail = _make_label("", PROMPT_SIZE, Color(0.74, 0.76, 0.80))
	_briefing_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_briefing_detail.custom_minimum_size = Vector2(720, 0)
	column.add_child(_briefing_detail)

	column.add_child(_gap(6))

	# The one line you will still be thinking about at 19-all, in the colour of
	# whoever stands to gain by it.
	_briefing_ask = _make_label("", BUTTON_SIZE, Color(0.95, 0.90, 0.60))
	_briefing_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_ask.custom_minimum_size = Vector2(720, 0)
	column.add_child(_briefing_ask)

	column.add_child(_gap(10))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	row.add_child(_make_wide_button("GO OUT", func() -> void: briefing_acknowledged.emit()))



func show_briefing(pressure: Pressure) -> void:
	_briefing_headline.text = pressure.headline.to_upper()
	_briefing_detail.text = pressure.detail
	_briefing_ask.text = pressure.ask
	_briefing_ask.add_theme_color_override("font_color",
		Sides.colour(pressure.wants) if pressure.wants != Sides.Team.NONE
		else Color(0.95, 0.90, 0.60))
	_briefing.visible = true


func hide_briefing() -> void:
	_briefing.visible = false


## The match starts the moment the briefing is dismissed, or straight away when there
## is no briefing.
##
## There used to be a screen here asking WHO DO YOU WANT TO WIN, answered before a ball
## was served. It was cut on purpose. Being asked to declare a favourite made the game
## tell you what kind of referee to be before you had seen anything, and most people do
## not sit down wanting a result — they sit down wanting to get it right, and find out
## later what they are willing to do. A reason to lean now only ever arrives from
## outside, in a briefing, and only sometimes.


# --- in-match ------------------------------------------------------------------

func _build_hud() -> void:
	var hud := Control.new()
	_hud = hud
	hud.name = "Hud"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hud)

	# The score and the prompt sit on plates. White text over a lit green court is
	# legible about half the time, which for the one line telling you the score is
	# half the time too little.
	hud.add_child(_build_scorebug())

	_message_label = _make_label("", MESSAGE_SIZE, Color(0.98, 0.94, 0.72))
	_message_label.set_anchors_preset(Control.PRESET_CENTER)
	_message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_message_label.position = Vector2(0, -70)
	hud.add_child(_message_label)

	_prompt_label = _make_label("", PROMPT_SIZE, Color(0.88, 0.90, 0.93))
	hud.add_child(_plate_for(_prompt_label, Control.PRESET_CENTER_BOTTOM, Vector2(0, -34)))

	# What the hall is doing. For a long time this was the *only* feedback the player
	# ever got about how much trouble they were in. The reputation meter below now says
	# what it has cost — but only when it changes, and only for three seconds, so the
	# room is still the thing you read continuously and the meter is only ever news.
	_reaction_label = _make_label("", REACTION_SIZE, Color(0.86, 0.80, 0.66))
	_reaction_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_reaction_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_reaction_label.position = Vector2(0, -110)
	hud.add_child(_reaction_label)

	# What the line judge said, in words, near the middle of the screen.
	#
	# The bubble over their head is not enough on its own. A badminton court is small and
	# both judges are in shot; a tennis court is twenty-four metres long and its judges
	# sit at the corners, fourteen metres from the chair and usually outside an eighty
	# degree view — so their call was going up where nobody could see it, which read as
	# them having nothing to say.
	_judge_label = _make_label("", REACTION_SIZE + 4, Color(0.86, 0.88, 0.94))
	hud.add_child(_plate_for(_judge_label, Control.PRESET_CENTER_BOTTOM,
		Vector2(0, -216), 0.72))
	_judge_plate = _judge_label.get_parent() as PanelContainer
	_judge_plate.visible = false

	_banner_label = _make_label("", BANNER_SIZE, Color(0.96, 0.42, 0.36))
	_banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner_label.position = Vector2(0, 76)
	hud.add_child(_banner_label)

	hud.add_child(_build_reputation_meter())
	hud.add_child(_build_reason_note())
	hud.add_child(_build_bubbles())


## The score bug at the top of the screen, the way a broadcast does it: a block of each
## team's colour with their name in it, the points between them in the largest type on
## screen, and a lit dot over whoever is serving.
##
## Who is serving matters more here than in most sports and was previously a bullet
## character in a run of text. In badminton the server decides which service court the
## rally starts from, so an umpire who has lost track of it cannot judge a service
## fault at all.
func _build_scorebug() -> PanelContainer:
	var bug := PanelContainer.new()
	bug.name = "ScoreBug"
	bug.add_theme_stylebox_override("panel", UiTheme.plate(UiTheme.ACCENT, 0.86))
	bug.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bug.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bug.position = Vector2(0, 22)
	bug.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bug.add_child(row)

	_serve_red = _serve_dot()
	row.add_child(_serve_red)
	row.add_child(_team_block("RED", UiTheme.RED))

	_score_points = _make_label("0  -  0", UiTheme.HUGE, UiTheme.CHALK)
	row.add_child(_score_points)

	row.add_child(_team_block("BLUE", UiTheme.BLUE))
	_serve_blue = _serve_dot()
	row.add_child(_serve_blue)

	_score_games = _make_label("", UiTheme.SMALL, UiTheme.MUTED)
	_score_games.custom_minimum_size = Vector2(140, 0)
	row.add_child(_score_games)

	# How many reviews each side still holds. Shown because it is the whole of the
	# threat: an umpire who cannot see that RED has two challenges left does not know
	# whether the next close call is worth lying about.
	_score_reviews = _make_label("", UiTheme.SMALL, UiTheme.MUTED)
	_score_reviews.custom_minimum_size = Vector2(210, 0)
	row.add_child(_score_reviews)
	return bug


func _team_block(name: String, colour: Color) -> PanelContainer:
	var block := PanelContainer.new()
	block.add_theme_stylebox_override("panel", UiTheme.block(colour))
	var label := _make_label(name, UiTheme.HEADING, Color.WHITE)
	block.add_child(label)
	return block


func _serve_dot() -> Label:
	var dot := _make_label("", UiTheme.HEADING, UiTheme.ACCENT)
	dot.custom_minimum_size = Vector2(26, 0)
	return dot


func set_score(board: Scoreboard, serving: Sides.Team) -> void:
	# Tennis counts in a language of its own, and a bug reading "2 - 1" in a sport whose
	# whole texture is "thirty-fifteen" would throw away the reason it is here. It is
	# also the one score in the game read from the server's point of view: forty-fifteen
	# and fifteen-forty are the same two numbers and opposite situations.
	var tennis := board as TennisScore
	if tennis != null:
		_score_points.text = tennis.called_score(serving)
	else:
		_score_points.text = "%d  -  %d" % [
			board.points[Sides.Team.RED], board.points[Sides.Team.BLUE]
		]
	_serve_red.text = "\u25cf" if serving == Sides.Team.RED else ""
	_serve_blue.text = "\u25cf" if serving == Sides.Team.BLUE else ""
	if tennis != null:
		_score_games.text = "GAMES  %d - %d      SETS  %d - %d" % [
			tennis.games[Sides.Team.RED], tennis.games[Sides.Team.BLUE],
			tennis.sets[Sides.Team.RED], tennis.sets[Sides.Team.BLUE],
		]
	else:
		_score_games.text = "" if board.games_needed <= 1 else "GAMES  %d - %d" % [
			board.games[Sides.Team.RED], board.games[Sides.Team.BLUE]
		]


## The reviews each side has left, or nothing at all at the venues without Hawk-Eye —
## where the absence is itself information, because it means nobody can check you.
func set_reviews(red: int, blue: int, enabled: bool) -> void:
	if not enabled:
		_score_reviews.text = ""
		return
	_score_reviews.text = "REVIEWS  %s   %s" % [_review_dots(red), _review_dots(blue)]


## Filled for a review still held, hollow for one spent. Read at a glance and in the same
## order as the score bug itself: red on the left, blue on the right.
func _review_dots(left: int) -> String:
	return "\u25cf".repeat(left) + "\u25cb".repeat(maxi(0, Challenge.PER_GAME - left))


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


## What the line judge called. `says_in` colours it: a judge who says a ball was good is
## agreeing with nobody in particular, and one who calls it out has just put a number on
## the board that you are about to either echo or contradict in public.
func show_line_judge(says_in: bool, seconds := 2.4) -> void:
	if _judge_label == null:
		return
	_judge_label.text = "LINE JUDGE   ·   %s" % ("IN" if says_in else "OUT")
	_judge_label.add_theme_color_override("font_color",
		Color(0.72, 0.86, 0.74) if says_in else Color(0.96, 0.62, 0.52))
	_judge_plate.add_theme_stylebox_override("panel", UiTheme.plate(
		Color(0.55, 0.85, 0.60) if says_in else Color(0.96, 0.42, 0.36), 0.72))
	_judge_plate.visible = true
	_judge_timer = seconds


func hide_line_judge() -> void:
	if _judge_plate != null:
		_judge_plate.visible = false
	_judge_timer = 0.0


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
	_root.add_child(_fault_panel)

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
## Which sport's faults the panel offers. Badminton's by default; the two volleyballs
## set their own, because "four hits" means nothing on a badminton court and "carry"
## means nothing on a volleyball one.
var fault_book: Array = CallBook.faults()


## Whether this sport hands out cards. Badminton does; neither volleyball has them
## modelled yet, and offering a card the game cannot price would be worse than not
## offering one at all.
var offers_cards := true


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
		for call in fault_book:
			_fault_rows.add_child(_make_accusation_row(call.label, call.id, Color(0.90, 0.88, 0.84)))

	if offers_cards:
		_fault_rows.add_child(
			_make_accusation_row("YELLOW CARD", &"yellow", Color(0.95, 0.85, 0.30)))
		_fault_rows.add_child(
			_make_accusation_row("RED CARD", &"red", Color(0.94, 0.36, 0.32)))

	_fault_panel.visible = true


func _make_accusation_row(label: String, id: StringName, tint: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	var name_label := _make_label(label, PROMPT_SIZE + 3, tint)
	name_label.custom_minimum_size = Vector2(320, 58)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_label)

	for team in [Sides.Team.BLUE, Sides.Team.RED]:
		var button := Button.new()
		button.text = Sides.label(team)
		button.custom_minimum_size = Vector2(170, 58)
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
	_root.add_child(_shuttle_cam_panel)

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

	_close_cam_caption = _make_label(
		"SHUTTLE CAM", PROMPT_SIZE - 3, Color(0.72, 0.74, 0.78))
	_close_cam_caption.position = Vector2(0, ShuttleCam.HEIGHT + 4)
	_close_cam_caption.size = Vector2(ShuttleCam.WIDTH, 18)
	_shuttle_cam_panel.add_child(_close_cam_caption)


## Shows the line camera's view of where the shuttle came down. The picture is
## deliberately small: it settles the obvious ones and settles nothing else, which
## is the only way it can exist without answering the question for the player.
## The camera on the line, whatever is flying over it.
##
## Named for the shuttlecock because badminton was the only sport when it was written.
## Both volleyballs use the same panel for a ball, so these are the names to call it by;
## the shuttle_cam pair below remain as badminton's.
func show_close_cam(view: Texture2D, caption := "BALL CAM") -> void:
	if _close_cam_caption != null:
		_close_cam_caption.text = caption
	show_shuttle_cam(view)


func hide_close_cam() -> void:
	hide_shuttle_cam()


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
	_root.add_child(_ending)

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
## The last screen, and the only one allowed to state the truth.
##
## It puts everything else away first. Every other `show_*` in this file does that and
## this one did not — it set `_ending.visible = true` twice and hid nothing — so whatever
## happened to be on screen when the match ended stayed behind it: the score bug, the
## review that was still up at the moment you were taken off, and, coming from the title
## screen, the whole main menu reading through the sheet.
##
## `hide_menus` is deliberately not used. It turns the HUD back **on**, because it is
## what a match beginning calls.
func show_ending(headline: String, detail: String, tint := Color(0.96, 0.42, 0.36)) -> void:
	hide_sport_menu()
	hide_format_menu()
	hide_settings()
	hide_teaching()
	hide_career()
	hide_history()
	hide_review()
	hide_fault_panel()
	hide_close_cam()
	hide_briefing()
	hide_reputation()
	hide_reason()
	hide_bubble()
	hide_line_judge()
	clear_messages()
	_main_menu.visible = false
	_pause_menu.visible = false
	if _hud != null:
		_hud.visible = false

	_ending_headline.text = headline
	_ending_headline.add_theme_color_override("font_color", tint)
	_ending_detail.text = detail
	_ending.visible = true


## Wraps a label in a dark plate and anchors the pair where it belongs.
func _plate_for(label: Label, preset: int, offset: Vector2, alpha := 0.80) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.plate(UiTheme.ACCENT, alpha))
	plate.set_anchors_preset(preset)
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.grow_vertical = Control.GROW_DIRECTION_BOTH
	plate.position = offset
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	return plate


func _make_label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label
