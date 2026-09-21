"""Cuts the recorded shots into the two-minute trailer.

    python3 tools/trailer/cut.py

The shots come out of `tools/trailer/record.sh`, which plays the real game and records it
with Godot's movie writer. Nothing here is staged: every rally, call and crowd reaction in
the finished film is something the game did while being recorded.

The edit is the list below — a card or a shot, and how long it holds. Cards exist because
the premise is the one thing footage cannot say: a stranger watching a rally has no way of
knowing they are looking at it from the umpire's chair, or that the interesting part is
that the umpire can lie.

The cards are drawn with PIL rather than ffmpeg's `drawtext`, because this ffmpeg was
built without freetype and has no such filter — and drawing them here is better anyway:
the game's own type, laid out deliberately, instead of a filter string with three levels
of escaping in it.

Music is CC0: Freesound 854836, "Tension Rising Cinematic Drone" by bassimat, taken from
2:30 in where it starts to build, and kept quiet under the game's own crowd and whistle.
"""

import pathlib
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

PROJECT = pathlib.Path(__file__).resolve().parent.parent.parent
SHOTS = PROJECT / "build" / "trailer"
FONT = PROJECT / "assets" / "fonts" / "BarlowCondensed-Bold.ttf"
MUSIC = PROJECT / "assets" / "audio" / "freesound" / "tension_rising_cinematic_drone_by_mantice.wav"
MUSIC_FROM = 150.0
OUT = SHOTS / "referee-for-fun-trailer.mp4"

W, H, FPS = 1920, 1080, 60
INK = (11, 13, 18)
GOLD = (242, 193, 78)

# ("card"|"title", text, seconds) or ("shot", name, seconds, start)
EDIT = [
    ("card", "Every sports game\nputs you on the court.", 4.5),
    ("shot", "open", 6.5, 0.4),
    ("card", "This one puts you\nin the chair.", 4.0),
    ("title", "REFEREE FOR FUN", 5.0),
    ("shot", "honest", 8.5, 0.3),
    ("card", "The rally is real.\nThe game knows exactly where it landed.", 5.0),
    ("shot", "brief", 4.8, 0.2),
    ("card", "Nobody asks you for a favour.\nThey tell you who they would like to win.", 5.5),
    ("shot", "lie", 5.8, 0.2),
    ("card", "Every close call is yours to bend.", 4.6),
    ("card", "The hall is watching.", 4.6),
    ("shot", "career", 4.8, 0.2),
    ("card", "Six sports.\nOne reputation.", 4.6),
    ("shot", "tennis", 4.8, 0.3),
    ("shot", "volley", 5.8, 0.4),
    ("shot", "beach", 5.8, 0.4),
    ("shot", "tabletennis", 4.8, 0.3),
    ("shot", "takraw", 4.8, 0.3),
    # The tail of the ending shot, where the game replays the worst calls of the match
    # and says what each one really was. "YOU CALLED IN - IT WAS OUT BY 86 cm" is the
    # whole premise in one frame, and it is the last thing before the end card.
    ("shot", "ending", 5.0, 9.8),
    ("card", "How long before\nsomebody notices?", 4.8),
    ("title", "REFEREE FOR FUN\nfree for macOS and Windows\njuslangit.github.io/referee-for-fun", 8.0),
]


def card_image(kind, body, path):
    image = Image.new("RGB", (W, H), INK)
    draw = ImageDraw.Draw(image)
    lines = body.split("\n")
    base = 92 if kind == "card" else 140

    rows = []
    for i, line in enumerate(lines):
        size = base if (kind == "card" or i == 0) else int(base * 0.34)
        colour = (252, 252, 250) if (kind == "card" or i == 0) else GOLD
        rows.append((line, ImageFont.truetype(str(FONT), size), colour, size))

    heights = [int(size * 1.30) for _, _, _, size in rows]
    y = H // 2 - sum(heights) // 2
    for i, (line, font, colour, size) in enumerate(rows):
        width = draw.textlength(line, font=font)
        draw.text(((W - width) / 2, y + (heights[i] - size) / 2 - size * 0.18),
                  line, font=font, fill=colour)
        y += heights[i]
    image.save(path)


def piece(kind, body, seconds, start, index):
    """One numbered piece of the edit, normalised to the same size, rate and audio."""
    path = SHOTS / f"cut_{index:02d}.mp4"
    common = ["-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
              "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2"]

    if kind in ("card", "title"):
        still = SHOTS / f"card_{index:02d}.png"
        card_image(kind, body, still)
        subprocess.run([
            "ffmpeg", "-v", "error", "-y",
            "-loop", "1", "-framerate", str(FPS), "-t", str(seconds), "-i", str(still),
            "-f", "lavfi", "-t", str(seconds), "-i", "anullsrc=r=48000:cl=stereo",
            "-vf", f"fade=t=in:st=0:d=0.45,fade=t=out:st={seconds - 0.55:.2f}:d=0.55",
        ] + common + ["-t", str(seconds), str(path)], check=True)
        return path

    subprocess.run([
        "ffmpeg", "-v", "error", "-y", "-ss", str(start), "-t", str(seconds),
        "-i", str(SHOTS / f"t_{body}.avi"),
        # A short dip from black at each end, so a cut between a card and a shot does not
        # flash.
        "-vf", f"scale={W}:{H},fps={FPS},"
               f"fade=t=in:st=0:d=0.25,fade=t=out:st={seconds - 0.3:.2f}:d=0.3",
        "-af", f"afade=t=in:st=0:d=0.25,afade=t=out:st={seconds - 0.3:.2f}:d=0.3",
    ] + common + [str(path)], check=True)
    return path


def main():
    pieces = []
    total = 0.0
    for i, item in enumerate(EDIT):
        kind, body, seconds = item[0], item[1], item[2]
        start = item[3] if len(item) > 3 else 0.0
        pieces.append(piece(kind, body, seconds, start, i))
        total += seconds
        print(f"  {i:02d}  {kind:5}  {seconds:4.1f}s  {body.splitlines()[0][:46]}")
    print(f"  total {total:.1f}s")

    listing = SHOTS / "edit.txt"
    listing.write_text("".join(f"file '{p.name}'\n" for p in pieces))

    joined = SHOTS / "joined.mp4"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0",
                    "-i", str(listing), "-c", "copy", str(joined)], check=True)

    # The bed is kept quiet on purpose. The game's own crowd, whistle and commentary are
    # the point of the film; a trailer where the music wins is a trailer for the music.
    subprocess.run([
        "ffmpeg", "-v", "error", "-y",
        "-i", str(joined),
        "-ss", str(MUSIC_FROM), "-t", str(total), "-i", str(MUSIC),
        "-filter_complex",
        f"[1:a]volume=0.30,afade=t=in:st=0:d=2.5,afade=t=out:st={total - 5:.2f}:d=5[bed];"
        f"[0:a][bed]amix=inputs=2:duration=first:dropout_transition=0,"
        # loudnorm in a single pass estimates as it goes and overshoots: the first mix of
        # this came out peaking at exactly 0 dBFS, which is where clipping lives. The
        # limiter behind it is the guarantee rather than the intention.
        f"loudnorm=I=-16:TP=-1.5:LRA=11,alimiter=limit=0.891:level=disabled[a]",
        "-map", "0:v", "-map", "[a]",
        "-c:v", "copy", "-c:a", "aac", "-b:a", "224k",
        "-movflags", "+faststart", str(OUT)], check=True)
    print(f"\nwrote {OUT}")


if __name__ == "__main__":
    sys.exit(main())
