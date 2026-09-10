# Where every sound came from

Everything here is **CC0** — public domain, no credit legally required and no licence to
carry into a build. It is written down anyway, because a reader should not have to
wonder which files in a repository are safe to ship.

Fetched with the `sfx` CLI. The download folders `freesound/` and `packs/` are **not in
the repository** — carrying 264 Kenney impact sounds to use one of them is the same
mistake as carrying the Meshy intermediates — so the files in *this* folder are the ones
the game loads, copied up and renamed to say what they are for.

To fetch the originals again:

    sfx get 710041     # tennis ball hit
    sfx get 816991     # volleyball spike
    sfx get 788264     # tennis ball bouncing
    sfx get 854616     # sand footstep
    sfx pack impact-sounds   # Kenney, for footstep_wood_000.ogg

## Shared

Replaced wholesale on 2026-09-09. The first set were placeholders and sounded it: a
whistle nobody would blow, a bed obviously eight seconds long, and applause with no room
in it.

| File | What it is | Source |
|---|---|---|
| `whistle.mp3` | the umpire's whistle | Referee whistle sound by Rosa-Orenes256, CC0 |
| `crowd_calm.mp3` | the hall when it is settled | Small Crowd Walla by IENBA, CC0 |
| `crowd_tense.mp3` | the hall when it is not | Norwegian football match ambience by Vogyik, CC0 |
| `applause.mp3` | the room liking a call | Crowd Cheer by FoolBoyMedia, CC0 |
| `groan.mp3` | the room not liking one | Crowd Groans by ShangusBurger, CC0 |
| `judge_out.mp3` | a line judge calling a ball out | Displeasure - No by Sadiquecat, CC0 |

**`judge_out.mp3` is a stand-in.** There is no CC0 recording anywhere of a person saying
the word "out", so this is a short, curt male vocal that reads as a call against at the
distance a line judge sits. Only OUT is ever played — a judge who thought the ball was
good signals with their hands and says nothing, which is what really happens and what
keeps the shout meaning one thing. A real "OUT!" is one `sfx make` away if
`ELEVENLABS_API_KEY` is ever put in `~/.claude/.env`.

## Per sport

The sports used to share one set of eight files, so a shuttlecock landing was also a
volleyball hitting sand and a tennis ball hitting a hard court. They are completely
different noises and the surface is half of what a landing tells you.

| File | Used by | Source |
|---|---|---|
| `shuttle_land.wav` | badminton — a shuttle stops dead | CC0 |
| `land_sand.mp3` | beach volleyball | Fs_Sand_01 by renandosanjos, CC0 |
| `land_wood.ogg` | indoor volleyball | Kenney impact-sounds, CC0 |
| `land_hardcourt.mp3` | tennis | Sports Tennis Ball Bouncing by amsaenz03, CC0 |
| `hit_soft.wav`, `hit_hard.wav` | badminton racket | CC0 |
| `hit_volley_hard.mp3` | a volleyball spiked | volleyball spike by Luisa_Sanchez, CC0 |
| `hit_tennis.mp3` | a tennis racket | Tennis-Ball-Hit by kletton97, CC0 |
| `hit_pingpong.wav` | a bat | built by `tools/audio/make_sounds.py` — our own work |
| `land_pingpong.wav` | the tabletop | built by `tools/audio/make_sounds.py` — our own work |

The two table tennis sounds are **generated rather than downloaded**, which is the only
place in this folder that is true. A ping pong ball is a hollow celluloid sphere and it
**rings** — everybody who has heard the sport can hum the note — so it is built as a
damped sine rather than the burst of filtered noise that is the whole truth of every
other ball here. The CC0 recordings that exist are all several seconds of a rally, and
there is no ffmpeg on this machine to cut a single hit out of one.

The two are deliberately close to each other and deliberately not the same. In this
sport the bat and the table make almost the same noise, which is exactly why the edge
ball — a click off the top versus a click off the side, two centimetres apart — is the
call the whole sport is built around.

Freesound files are 128 kbps mp3 previews rather than the original WAVs. `sfx auth` is a
one-time browser login that unlocks originals; it has not been run on this machine.
