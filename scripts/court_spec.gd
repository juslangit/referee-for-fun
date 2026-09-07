class_name CourtSpec
extends RefCounted

## Official BWF badminton court dimensions, in metres.
##
## This file is the single source of truth for the court. The visual court is built
## from these numbers, and the in/out judgement is made from these numbers, so the
## line the player sees is exactly the line the game judges against. If those two
## ever disagreed, the whole game would be broken — you would be lying without
## meaning to.
##
## Axes: +Z runs down the length of the court, +X across its width, +Y is up.
## The net sits at z = 0, so the two halves are z > 0 and z < 0.

## Half the full court length. Full court is 13.40 m.
const HALF_LENGTH := 6.70

## Half the doubles width. Full doubles court is 6.10 m.
const HALF_WIDTH_DOUBLES := 3.05

## Half the singles width. Full singles court is 5.18 m.
const HALF_WIDTH_SINGLES := 2.59

## Distance from the net to the short service line.
const SHORT_SERVICE_LINE := 1.98

## Distance from the net to the doubles long service line.
const LONG_SERVICE_LINE_DOUBLES := 5.94

## Painted line width. Real courts use 40 mm.
const LINE_WIDTH := 0.04

## Net height at the centre, and at the posts. A real net sags slightly in the middle.
const NET_HEIGHT_CENTRE := 1.524
const NET_HEIGHT_POST := 1.55

## How far down the net hangs from its top tape.
const NET_DEPTH := 0.76

## The posts stand on the doubles sideline, whether or not singles is being played.
const POST_X := HALF_WIDTH_DOUBLES


## Was the shuttle in?
##
## In badminton a shuttle landing on the line is IN, and the court dimensions are
## measured to the outer edge of the painted line — so the boundary is exactly the
## nominal number, with nothing to add or subtract.
static func is_in(landing: Vector3, doubles := true) -> bool:
	var half_width := HALF_WIDTH_DOUBLES if doubles else HALF_WIDTH_SINGLES
	return absf(landing.x) <= half_width and absf(landing.z) <= HALF_LENGTH


## How far the shuttle was from the nearest boundary line, in metres.
## Positive means inside the court, negative means outside.
##
## This is the most important number in the game. It is not used to decide whether
## the shuttle was in — is_in() does that — it is used to decide how obvious the
## truth was. Calling a shuttle that missed by 2 cm is almost invisible. Calling one
## that missed by a metre is an outrage, and the suspicion system will price the two
## very differently.
static func margin(landing: Vector3, doubles := true) -> float:
	var half_width := HALF_WIDTH_DOUBLES if doubles else HALF_WIDTH_SINGLES
	var slack_x := half_width - absf(landing.x)
	var slack_z := HALF_LENGTH - absf(landing.z)

	# Outside on at least one axis: report the straight-line distance to the court.
	if slack_x < 0.0 or slack_z < 0.0:
		var overshoot := Vector2(maxf(0.0, -slack_x), maxf(0.0, -slack_z))
		return -overshoot.length()

	# Inside: report the distance to whichever line was closest to being missed.
	return minf(slack_x, slack_z)
