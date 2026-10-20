# DESIGN.md — Referee For Fun website (`web/`)

Source: not one awesome-design-md entry. Luqman rejected four library directions (PlayStation, Nike,
Ferrari, the old broadcast palette) on 2026-10-20 and gave two reference pages instead:
<https://www.rockstargames.com/gta-v> and <https://www.nintendo.com/my/games/zelda/totk/edition/index.html>.
This file records the blend he approved from a sample the same day. Design language only: no
Rockstar or Nintendo names, marks, fonts or copy.

## What comes from where

| From Rockstar (GTA V) | From Nintendo (Zelda TotK edition page) |
|---|---|
| Near-black canvas, white type, almost no colour in the chrome | Gold ornament: arrow-tipped lines either side of a centred heading |
| Bold condensed headings (theirs: Chalet Comprimé; ours: Barlow Condensed, the game's own face) | Small-caps serif for dates and kickers ("Release date 20 October 2026") |
| Black top bar: wordmark, uppercase links, one round outlined action | Thin gold frame with corner brackets around the store block |
| Hero with a slanted top edge, logo lockup, headline, two square outlined buttons | The gameplay video shown inside the hardware (theirs a Switch, ours a desktop monitor) on a blurred in-game backdrop |
| Feature rows alternating picture left / right | A white rule ending in a diamond node under each feature heading |
| Edition cards: picture header, platform icons, one full-width button | A "Find a Retailer" button fixed bottom-right → our "Download free" |

## Tokens

```
--ink #0b0b0b   --ink-2 #111   --ink-3 #181818   --ink-4 #222     surfaces, separated by tone steps
--white #fff    --text #ececec --soft #b9b9b9                      type
--gold #d9b45a  --gold-line rgba(217,180,90,.55)                   ornament and the one accent
--red #d63c36   --blue #2e6fd0                                     the game's team colours, in-game UI only
Display  Barlow Condensed 600/700, line-height ~1.04, tracking -0.01em
Body     Barlow 400/500/600, 18px / 1.65
Label    Cormorant SC 600/700 — dates, kickers, sheet terms only
Radius   4px buttons and media, 6px cards, 999px for the nav pill, tabs and toggles
```

## Rules

- Single dark theme. The logo (`assets/ui/title_logo.png`) is white outline type on transparent and has
  nowhere to sit on a light ground (D-059 still holds).
- Primary action = solid white button; secondary = white outline. Gold is never a button fill at rest.
- Drawn OS dialogs in the install guide carry `data-ui` and keep their own system look.
- Pictures are the game's own: `dev/looks/_venueshot.tscn` (WITH_UI=1 for chair shots) and
  `dev/looks/_readme.tscn`. Never stand in a stock photo for the game.

## Where this departs from taste-skill's house rules (on purpose, Luqman's approved sample)

Gold frame and corner brackets, the diamond rules, the small-caps kickers above headings, three type
families, and a scrim gradient on cover images. Everything else in taste-skill's house rules holds.
