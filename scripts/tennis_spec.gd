class_name TennisSpec
extends RefCounted

## Official ITF tennis court dimensions, in metres.
##
## The same contract as the other three specs: the court the player looks at is built
## from these numbers and the in/out judgement is made from these numbers, so the line
## on the screen is the line the game judges against.
##
## Axes as everywhere else: +Z down the length, +X across, +Y up, net at z = 0.
##
## Tennis brings two things none of the others have.
##
## **A court that is two courts.** The singles lines are inside the doubles ones, and
## which pair is live depends on what is being played — so a ball landing in the
## tramlines is in for one match and out for another, off the same bounce.
##
## **A net that is not level.** It is 1.07 m at the posts and 0.914 m in the middle,
## because it hangs. Every other net in this game is a straight line.

## Half the full length. The court is 23.77 m end to end.
const HALF_LENGTH := 11.885

## Half the width, doubles and singles. 10.97 m and 8.23 m across.
const HALF_WIDTH_DOUBLES := 5.485
const HALF_WIDTH_SINGLES := 4.115

## How far the service line is from the net.
const SERVICE_LINE := 6.40

## Painted line width. The baseline may be up to 10 cm; everything else is 5.
const LINE_WIDTH := 0.05
const BASELINE_WIDTH := 0.10

## The net sags. 1.07 m where it is tied and 0.914 m in the middle, which is the height
## every shot down the middle of the court has to beat.
const NET_HEIGHT_POST := 1.07
const NET_HEIGHT_CENTRE := 0.914
const NET_DEPTH := 1.07

## The posts stand 0.914 m outside the doubles sideline.
const POST_X := HALF_WIDTH_DOUBLES + 0.914

## The run-back and side room a real court has around it.
const RUN_BACK := 6.40
const SIDE_ROOM := 3.66

## How close to the boundary still counts as on it. Same reasoning as everywhere else:
## far smaller than anything anybody could see, far larger than the error float
## arithmetic accumulates.
const LINE_TOLERANCE := 0.0001


## Was the ball in? `doubles` decides which pair of sidelines is live.
static func is_in(landing: Vector3, doubles := false) -> bool:
	var half_width := HALF_WIDTH_DOUBLES if doubles else HALF_WIDTH_SINGLES
	return (
		absf(landing.x) <= half_width + LINE_TOLERANCE
		and absf(landing.z) <= HALF_LENGTH + LINE_TOLERANCE
	)


## Whether a serve landed in the correct service box: past the net, short of the service
## line, and on the diagonal from the server. A serve is judged by the *singles*
## sidelines even in doubles, which is the detail everybody forgets.
static func is_a_good_serve(landing: Vector3, into: float, court: float) -> bool:
	if signf(landing.z) != signf(into):
		return false
	if absf(landing.z) > SERVICE_LINE + LINE_TOLERANCE:
		return false
	if absf(landing.x) > HALF_WIDTH_SINGLES + LINE_TOLERANCE:
		return false
	# The correct half of the service court, diagonally opposite the server.
	return signf(landing.x) == signf(court) or is_zero_approx(landing.x)


## How far from the nearest line, in metres. Positive inside, negative out.
static func margin(landing: Vector3, doubles := false) -> float:
	var half_width := HALF_WIDTH_DOUBLES if doubles else HALF_WIDTH_SINGLES
	var slack_x := half_width - absf(landing.x)
	var slack_z := HALF_LENGTH - absf(landing.z)
	if slack_x < 0.0 or slack_z < 0.0:
		var overshoot := Vector2(maxf(0.0, -slack_x), maxf(0.0, -slack_z))
		return -overshoot.length()
	return minf(slack_x, slack_z)


## How high the net is at a given point across the court.
##
## It hangs, so this is a curve rather than a number — and it is why a ball down the
## middle clears a lower net than one up the line, which is a real part of how tennis is
## played and the reason the shot solver has to ask rather than assume.
static func net_height_at(x: float) -> float:
	var across := clampf(absf(x) / POST_X, 0.0, 1.0)
	# A catenary is close enough to a parabola over this span, and a parabola is
	# something the rest of the game can reason about.
	return NET_HEIGHT_CENTRE + (NET_HEIGHT_POST - NET_HEIGHT_CENTRE) * across * across


## How far a serve was from the nearest line of the service box it was aimed into.
##
## Deliberately not the same as `margin`. A serve that lands a centimetre past the
## service line is a fault by a centimetre — and it is also five metres inside the
## baseline, so measuring it against the court would report it as the most obviously
## good ball of the match. The box has its own three lines and a serve is judged against
## those: the service line, the centre service line, and the singles sideline.
static func serve_margin(landing: Vector3, into: float, court: float) -> float:
	# Long, past the service line.
	var slack_long := SERVICE_LINE - absf(landing.z)
	# Wide, past the singles sideline.
	var slack_wide := HALF_WIDTH_SINGLES - absf(landing.x)
	# Into the wrong half of the service court, across the centre service line.
	var slack_centre := landing.x * signf(court)
	# In the wrong half of the court altogether: it never crossed the net.
	if signf(landing.z) != signf(into):
		return -(absf(landing.z) + SERVICE_LINE)

	if slack_long < 0.0 or slack_wide < 0.0 or slack_centre < 0.0:
		var out_by := Vector2(
			maxf(0.0, -slack_wide) + maxf(0.0, -slack_centre),
			maxf(0.0, -slack_long))
		return -out_by.length()
	return minf(slack_long, minf(slack_wide, slack_centre))
