# dev

Scenes that exist to look at the game rather than to be part of it.

None of these ship. Each one loads a game scene, drives it from the outside, and either
prints numbers or saves a picture. They live here because a game about millimetres cannot
be checked by eye, and almost every real bug in this project was found by one of them
printing something that disagreed with what the screen appeared to show — a shuttle
landing a centimetre inside the floor, a crowd stretched five times its height, a racket
balanced across a player's fist, a whistle that measured 0 Hz.

They are sorted by what they do with what they find:

| folder | what is in it |
|---|---|
| `checks/` | **84 scenes that print numbers.** Everything with an answer that can be wrong: fair play, aim, scoring, rotation, pricing, whether a match can finish. These are the ones to run after changing anything. |
| `looks/` | **48 scenes that take pictures.** The hall from the chair, a lesson page, a pose held at the frame that matters. Judged by eye, because some things only a person can see. |
| `shots/` | Where the pictures land. Ignored by git — output, not source. |

Run one with:

    /Applications/Godot.app/Contents/MacOS/Godot --path . res://dev/checks/_fairplay.tscn --quit-after 20000

And the whole of `checks/` will tell you whether the game still works. `_selfcheck`
answers the narrower question of whether every scene in both folders still *loads*, which
is what catches a move like this one going wrong.

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
| `_soundwiring` | Is the room audible in every sport? Checks the crowd bed follows suspicion and that the ball is heard being struck and landing. Both volleyballs shipped without any of it. |
| `_servelaw` | Can a serve struck below 1.15 m still clear the net and reach the service box, and does each of the three service faults price correctly called, missed and invented? |
| `_worstcalls` | Does the end-of-match replay keep the right calls, show all of them, and give way to the result — and does the paper come out when, and only when, the umpire was taken off or the career ended? All five sports, plus every combination of facts the paper can print, checked for pronouns and trademarks. Puts the career save back afterwards. |
| `_replayshot` | Pictures of the replay and the paper at full size, in `looks/`. `SPORT=badminton\|beach\|indoor\|tennis\|table_tennis`, `TIER=`, `PAGE=front` for a career that ends. |
| `_badmintonreview` | Does a badminton review finish? Asks for one at the national championship directly. |
| `_fps` | How fast does every sport run, at the bottom and top of its ladder, and what does each expensive thing cost? Windowed, vsync off, real rallies. `ONLY=badminton`, `SECONDS=6`, `TRIALS=lamp,upscale` to run only the trials whose names contain those words, `SHOTS=1` to keep a picture of each. In `looks/`. |
| `_budget` | Where the triangles are: every visible model in a venue by triangles times copies, and which cast shadows. Found the 7,404-triangle stadium seat that held badminton to twenty frames a second. `SPORT=`, `TIER=`. In `looks/`. |
| `_lessonback` | Can a player read the rules again, in every sport? Checks the ladder offers HOW TO REFEREE, that it opens that sport's lesson, and that GOT IT comes back to the ladder. |
| `_endings` | Can a match in each sport actually finish, and how many rallies does the shortest one take? Every other harness stops after a fixed count, so the ending screen and the career fold-in had never been reached in either volleyball. |
| `_faultkey` | Does F open the fault panel and complete a call, in both volleyballs? Written after both prompts turned out to advertise a key nothing was listening to. |
| `_indoorbugs` | Three reported faults at the venue a new career actually starts on: are there line judges, are the six in position before the first serve, and does a rally follow every whistle? |
| `_cover` | Do the volleyball line judges actually give an official cover? Prices the same wrong call three ways — nobody spoke, the judge agreed, the judge disagreed. Found the verdict-enum mismatch. |
| `_sets` | Is the last set shorter than the rest? Drives each sport's match to its decider and prints what every set was played to. |
| `_tennislook` | The tennis court empty, from the chair and from above: do the two sets of sidelines read as one court, and does the net look like it sags? |
| `_tennisscore` | Does tennis count the way tennis counts? A game, deuce and advantage, a set won by two, a tiebreak at six-all, and a match. Arithmetic, checked before anything was built on it. |
| `_rotate` | Does the rotation rotate the way volleyball rotates? Six turns, who serves, and whether the legality test catches the arrangements it should. Pure arithmetic, checked before anything was built on it. |
| `_indoorrules` | The four positional calls, made, missed and invented, one at a time. Waiting for a rotation fault to come up on its own takes forty rallies; this builds each by hand. |
| `_indoorplay` | Indoor's fair-play check. `WATCHING=no` gives a referee who judges the ball perfectly and never looks at the lineup. |
| `_indoorshot` | Twelve players, two liberos and the attack lines, from the stand. |
| `_beachreview` | Does the beach challenge fire, on what, and what does being caught cost? An honest referee must never be punished by it and a liar must be afraid of it. |
| `_beachteach` | The beach lesson, and a review on screen. |
| `_clickcheck` | Is the mouse free on every screen that has a button on it, and what visible control is sitting over the menu? Written after buttons before a beach match turned out to be drawn, lit and completely dead. |
| `_vbposes` | The six volleyball clips, one character each, held at the moment that matters. The poses are authored blind as numbers in a Python file, so this is the only way to find out whether "both arms locked in front" produced that. |
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

Every one of these writes its pictures into `shots/`. Twenty-one of them used to write
into the project root instead, which left a dozen large PNGs sitting next to
`project.godot` — tidied on 2026-09-09, and the reason the folder split happened at all.
