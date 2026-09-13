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
    sfx pack impact-sounds                 # Kenney, for the wood and court footsteps
    sfx pack interface-sounds              # Kenney, for the menus, the board and the review

Each original is then converted to 16-bit 48 kHz WAV with the `afconvert` that ships with
macOS and copied up under the name in the tables (everything added since 2026-09-13 is cut
with ffmpeg by `tools/audio/cut_sounds.py` instead, which fetches its own originals):

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

**Since 2026-09-13 every sound here is a recording.** The badminton and table tennis
sounds built by `tools/audio/make_sounds.py` were the last placeholders and are gone.
Everything cut out of a longer recording is cut by `tools/audio/cut_sounds.py`, which
names the Freesound id, where in the recording the event is and how long to keep, and
fetches the original if it is missing:

    python3 tools/audio/cut_sounds.py

That script is also how the tennis bounce was found to be wrong: `land_hardcourt.wav` had
been copied up whole, and the whole recording is **three** bounces — so every tennis
landing in the game bounced three times. It is cut to one now, three ways.

| File | Used by | Source |
|---|---|---|
| `badminton/badminton_hit_soft.wav` | badminton — a clear or a drop | Badminton.wav by PerMagnusLindborg (#324244), CC0 |
| `badminton/badminton_hit_hard.wav` | badminton — a smash | Badminton hit by 14FPanskaBubik_Lukas (#418533), with the racket swish of SWSH_Badminton Racquet_Recording_02 by JW_Audio (#838767) laid under it, both CC0 |
| `badminton/badminton_land.wav` | badminton — a shuttle landing on its cork | cork_drops.wav by DirectD3D (#555240), CC0, softened |
| `land_sand.wav` | beach volleyball | Fs_Sand_01 by renandosanjos (#854616), CC0 |
| `volleyball/indoor_land_1.wav`, `_2` | indoor volleyball — a ball on a sprung wooden floor | Bouncing Basketball by DigPro120 (#859910), CC0, raised a little for a lighter ball |
| `volleyball/volley_hit_soft_1.wav`, `_2` | both volleyballs — a forearm pass and a set | 09_Volleyball outdoor hit-2 by 16HPanskaResatko_Matej (#497968), CC0 |
| `hit_volley_hard.wav` | both volleyballs — a spike | Volleyball spike by Luisa_Sanchez (**#813420**), CC0 |
| `hit_tennis.wav` | a tennis racket | Tennis-Ball-Hit by kletton97 (#710041), CC0 |
| `tennis/tennis_land_1.wav`, `_2`, `_3` | tennis — one bounce each | Sports Tennis Ball Bouncing by amsaenz03 (#788264), CC0 |
| `tennis/tennis_net_cord.wav` | tennis — a serve clipping the cord | Net Impact Tennis Ball Smacks Bounces by amsaenz03 (#788265), CC0 |
| `table_tennis/tt_hit_1.wav` | a bat | Ping pong hit by 14FPanskaBubik_Lukas (#418556), CC0 |
| `table_tennis/tt_hit_2.wav` | a bat | Ping pong ball hit by michorvath (#269718), CC0 |
| `table_tennis/tt_bounce_1.wav`, `_2` | the tabletop, and the edge ball | Dropping ping pong ball on table by giddster (#414460), CC0 |
| `table_tennis/tt_net.wav` | a serve clipping the net | #788265 again, raised in pitch for a ball a tenth of the mass |

The **edge ball** has no file of its own. A ball off the top edge and a ball off the side
sound almost the same — that is the call — so both are the table bounce, played a
fraction higher for the top edge and lower and flatter for the side. See `Sound.edge`.

## Feet

| File | Used by | Source |
|---|---|---|
| `steps/step_wood_1.ogg` … `_4` | badminton, indoor volleyball, table tennis | Kenney impact-sounds, `footstep_wood_000`–`003`, CC0 |
| `steps/step_court_1.ogg` … `_4` | tennis, on a hard court | Kenney impact-sounds, `footstep_concrete_000`–`003`, CC0 |
| `steps/step_sand_1.wav` … `_5` | beach volleyball | Steps_Fine_Snow_Or_Sand_Strong 19, 22, 24, 25, 27 by BlondPanda (#778557, #778561, #778563, #778564, #778566), CC0 |
| `steps/squeak_1.wav` | a shoe stopping — every indoor court sport, and tennis | Rubber Shoe Squeak by baidonovan (#187343), CC0 |
| `steps/squeak_2.wav` | the same | basketball shoes by conradts (#190558), CC0 |

## The room outside the rally, and the menus

| File | What it is | Source |
|---|---|---|
| `hall/scoreboard_tick.ogg` | the hanging board changing after a point | Kenney interface-sounds `tick_001`, CC0 |
| `hall/set_cheer.mp3` | a set or a game won | Crowd Cheer 3 by Krizin (#651641), CC0 |
| `hall/match_cheer.mp3` | the match won | Crowd Cheer 7 by Krizin (#651644), CC0 |
| `hall/removed_boo.mp3` | the umpire taken off the match | JM_AMB_INT_Crowd Sport 01 - Booing by Julien_Matthey (#557189), CC0 |
| `hall/review_open.ogg` | a review coming up on the big screen | Kenney interface-sounds `maximize_006`, CC0 |
| `hall/review_oooh.mp3` | the hall drawing its breath for it | Crowd Oooh (#324890), CC0 |
| `hall/review_stands.ogg` | the call stands | Kenney interface-sounds `confirmation_001`, CC0 |
| `hall/review_overturned.ogg` | the call is overturned | Kenney interface-sounds `error_006`, CC0 |
| `ui/ui_hover.ogg` | the pointer onto a button | Kenney interface-sounds `tick_002`, CC0 |
| `ui/ui_press.ogg` | a button pressed | Kenney interface-sounds `click_001`, CC0 |

The four crowd files are mp3 at 192 kbps rather than WAV — eight seconds of 48 kHz stereo
is 1.5 MB as a WAV — and not Ogg, because the Homebrew ffmpeg has only its experimental
Vorbis encoder and Godot will not import Opus.

## Who makes which noise

Decided with Luqman on 2026-09-13, by how each sport is really officiated:

- **Only volleyball's referee blows a whistle.** Tennis, badminton and table tennis
  umpires start a point with their voice. `Sound.whistle()` is still called everywhere
  a point starts; the sport's kit decides whether anything is heard.
- **Only tennis and badminton line judges shout OUT.** A volleyball line judge signals
  with a flag, and table tennis has no line judges at all.

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
