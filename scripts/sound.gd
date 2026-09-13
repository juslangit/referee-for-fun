class_name Sound
extends Node3D

## Everything the hall sounds like.
##
## It matters more here than it looks. The crowd is the thing that tells the player how
## much trouble they are in from moment to moment — nothing counts their mistakes, on
## purpose — and the hall was recently darkened to the point where you can barely make
## the people out. That left the whole feedback loop resting on a line of text. A room
## that murmurs, and murmurs differently when it stops trusting you, gives it back.
##
## Two crowd beds play at once, all match, and the mix between them follows suspicion.
## Nobody is meant to notice the crossfade — only that the room has got tighter.

## The shared half of the hall: the two crowd beds, the whistle, and what the room makes
## of a call. All replaced once, because the first set were placeholders and sounded it —
## a whistle nobody would blow, a bed that was obviously eight seconds long, and applause
## that had no room in it.
const CALM := "res://assets/audio/crowd_calm.mp3"
const TENSE := "res://assets/audio/crowd_tense.mp3"
const WHISTLE := "res://assets/audio/whistle.wav"

## The line judge, calling a ball out.
##
## **Only OUT is ever called.** A line judge who thinks a ball was in says nothing and
## signals with their hands — so silence here is information, and a shout always means
## the same thing. Calling both would make the loudest event in a rally happen on every
## rally, which is the same as it happening on none.
const JUDGE_OUT := "res://assets/audio/judge_out.wav"
const JUDGE_DB := -7.0
const APPLAUSE := "res://assets/audio/applause.wav"
const GROAN := "res://assets/audio/groan.wav"

## The room outside the rally: a point going up on the board, a set, the end of the night,
## and the few seconds of a review.
const SCOREBOARD := "res://assets/audio/hall/scoreboard_tick.ogg"
const SET_CHEER := "res://assets/audio/hall/set_cheer.mp3"
const MATCH_CHEER := "res://assets/audio/hall/match_cheer.mp3"
const REMOVED_BOO := "res://assets/audio/hall/removed_boo.mp3"
const REVIEW_OPEN := "res://assets/audio/hall/review_open.ogg"
const REVIEW_OOOH := "res://assets/audio/hall/review_oooh.mp3"
const REVIEW_STANDS := "res://assets/audio/hall/review_stands.ogg"
const REVIEW_OVERTURNED := "res://assets/audio/hall/review_overturned.ogg"

## Footsteps, by what the court is made of, and the squeak of a shoe stopping on it.
const STEPS_WOOD := [
	"res://assets/audio/steps/step_wood_1.ogg", "res://assets/audio/steps/step_wood_2.ogg",
	"res://assets/audio/steps/step_wood_3.ogg", "res://assets/audio/steps/step_wood_4.ogg",
]
const STEPS_SAND := [
	"res://assets/audio/steps/step_sand_1.wav", "res://assets/audio/steps/step_sand_2.wav",
	"res://assets/audio/steps/step_sand_3.wav", "res://assets/audio/steps/step_sand_4.wav",
	"res://assets/audio/steps/step_sand_5.wav",
]
const STEPS_COURT := [
	"res://assets/audio/steps/step_court_1.ogg", "res://assets/audio/steps/step_court_2.ogg",
	"res://assets/audio/steps/step_court_3.ogg", "res://assets/audio/steps/step_court_4.ogg",
]
const SQUEAKS := [
	"res://assets/audio/steps/squeak_1.wav", "res://assets/audio/steps/squeak_2.wav",
]

const VOLLEY_SOFT := [
	"res://assets/audio/volleyball/volley_hit_soft_1.wav",
	"res://assets/audio/volleyball/volley_hit_soft_2.wav",
]
const VOLLEY_HARD := ["res://assets/audio/hit_volley_hard.wav"]
const TENNIS_HIT := ["res://assets/audio/hit_tennis.wav"]

## What each sport is made of.
##
## All four used to share these three files, so a shuttlecock landing was also a
## volleyball dropping into sand and a tennis ball off a hard court. Those are three
## completely different noises, and **the surface is half of what a landing tells you** —
## a ball hitting sand is a thud you feel and a ball hitting a hard court is a crack you
## hear from the back row. In a game whose whole subject is judging where something
## landed, that is not decoration.
##
## Each entry is a list rather than one file, and one is picked at random every time. A
## table tennis rally is twenty contacts; the same sample twenty times in a row is a
## machine gun, not a rally.
##
## `whistle` and `shouts_out` are how the sport is officiated, and they are not the same in
## all five. **Only volleyball's referee blows a whistle.** A tennis chair umpire, a
## badminton umpire and a table tennis umpire all start a point with their voice, not a
## whistle. And only tennis and badminton line judges shout: a volleyball line judge
## signals with a flag and says nothing, and table tennis has no line judges at all. Both
## were played in every sport until 2026-09-13.
##
## Missing files fall back to the badminton set rather than to silence: this is a look-up
## of what a sport would like, not a promise that it has been sourced yet.
const KITS := {
	&"badminton": {
		"soft": ["res://assets/audio/badminton/badminton_hit_soft.wav"],
		"hard": ["res://assets/audio/badminton/badminton_hit_hard.wav"],
		"land": ["res://assets/audio/badminton/badminton_land.wav"],
		"steps": STEPS_WOOD,
		"squeaks": true,
		"whistle": false,
		"shouts_out": true,
	},
	&"beach": {
		"soft": VOLLEY_SOFT,
		"hard": VOLLEY_HARD,
		"land": ["res://assets/audio/land_sand.wav"],
		"steps": STEPS_SAND,
		# Bare feet in sand do not squeak.
		"squeaks": false,
		"whistle": true,
		"shouts_out": false,
	},
	&"indoor": {
		"soft": VOLLEY_SOFT,
		"hard": VOLLEY_HARD,
		"land": [
			"res://assets/audio/volleyball/indoor_land_1.wav",
			"res://assets/audio/volleyball/indoor_land_2.wav",
		],
		"steps": STEPS_WOOD,
		"squeaks": true,
		"whistle": true,
		"shouts_out": false,
	},
	&"tennis": {
		"soft": TENNIS_HIT,
		"hard": TENNIS_HIT,
		"land": [
			"res://assets/audio/tennis/tennis_land_1.wav",
			"res://assets/audio/tennis/tennis_land_2.wav",
			"res://assets/audio/tennis/tennis_land_3.wav",
		],
		"net": ["res://assets/audio/tennis/tennis_net_cord.wav"],
		"steps": STEPS_COURT,
		"squeaks": true,
		"whistle": false,
		"shouts_out": true,
	},
	# The one sport where the bat and the table make nearly the same noise — a hollow
	# click either way — which is exactly why the edge ball is decided by a sound the
	# umpire has to be able to tell apart from it.
	&"table_tennis": {
		"soft": [
			"res://assets/audio/table_tennis/tt_hit_1.wav",
			"res://assets/audio/table_tennis/tt_hit_2.wav",
		],
		"hard": [
			"res://assets/audio/table_tennis/tt_hit_1.wav",
			"res://assets/audio/table_tennis/tt_hit_2.wav",
		],
		"land": [
			"res://assets/audio/table_tennis/tt_bounce_1.wav",
			"res://assets/audio/table_tennis/tt_bounce_2.wav",
		],
		"net": ["res://assets/audio/table_tennis/tt_net.wav"],
		"steps": STEPS_WOOD,
		"squeaks": true,
		"whistle": false,
		"shouts_out": false,
	},
}

## Which sport this hall is currently hosting. Set once, when the match is built.
var kit := &"badminton"

## How loud each thing sits, in decibels. The crowd is deliberately well down: it is a
## bed to be felt rather than listened to, and a hall you have to talk over is a hall
## nobody can referee in.
const CROWD_DB := -19.0
const WHISTLE_DB := -5.0
const HIT_DB := -9.0
const REACTION_DB := -9.0
## Feet are the quietest thing on court. Four people running are a texture under the
## rally, and the moment they compete with the ball the ball stops telling you anything.
const STEP_DB := -21.0
const SQUEAK_DB := -17.0
const SCOREBOARD_DB := -20.0
const REVIEW_DB := -8.0
const ENDING_DB := -6.0

## How quickly the room's mood follows the umpire's. Slow on purpose — a hall does not
## turn on you between one rally and the next, it sours over a game.
const MOOD_SPEED := 0.35

## How many strikes can ring at once. A rally is one shuttle, but a smash and its
## landing can overlap, and cutting one off to start the other is worse than either.
const STRIKE_VOICES := 4

## How many feet can land at once. Four players at a run is about eighteen steps a
## second; each is a fifth of a second long, so six is enough that none are cut off.
const STEP_VOICES := 6

## A ball arriving this fast is as loud as its sound gets; slower ones are quieter. A
## tennis ball dribbling to rest after a point is not a second landing.
const LOUD_BOUNCE := 14.0
const QUIETEST_BOUNCE := 0.8

## How far a player runs between footsteps, in metres.
const STRIDE := 1.1

## A player who was running and has all but stopped has planted a foot, and on a court
## that grips, that squeaks. Not every time — a squeak on every stop is a cartoon.
const SQUEAK_FROM_SPEED := 2.6
const SQUEAK_CHANCE := 0.35

## Everything this hall has been asked to play, counted by name. Nothing in the game reads
## it; `dev/checks/_everysound` does, because it cannot listen either.
var heard := {}

var _calm: AudioStreamPlayer
var _tense: AudioStreamPlayer
var _reaction: AudioStreamPlayer
var _whistle: AudioStreamPlayer
var _occasion: AudioStreamPlayer
var _review: AudioStreamPlayer
var _scoreboard: AudioStreamPlayer
var _strikes: Array[AudioStreamPlayer3D] = []
var _next_strike := 0
var _steps: Array[AudioStreamPlayer3D] = []
var _next_step := 0

var _mood := 0.0
var _wanted_mood := 0.0

## Per player: how far they have run since their last step, and how fast they were going.
var _stride := {}
var _pace := {}
var _last_seen := {}


func _ready() -> void:
	# The mixer is split before anything is created, so every player below lands on a
	# bus the settings screen can actually move.
	Settings.ensure_buses()

	_calm = _bed(CALM)
	_tense = _bed(TENSE)
	_whistle = _flat(WHISTLE, WHISTLE_DB)
	_reaction = _flat(APPLAUSE, REACTION_DB)
	# The hall's reaction belongs with the hall, not with the whistle.
	_reaction.bus = Settings.CROWD_BUS
	# A set or a match ending, and the review: the room again, but on their own players so
	# that a groan at the call does not cut off the cheer at the set.
	_occasion = _flat(MATCH_CHEER, ENDING_DB)
	_occasion.bus = Settings.CROWD_BUS
	_review = _flat(REVIEW_OPEN, REVIEW_DB)
	_scoreboard = _flat(SCOREBOARD, SCOREBOARD_DB)

	for i in STRIKE_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Strike%d" % i
		voice.volume_db = HIT_DB
		# Heard across a hall rather than from a metre away. Without this the shuttle is
		# inaudible from the chair, which is where the player always is.
		voice.unit_size = 14.0
		voice.max_distance = 40.0
		voice.bus = Settings.EFFECTS_BUS
		add_child(voice)
		_strikes.append(voice)

	for i in STEP_VOICES:
		var foot := AudioStreamPlayer3D.new()
		foot.name = "Step%d" % i
		foot.volume_db = STEP_DB
		# Nearer than a ball. You hear the player at the net and not the one at the back.
		foot.unit_size = 6.0
		foot.max_distance = 30.0
		foot.bus = Settings.EFFECTS_BUS
		add_child(foot)
		_steps.append(foot)

	_set_mix(0.0)


## A looping bed. The loop points are set here rather than in the import settings so
## that the sound works from a fresh checkout without anybody opening the editor.
func _bed(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = path.get_file().get_basename()
	var stream := _looping(path)
	if stream == null:
		return player
	player.stream = stream
	player.volume_db = -80.0
	player.bus = Settings.CROWD_BUS
	add_child(player)
	player.play()
	return player


static func _looping(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		# Frames, worked out from the length rather than from the size of the buffer.
		# `data.size() / 2` is only the frame count while the samples are uncompressed
		# sixteen-bit, and Godot's importer compresses by default — so that arithmetic
		# quietly set the loop to the first second of a six second bed, and the hall
		# would have hiccupped once a second all match.
		wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	elif stream is AudioStreamMP3:
		# An mp3 loops with a flag rather than with sample positions, and the beds are
		# mp3 now because that is what Freesound hands out without a login. Without this
		# branch the hall played its crowd once, stopped, and stayed silent for the rest
		# of the match — which is worse than the placeholder it replaced.
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream


func _flat(path: String, level: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = path.get_file().get_basename()
	if ResourceLoader.exists(path):
		player.stream = load(path)
	player.volume_db = level
	player.bus = Settings.EFFECTS_BUS
	add_child(player)
	return player


# --- what the game asks for ------------------------------------------------------

## The referee's whistle — in the two sports whose referee has one. See KITS.
func whistle() -> void:
	if not _kit().get("whistle", false):
		return
	_count(&"whistle")
	if _whistle.stream != null:
		_whistle.play()


## The ball being struck, at the racket rather than in the middle of your head.
func strike(where: Vector3, hard: bool) -> void:
	_count(&"strike")
	_ring(_from_kit("hard" if hard else "soft"), where, HIT_DB)


## The ball arriving, on whatever this sport is played on.
##
## For the shuttle, which lands once and stops dead. A ball bounces, and is heard through
## `bounce` every time it does.
func landing(where: Vector3) -> void:
	_count(&"land")
	_ring(_from_kit("land"), where, HIT_DB)


## A ball meeting the floor, the sand or the table: every time, not only the time the
## point is decided on.
##
## Tennis and table tennis are sports in which the ball lands on nearly every stroke, and
## until this existed only the last landing of a point made a noise. A rally of eight
## groundstrokes was eight cracks of the racket and silence in between, which is not a
## sound anybody who has sat by a court has heard.
func bounce(where: Vector3, speed: float) -> void:
	if speed < QUIETEST_BOUNCE:
		return
	_count(&"bounce")
	var level := HIT_DB + linear_to_db(clampf(speed / LOUD_BOUNCE, 0.2, 1.0))
	var pitch := randf_range(0.96, 1.04)
	# A table tennis ball that has missed the table carries on down to the floor, and the
	# floor is lower and duller than the tabletop.
	if kit == &"table_tennis" and where.y < 0.3:
		level -= 6.0
		pitch *= 0.82
	_ring(_from_kit("land"), where, level, pitch)


## The edge ball, which is table tennis's own call.
##
## A ball off the top edge and a ball off the side sound almost the same — that is the
## whole difficulty — but not quite. The top edge is the tabletop, a fraction thinner. The
## side is the edge of the board taking the ball square on, and it is lower and flatter,
## and the ball does not come up off it the same way.
func edge(where: Vector3, on_top: bool) -> void:
	_count(&"edge")
	if on_top:
		_ring(_from_kit("land"), where, HIT_DB - 1.5, 1.08)
	else:
		_ring(_from_kit("land"), where, HIT_DB - 4.0, 0.78)


## A serve clipping the top of the net, as loud as the touch was heavy.
##
## The lesson for both net sports says this call is decided by a sound, and until
## 2026-09-13 there was no sound: the net shivered and that was all. A graze is barely
## audible from the chair and a heavy touch is plain, which is what makes a let the
## easiest thing in tennis to invent and the easiest to miss.
func net_cord(where: Vector3, how_plain: float) -> void:
	if not _kit().has("net"):
		return
	_count(&"net")
	_ring(_from_kit("net"), where, HIT_DB - 10.0 + clampf(how_plain, 0.0, 1.0) * 9.0,
		randf_range(0.95, 1.05))


## A line judge calling a ball out, from where they are sitting rather than from the
## middle of your head. It is the only thing in a rally that comes from the corner of
## the court, and in tennis that is fourteen metres away and usually off the side of the
## screen — which is exactly why it needs a sound as well as a flag.
##
## Only where line judges really shout. See KITS.
func judge_calls_out(where: Vector3) -> void:
	if not _kit().get("shouts_out", false):
		return
	_count(&"judge_out")
	_ring(JUDGE_OUT, where, JUDGE_DB)


## A player's foot coming down.
func footstep(where: Vector3) -> void:
	var steps: Array = _kit().get("steps", STEPS_WOOD)
	if steps.is_empty():
		return
	_count(&"step")
	_foot(String(steps.pick_random()), where, STEP_DB)


## A shoe gripping the court as a player stops.
func squeak(where: Vector3) -> void:
	if not _kit().get("squeaks", false):
		return
	_count(&"squeak")
	_foot(String(SQUEAKS.pick_random()), where, SQUEAK_DB)


## The score going up on the hanging board. Quiet and electronic, on every point, because
## it says nothing about how the call went — that is what the crowd is for.
func scoreboard() -> void:
	_count(&"scoreboard")
	if _scoreboard.stream != null:
		_scoreboard.play()


## A set or a game won, and the match going on.
func set_won() -> void:
	_count(&"set_won")
	_occasion_plays(SET_CHEER)


## The end of the night. A match that finished gets its cheer — preceded, in volleyball,
## by the referee's whistle — and an umpire walked off the court gets booed out of it.
func match_over(removed: bool) -> void:
	_count(&"match_over")
	if removed:
		_occasion_plays(REMOVED_BOO)
		return
	whistle()
	_occasion_plays(MATCH_CHEER)


## A review being called up on the big screen, and the hall drawing its breath.
func review_begins() -> void:
	_count(&"review")
	_play_on(_review, REVIEW_OPEN, REVIEW_DB)
	_occasion_plays(REVIEW_OOOH)


## The review's answer, before the room makes up its mind about it.
func review_answer(overturned: bool) -> void:
	_count(&"review_answer")
	_play_on(_review, REVIEW_OVERTURNED if overturned else REVIEW_STANDS, REVIEW_DB)


## The hall's verdict on the call. Applause if it liked it, a groan if it did not — and
## nothing at all if the rally was too dull to have an opinion about, because a room
## that reacts to everything is a room that is telling you nothing.
func react(approving: bool) -> void:
	_count(&"applause" if approving else &"groan")
	var path := APPLAUSE if approving else GROAN
	if not ResourceLoader.exists(path):
		return
	_reaction.stream = load(path)
	_reaction.volume_db = REACTION_DB
	_reaction.play()


func _occasion_plays(path: String) -> void:
	_play_on(_occasion, path, ENDING_DB)


func _play_on(player: AudioStreamPlayer, path: String, level: float) -> void:
	if not ResourceLoader.exists(path):
		return
	player.stream = load(path)
	player.volume_db = level
	player.play()


## One sound, at a place in the hall, on the next of the shared ball voices.
func _ring(path: String, where: Vector3, level: float, pitch := 1.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var voice := _strikes[_next_strike]
	_next_strike = (_next_strike + 1) % _strikes.size()
	voice.stream = load(path)
	# Set every time rather than once at build. The four players are shared, and the
	# line judge's call is louder than a contact — one shout would otherwise leave
	# whichever player it used turned up for the rest of the match.
	voice.volume_db = level
	voice.pitch_scale = pitch
	voice.global_position = where
	voice.play()


func _foot(path: String, where: Vector3, level: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var voice := _steps[_next_step]
	_next_step = (_next_step + 1) % _steps.size()
	voice.stream = load(path)
	voice.volume_db = level + randf_range(-2.0, 1.0)
	voice.pitch_scale = randf_range(0.92, 1.08)
	voice.global_position = where
	voice.play()


func _kit() -> Dictionary:
	return KITS.get(kit, KITS[&"badminton"])


## One sound out of this sport's kit, falling back to badminton's if it is not there.
func _from_kit(which: String) -> String:
	var chosen: Array = _kit().get(which, [])
	var path := String(chosen.pick_random()) if not chosen.is_empty() else ""
	if path.is_empty() or not ResourceLoader.exists(path):
		var fallback: Array = KITS[&"badminton"].get(which, [""])
		return String(fallback[0])
	return path


func _count(what: StringName) -> void:
	heard[what] = int(heard.get(what, 0)) + 1


## Listens for feet. Every athlete puts themselves in the `athletes` group, so the hall
## hears whoever is on court without each sport having to hand its players over — and
## there are five sports, a doubles rebuild and a teaching screen that all make players.
func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	var still_here := {}
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var athlete := node as Node3D
		if athlete == null or not athlete.is_inside_tree():
			continue
		var id := athlete.get_instance_id()
		still_here[id] = true
		var here := athlete.global_position
		if not _last_seen.has(id):
			_last_seen[id] = here
			_stride[id] = 0.0
			_pace[id] = 0.0
			continue
		var before: Vector3 = _last_seen[id]
		_last_seen[id] = here
		var moved := Vector2(here.x - before.x, here.z - before.z).length()
		# A player put somewhere rather than running there — a new rally, a change of
		# ends — has not taken forty steps.
		if moved > 1.0:
			_stride[id] = 0.0
			_pace[id] = 0.0
			continue
		var pace := moved / delta
		if float(_pace[id]) >= SQUEAK_FROM_SPEED and pace < 0.4 \
				and randf() < SQUEAK_CHANCE:
			squeak(here)
		_pace[id] = pace
		_stride[id] = float(_stride[id]) + moved
		if float(_stride[id]) >= STRIDE:
			_stride[id] = 0.0
			footstep(here)
	for id in _last_seen.keys():
		if not still_here.has(id):
			_last_seen.erase(id)
			_stride.erase(id)
			_pace.erase(id)


## How much the room trusts you, from nought to one. Fed straight from suspicion.
func set_mood(level: float) -> void:
	_wanted_mood = clampf(level, 0.0, 1.0)


func _process(delta: float) -> void:
	if is_equal_approx(_mood, _wanted_mood):
		return
	_mood = move_toward(_mood, _wanted_mood, delta * MOOD_SPEED)
	_set_mix(_mood)


## Crossfades the two beds. Equal power rather than a straight blend, so the room does
## not dip in the middle as one bed hands over to the other.
func _set_mix(mood: float) -> void:
	var tense := sqrt(mood)
	var calm := sqrt(1.0 - mood)
	# The whole crowd also swells as the mood sours: a hall that has stopped trusting
	# the umpire is not merely a different noise, it is a louder one.
	var swell := 1.0 + mood * 0.8
	if _calm != null:
		_calm.volume_db = _level(calm * swell)
	if _tense != null:
		_tense.volume_db = _level(tense * swell)


func _level(amount: float) -> float:
	if amount <= 0.001:
		return -80.0
	return CROWD_DB + linear_to_db(amount)
