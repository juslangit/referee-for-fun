#!/usr/bin/env python3
"""Draw the packaging art: the disk image window background and the app icon.

    tools/build/make_art.py

Writes three files, all of them committed, because they are art rather than
build output and the .dmg has to be reproducible without a working Python:

    tools/build/dmg/background.tiff   the window behind the two icons
    assets/icon.png                   1024 px, what Godot exports from
    assets/icon.ico                   the same icon for the Windows build

Why the window is a court seen from above
-----------------------------------------
The disk image is the first thing a player sees, before the menu and before a
rally, so it should look like the game rather than like a folder. The field is
the badminton court's own mat colour -- Color(0.10, 0.30, 0.24) in
scripts/court.gd -- with the lines of a real doubles court on it at true
proportions: 13.4 m by 6.1 m, service lines 1.98 m from the net, doubles long
service line 0.76 m in from the back, sidelines 0.46 m inside. A court drawn
with invented measurements would be the one thing in this project a player
could catch out, and the numbers cost nothing to get right.

The net falls down the middle of the window, which puts the game on one side
and Applications on the other, and the yellow arrow crosses it. Installing the
game is a shot over the net.

Why the icon is the whistle
---------------------------
The export had no icon at all -- application/icon was empty in
export_presets.cfg -- so the build shipped wearing Godot's robot, which is the
engine's mark and not the game's. The whistle is already the game's mark: it
sits at the end of the title logo, on the menu, above the yellow rule.

It is lifted from assets/ui/title_logo.png rather than redrawn, so it is the
same whistle a player sees on the title screen. The honest limit of that is
resolution: the whistle is about 160 px wide in the logo, so it is crisp at the
16-128 px sizes macOS actually shows in a Finder window, the Dock and the
sidebar, and softer at 512 and 1024, where it is upscaled about six times.
Unsharp masking hides some of that; a redrawn vector whistle would be the real
fix if the icon is ever wanted at poster size.
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parents[2]
LOGO = REPO / "assets/ui/title_logo.png"
FONT = REPO / "assets/fonts/BarlowCondensed-SemiBold.ttf"

# The window, at 1x. The Finder window is set to exactly this in make_dmg.sh,
# so these two numbers and the ones in that script's AppleScript must agree.
WIDTH, HEIGHT = 640, 420

# Straight out of scripts/court.gd, so the packaging and the game are the same
# colours rather than two people's idea of green.
MAT = (26, 77, 61)          # Color(0.10, 0.30, 0.24), the court mat
LINE = (242, 242, 235)      # Color(0.95, 0.95, 0.92), the painted lines
YELLOW = (246, 190, 34)     # sampled from the rule under the title logo

# A doubles court, in metres, and where the icons stand on it.
COURT_M = (13.4, 6.1)
SERVICE_FROM_NET_M = 1.98
LONG_SERVICE_FROM_BACK_M = 0.76
SIDELINE_INSET_M = 0.46

ICON_Y = 236                # centre of both icons, at 1x
APP_X, APPLICATIONS_X = 168, 472


def _font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT), size)


def _spaced(draw: ImageDraw.ImageDraw, xy, text: str, font, fill, gap: float) -> None:
    """Letter-spaced, centred text. Barlow Condensed is narrow enough that a
    caption set solid reads as one word at this size."""
    widths = [draw.textlength(ch, font=font) for ch in text]
    total = sum(widths) + gap * (len(text) - 1)
    x, y = xy
    x -= total / 2
    for ch, w in zip(text, widths):
        draw.text((x, y), ch, font=font, fill=fill)
        x += w + gap


def background(scale: int) -> Image.Image:
    """The window background at 1x or 2x. Everything is expressed in 1x units
    and multiplied, so the two images are the same picture and not two
    drawings that happen to look alike."""
    s = scale
    w, h = WIDTH * s, HEIGHT * s
    img = Image.new("RGB", (w, h), MAT)
    draw = ImageDraw.Draw(img, "RGBA")

    # A little more light at the top than the bottom, like a lit hall. Drawn as
    # rows rather than with a gradient helper to keep this dependency-free.
    for y in range(h):
        t = y / h
        shade = int(22 * (t - 0.35))
        draw.line([(0, y), (w, y)], fill=(
            max(0, MAT[0] - shade), max(0, MAT[1] - shade), max(0, MAT[2] - shade)))

    # The court, at the real aspect ratio, centred under the logo.
    court_w = 552 * s
    court_h = int(court_w * COURT_M[1] / COURT_M[0])
    left = (w - court_w) // 2
    top = 108 * s
    right, bottom = left + court_w, top + court_h
    per_m_x = court_w / COURT_M[0]
    per_m_y = court_h / COURT_M[1]
    thin = max(1, int(1.5 * s))
    paint = LINE + (170,)

    draw.rectangle([left, top, right, bottom], outline=paint, width=max(1, 2 * s))

    # Doubles sidelines, both sides.
    for inset in (SIDELINE_INSET_M * per_m_y,):
        draw.line([(left, top + inset), (right, top + inset)], fill=paint, width=thin)
        draw.line([(left, bottom - inset), (right, bottom - inset)], fill=paint, width=thin)

    mid_x = (left + right) / 2
    service = SERVICE_FROM_NET_M * per_m_x
    long_service = LONG_SERVICE_FROM_BACK_M * per_m_x
    for side in (-1, 1):
        x = mid_x + side * service
        draw.line([(x, top), (x, bottom)], fill=paint, width=thin)          # short service
        x = mid_x + side * (COURT_M[0] / 2 * per_m_x - long_service)
        draw.line([(x, top), (x, bottom)], fill=paint, width=thin)          # doubles long service
        # Centre line, from the short service line to the back.
        draw.line([(mid_x + side * service, (top + bottom) / 2),
                   (mid_x + side * COURT_M[0] / 2 * per_m_x, (top + bottom) / 2)],
                  fill=paint, width=thin)

    # The net, down the middle: mesh as a soft band, with the white tape on top.
    net_half = 4 * s
    draw.rectangle([mid_x - net_half, top, mid_x + net_half, bottom],
                   fill=(255, 255, 255, 38))
    draw.line([(mid_x, top), (mid_x, bottom)], fill=(255, 255, 255, 90), width=thin)

    # The title logo, sized to the window rather than to itself.
    logo = Image.open(LOGO).convert("RGBA")
    logo_w = 392 * s
    logo = logo.resize((logo_w, round(logo_w * logo.height / logo.width)), Image.LANCZOS)
    img.paste(logo, ((w - logo.width) // 2, 26 * s), logo)

    # The arrow, crossing the net. Drawn between the icons, not under them, so
    # it never competes with what Finder puts there.
    y = ICON_Y * s
    x0, x1 = (APP_X + 84) * s, (APPLICATIONS_X - 84) * s
    draw.line([(x0, y), (x1 - 9 * s, y)], fill=YELLOW + (235,), width=max(2, 3 * s))
    draw.polygon([(x1, y), (x1 - 13 * s, y - 8 * s), (x1 - 13 * s, y + 8 * s)],
                 fill=YELLOW + (235,))

    _spaced(draw, (w / 2, 372 * s), "DRAG THE GAME INTO APPLICATIONS",
            _font(15 * s), (235, 235, 228, 175), 1.4 * s)
    return img


def _whistle_from_logo(logo: Image.Image) -> Image.Image:
    """Cut the whistle, and its three motion ticks, out of the title logo.

    Found by looking for the blank columns that separate it from the rest of
    the logo rather than by hard-coded numbers, because the logo is generated
    by tools/ui/prepare_art.gd and a re-run moves everything a few pixels. A
    guessed box would then quietly include the tail of the N in FUN and a
    slice of the yellow rule, which is exactly what the first attempt did."""
    alpha = logo.getchannel("A")
    px = alpha.load()
    filled = [any(px[x, y] > 60 for y in range(logo.height)) for x in range(logo.width)]

    right = max(x for x in range(logo.width) if filled[x])
    left = right
    while left > 0 and any(filled[max(0, left - 6):left]):
        left -= 1

    group = logo.crop((left, 0, right + 1, logo.height))
    return group.crop(group.getbbox())


def icon() -> Image.Image:
    """1024 px, the whistle on a court-green tile.

    The body is inset and rounded because macOS expects an app icon to be a
    tile with air around it, not a full-bleed square -- a full square icon
    stands out as wrong beside every other icon in the Dock."""
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")

    margin, radius = 92, 200
    body = [margin, margin, size - margin, size - margin]
    draw.rounded_rectangle(body, radius=radius, fill=MAT + (255,))

    # The tile carries nothing but the whistle. Court lines were tried here and
    # taken out again: the whistle covers most of them, so what survives reads
    # as three stray rectangles rather than as a court, and at 32 px it is
    # simply dirt. The window has room for a court; an icon does not.
    logo = Image.open(LOGO).convert("RGBA")
    whistle = _whistle_from_logo(logo)
    target_w = 640
    whistle = whistle.resize(
        (target_w, round(target_w * whistle.height / whistle.width)), Image.LANCZOS)
    whistle = whistle.filter(ImageFilter.UnsharpMask(radius=3, percent=110, threshold=2))
    img.alpha_composite(whistle, ((size - whistle.width) // 2,
                                  (size - whistle.height) // 2 + 8))
    return img


def main() -> int:
    for needed in (LOGO, FONT):
        if not needed.exists():
            print(f"missing: {needed}", file=sys.stderr)
            return 1

    out_dmg = REPO / "tools/build/dmg"
    out_dmg.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        background(1).save(tmp / "background.png")
        background(2).save(tmp / "background@2x.png")
        # One .tiff holding both, which is how macOS is told that the second
        # image is the retina version of the first. Two PNGs cannot say that.
        subprocess.run(
            ["tiffutil", "-cathidpicheck", str(tmp / "background.png"),
             str(tmp / "background@2x.png"), "-out", str(out_dmg / "background.tiff")],
            check=True, stdout=subprocess.DEVNULL)

        art = icon()
        art.save(REPO / "assets/icon.png")
        # Windows wants the sizes baked in; PIL writes them all into one .ico.
        art.save(REPO / "assets/icon.ico",
                 sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

        # An .icns too, for the disk image's own volume icon.
        iconset = tmp / "icon.iconset"
        iconset.mkdir()
        for px in (16, 32, 128, 256, 512):
            art.resize((px, px), Image.LANCZOS).save(iconset / f"icon_{px}x{px}.png")
            art.resize((px * 2, px * 2), Image.LANCZOS).save(iconset / f"icon_{px}x{px}@2x.png")
        subprocess.run(["iconutil", "-c", "icns", str(iconset),
                        "-o", str(out_dmg / "volume.icns")], check=True)

    print("wrote:")
    for p in (out_dmg / "background.tiff", out_dmg / "volume.icns",
              REPO / "assets/icon.png", REPO / "assets/icon.ico"):
        print(f"  {p.relative_to(REPO)}  {p.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
