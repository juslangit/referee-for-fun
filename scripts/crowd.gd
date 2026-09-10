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
## `visibility` is how plainly the ball itself could be read — **not** whether the call
## was wrong. That distinction is the whole of a bug Luqman found by playing: this used
## to take visibility and the mood and nothing else, so a ball plainly out that the
## umpire correctly called out arrived here at 0.9 and the hall shouted "CHEAT!" at
## somebody who had just done the job perfectly. The docstring above this function
## claimed a correct call drew nothing. Nothing in the code said so, because the verdict
## was never passed in.
##
## `was_wrong` has no default on purpose. A default would have let this same call site,
## or a new one, quietly keep the old behaviour.
static func react_to_call(visibility: float, mood: Suspicion.Mood,
		was_wrong: bool) -> String:
	# The hall complains about calls it thinks were wrong. It has no complaint about one
	# that was right, however plain the ball was — that is just the job being done.
	if not was_wrong:
		return ""
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
## The hall coming round, after it had turned on you and you have put a run of calls
## together since.
##
## This is the only approving thing anybody in this game ever says, and it is carefully
## **not** a verdict on the call that triggered it. Every line here is about the umpire
## over the last few minutes — their eyes, their grip on the match — and none of them
## says a ball was in or out, which is the rule the whole file is built on. A crowd that
## confirmed individual calls would hand the player the one thing the game withholds.
##
## It only ever fires after the room has soured, which is what makes it worth anything.
## A hall that applauded every correct call would be a scoreboard.
const APPROVAL := [
	"\"That's more like it, ref!\"",
	"\"All right. He's found his eyes.\"",
	"the booing has stopped",
	"somebody near the front nods towards the chair",
	"a ripple of applause, and this time it is for you",
	"the RED coach sits back down",
	"the hall has gone back to watching the players",
]


static func react_to_recovery() -> String:
	return _pick(APPROVAL)


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


# --- what one person in the stands says -----------------------------------------

## The same reactions again, as things a single person actually says out loud.
##
## Everything above this line is the room described from the chair: scattered booing, a
## coach on his feet, the hall going quiet. None of it can go in a bubble over one
## person's head, because none of it is an utterance — a spectator captioned "scattered
## booing" reads as a bug. So each situation has a second bank of lines that are, and a
## bubble takes from here while the line under the HUD keeps describing the room.
##
## **The hard rule at the top of this file applies here with no exceptions.** Nobody in
## the stands may say whether the ball was in or out, however furious they are, because
## somebody who could see it and says so has handed the player the one thing the game
## exists to withhold. Read the banks below and every line is about the umpire — his
## eyes, his nerve, his honesty, how long he took — and never about the shuttle. The
## review lines are the single exception, for the same reason the narration's are: after
## a review there is nothing left to withhold.
##
## They are also written to be shouted across a hall rather than read off a page. Short,
## and most of them a question, because a hall that doubts an official asks him things.
const SAID_DOUBTFUL := [
	"\"Did he get that?\"",
	"\"What did he give there?\"",
	"\"Hm. Watch him.\"",
	"\"Did you see it? I didn't.\"",
	"\"He had to think about that one.\"",
]

const SAID_COMPLAINT := [
	"\"REF!\"",
	"\"Oh, come ON!\"",
	"\"Are you WATCHING this?\"",
	"\"Open your eyes, ref!\"",
	"\"That's twice now!\"",
	"\"Have a word with yourself!\"",
]

const SAID_HOSTILITY := [
	"\"CHEAT!\"",
	"\"WHO'S PAYING YOU?\"",
	"\"GET HIM OFF!\"",
	"\"You're a DISGRACE!\"",
	"\"We can all SEE you!\"",
	"\"Whose side are you ON?\"",
]

const SAID_IMPATIENCE := [
	"\"COME ON, REF!\"",
	"\"What is there to think about?\"",
	"\"Any day now!\"",
	"\"Make your MIND up!\"",
	"\"We haven't got all night!\"",
]

const SAID_CARD := [
	"\"FOR WHAT?!\"",
	"\"HE DIDN'T DO ANYTHING!\"",
	"\"You're JOKING!\"",
	"\"Put it AWAY!\"",
	"\"What was THAT for?\"",
]

## The only approving thing anybody says, and still not a verdict on any one call —
## the same care as the narration bank it sits beside.
const SAID_APPROVAL := [
	"\"That's more like it, ref!\"",
	"\"All right. He's found his eyes.\"",
	"\"See? He can do it.\"",
	"\"Fair enough, that.\"",
	"\"Better.\"",
]

const SAID_AMBIENT := {
	Suspicion.Mood.MURMURING: [
		"\"Keep an eye on him.\"",
		"\"Something's not right here.\"",
	],
	Suspicion.Mood.RESTLESS: [
		"\"He's at it again.\"",
		"\"Every time. Every single time.\"",
	],
	Suspicion.Mood.HOSTILE: [
		"\"How is he still in that chair?\"",
		"\"Nobody's here for the badminton now.\"",
	],
	Suspicion.Mood.WARNED: [
		"\"They're writing it all down.\"",
		"\"He's finished after tonight.\"",
	],
}

## Allowed to be certain, because the screen has already told everybody.
const SAID_OVERTURNED := [
	"\"THERE it is!\"",
	"\"We ALL saw that!\"",
	"\"Explain THAT one!\"",
]
const SAID_UPHELD := [
	"\"Fair enough, then.\"",
	"\"He got that one.\"",
	"\"Waste of a review.\"",
]


## What one spectator says about a call, chosen by the same thresholds as the narration
## so the shout and the line under it are always describing the same reaction.
static func said_about_call(visibility: float, mood: Suspicion.Mood,
		was_wrong: bool) -> String:
	if not was_wrong or visibility < NOTICE_THRESHOLD:
		return ""
	if visibility > 0.45 or mood >= Suspicion.Mood.HOSTILE:
		return _pick(SAID_HOSTILITY)
	if visibility > 0.22 or mood >= Suspicion.Mood.RESTLESS:
		return _pick(SAID_COMPLAINT)
	return _pick(SAID_DOUBTFUL)


## Another voice from the same hostile room, for when one is not enough.
##
## Only ever drawn from the hostility bank, because this is only ever asked for once the
## hall has made its mind up. A settled room that suddenly produced three simultaneous
## shouts would be saying something the mood does not support.
static func another_hostile_voice() -> String:
	return _pick(SAID_HOSTILITY)


static func said_about_delay(seconds: float) -> String:
	if Suspicion.hesitation_cost(seconds) <= 0.0:
		return ""
	return _pick(SAID_IMPATIENCE)


static func said_about_card(_red: bool) -> String:
	return _pick(SAID_CARD)


static func said_about_recovery() -> String:
	return _pick(SAID_APPROVAL)


static func said_about_review(overturned: bool) -> String:
	return _pick(SAID_OVERTURNED if overturned else SAID_UPHELD)


static func said_ambient(mood: Suspicion.Mood) -> String:
	if not SAID_AMBIENT.has(mood):
		return ""
	return _pick(SAID_AMBIENT[mood])


static func _pick(lines: Array) -> String:
	return lines[randi() % lines.size()]
