"""Cuts every recorded sound the game loads out of the CC0 recording it came from.

    python3 tools/audio/cut_sounds.py            # fetch anything missing, then cut it all
    python3 tools/audio/cut_sounds.py tt_bounce  # just the files whose names start so

Most Freesound recordings of a sport are several seconds of it: a ball dropped and left
to bounce, a player hitting four balls in a row, a crowd cheering for eight seconds. The
game wants **one** of those events, starting on its attack, so each entry below names a
recording, where in it the event is, and how long to keep. Cutting by hand in an editor
would work once and then be lost; written down, it can be run again and argued with.

The originals land in `assets/audio/freesound/` and `assets/audio/packs/`, which are not
in the repository (see the .gitignore). Only the cut files are.

It needs `ffmpeg` and the `sfx` CLI. It is also how a mistake like the tennis bounce was
found: `land_hardcourt.wav` had been copied up whole, and the whole of that recording is
**three** bounces, so every tennis landing in the game bounced three times.
"""

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
AUDIO = os.path.join(ROOT, "assets", "audio")
FREESOUND = os.path.join(AUDIO, "freesound")
PACKS = os.path.join(AUDIO, "packs")

# Short sounds are mono, because they are placed in the hall and Godot throws the stereo
# image away for a positional sound anyway. The crowd is stereo, because it is not — and
# it is mp3 at 192 kbps, because eight seconds of 48 kHz stereo is 1.5 MB as a WAV. Not
# Ogg: the Homebrew ffmpeg has only its experimental Vorbis encoder, and Godot will not
# import Opus.
RATE = 48000

# Every recording used, by Freesound id, and the name it is saved under.
RECORDINGS = {
    "badminton_clear": 324244,     # Badminton.wav, PerMagnusLindborg
    "badminton_hit": 418533,       # Badminton hit.WAV, 14FPanskaBubik_Lukas
    "badminton_swish": 838767,     # SWSH_Badminton Racquet_Recording_02, JW_Audio
    "cork_drops": 555240,          # cork_drops.wav, DirectD3D
    "pingpong_bat": 418556,        # Ping pong hit.WAV, 14FPanskaBubik_Lukas
    "pingpong_hit": 269718,        # Ping pong ball hit, michorvath
    "pingpong_table": 414460,      # Dropping ping pong ball on table, giddster
    "volleyball_outdoor": 497968,  # 09_Volleyball outdoor hit-2.wav, 16HPanskaResatko_Matej
    "basketball_bounce": 859910,   # Bouncing Basketball, DigPro120
    "tennis_bounce": 788264,       # Sports Tennis Ball Bouncing, amsaenz03
    "tennis_net": 788265,          # Net Impact Tennis Ball Smacks Bounces, amsaenz03
    "shoe_squeak": 187343,         # Rubber Shoe Squeak.wav, baidonovan
    "basketball_shoes": 190558,    # basketball shoes.wav, conradts
    "sand_step_19": 778557,        # Steps_Fine_Snow_Or_Sand_Strong_19, BlondPanda
    "sand_step_22": 778561,
    "sand_step_24": 778563,
    "sand_step_25": 778564,
    "sand_step_27": 778566,
    "crowd_oooh": 324890,          # Crowd Oooh.wav, deleted_user_2104797
    "crowd_cheer_3": 651641,       # Crowd Cheer 3, Krizin
    "crowd_cheer_7": 651644,       # Crowd Cheer 7, Krizin
    "crowd_booing": 557189,        # JM_AMB_INT_Crowd Sport 01 - Booing, Julien_Matthey
}

KENNEY = {
    "impact-sounds": os.path.join(PACKS, "impact-sounds", "Audio"),
    "interface-sounds": os.path.join(PACKS, "interface-sounds", "Audio"),
}

# name: (source, start seconds, length seconds, extra ffmpeg filters, stereo)
#
# The start is a few milliseconds before the attack, never on it: a cut exactly on the
# attack loses the first half-wave, and the sharpest part of a hit is the part that tells
# you what was hit.
CUTS = {
    # Badminton. A clear is the long, easy stroke; a smash is the same contact with a racket
    # arriving through the air a tenth of a second before it, which is most of what makes a
    # smash sound like one from the chair.
    "badminton_hit_soft": ("badminton_clear", 0.00, 0.40, "", False),
    "badminton_hit_hard": ("badminton_hit", 0.58, 0.36, "", False),
    # A shuttle is a cork base under sixteen feathers, and it lands on the cork. There is
    # no recording of one landing, and a cork dropped on a hard floor is the same object
    # making the same noise — softened, because a court mat is not a floor.
    "badminton_land": ("cork_drops", 0.45, 0.24, "lowpass=f=3500", False),

    # Table tennis. Two contacts and two table bounces each, so that a rally of twenty
    # strokes is not one sample played twenty times.
    "tt_hit_1": ("pingpong_bat", 0.72, 0.14, "", False),
    "tt_hit_2": ("pingpong_hit", 0.06, 0.14, "", False),
    "tt_bounce_1": ("pingpong_table", 0.36, 0.20, "highpass=f=180", False),
    "tt_bounce_2": ("pingpong_table", 0.88, 0.20, "highpass=f=180", False),
    # The net is a 15 cm strip of fabric on a clamp. A ball clipping it is a small, dry
    # tick: the tennis ball hitting a tennis net, raised in pitch and with the thump taken
    # out, because the ball is a tenth of the mass.
    "tt_net": ("tennis_net", 0.17, 0.10,
               "asetrate=48000*1.6,aresample=48000,highpass=f=900", False),

    # Volleyball, a forearm pass and a set: the dull slap of skin on leather, nothing like a
    # racket. Both volleyballs share these; the ball is the same ball.
    "volley_hit_soft_1": ("volleyball_outdoor", 1.92, 0.18, "", False),
    "volley_hit_soft_2": ("volleyball_outdoor", 4.13, 0.18, "", False),
    # A ball landing on a sprung wooden floor. A basketball on a gym floor is the nearest
    # recording there is; a volleyball is lighter and softer-skinned, so it is lifted a
    # little and has its lowest boom taken off.
    "indoor_land_1": ("basketball_bounce", 1.80, 0.34,
                      "asetrate=44100*1.12,aresample=48000,highpass=f=110", False),
    "indoor_land_2": ("basketball_bounce", 1.08, 0.30,
                      "asetrate=44100*1.12,aresample=48000,highpass=f=110", False),

    # Tennis. One bounce each, out of the recording that used to be copied up whole.
    "tennis_land_1": ("tennis_bounce", 0.62, 0.22, "", False),
    "tennis_land_2": ("tennis_bounce", 0.11, 0.22, "", False),
    "tennis_land_3": ("tennis_bounce", 1.19, 0.22, "", False),
    # A serve clipping the net cord — the call the sport is "decided by a sound".
    "tennis_net_cord": ("tennis_net", 0.17, 0.14, "", False),

    # Footsteps on sand. Each of these recordings is one step already.
    "step_sand_1": ("sand_step_19", 0.00, 0.75, "", False),
    "step_sand_2": ("sand_step_22", 0.00, 0.75, "", False),
    "step_sand_3": ("sand_step_24", 0.00, 0.75, "", False),
    "step_sand_4": ("sand_step_25", 0.00, 0.75, "", False),
    "step_sand_5": ("sand_step_27", 0.00, 0.75, "", False),
    # The noise every indoor court sport is known by.
    "squeak_1": ("shoe_squeak", 0.06, 0.26, "", False),
    "squeak_2": ("basketball_shoes", 0.00, 0.32, "", False),

    # The room, outside the rally.
    "review_oooh": ("crowd_oooh", 0.85, 3.00, "", True),
    "set_cheer": ("crowd_cheer_3", 0.00, 4.80, "", True),
    "match_cheer": ("crowd_cheer_7", 0.00, 8.40, "", True),
    "removed_boo": ("crowd_booing", 0.20, 8.00, "", True),
}

# The two things that badminton's smash is made of, laid one over the other.
LAYERS = {
    "badminton_hit_hard": ("badminton_swish", 0.00, 0.17, 0.0, -6.0),  # starts with the cut
}

# Kenney files used as they are, apart from the name. (pack, file, name)
COPIES = [
    ("impact-sounds", "footstep_wood_000.ogg", "step_wood_1.ogg"),
    ("impact-sounds", "footstep_wood_001.ogg", "step_wood_2.ogg"),
    ("impact-sounds", "footstep_wood_002.ogg", "step_wood_3.ogg"),
    ("impact-sounds", "footstep_wood_003.ogg", "step_wood_4.ogg"),
    ("impact-sounds", "footstep_concrete_000.ogg", "step_court_1.ogg"),
    ("impact-sounds", "footstep_concrete_001.ogg", "step_court_2.ogg"),
    ("impact-sounds", "footstep_concrete_002.ogg", "step_court_3.ogg"),
    ("impact-sounds", "footstep_concrete_003.ogg", "step_court_4.ogg"),
    ("interface-sounds", "tick_002.ogg", "ui_hover.ogg"),
    ("interface-sounds", "click_001.ogg", "ui_press.ogg"),
    ("interface-sounds", "tick_001.ogg", "scoreboard_tick.ogg"),
    ("interface-sounds", "maximize_006.ogg", "review_open.ogg"),
    ("interface-sounds", "confirmation_001.ogg", "review_stands.ogg"),
    ("interface-sounds", "error_006.ogg", "review_overturned.ogg"),
]

# Which folder under assets/audio/ each new file goes in, by the start of its name.
FOLDERS = [
    ("badminton_", "badminton"), ("tt_", "table_tennis"), ("volley_", "volleyball"),
    ("indoor_", "volleyball"), ("tennis_", "tennis"), ("step_", "steps"),
    ("squeak_", "steps"), ("ui_", "ui"), ("review_", "hall"), ("set_", "hall"),
    ("match_", "hall"), ("removed_", "hall"), ("scoreboard_", "hall"),
]


def folder_for(name):
    for prefix, folder in FOLDERS:
        if name.startswith(prefix):
            return os.path.join(AUDIO, folder)
    raise SystemExit("no folder for %s" % name)


def run(*args):
    subprocess.run(args, check=True, capture_output=True)


def original(key):
    """The downloaded recording for `key`, fetching it with sfx if it is not here."""
    for entry in os.listdir(FREESOUND) if os.path.isdir(FREESOUND) else []:
        if os.path.splitext(entry)[0] == key and not entry.endswith(".import"):
            return os.path.join(FREESOUND, entry)
    os.makedirs(FREESOUND, exist_ok=True)
    run("sfx", "get", str(RECORDINGS[key]), "-o", FREESOUND, "--name", key)
    return original(key)


def peak_db(path):
    out = subprocess.run(
        ["ffmpeg", "-hide_banner", "-i", path, "-af", "volumedetect", "-f", "null", "-"],
        capture_output=True, text=True).stderr
    return float(re.search(r"max_volume: (-?[\d.]+) dB", out).group(1))


def cut(name, source, start, length, extra, stereo):
    target = os.path.join(folder_for(name), name + (".mp3" if stereo else ".wav"))
    os.makedirs(os.path.dirname(target), exist_ok=True)
    fade = min(0.06, length * 0.35) if not stereo else 1.2
    chain = [f"atrim=start={start}:duration={length}", "asetpts=PTS-STARTPTS"]
    if extra:
        chain.append(extra)
    chain += ["afade=t=in:d=0.003", f"afade=t=out:st={length - fade:.3f}:d={fade:.3f}"]

    rough = target + ".rough.wav"
    inputs = ["-i", original(source)]
    graph = "[0:a]" + ",".join(chain) + "[main]"
    if name in LAYERS:
        layer, l_start, l_len, delay, gain = LAYERS[name]
        inputs += ["-i", original(layer)]
        graph += (f";[1:a]atrim=start={l_start}:duration={l_len},asetpts=PTS-STARTPTS,"
                  f"aresample={RATE},volume={gain}dB,adelay={int(delay * 1000)}[layer]"
                  ";[main][layer]amix=inputs=2:normalize=0[out]")
        out_label = "[out]"
    else:
        out_label = "[main]"
    run("ffmpeg", "-y", *inputs, "-filter_complex", graph, "-map", out_label,
        "-ac", "2" if stereo else "1", "-ar", str(RATE), "-c:a", "pcm_s16le", rough)

    # Every cut is brought to the same peak, so that the levels in sound.gd are the only
    # thing deciding how loud something is — not whoever happened to hold the microphone.
    gain = -1.0 - peak_db(rough)
    codec = ["-c:a", "libmp3lame", "-b:a", "192k"] if stereo else ["-c:a", "pcm_s16le"]
    run("ffmpeg", "-y", "-i", rough, "-af", f"volume={gain:.2f}dB", *codec, target)
    os.remove(rough)
    print("   %-26s %s" % (name, os.path.relpath(target, AUDIO)))


def copy(pack, file, name):
    source = os.path.join(KENNEY[pack], file)
    if not os.path.exists(source):
        run("sfx", "pack", pack, "-o", PACKS)
    target = os.path.join(folder_for(name), name)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(source, "rb") as src, open(target, "wb") as dst:
        dst.write(src.read())
    print("   %-26s %s" % (name, os.path.relpath(target, AUDIO)))


def main(wanted):
    for name, spec in CUTS.items():
        if not wanted or any(name.startswith(w) for w in wanted):
            cut(name, *spec)
    for pack, file, name in COPIES:
        if not wanted or any(name.startswith(w) for w in wanted):
            copy(pack, file, name)


if __name__ == "__main__":
    main(sys.argv[1:])
