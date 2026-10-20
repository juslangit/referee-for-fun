"""Draws the two patterned surfaces Stadium Titiwangsa is modelled with, as textures:

* `songket_mural.png` — the mural the hall was given in its 2026 upgrade, drawn as a songket
  weave: gold diamonds and stars on a deep red and blue ground, the pattern every Malaysian
  sports hall borrows when it wants to look like home.
* `roster_blocks.png` — the band of ventilation blocks (roster) high on the walls of every
  older Malaysian hall: a grid of pierced concrete blocks with the dark of the night behind.

    python3 tools/stadium/make_patterns.py

Writes tools/stadium/textures/. Both are drawn here, so they are ours to ship.
"""

import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "textures")


def songket(w=2048, h=512):
    im = Image.new("RGB", (w, h), (120, 18, 32))
    d = ImageDraw.Draw(im)
    gold = (222, 172, 58)
    deep = (20, 40, 110)
    # Horizontal borders.
    for y0, y1 in ((0, 46), (h - 46, h)):
        d.rectangle([0, y0, w, y1], fill=deep)
        for x in range(0, w, 32):
            d.polygon([(x, (y0 + y1) // 2), (x + 16, y0 + 6), (x + 32, (y0 + y1) // 2), (x + 16, y1 - 6)], fill=gold)
    # The main field: big diamonds with an eight-point star inside each, small diamonds between.
    cell = 200
    cy = h // 2
    for i in range(-1, w // cell + 2):
        cx = i * cell + cell // 2
        r = 150
        d.polygon([(cx, cy - r), (cx + r * 0.75, cy), (cx, cy + r), (cx - r * 0.75, cy)], outline=gold, width=10)
        r2 = 110
        d.polygon([(cx, cy - r2), (cx + r2 * 0.75, cy), (cx, cy + r2), (cx - r2 * 0.75, cy)], fill=deep)
        pts = []
        for k in range(16):
            a = math.pi * k / 8
            rr = 72 if k % 2 == 0 else 32
            pts.append((cx + rr * math.sin(a), cy - rr * math.cos(a)))
        d.polygon(pts, fill=gold)
        d.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=(120, 18, 32))
        sx = cx + cell // 2
        for dy in (-120, 120):
            d.polygon([(sx, cy + dy - 26), (sx + 18, cy + dy), (sx, cy + dy + 26), (sx - 18, cy + dy)], fill=gold)
    im.save(os.path.join(OUT, "songket_mural.png"))


def roster(w=512, h=256):
    block = 64
    im = Image.new("RGB", (w, h), (196, 194, 186))
    d = ImageDraw.Draw(im)
    for by in range(0, h, block):
        for bx in range(0, w, block):
            d.rectangle([bx, by, bx + block - 1, by + block - 1], outline=(150, 148, 142), width=3)
            # A pierced quatrefoil in each block, dark behind.
            c = (bx + block // 2, by + block // 2)
            for ox, oy in ((-12, 0), (12, 0), (0, -12), (0, 12)):
                d.ellipse([c[0] + ox - 11, c[1] + oy - 11, c[0] + ox + 11, c[1] + oy + 11], fill=(16, 20, 30))
            d.rectangle([c[0] - 6, c[1] - 6, c[0] + 6, c[1] + 6], fill=(196, 194, 186))
    im.save(os.path.join(OUT, "roster_blocks.png"))


if __name__ == "__main__":
    songket()
    roster()
    print("ok")
