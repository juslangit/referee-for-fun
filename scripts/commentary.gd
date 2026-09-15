class_name Commentary
extends Node

## The two voices on the broadcast, and the slow way they make their minds up about you.
##
## *Courtside Live* covers every rung of every ladder, from a school hall's livestream to
## a world final, so the same two people follow the umpire the whole way up. Dan Mercer
## calls the play and likes everybody. Aisha Karim umpired internationally for twenty years
## and watches the chair more than the court. Luqman chose text captions, commentators
## who know only what the hall knows, and a memory that lasts the whole career
## (2026-09-15).
##
## **The rule of `Crowd` applies here with no exceptions: nobody on the broadcast may say
## whether a ball was in or out, or whether a call was right.** A commentator who could
## see it and said so would hand the umpire the one thing the game withholds. So they
## react on exactly the crowd's triggers — a wrong call only as far as the hall could see
## it, a silence, an overrule, a card — and everything they say is about the person in the
## chair. After a review they may be certain, for the reason the crowd may: the screen has
## just told the whole building. `dev/checks/_commentary` reads every line for words that
## would break this.
##
## Their memory is the career's own history — the last venue, whether you were taken off
## it, your reputation — which is all public record. Nothing new is saved.

signal spoke(speaker: String, line: String)

enum Tone {
	## They like you, or have no reason not to.
	WARM,
	## Something has caught Aisha's eye.
	WATCHFUL,
	## They have stopped giving you the benefit of the doubt.
	DOUBTING,
	## They are talking about you the way the paper will.
	DAMNING,
}

const DAN := "DAN MERCER"
const AISHA := "AISHA KARIM"
const CHANNEL := "COURTSIDE LIVE"

## Nobody talks over anybody. A line stays up for about as long as it takes to read.
const SECONDS_PER_CHARACTER := 0.055
const SHORTEST_LINE := 3.0
const PAUSE_BETWEEN_LINES := 0.5

## How long the broadcast stays quiet before it will fill a gap between points, and how
## often it takes the chance. A commentary that talked over every rally would bury the
## few lines that matter.
const QUIET_BEFORE_SMALL_TALK := 14.0
const SMALL_TALK_CHANCE := 0.35
## A silence or an overrule is remarked on this often. A call the hall saw is always.
const REMARK_CHANCE := 0.6

## How far ahead of itself the broadcast will queue. Anything less important than a card,
## a review, a warning or the opening is simply dropped when somebody is already talking.
const QUEUE_LIMIT := 3

enum Priority { SMALL_TALK, REMARK, NEWS }

var ui: RefereeUI

## What they thought of you walking in, which a match can only make worse — or, once the
## room has come round, a step better.
var base_tone := Tone.WARM
var official := "umpire"

var _context := {}
var _queue: Array = []
var _line_left := 0.0
var _quiet_for := 0.0
var _speaking := false
## The breath between one line and the next, counted down rather than awaited, so a match
## freed in the middle of it has nothing left waiting to run.
var _gap_left := 0.0


# --- what they already know -----------------------------------------------------

## What they make of you before a ball is struck, from the record alone.
static func tone_from_career(career: Career) -> Tone:
	if career == null or career.history.is_empty():
		return Tone.WARM
	var last: Dictionary = career.history[0]
	if bool(last.get("removed", false)) or career.reputation < 0.5:
		return Tone.DOUBTING
	if career.reputation < 0.8 or career.times_removed > 0:
		return Tone.WATCHFUL
	return Tone.WARM


## What they sound like now: whichever is worse of what they walked in thinking and what
## the hall is telling them.
static func tone_for(base: Tone, mood: Suspicion.Mood) -> Tone:
	var from_the_room := Tone.WARM
	match mood:
		Suspicion.Mood.MURMURING: from_the_room = Tone.WATCHFUL
		Suspicion.Mood.RESTLESS: from_the_room = Tone.DOUBTING
		Suspicion.Mood.HOSTILE, Suspicion.Mood.WARNED: from_the_room = Tone.DAMNING
	return maxi(base, from_the_room) as Tone


## Which opening the record calls for.
static func opening_for(career: Career, venue_name: String, sport_name: StringName) -> String:
	if career == null or career.history.is_empty():
		return "first"
	var last: Dictionary = career.history[0]
	if bool(last.get("removed", false)):
		return "removed_last_time"
	if career.reputation < 0.5:
		return "low_reputation"
	# There is no demotion anywhere on a ladder, so a different venue in the same sport
	# is a promotion.
	if String(last.get("sport", "")) == String(sport_name) \
			and String(last.get("venue", "")) != venue_name:
		return "promoted"
	if career.reputation >= 0.85 and career.matches_refereed >= 3:
		return "good_record"
	return "ordinary"


static func official_for(sport_name: StringName) -> String:
	if sport_name == Career.BEACH or sport_name == Career.INDOOR:
		return "referee"
	return "umpire"


# --- the lines --------------------------------------------------------------------
#
# Each entry is an exchange: one or more [speaker, line] pairs said in order. {official}
# is "umpire" or "referee", {authority} whoever comes out to the chair; {venue},
# {last_venue} and {matches} come from the career.

const OPENING := {
	"first": [
		[[DAN, "Welcome to {venue}. A new face in the chair tonight."],
		 [AISHA, "First match on the circuit. Nobody knows anything about this {official} yet, which is exactly how an {official} should start."]],
		[[DAN, "We're live from {venue}, and there's an {official} here we've never seen before."],
		 [AISHA, "Then let's hope we don't notice them."]],
	],
	"promoted": [
		[[DAN, "Tonight at {venue}, a familiar {official} stepping up from {last_venue}."],
		 [AISHA, "Bigger room, more people watching. The job doesn't change. The pressure does."]],
		[[DAN, "Our {official} has come up from {last_venue}. Quite a jump."],
		 [AISHA, "They earned the promotion. Now they have to keep it."]],
	],
	"removed_last_time": [
		[[DAN, "Welcome to {venue}. And, er, a name in the chair some of you will remember."],
		 [AISHA, "Taken off at {last_venue}. I'm surprised they've been given another one so soon."]],
		[[DAN, "We should mention how this {official}'s last match ended."],
		 [AISHA, "Escorted off at {last_venue}. Every call tonight gets looked at twice. Rightly."]],
	],
	"low_reputation": [
		[[DAN, "Live from {venue}, with an {official} who has had a difficult run."],
		 [AISHA, "{matches} matches, and people have started talking. I'll be watching the chair."]],
		[[DAN, "Our {official} tonight comes with something of a reputation."],
		 [AISHA, "Not the kind you want. Let's see what they do with the benefit of the doubt."]],
	],
	"good_record": [
		[[DAN, "Tonight at {venue}, one of the steadiest {official}s on the circuit."],
		 [AISHA, "{matches} matches and hardly a murmur. You don't notice good officials. That's the compliment."]],
		[[DAN, "A safe pair of hands in the chair tonight."],
		 [AISHA, "Quiet, quick, consistent. I wish I'd been that boring at their age."]],
	],
	"ordinary": [
		[[DAN, "Good evening from {venue}. The players are ready, and so is the {official}."],
		 [AISHA, "{matches} matches in. Solid enough. Let's have a clean one."]],
		[[DAN, "We're under way shortly at {venue}."],
		 [AISHA, "Nothing on this {official}'s record to worry about. Nothing to write home about either."]],
	],
}

## A call the hall reacted to, by how badly the broadcast now thinks of the chair. There
## is no WARM bank: a call anybody noticed has already cost the warmth.
const CALL := {
	Tone.WATCHFUL: [
		[[DAN, "Hm. A few heads turning in the crowd."], [AISHA, "The {official} will have felt that. The hall wasn't sure."]],
		[[AISHA, "I'd like to see that one again from the chair's side."]],
		[[DAN, "Some muttering there."], [AISHA, "Muttering is how it starts."]],
		[[AISHA, "The players are looking up at the chair. Never a good sign."]],
	],
	Tone.DOUBTING: [
		[[DAN, "Oh, they did NOT like that."], [AISHA, "And that's twice now the room has gone the same way."]],
		[[AISHA, "I've sat in that chair. When a whole hall reacts like that, you've lost them."]],
		[[DAN, "The bench is up."], [AISHA, "They're entitled to ask the question. Look at the {official}'s body language."]],
		[[AISHA, "Every tight one seems to be going one way tonight. I'm only saying what the crowd is saying."]],
	],
	Tone.DAMNING: [
		[[DAN, "The whole place is on its feet."], [AISHA, "I have never seen an {official} lose a room this fast."]],
		[[AISHA, "I'm struggling to find a charitable way to describe this."]],
		[[DAN, "I don't quite know what to say, Aisha."], [AISHA, "Then let me. Somebody from the federation should be watching this."]],
		[[AISHA, "At some point it stops being a bad night and becomes a pattern."]],
	],
}

## Standing there saying nothing.
const DELAY := {
	Tone.WARM: [
		[[DAN, "Taking a moment over that one."], [AISHA, "Better slow than sorry."]],
		[[AISHA, "No harm in a second look."]],
	],
	Tone.WATCHFUL: [
		[[DAN, "Still waiting on the call."], [AISHA, "The longer you wait, the more people wonder what you're deciding."]],
	],
	Tone.DOUBTING: [
		[[AISHA, "That's a long time to decide something you either saw or didn't."]],
		[[DAN, "The slow clap's started."], [AISHA, "And the {official} has earned it."]],
	],
	Tone.DAMNING: [
		[[AISHA, "What is there to think about, unless it's which answer you'd prefer?"]],
	],
}

## Contradicting the line judge, where the hall had no complaint about the call itself.
const OVERRULE := {
	"light": [
		[[DAN, "The {official} overrules the line judge."], [AISHA, "That takes nerve. You'd better be certain."]],
		[[AISHA, "Overruled. The line judge won't enjoy that, but it's the {official}'s call."]],
	],
	"heavy": [
		[[DAN, "Overruled again."], [AISHA, "Two officials disagreeing in public, and the chair always wins. Interesting."]],
		[[AISHA, "The line judge is looking straight at the chair. I would be too."]],
	],
}

## The room coming round, which is the only thing that softens them.
const RECOVERY := [
	[[DAN, "Things have calmed down in here."], [AISHA, "A few clean ones in a row. That's how you get a hall back."]],
	[[AISHA, "Credit where it's due. The {official} has steadied this."]],
	[[DAN, "The crowd's gone back to watching the players."], [AISHA, "Which is all an {official} ever wants."]],
]

const CARD := [
	[[DAN, "A CARD! For what?"], [AISHA, "I've watched it back in my head and I have nothing."]],
	[[AISHA, "I'd love to hear the explanation for that one. So would the bench."]],
	[[DAN, "Up goes the card, and the coach is beside himself."], [AISHA, "Cards are for things people can see."]],
]

## After a review the screen has told everybody, so they may say what it showed.
const REVIEW_OVERTURNED := [
	[[DAN, "And the review OVERTURNS it."], [AISHA, "That is the one thing an {official} cannot hide from."]],
	[[AISHA, "The screen doesn't have a favourite. That call was wrong, and everyone here just watched it."]],
	[[DAN, "Overturned!"], [AISHA, "Embarrassing. The kind of thing people remember at appointment time."]],
]
const REVIEW_UPHELD := [
	[[DAN, "The call stands."], [AISHA, "Good call from the chair. The challenge wasted."]],
	[[AISHA, "Upheld. The {official} had that exactly right."]],
	[[DAN, "Review says the {official} got it."], [AISHA, "That buys a little trust back."]],
]

const WARNING := [
	[[DAN, "The {authority} is walking over to the chair."], [AISHA, "That's a formal warning in all but name. One more like that and it's over."]],
	[[AISHA, "When the {authority} walks over to the chair, you are not being asked how your evening is going."]],
]

## Filling a gap between points.
const SMALL_TALK := {
	Tone.WARM: [
		[[DAN, "Lovely atmosphere here tonight."], [AISHA, "And a quiet chair. That's how it should be."]],
		[[AISHA, "You haven't heard me mention the {official} much. That's deliberate."]],
		[[DAN, "Good rhythm to this match."], [AISHA, "Officials set the rhythm more than people think."]],
	],
	Tone.WATCHFUL: [
		[[AISHA, "I'm keeping half an eye on the chair tonight. Just a feeling."]],
		[[DAN, "The crowd's a little edgy."], [AISHA, "They've noticed something. They're not sure what yet."]],
	],
	Tone.DOUBTING: [
		[[AISHA, "The players have stopped trusting the chair. You can see them look up after every rally."]],
		[[DAN, "Tense in here."], [AISHA, "That's not the badminton. That's the {official}."]],
		[[AISHA, "{matches} matches in and this is the night people will talk about."]],
	],
	Tone.DAMNING: [
		[[DAN, "Nobody's watching the players any more."], [AISHA, "No. They're watching the chair, and so am I."]],
		[[AISHA, "I'd be amazed if this {official} gets another appointment after tonight."]],
		[[DAN, "Hard to call this a contest."], [AISHA, "It's a contest. It's just not between the players."]],
	],
}

## The last word, quoted on the result screen.
const LAST_WORD := {
	"clean": [
		"\"A match nobody will remember the {official} for. That's the highest praise I have.\"",
		"\"Quiet, fair, finished. Well done.\"",
	],
	"rough": [
		"\"They got to the end. I'm not sure that's the same as getting through it.\"",
		"\"There'll be questions about tonight, and I don't think they'll all have answers.\"",
	],
	"removed": [
		"\"Taken off in front of everyone. In twenty years I saw it happen twice.\"",
		"\"The match went on without them. That tells you everything.\"",
	],
}


# --- during a match -----------------------------------------------------------------

func open_match(career: Career, sport_name: StringName, venue_name: String) -> void:
	official = official_for(sport_name)
	base_tone = tone_from_career(career)
	var last_venue := ""
	var matches := 0
	if career != null:
		matches = career.matches_refereed
		if not career.history.is_empty():
			last_venue = String(career.history[0].get("venue", ""))
	_context = {
		"official": official,
		# Who comes out to the chair when it goes wrong. Badminton's banner says so.
		"authority": "tournament referee" if sport_name == Career.BADMINTON else "match referee",
		"venue": _spoken(venue_name),
		"last_venue": _spoken(last_venue),
		"matches": str(matches),
	}
	# A sport with no badminton in it should not be told about "the badminton".
	if sport_name != Career.BADMINTON:
		_context["sport_noun"] = "the match"
	_queue.clear()
	_line_left = 0.0
	_gap_left = 0.0
	_quiet_for = 0.0
	_speaking = false
	_say(_pick(OPENING[opening_for(career, venue_name, sport_name)]), Priority.NEWS)


## What they make of one call. The arguments are what the hall itself was handed, and the
## thresholds are the hall's own (`Crowd.react_to_call`), so the broadcast never reacts to
## anything the room did not.
func on_call(visibility: float, mood: Suspicion.Mood, was_wrong: bool,
		seconds_to_call: float, overruled: bool, came_round: bool) -> void:
	if came_round:
		base_tone = maxi(Tone.WARM, base_tone - 1) as Tone
		_say(_pick(RECOVERY), Priority.REMARK)
		return

	var tone := tone_for(base_tone, mood)
	if was_wrong and visibility >= Crowd.NOTICE_THRESHOLD:
		var at_least := Tone.WATCHFUL
		if visibility > 0.45 or mood >= Suspicion.Mood.HOSTILE:
			at_least = Tone.DAMNING
		elif visibility > 0.22 or mood >= Suspicion.Mood.RESTLESS:
			at_least = Tone.DOUBTING
		_say(_pick(CALL[maxi(tone, at_least)]), Priority.REMARK)
		return

	if randf() >= REMARK_CHANCE:
		return
	if overruled:
		_say(_pick(OVERRULE["heavy" if tone >= Tone.DOUBTING else "light"]), Priority.REMARK)
	elif Suspicion.hesitation_cost(seconds_to_call) > 0.0:
		_say(_pick(DELAY[tone]), Priority.REMARK)


func on_card() -> void:
	_say(_pick(CARD), Priority.NEWS)


func on_review(overturned: bool) -> void:
	_say(_pick(REVIEW_OVERTURNED if overturned else REVIEW_UPHELD), Priority.NEWS)


func on_warning() -> void:
	_say(_pick(WARNING), Priority.NEWS)


## A gap between points, which they fill only when they have been quiet a while.
func between_points(mood: Suspicion.Mood) -> void:
	if _speaking or _quiet_for < QUIET_BEFORE_SMALL_TALK or randf() >= SMALL_TALK_CHANCE:
		return
	_say(_pick(SMALL_TALK[tone_for(base_tone, mood)]), Priority.SMALL_TALK)


## Aisha's verdict on the night, for the result screen.
func last_word(removed: bool, mood: Suspicion.Mood) -> String:
	var kind := "removed" if removed else (
		"clean" if mood <= Suspicion.Mood.MURMURING else "rough")
	var lines: Array = LAST_WORD[kind]
	var line := String(lines[randi() % lines.size()])
	return "%s   — %s, %s" % [_fill(line), _title_case(AISHA), _title_case(CHANNEL)]


func stop() -> void:
	_queue.clear()
	_speaking = false
	_line_left = 0.0
	_gap_left = 0.0
	if ui != null:
		ui.hide_commentary()


# --- saying it --------------------------------------------------------------------

func _say(exchange: Array, priority: Priority) -> void:
	if exchange.is_empty():
		return
	if _speaking:
		if priority != Priority.NEWS or _queue.size() >= QUEUE_LIMIT * 2:
			return
		for pair in exchange:
			_queue.append(pair)
		return
	for pair in exchange:
		_queue.append(pair)
	_next_line()


func _next_line() -> void:
	if _queue.is_empty():
		_speaking = false
		_quiet_for = 0.0
		if ui != null:
			ui.hide_commentary()
		return
	var pair: Array = _queue.pop_front()
	var line := _fill(String(pair[1]))
	_speaking = true
	_line_left = maxf(SHORTEST_LINE, line.length() * SECONDS_PER_CHARACTER)
	if ui != null:
		ui.show_commentary(CHANNEL, String(pair[0]), line)
	spoke.emit(String(pair[0]), line)


func _process(delta: float) -> void:
	# Read at the speed people read, not the speed of the match: a landing in slow motion
	# must not hold a caption up three times as long.
	var real := delta / maxf(0.01, Engine.time_scale)
	if _gap_left > 0.0:
		_gap_left -= real
		if _gap_left <= 0.0:
			_next_line()
		return
	if not _speaking:
		_quiet_for += real
		return
	_line_left -= real
	if _line_left > 0.0:
		return
	if ui != null:
		ui.hide_commentary()
	if _queue.is_empty():
		_speaking = false
		_quiet_for = 0.0
	else:
		_gap_left = PAUSE_BETWEEN_LINES


func _fill(line: String) -> String:
	var out := line
	for key in _context:
		out = out.replace("{%s}" % key, String(_context[key]))
	# "an umpire" but "a referee".
	out = out.replace("an referee", "a referee").replace("An referee", "A referee")
	if _context.has("sport_noun"):
		out = out.replace("the badminton", String(_context["sport_noun"]))
	return out


## "International final" as it is said aloud: "the international final".
static func _spoken(venue_name: String) -> String:
	if venue_name.is_empty():
		return ""
	return "the " + venue_name.to_lower()


static func _title_case(caps: String) -> String:
	return " ".join(Array(caps.split(" ")).map(func(w: String) -> String:
		return w.substr(0, 1) + w.substr(1).to_lower()))


static func _pick(options: Array) -> Array:
	if options.is_empty():
		return []
	return options[randi() % options.size()]
