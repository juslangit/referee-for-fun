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
const WHISTLE := "res://assets/audio/whistle.mp3"

## The line judge, calling a ball out.
##
## **Only OUT is ever called.** A line judge who thinks a ball was in says nothing and
## signals with their hands — so silence here is information, and a shout always means
## the same thing. Calling both would make the loudest event in a rally happen on every
## rally, which is the same as it happening on none.
const JUDGE_OUT := "res://assets/audio/judge_out.mp3"
const JUDGE_DB := -7.0
const HIT_SOFT := "res://assets/audio/hit_soft.wav"
const HIT_HARD := "res://assets/audio/hit_hard.wav"
const LAND := "res://assets/audio/shuttle_land.wav"

## What each sport is made of.
##
## All four used to share these three files, so a shuttlecock landing was also a
## volleyball dropping into sand and a tennis ball off a hard court. Those are three
## completely different noises, and **the surface is half of what a landing tells you** —
## a ball hitting sand is a thud you feel and a ball hitting a hard court is a crack you
## hear from the back row. In a game whose whole subject is judging where something
## landed, that is not decoration.
##
## Missing files fall back to the badminton set rather than to silence: this is a look-up
## of what a sport would like, not a promise that it has been sourced yet.
const KITS := {
	&"badminton": {
		"soft": HIT_SOFT,
		"hard": HIT_HARD,
		"land": LAND,
	},
	&"beach": {
		"soft": HIT_SOFT,
		"hard": "res://assets/audio/hit_volley_hard.mp3",
		"land": "res://assets/audio/land_sand.mp3",
	},
	&"indoor": {
		"soft": HIT_SOFT,
		"hard": "res://assets/audio/hit_volley_hard.mp3",
		"land": "res://assets/audio/land_wood.ogg",
	},
	&"tennis": {
		"soft": "res://assets/audio/hit_tennis.mp3",
		"hard": "res://assets/audio/hit_tennis.mp3",
		"land": "res://assets/audio/land_hardcourt.mp3",
	},
	# The one sport where the bat and the table make nearly the same noise — a hollow
	# click either way — which is exactly why the edge ball is decided by a sound the
	# umpire has to be able to tell apart from it.
	&"table_tennis": {
		"soft": "res://assets/audio/hit_pingpong.wav",
		"hard": "res://assets/audio/hit_pingpong.wav",
		"land": "res://assets/audio/land_pingpong.wav",
	},
}

## Which sport this hall is currently hosting. Set once, when the match is built.
var kit := &"badminton"
const APPLAUSE := "res://assets/audio/applause.mp3"
const GROAN := "res://assets/audio/groan.mp3"

## How loud each thing sits, in decibels. The crowd is deliberately well down: it is a
## bed to be felt rather than listened to, and a hall you have to talk over is a hall
## nobody can referee in.
const CROWD_DB := -19.0
const WHISTLE_DB := -5.0
const HIT_DB := -9.0
const REACTION_DB := -9.0

## How quickly the room's mood follows the umpire's. Slow on purpose — a hall does not
## turn on you between one rally and the next, it sours over a game.
const MOOD_SPEED := 0.35

## How many strikes can ring at once. A rally is one shuttle, but a smash and its
## landing can overlap, and cutting one off to start the other is worse than either.
const STRIKE_VOICES := 4

var _calm: AudioStreamPlayer
var _tense: AudioStreamPlayer
var _reaction: AudioStreamPlayer
var _whistle: AudioStreamPlayer
var _strikes: Array[AudioStreamPlayer3D] = []
var _next_strike := 0

var _mood := 0.0
var _wanted_mood := 0.0


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

func whistle() -> void:
	if _whistle.stream != null:
		_whistle.play()


## The ball being struck, at the racket rather than in the middle of your head.
func strike(where: Vector3, hard: bool) -> void:
	var path := _from_kit("hard" if hard else "soft")
	if not ResourceLoader.exists(path):
		return
	var voice := _strikes[_next_strike]
	_next_strike = (_next_strike + 1) % _strikes.size()
	voice.stream = load(path)
	# Set every time rather than once at build. The four players are shared, and the
	# line judge's call is louder than a contact — one shout would otherwise leave
	# whichever player it used turned up for the rest of the match.
	voice.volume_db = HIT_DB
	voice.global_position = where
	voice.play()


## The ball arriving, on whatever this sport is played on.
func landing(where: Vector3) -> void:
	var path := _from_kit("land")
	if not ResourceLoader.exists(path):
		return
	var voice := _strikes[_next_strike]
	_next_strike = (_next_strike + 1) % _strikes.size()
	voice.stream = load(path)
	voice.volume_db = HIT_DB
	voice.global_position = where
	voice.play()


## One sound out of this sport's kit, falling back to badminton's if it is not there.
func _from_kit(which: String) -> String:
	var chosen: Dictionary = KITS.get(kit, KITS[&"badminton"])
	var path := String(chosen.get(which, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return String(KITS[&"badminton"][which])
	return path


## A line judge calling a ball out, from where they are sitting rather than from the
## middle of your head. It is the only thing in a rally that comes from the corner of
## the court, and in tennis that is fourteen metres away and usually off the side of the
## screen — which is exactly why it needs a sound as well as a flag.
func judge_calls_out(where: Vector3) -> void:
	if not ResourceLoader.exists(JUDGE_OUT):
		return
	var voice := _strikes[_next_strike]
	_next_strike = (_next_strike + 1) % _strikes.size()
	voice.stream = load(JUDGE_OUT)
	voice.volume_db = JUDGE_DB
	voice.global_position = where
	voice.play()


## The hall's verdict on the call. Applause if it liked it, a groan if it did not — and
## nothing at all if the rally was too dull to have an opinion about, because a room
## that reacts to everything is a room that is telling you nothing.
func react(approving: bool) -> void:
	var path := APPLAUSE if approving else GROAN
	if not ResourceLoader.exists(path):
		return
	_reaction.stream = load(path)
	_reaction.volume_db = REACTION_DB
	_reaction.play()


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
