# Where every sound came from

Everything here is **CC0** — public domain, no credit legally required and no licence to
carry into a build. It is written down anyway, because a reader should not have to
wonder which files in a repository are safe to ship.

Fetched with the `sfx` CLI. The download folders `freesound/` and `packs/` are **not in
the repository** — carrying 264 Kenney impact sounds to use one of them is the same
mistake as carrying the Meshy intermediates — so the files in *this* folder are the ones
the game loads, copied up and renamed to say what they are for.

To fetch the originals again:

    sfx get 538422 --name whistle          # referee whistle
    sfx get 397434 --name applause         # crowd cheer
    sfx get 764253 --name groan            # crowd groans
    sfx get 801075 --name judge_out        # "Displeasure - No", the stand-in "out"
    sfx get 854616 --name land_sand        # sand footstep
    sfx get 788264 --name land_hardcourt   # tennis ball bouncing
    sfx get 710041 --name hit_tennis       # tennis ball hit
    sfx get 813420 --name hit_volley_hard  # volleyball spike
    sfx get 653920                         # crowd bed, calm   (the game uses the mp3 preview)
    sfx get 868982                         # crowd bed, tense  (the game uses the mp3 preview)
    sfx pack impact-sounds                 # Kenney, for footstep_wood_000.ogg

Each original is then converted to 16-bit 48 kHz WAV with the `afconvert` that ships with
macOS — there is no ffmpeg on this machine — and copied up under the name in the tables:

    afconvert -f WAVE -d LEI16@48000 --src-complexity bats <original>.wav <name>.wav

## Shared

Replaced wholesale on 2026-09-09. The first set were placeholders and sounded it: a
whistle nobody would blow, a bed obviously eight seconds long, and applause with no room
in it.

| File | What it is | Source |
|---|---|---|
| `whistle.wav` | the umpire's whistle | Referee whistle sound by Rosa-Orenes256 (#538422), CC0 |
| `crowd_calm.mp3` | the hall when it is settled | Small Crowd Walla by IENBA (#653920), CC0 |
| `crowd_tense.mp3` | the hall when it is not | Norwegian football match ambience by Vogyik (#868982), CC0 |
| `applause.wav` | the room liking a call | Crowd Cheer by FoolBoyMedia (#397434), CC0 |
| `groan.wav` | the room not liking one | Crowd Groans by ShangusBurger (#764253), CC0 |
| `judge_out.wav` | a line judge calling a ball out | Displeasure - No by Sadiquecat (#801075), CC0 |

**`judge_out.wav` is a stand-in.** There is no CC0 recording anywhere of a person saying
the word "out", so this is a short, curt male vocal that reads as a call against at the
distance a line judge sits. Only OUT is ever played — a judge who thought the ball was
good signals with their hands and says nothing, which is what really happens and what
keeps the shout meaning one thing. ElevenLabs, which could generate a
real "OUT!", was set aside on 2026-09-10 for lack of budget; a CC0 recording of a person
saying it is the route if one ever turns up.

## Per sport

The sports used to share one set of eight files, so a shuttlecock landing was also a
volleyball hitting sand and a tennis ball hitting a hard court. They are completely
different noises and the surface is half of what a landing tells you.

| File | Used by | Source |
|---|---|---|
| `shuttle_land.wav` | badminton — a shuttle stops dead | CC0 |
| `land_sand.wav` | beach volleyball | Fs_Sand_01 by renandosanjos (#854616), CC0 |
| `land_wood.ogg` | indoor volleyball | Kenney impact-sounds, CC0 |
| `land_hardcourt.wav` | tennis | Sports Tennis Ball Bouncing by amsaenz03 (#788264), CC0 |
| `hit_soft.wav`, `hit_hard.wav` | badminton racket | CC0 |
| `hit_volley_hard.wav` | a volleyball spiked | Volleyball spike by Luisa_Sanchez (**#813420**), CC0 |
| `hit_tennis.wav` | a tennis racket | Tennis-Ball-Hit by kletton97 (#710041), CC0 |
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

## Quality

Since 2026-09-10 the eight short sounds are the **original recordings**, fetched after the
one-time `sfx auth` login and converted to 16-bit 48 kHz WAV. Before that every Freesound
file here was a 128 kbps mp3 preview, and the difference is audible where it matters: on a
whistle, a racket and a ball landing, which are all sharp attacks that mp3 smears.

**The two crowd beds are deliberately still the previews.** Their originals are 7.7 MB and
24.6 MB of 24-bit stereo, and a file added to git stays in the history for good even if it
is later deleted. For walla mixed quietly under everything else the preview is close to
indistinguishable, so the 32 MB was not spent. `sfx get 653920` and `sfx get 868982` fetch
them if that changes.

**The volleyball spike's ID was wrong here until 2026-09-10.** This file said 816991; the
sound the game has always played is 813420 — the same author, also CC0, 2.55 s against
816991's 1.02 s. Both were downloaded under the same filename and the second one won.
