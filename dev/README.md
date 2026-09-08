# dev

Scenes that exist to look at the game rather than to be part of it.

None of these ship. Each one loads `scenes/match.tscn`, drives it from the outside, and
either prints numbers or saves a picture into `shots/`. They live here because a game
about millimetres cannot be checked by eye, and almost every real bug in this project was
found by one of them printing something that disagreed with what the screen appeared to
show — a shuttle landing a centimetre inside the floor, a crowd stretched five times its
height, a racket balanced across a player's fist, a whistle that measured 0 Hz.

Run one with:

    /Applications/Godot.app/Contents/MacOS/Godot --path . res://dev/_fairplay.tscn --quit-after 20000

The ones worth keeping in mind:

| scene | what it answers |
|---|---|
| `_fairplay` | Does an honest umpire get punished? Plays a match calling only the truth, then again calling every fault, and reports the suspicion each ends on. Set `UMPIRE=perfect` for the second. |
| `_aimcheck` | Can a player land a shuttle on a line? Reports the miss in millimetres against a line 40 mm wide. |
| `_flow` | Does the front end still reach a rally? Presses only the things a player can press. |
| `_teach` | The lesson, page by page, and whether a first-timer is shown it unasked. |
| `_menus` | The three front-of-game screens. |
| `_seat`, `_layout`, `_close` | The hall from the chair, from above, and up close. `TIER=0..2` picks the venue. |
| `_card`, `_courtmap` | Regenerate the artwork in `assets/ui/`. |
| `_beachflow` | Can a player reach a beach rally from the menu? Checks the sport card is there and playable, then drives the beach scene from the career screen to a call pressing only what a player can press. |
| `_sportshot` | The sport menu, now that more than one card is lit. |
| `_beachplay` | Beach volleyball's fair-play check: plays a match calling everything truthfully — line, touch and faults — and reports what the game charged for it. Must be zero. |
| `_ballaim` | Does the volleyball land where it was aimed? The beach answer to `_aimcheck`. |
| `_beachlook`, `_beachshot` | The sand court empty, and the match in progress from the stand. |
| `_serveheight` | How high a beach serve is when it reaches the net, per angle and depth. Written to answer why thirteen of the first seventeen rallies buried themselves in the tape. |
| `_sports` | One reputation, a ladder each: does a bad match at one sport follow you to another, does each ladder stay its own, and does a save from before the second sport still open? |
| `_rotation` | Does the serve come from the right service court and cross the right diagonal? 400 serves, 50 per score per side. |
| `_pressure` | The four reasons to lie: how often each turns up, what it does to a career, whether a grudge follows you into the next match, and — the one that matters — whether an honest umpire is still able to climb. |
| `_wrongcourt` | The service court error: is the mistake actually on the floor, do the two moments do the two different things the law says, can it ever move the score (it must not), and does watching for it cost nothing while ignoring it costs a little? |
| `_readme` | The six pictures in the top-level README, written into `docs/`. Kept as a scene so they can be retaken after the game changes rather than slowly becoming a photograph of a version nobody can play. |
| `_courtshot` | The same serve from the chair, lined up correctly and then with each side in the wrong box — the only way to check that the call is fair to ask for. |
| `_debt` | Does the umpire's own first visible mistake trap them? Checks both that the trap fires and that it never fires on a call the hall could not see. |
| `_props`, `_people` | Every downloaded model in a row, at the size it is used, so a model that arrived upside down is seen before three hundred of it are put in the stands. |

`shots/` is where they write. It is ignored by git — the pictures are output, not source.
