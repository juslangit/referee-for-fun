class_name Crowd
extends RefCounted

## What the hall says, and the only way the player ever learns they are in trouble.
##
## There is one hard rule in this file, and the game does not work without it:
## **nothing here may ever say whether the shuttle was in or out.** A crowd shouting
## "that was out!" would be handing the player the answer, and the answer is the one
## thing they are not allowed to have. So every line is about the umpire — their
## eyesight, their honesty, their competence — and never about the shuttle.
##
## The lines are also only triggered by how *visible* a wrong call was. A lie nobody
## could see gets silence. That silence is not the crowd being fooled; it is the
## crowd genuinely not knowing, same as the player.

## How visible a single call has to be before anyone reacts to it at all.
const NOTICE_THRESHOLD := 0.12

## Muttering that follows a call the hall did not like, but is not sure about.
const DOUBTFUL := [
	"a few people look at each other",
	"someone near the back says something",
	"a low murmur runs along the near side",
	"the RED coach leans over and says something to his bench",
]

## Open complaint.
const COMPLAINT := [
	"\"REF!\"",
	"\"Oh, come ON!\"",
	"scattered booing",
	"a player turns and stares at the chair",
	"\"Are you WATCHING this?\"",
]

## The hall has made its mind up.
const HOSTILITY := [
	"\"CHEAT!\"",
	"sustained booing from both ends",
	"a coach is on his feet, pointing at you",
	"\"WHO'S PAYING YOU?\"",
	"something lands on the court",
	"both benches are shouting at once",
]

## What the hall does while the umpire stands there saying nothing.
const IMPATIENCE := [
	"somebody starts a slow clap",
	"\"COME ON, REF!\"",
	"the hall is waiting",
	"a player spreads their arms at the chair",
	"\"What is there to think about?\"",
]

## What happens when the umpire produces a card nobody was expecting.
const CARD_UPROAR := [
	"the whole hall is on its feet",
	"\"FOR WHAT?!\"",
	"the bench is halfway onto the court",
	"a coach is being held back",
	"\"HE DIDN'T DO ANYTHING!\"",
]

## Ambient pressure between rallies, once things have gone bad.
const AMBIENT := {
	Suspicion.Mood.MURMURING: [
		"the hall has gone quiet in a way it was not before",
		"people are watching you instead of the players",
	],
	Suspicion.Mood.RESTLESS: [
		"the booing starts before you have even called it",
		"a coach has not sat down for three rallies",
	],
	Suspicion.Mood.HOSTILE: [
		"nobody is watching the badminton any more",
		"the crowd counts every second you take to decide",
		"a steward has moved to stand near your chair",
	],
	Suspicion.Mood.WARNED: [
		"the tournament referee is watching from the side of the court",
		"every call you make now is being written down",
	],
}


## What the hall says immediately after a call, or an empty string for silence.
##
## `visibility` is how plainly wrong the call looked, not whether it was wrong. An
## invisible lie draws nothing, and a genuinely correct call that happened to look
## odd draws nothing either — the hall only reacts to what it can see.
static func react_to_call(visibility: float, mood: Suspicion.Mood) -> String:
	if visibility < NOTICE_THRESHOLD:
		return ""

	# Once the hall is already hostile, it reacts to far less.
	var loud := visibility > 0.45 or mood >= Suspicion.Mood.HOSTILE
	var pointed := visibility > 0.22 or mood >= Suspicion.Mood.RESTLESS

	if loud:
		return _pick(HOSTILITY)
	if pointed:
		return _pick(COMPLAINT)
	return _pick(DOUBTFUL)


## What the hall says about a call that took a while. Empty if it was quick enough
## that nobody noticed.
## What the hall says once a review has answered the question for it.
##
## These are the only crowd lines in the game allowed to be certain about anything. Every
## other line is careful never to say whether the shuttle was in or out (see D-009) —
## because the crowd saying so would hand the player the answer the game is built on
## withholding. After a review there is nothing left to withhold: everyone in the
## building has just watched it on a screen, the umpire included.
const OVERTURNED := [
	"the whole hall saw that, and so did you",
	"the screen does not blink",
	"they are not booing the players",
	"a thousand people just learned something about you",
]
const UPHELD := [
	"the screen agrees with you, this time",
	"somebody has just wasted a review",
	"a small nod from the chair opposite",
	"they will think twice before asking again",
]


static func react_to_review(overturned: bool) -> String:
	return _pick(OVERTURNED if overturned else UPHELD)


static func react_to_delay(seconds: float) -> String:
	if Suspicion.hesitation_cost(seconds) <= 0.0:
		return ""
	return _pick(IMPATIENCE)


## What the hall makes of a card. There is no quiet version of this.
static func react_to_card(red: bool) -> String:
	if red:
		return _pick(CARD_UPROAR)
	return _pick(COMPLAINT if randf() < 0.5 else CARD_UPROAR)


## Something for the hall to do between rallies, once it has stopped trusting you.
static func ambient(mood: Suspicion.Mood) -> String:
	if not AMBIENT.has(mood):
		return ""
	return _pick(AMBIENT[mood])


static func _pick(lines: Array) -> String:
	return lines[randi() % lines.size()]
