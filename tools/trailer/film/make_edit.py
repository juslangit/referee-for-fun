"""Writes index.html, the v0.3.1 trailer composition, from one edit list.

    python3 tools/trailer/film/make_edit.py

The shots come from tools/trailer/record.sh, converted into assets/shots/ with ffmpeg (BRIEF.md).
After this the film is checked and rendered with HyperFrames
(hyperframes check; hyperframes render --fps 60 --quality delivery), then loudness-normalised
to -16 LUFS in two loudnorm passes with a limiter behind it.
"""
import json, pathlib

OUT = pathlib.Path(__file__).resolve().parent / "index.html"

# (kind, start, duration, payload)
EDIT = [
    ("card", 0.0, 3.5, {"lines": ["Every sports game", "puts you on the court."], "bg": "bg-arena"}),
    ("shot", 3.5, 5.0, {"src": "open", "from": 2.6}),
    ("card", 8.5, 3.0, {"lines": ["This one puts you", "in the chair."], "bg": "bg-arena"}),
    ("logo", 11.5, 3.5, {}),
    ("shot", 15.0, 5.0, {"src": "hall", "from": 0.2, "lt": ["Community hall", "Where every umpire starts"]}),
    ("shot", 20.0, 5.5, {"src": "honest", "from": 3.6, "lt": ["International final", "The same job. A bigger room."]}),
    ("card", 25.5, 3.2, {"lines": ["The rally is real.", "The game knows where it landed."], "bg": "bg-arena"}),
    ("shot", 28.7, 4.0, {"src": "brief", "from": 0.3}),
    ("card", 32.7, 4.0, {"lines": ["Nobody asks you for a favour.", "They tell you who they'd like to win."], "bg": "bg-hall", "size": 92}),
    ("shot", 36.7, 6.5, {"src": "lie", "from": 5.3}),
    ("card", 43.2, 3.2, {"lines": ["Every close call", "is yours to bend."], "bg": "bg-arena"}),
    ("rep", 46.4, 4.0, {}),
    ("shot", 50.4, 3.2, {"src": "career", "from": 0.5}),
    ("card", 53.6, 3.0, {"lines": ["Six sports.", "One reputation."], "bg": "bg-hall"}),
    ("shot", 56.6, 3.4, {"src": "tennis", "from": 2.8, "lt": ["Tennis", "An open-air stadium"], "hard": True}),
    ("shot", 60.0, 3.4, {"src": "volley", "from": 2.3, "lt": ["Indoor volleyball", "A hall after MITEC"], "hard": True}),
    ("shot", 63.4, 3.4, {"src": "beach", "from": 2.2, "lt": ["Beach volleyball", "Under a photographed sky"], "hard": True}),
    ("shot", 66.8, 3.4, {"src": "tabletennis", "from": 1.0, "lt": ["Table tennis", "A dome after Malawati"], "hard": True}),
    ("shot", 70.2, 3.4, {"src": "takraw", "from": 3.0, "lt": ["Sepak takraw", "A hall after Titiwangsa"], "hard": True}),
    ("shot", 73.6, 5.8, {"src": "ending", "from": 6.2}),
    ("card", 79.4, 3.6, {"lines": ["How long before", "somebody notices?"], "bg": "bg-arena"}),
    ("end", 83.0, 7.0, {}),
]
TOTAL = 90.0

html, js = [], []
cut_points = []      # times where the picture dips through black
music_pts = [(0.0, 0.0), (1.2, 0.55)]

for i, (kind, start, dur, p) in enumerate(EDIT):
    cid = f"p{i:02d}"
    end = start + dur
    if kind == "shot":
        html.append(
            f'<video id="{cid}" class="clip shot" src="assets/shots/{p["src"]}.mp4" playsinline data-has-audio="true" '
            f'data-start="{start}" data-duration="{dur}" data-media-start="{p["from"]}" data-track-index="0" data-volume="1"></video>')
        if "lt" in p:
            a, b = p["lt"]
            html.append(
                f'<div id="{cid}-lt" class="clip lt" data-start="{start + 0.35:.2f}" data-duration="{dur - 0.65:.2f}" data-track-index="2">'
                f'<div class="lt-in"><b>{a}</b><span>{b}</span></div></div>')
            js.append(f'tl.fromTo("#{cid}-lt .lt-in", {{clipPath:"inset(0 100% 0 0)"}}, {{clipPath:"inset(0 0% 0 0)", duration:.45, ease:"power3.out"}}, {start + 0.4:.2f});')
            js.append(f'tl.fromTo("#{cid}-lt b", {{x:-24}}, {{x:0, duration:.5, ease:"power3.out"}}, {start + 0.45:.2f});')
            js.append(f'tl.to("#{cid}-lt .lt-in", {{clipPath:"inset(0 0% 0 100%)", duration:.3, ease:"power2.in"}}, {end - 0.6:.2f});')
        # music sits under the game's own sound during shots
        music_pts += [(start + 0.3, 0.30), (end - 0.3, 0.30)]
    else:
        music_pts += [(start + 0.3, 0.55), (end - 0.3, 0.55)]
        if kind == "card":
            fs = f' style="font-size:{p["size"]}px"' if "size" in p else ""
            lines = "".join(f'<div class="ln"><span{fs}>{l}</span></div>' for l in p["lines"])
            html.append(
                f'<section id="{cid}" class="clip card" data-start="{start}" data-duration="{dur}" data-track-index="1">'
                f'<img class="cbg" data-layout-allow-overflow src="assets/img/{p["bg"]}.jpg" alt="">'
                f'<div class="cwrap"><div class="rule"></div>{lines}</div>'
                f'<div class="tag"><b>REFEREE FOR FUN</b><span>v0.3.1</span></div></section>')
            js.append(f'tl.fromTo("#{cid} .cbg", {{scale:1.12}}, {{scale:1.0, duration:{dur}, ease:"none"}}, {start});')
            js.append(f'tl.fromTo("#{cid} .rule", {{scaleX:0}}, {{scaleX:1, duration:.4, ease:"power3.out"}}, {start + 0.15:.2f});')
            js.append(f'tl.fromTo("#{cid} .ln span", {{yPercent:110}}, {{yPercent:0, duration:.55, ease:"back.out(1.6)", stagger:.14}}, {start + 0.2:.2f});')
            js.append(f'tl.fromTo("#{cid} .tag", {{clipPath:"inset(0 100% 0 0)"}}, {{clipPath:"inset(0 0% 0 0)", duration:.4, ease:"power2.out"}}, {start + 0.5:.2f});')
            js.append(f'tl.to("#{cid} .ln span", {{yPercent:-110, duration:.3, ease:"power2.in", stagger:.06}}, {end - 0.45:.2f});')
        elif kind == "logo":
            html.append(
                f'<section id="{cid}" class="clip card logo-card" data-start="{start}" data-duration="{dur}" data-track-index="1">'
                f'<img class="cbg" data-layout-allow-overflow src="assets/img/bg-arena.jpg" alt=""><div class="lock"><img class="logo" src="assets/img/logo.png" alt="Referee For Fun">'
                f'<div class="slab"></div><p class="sub">You are the umpire, not the athlete.</p></div></section>')
            js.append(f'tl.fromTo("#{cid} .cbg", {{scale:1.15}}, {{scale:1.0, duration:{dur}, ease:"none"}}, {start});')
            js.append(f'tl.fromTo("#{cid} .logo", {{scale:1.35, opacity:0}}, {{scale:1, opacity:1, duration:.5, ease:"expo.out"}}, {start + 0.1:.2f});')
            js.append(f'tl.fromTo("#{cid} .slab", {{scaleX:0}}, {{scaleX:1, duration:.45, ease:"power3.out"}}, {start + 0.45:.2f});')
            js.append(f'tl.fromTo("#{cid} .sub", {{y:24, opacity:0}}, {{y:0, opacity:1, duration:.5, ease:"power3.out"}}, {start + 0.75:.2f});')
        elif kind == "rep":
            html.append(
                f'<section id="{cid}" class="clip card rep-card" data-start="{start}" data-duration="{dur}" data-track-index="1">'
                f'<img class="cbg" data-layout-allow-overflow src="assets/img/bg-hall.jpg" alt=""><div class="repwrap">'
                f'<div class="replabel"><b>REPUTATION</b><span>The hall is watching</span></div>'
                f'<div class="repnum"><span id="repv">72</span><small>/100</small><i id="repd">▼ 45</i></div>'
                f'<div class="meter"><div class="fill" id="repfill"></div></div></div></section>')
            js.append(f'tl.fromTo("#{cid} .replabel", {{clipPath:"inset(0 100% 0 0)"}}, {{clipPath:"inset(0 0% 0 0)", duration:.4, ease:"power3.out"}}, {start + 0.15:.2f});')
            js.append(f'tl.fromTo("#{cid} .repnum", {{y:40, opacity:0}}, {{y:0, opacity:1, duration:.45, ease:"back.out(1.7)"}}, {start + 0.25:.2f});')
            js.append(f'const rep = {{v:72}}; tl.to(rep, {{v:27, duration:2.4, ease:"power2.in", onUpdate:()=>{{document.getElementById("repv").textContent = Math.round(rep.v);}}}}, {start + 0.8:.2f});')
            js.append(f'tl.fromTo("#repfill", {{scaleX:.72}}, {{scaleX:.27, duration:2.4, ease:"power2.in"}}, {start + 0.8:.2f});')
            js.append(f'tl.fromTo("#repd", {{opacity:0, x:-16}}, {{opacity:1, x:0, duration:.3, ease:"power2.out"}}, {start + 2.9:.2f});')
            js.append(f'tl.fromTo("#{cid} .repwrap", {{x:0}}, {{x:10, duration:.05, repeat:7, yoyo:true, ease:"none"}}, {start + 3.0:.2f});')
        elif kind == "end":
            html.append(
                f'<section id="{cid}" class="clip card end-card" data-start="{start}" data-duration="{dur}" data-track-index="1">'
                f'<img class="cbg" data-layout-allow-overflow src="assets/img/bg-arena.jpg" alt=""><div class="lock"><img class="logo" src="assets/img/logo.png" alt="Referee For Fun">'
                f'<div class="slab"></div><p class="free">Free for macOS and Windows</p>'
                f'<div class="tag big"><b>OUT NOW · v0.3.1</b><span>juslangit.github.io/referee-for-fun</span></div></div></section>')
            js.append(f'tl.fromTo("#{cid} .cbg", {{scale:1.0}}, {{scale:1.1, duration:{dur}, ease:"none"}}, {start});')
            js.append(f'tl.fromTo("#{cid} .logo", {{scale:1.35, opacity:0}}, {{scale:1, opacity:1, duration:.55, ease:"expo.out"}}, {start + 0.15:.2f});')
            js.append(f'tl.fromTo("#{cid} .slab", {{scaleX:0}}, {{scaleX:1, duration:.45, ease:"power3.out"}}, {start + 0.5:.2f});')
            js.append(f'tl.fromTo("#{cid} .free", {{y:24, opacity:0}}, {{y:0, opacity:1, duration:.5, ease:"power3.out"}}, {start + 0.8:.2f});')
            js.append(f'tl.fromTo("#{cid} .tag", {{clipPath:"inset(0 100% 0 0)"}}, {{clipPath:"inset(0 0% 0 0)", duration:.5, ease:"power2.out"}}, {start + 1.2:.2f});')
    if not p.get("hard"):
        cut_points.append(start)

music_pts += [(TOTAL - 3.5, 0.6), (TOTAL, 0.0)]
music_pts = sorted({round(t, 2): v for t, v in music_pts}.items())
lane = {"version": 1, "lanes": [{"target": "volume", "points": [{"t": t, "v": v} for t, v in music_pts]}]}

# dips through black at every card/shot boundary; the sports montage cuts hard
for t in cut_points[1:]:
    js.append(f'tl.fromTo("#dip", {{opacity:0}}, {{opacity:1, duration:.18, ease:"power1.in"}}, {t - 0.18:.2f}).to("#dip", {{opacity:0, duration:.24, ease:"power1.out"}}, {t:.2f});')
js.insert(0, 'tl.fromTo("#dip", {opacity:1}, {opacity:0, duration:.5, ease:"power1.out"}, 0);')
js.append(f'tl.to("#dip", {{opacity:1, duration:1.0, ease:"power1.in"}}, {TOTAL - 1.0});')

page = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=1920, height=1080">
<title>Referee For Fun — v0.3.1 trailer</title>
<script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>
<style>
@font-face{{font-family:"Barlow Condensed";src:url("assets/fonts/BarlowCondensed-Bold.ttf") format("truetype");font-weight:700}}
@font-face{{font-family:"Barlow Semi Condensed";src:url("assets/fonts/BarlowSemiCondensed-SemiBold.ttf") format("truetype");font-weight:600}}
:root{{--hall:#0B1119;--panel:#141E2A;--chalk:#EDF2F8;--muted:#B4C3D3;--cap:#FFC22E;--ink:#1A1400;--red:#D63C36}}
body{{margin:0;background:var(--hall)}}
#root{{position:relative;width:100%;height:100%;overflow:hidden;background:var(--hall);font-family:"Barlow Condensed",sans-serif;color:var(--chalk)}}
.shot{{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}}
.card{{position:absolute;inset:0;overflow:hidden;background:var(--hall)}}
.cbg{{position:absolute;inset:-40px;width:calc(100% + 80px);height:calc(100% + 80px);object-fit:cover;filter:blur(14px) brightness(.28) saturate(1.2)}}
.ghost{{position:absolute;right:-60px;bottom:-120px;font-size:520px;line-height:1;font-weight:700;color:rgba(237,242,248,.045);letter-spacing:-.02em}}
.cwrap{{position:absolute;inset:0;padding:0 180px;display:flex;flex-direction:column;justify-content:center;gap:6px}}
.rule{{width:150px;height:12px;background:var(--cap);transform-origin:left;margin-bottom:26px}}
.ln{{overflow:hidden;padding-bottom:6px}}
.ln span{{display:block;font-size:118px;line-height:1.0;text-transform:uppercase;letter-spacing:-.005em}}
.ln + .ln span{{color:var(--cap)}}
.tag{{position:absolute;left:180px;bottom:90px;display:flex;align-items:stretch;background:#0d141d;border-left:10px solid var(--cap);font-family:"Barlow Semi Condensed",sans-serif;font-size:26px;letter-spacing:.08em;text-transform:uppercase}}
.tag b{{background:var(--cap);color:var(--ink);padding:12px 20px;font-weight:600}}
.tag span{{padding:12px 22px;color:var(--chalk)}}
.lock{{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:26px}}
.logo{{width:1180px;height:auto}}
.slab{{width:300px;height:16px;background:var(--cap);transform:skewX(-18deg);transform-origin:left}}
.sub{{margin:0;font-size:58px;text-transform:uppercase;color:var(--chalk)}}
.free{{margin:0;font-size:72px;text-transform:uppercase;color:var(--chalk)}}
.tag.big{{position:static;font-size:34px}}
.lt{{position:absolute;left:96px;bottom:330px}}
.lt-in{{display:flex;align-items:stretch;background:rgba(11,17,25,.92);border-left:10px solid var(--cap)}}
.lt-in b{{font-size:58px;line-height:1;padding:14px 26px 12px;text-transform:uppercase;color:var(--chalk)}}
.lt-in span{{display:flex;align-items:center;padding:0 26px;background:var(--cap);color:var(--ink);font-family:"Barlow Semi Condensed",sans-serif;font-weight:600;font-size:30px;letter-spacing:.04em;text-transform:uppercase}}
.repwrap{{position:absolute;inset:0;padding:0 180px;display:flex;flex-direction:column;justify-content:center;align-items:flex-start}}
.meter{{align-self:stretch}}
.replabel{{display:inline-flex;align-items:stretch;border-left:10px solid var(--cap);background:#0d141d;font-family:"Barlow Semi Condensed",sans-serif;font-size:34px;letter-spacing:.1em;text-transform:uppercase}}
.replabel b{{background:var(--cap);color:var(--ink);padding:12px 22px;font-weight:600}}
.replabel span{{padding:12px 24px}}
.repnum{{display:flex;align-items:baseline;gap:22px;margin-top:20px;font-variant-numeric:tabular-nums}}
.repnum span{{font-size:330px;line-height:.9}}
.repnum small{{font-size:90px;color:var(--muted)}}
.repnum i{{font-style:normal;font-size:120px;color:#FF6B63;margin-left:30px}}
.meter{{height:30px;background:#05080c;margin-top:20px}}
.fill{{height:100%;background:var(--cap);transform-origin:left}}
#dip{{position:absolute;inset:0;background:#000;pointer-events:none;z-index:50}}
</style>
</head>
<body>
<div id="root" data-composition-id="main" data-start="0" data-width="1920" data-height="1080" data-duration="{TOTAL}">
{chr(10).join(html)}
<audio id="music" src="assets/audio/music.m4a" data-start="0" data-duration="{TOTAL}" data-track-index="3" data-volume="0.55" data-automation='{json.dumps(lane)}'></audio>
<div id="dip"></div>
</div>
<script>
const tl = gsap.timeline({{ paused: true }});
{chr(10).join(js)}
window.__timelines["main"] = tl;
</script>
</body>
</html>
'''
OUT.write_text(page)
print("wrote", OUT, len(EDIT), "pieces", TOTAL, "s")
