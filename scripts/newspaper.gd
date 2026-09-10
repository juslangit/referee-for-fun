class_name Newspaper
extends RefCounted

## The next morning's paper, for a night that went badly enough to be written about.
##
## Two sizes, and the difference between them is the point. Being taken off a match gets a
## few paragraphs on an inside page of the sport section, which is where a referee's bad
## night usually goes. A career that has ended makes the **front page** — which a referee
## almost never does, and which takes a great deal to earn.
##
## Written from plain facts and kept apart from the screen that prints it, so it can be
## checked for what it must never say without drawing anything. It never guesses at the
## umpire's pronouns, and the paper is made up: this game carries no real names.

const TITLE := "THE MORNING RALLY"

const DAYS := ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
const MONTHS := ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST",
	"SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
const NUMBERS := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight",
	"nine", "ten", "eleven", "twelve"]
const ORDINALS := ["", "first", "second", "third", "fourth", "fifth", "sixth", "seventh",
	"eighth", "ninth", "tenth"]


## The story for a night, or an empty dictionary if there is nothing to write.
##
## Every key in `f` is a plain fact:
##   sport          "BADMINTON"
##   venue          "District championship"
##   thrown_off     the tournament took the umpire off
##   walked_out     the umpire left the chair by choice
##   career_over    reputation gone, and nobody will appoint the umpire again
##   wrong, stolen  wrong calls, and how many of them decided the rally
##   helped         "RED" or "BLUE" if the wrong calls leaned one way, otherwise ""
##   mentioned      somebody had mentioned that very result before the match
##   matches        matches refereed in the whole career, this one included
##   removals       matches not finished, this one included
##   worst_truth    what really happened on the worst call, or ""
##   worst_called   what the umpire said about it, or ""
static func story(f: Dictionary) -> Dictionary:
	var front: bool = f.get("career_over", false)
	var walked: bool = f.get("walked_out", false)
	if not front and not walked and not f.get("thrown_off", false):
		return {}

	var sport := String(f.get("sport", "BADMINTON")).to_lower()
	var venue := String(f.get("venue", "the hall"))
	var wrong := int(f.get("wrong", 0))
	var stolen := int(f.get("stolen", 0))
	var helped := String(f.get("helped", ""))
	var mentioned: bool = f.get("mentioned", false) and helped != ""
	var matches := int(f.get("matches", 1))
	var removals := int(f.get("removals", 0))
	var truth := String(f.get("worst_truth", ""))
	var called := String(f.get("worst_called", ""))
	var at := "the " + venue.to_lower()

	var body: Array[String] = []

	# What happened last night.
	if front:
		var opening := "The umpire in charge of last night's %s match at %s has refereed for the last time." % [sport, at]
		if walked:
			opening += " The umpire left the chair before the finish and did not come back."
		elif f.get("thrown_off", false):
			opening += " The tournament took the umpire off before the finish."
		body.append(opening)
	elif walked:
		body.append("The umpire at last night's %s match at %s left the chair before the finish and did not come back." % [sport, at])
	else:
		body.append("The umpire at last night's %s match at %s was taken off before the finish." % [sport, at])

	# The calls.
	if wrong == 0:
		if front:
			body.append("Last night was not the worst of it. It was only the last of it.")
		elif walked:
			body.append("No call had been disputed. No reason was given.")
		else:
			body.append("Officials would not say what had prompted it.")
	elif wrong == 1:
		body.append("One call went against what actually happened%s." % (
			", and it decided the rally" if stolen >= 1 else ""))
	else:
		var decided := "%s of them deciding the rally" % count(stolen)
		if stolen == 0:
			decided = "though none of them decided a rally"
		elif stolen >= wrong:
			decided = "and every one of them decided the rally"
		body.append("%s calls went against what actually happened, %s." % [
			count(wrong).capitalize(), decided])

	# Which way they went.
	if helped != "" and wrong >= 2:
		var which := "Almost every one of them went %s's way." % helped.capitalize()
		if mentioned:
			which += " That, according to one source, was the result somebody had mentioned to the umpire before the match."
		else:
			which += " Nobody has been able to say why."
		body.append(which)
	elif wrong >= 3:
		body.append("They went both ways. \"Not bent,\" said one former official. \"Just bad at it.\"")

	# The worst of them.
	if truth != "":
		body.append("On the worst of them the replay was plain: %s. The call was %s." % [
			sentence(truth, false), called])

	# The career.
	if front:
		var career := "It ends a career of %d matches" % matches
		if removals > 0:
			career += ", %s of them unfinished" % count(removals)
		body.append(career + ".")
		body.append("Asked for a comment, the federation said only: \"We have all seen %s.\"" % (
			"the replays" if truth != "" else "enough"))
	else:
		if removals <= 1:
			body.append("It is the first match the umpire has not finished.")
		else:
			body.append("It is the %s match the umpire has not finished." % ordinal(removals))
		if walked:
			body.append("The chair was still empty when the hall was locked.")
		else:
			body.append("\"The appointment is under review,\" a spokesperson said.")

	return {
		"front_page": front,
		"title": TITLE,
		"date": next_morning(),
		"section": "FINAL EDITION" if front else "SPORT   ·   PAGE %d" % (31 + (matches * 7) % 19),
		"kicker": "CAREER OVER" if front else ("WALKED OUT" if walked else "TAKEN OFF"),
		"headline": _front_headline(f, helped, mentioned, stolen, truth, called, walked)
			if front else _inside_headline(venue, helped, wrong, walked),
		"standfirst": _standfirst(matches) if front else "",
		"body": body,
		"caption": "%s. The call: %s." % [sentence(truth, true), called] if truth != "" else "",
	}


static func _front_headline(_f: Dictionary, helped: String, mentioned: bool, stolen: int,
		truth: String, called: String, walked: bool) -> String:
	if mentioned:
		return "SOMEBODY MENTIONED A RESULT"
	if helped != "" and stolen >= 3:
		return "THE BEST PLAYER %s HAD WAS IN THE CHAIR" % helped
	if truth.begins_with("IT WAS OUT BY") or truth.begins_with("IT WAS IN BY"):
		return "%s. CALLED %s." % [truth.trim_prefix("IT WAS ").to_upper(), called]
	if walked:
		return "THE UMPIRE WHO WALKED AWAY"
	return "FINAL WHISTLE FOR THE UMPIRE NOBODY BELIEVED"


static func _inside_headline(venue: String, helped: String, wrong: int, walked: bool) -> String:
	if walked:
		return "UMPIRE WALKS OUT AT %s" % venue.to_upper()
	if helped != "" and wrong >= 2:
		return "UMPIRE TAKEN OFF AS CALLS GO %s'S WAY" % helped
	return "UMPIRE TAKEN OFF AT %s" % venue.to_upper()


static func _standfirst(matches: int) -> String:
	var how_many := count(matches).capitalize() if matches < NUMBERS.size() else str(matches)
	return "%s matches, and none to come. Nobody will appoint the umpire again." % how_many


## Tomorrow's date, because this is the paper the morning after.
static func next_morning() -> String:
	var day := Time.get_date_dict_from_unix_time(int(Time.get_unix_time_from_system()) + 86400)
	return "%s %d %s %d" % [DAYS[day["weekday"]], day["day"], MONTHS[day["month"] - 1], day["year"]]


static func count(n: int) -> String:
	return NUMBERS[n] if n >= 0 and n < NUMBERS.size() else str(n)


static func ordinal(n: int) -> String:
	return ORDINALS[n] if n > 0 and n < ORDINALS.size() else "%dth" % n


## A caption from the replay, turned into a sentence: lower case, with the two teams keeping
## their capitals. `capital` starts it with one.
static func sentence(text: String, capital: bool) -> String:
	var said := text.to_lower()
	said = RegEx.create_from_string("\\bred\\b").sub(said, "Red", true)
	said = RegEx.create_from_string("\\bblue\\b").sub(said, "Blue", true)
	if capital and said.length() > 0:
		said = said[0].to_upper() + said.substr(1)
	return said
