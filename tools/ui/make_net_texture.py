#!/usr/bin/env python3
"""Draws the net: one cord cell, tiled to each sport's own gauge.

    python3 tools/ui/make_net_texture.py

Writes assets/ui/net_cord.png

Why one texture and not six
---------------------------
A net is a square grid of cord, and every sport's net is the same thing at a different
size. So this draws **one cell** — a single square of mesh with its two cords — and each
court tiles it to its own gauge through the material's `uv1_scale`. Luqman, 2026-09-20:
"if two sports can use one same net, just do one." One is enough for all six.

    badminton      15-20 mm squares (BWF)      -> 18 mm
    sepak takraw   60-80 mm (ISTAF)            -> 70 mm
    volleyball     100 mm (FIVB), indoor and beach alike
    tennis         not more than 40 mm (ITF)   -> 40 mm
    table tennis   fine mesh (ITTF)            -> 12.5 mm

What this replaces
------------------
The net was two solid boxes: a 2 cm slab for the mesh and another for the tape, the
first at 55% alpha. Close up it reads as a white bar with a faint smear under it and
nothing you could call a net — and an umpire spends the whole match looking through it.

The cord is drawn at 3% of the cell. Real cord runs from 0.8 mm on a badminton net to
about 2 mm on a volleyball one, which is 4.4% and 2% of their squares — 3% sits between
them and reads correctly at every gauge without needing a texture each. That is the one
approximation here and it is deliberate.

Drawn with soft edges rather than hard ones, so the cords stay visible when the net is
far away and the texture is being minified; a one-pixel hard line disappears into
nothing at a distance and the net flickers as the camera moves.
"""

import pathlib

from PIL import Image, ImageDraw, ImageFilter

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parent.parent / "assets" / "ui" / "net_cord.png"

## One cell, at a size that survives being tiled dozens of times across a 9.5 m net.
CELL = 128

## How thick the cord is as a fraction of the square it encloses. See the note above.
CORD = 0.03

## The cord's own colour. Nets are dark but not black — a black net against a dark hall
## disappears, and the one thing a net must never do is stop being visible.
CORD_COLOUR = (24, 26, 30)


def main() -> None:
    # Drawn at four times the final size and shrunk, which is cheaper than antialiasing
    # by hand and gives the cord a soft edge for free.
    scale = 4
    big = CELL * scale
    thickness = max(2, round(big * CORD))

    sheet = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(sheet)
    # Two cords per cell, on two edges only, so tiling does not double them up.
    draw.rectangle([0, 0, big - 1, thickness - 1], fill=CORD_COLOUR + (255,))
    draw.rectangle([0, 0, thickness - 1, big - 1], fill=CORD_COLOUR + (255,))

    sheet = sheet.resize((CELL, CELL), Image.LANCZOS)
    sheet = sheet.filter(ImageFilter.GaussianBlur(0.4))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    covered = 100.0 * sum(1 for p in sheet.getdata() if p[3] > 8) / (CELL * CELL)
    print(f"wrote {OUT.relative_to(HERE.parent.parent)}  {CELL}x{CELL}, "
          f"cord {CORD * 100:.0f}% of the cell, {covered:.1f}% of the sheet is cord")


main()
