#!/usr/bin/env python3
"""Builds docs/index.html: the whole record of Referee For Fun in one file.

Luqman asked on 2026-09-15 for one HTML file holding the entire pipeline of this game —
the idea, the planning, every decision and method, the session logs, and the screenshots
with their explanations — as a full technical record, kept in the repo and added to as the
work goes on. So this is a generator rather than a hand-written page: the project notes stay
the source of truth, and the page is rebuilt from them.

    python3 tools/docs/build_docs.py
    python3 tools/docs/build_docs.py --publish                # and put it on the website

The page is published as a website at SITE below. `docs-site publish` collects
every project's docs/index.html and deploys them together, so the link never
changes and anyone can open it.

Reads:
    ~/.claude/knowledge/projects/referee-for-fun/*.md and log/*.md   (override: KNOWLEDGE=...)
    dev/shots/*.png and docs/*.png                                  (the galleries below)
    dev/checks/*.gd, dev/looks/*.gd                                 (their ## headers)
    git log

Writes docs/index.html, fully self-contained: every screenshot is embedded as a JPEG. No
Python packages beyond the standard library; `sips` (built into macOS) shrinks the images.

To add something: put its screenshots in dev/shots, add a gallery entry to GALLERIES, and
run this again. Notes written into the knowledge base appear on their own.
"""

import base64
import datetime
import html
import os
import pathlib
import re
import subprocess
import tempfile

PROJECT = pathlib.Path(__file__).resolve().parents[2]
KNOWLEDGE = pathlib.Path(os.environ.get(
    "KNOWLEDGE", pathlib.Path.home() / ".claude/knowledge/projects/referee-for-fun"))
OUT = PROJECT / "docs" / "index.html"
SITE = "https://luqman-docs.netlify.app/referee-for-fun/"   # the page on the documentation website
SHOTS = PROJECT / "dev" / "shots"
IMAGE_WIDTH = 880
IMAGE_QUALITY = 62


# --- the galleries ---------------------------------------------------------------------
#
# Each gallery: (id, title, intro, [(file, caption), ...]). A file is a name in dev/shots or
# a path from the project root. The date under each picture is the file's own, so an old
# screenshot says it is old.

GALLERIES = [
    ("screens-interface", "The broadcast interface", "Every screen restyled on 2026-09-15 from real sports television, starting from two OpenArt concept mockups. Each sport's score bug copies that sport's own broadcast.", [
        ("dev/ref/ui-redesign/mockup_main_menu.png", "OpenArt mockup: the title screen as a sports-game home screen."),
        ("dev/ref/ui-redesign/mockup_hud_badminton.png", "OpenArt mockup: the badminton HUD modelled on BWF television. Its Q/E keys were wrong and not copied."),
        ("dev/ref/ui-redesign/sheet_portraits.png", "The five athletes, drawn together on one OpenArt sheet so they match, then cut into tiles."),
        ("_shot_menu_career", "The home screen as built: the career tile, the lessons, and every sport one click away."),
        ("hud_badminton", "Badminton, as BWF shows it: top left, the finished game in pale cells, the shuttle on the server, MATCH POINT."),
        ("hud_beach", "Beach volleyball, as the Beach Pro Tour shows it: one mirrored strip at the bottom centre."),
        ("hud_indoor", "Indoor volleyball, as the Nations League shows it: sets, points, the set number, SET POINT."),
        ("hud_tennis", "Tennis, as the tours show it: bottom left, the finished set, games lit, points 40-30."),
        ("hud_table_tennis", "Table tennis, as WTT shows it: games won in colour, points beside them, GAME POINT."),
        ("screen_review_answer", "The review card: OFFICIAL REVIEW over a big verdict bar, like the BWF and FIVB graphics."),
        ("screen_career", "The career: the ladder as broadcast plates, and all six sports in a grid."),
        ("screen_faults", "The fault panel, with the sides in their colours."),
        ("screen_settings", "Settings, with the sliders and switch drawn in the theme."),
        ("screen_ending", "FULL TIME."),
    ]),
    ("screens-venues", "Real-event venues", "Every sport dressed as a real Malaysian event on 2026-09-15: sponsor boards, a big screen, TV cameras and their operators, photographers, flags in the crowd, and the people and furniture at the side of the court. Modelled on the real events; every name and sponsor is invented. The top rung of each ladder is shown before and after, then all three rungs.", [
        ("dev/ref/events/logo_badminton.png", "OpenArt: the five event logos were generated on white, then keyed and trimmed by tools/events/prepare_event_art.gd."),
        ("dev/ref/events/sponsors_a.png", "OpenArt: twelve invented Malaysian sponsors on two sheets, cut into single logos for the boards."),
        ("dev/ref/events/crowd_banners.png", "OpenArt: supporters' banners, hung along the backs of the stands and held up in the crowd."),
        ("dev/shots/events/tennis_4_before_wide.png", "Tennis, top rung, before: an open court with two blocks of seats and nothing else."),
        ("dev/shots/events/tennis_4_wide.png", "After: the Kuala Lumpur Tennis Open, indoors like the Malaysian Open at Putra Stadium. Pale grey-blue surround, KUALA LUMPUR behind the baselines, royal-blue backdrop, the screen, cameras, ball kids."),
        ("dev/shots/events/tennis_4_chair.png", "From the umpire's chair."),
        ("dev/shots/events/tennis_0_wide.png", "The club courts: outdoors, green windbreak, printed boards every other panel, one camera."),
        ("dev/shots/events/table_tennis_4_before_wide.png", "Table tennis, top rung, before."),
        ("dev/shots/events/table_tennis_4_chair.png", "After, from the umpire's low chair: purple floor and black LED barriers with the sponsors glowing, like the 2016 World Team Table Tennis Championships in Kuala Lumpur."),
        ("dev/shots/events/table_tennis_4_wide.png", "The hall: salmon walls with a sponsor band, the camera on its platform behind the end barrier, the screen, flags."),
        ("dev/shots/events/table_tennis_2_far.png", "The national ranking event: printed boards on the barriers and magenta banners from the roof."),
        ("dev/shots/events/indoor_4_before_far.png", "Indoor volleyball, before: the hall's walls stood through the second row of seats."),
        ("dev/shots/events/indoor_4_wide.png", "After: the Gemilang Volleyball Championship. Orange court in a teal free zone, blue posts, LED boards, the wau kite on the end wall, the scorer's table and team benches opposite the referee."),
        ("dev/shots/events/indoor_4_chair.png", "From the referee's stand."),
        ("dev/shots/events/indoor_0_wide.png", "The sports hall at the bottom of the ladder: cream walls, a few printed boards, one camera on the floor."),
        ("dev/shots/events/beach_4_before_chair.png", "Beach volleyball, before: sand to the horizon."),
        ("dev/shots/events/beach_4_chair.png", "After: Pantai Cenang, Langkawi. The sea and the islands behind the stand, white sponsor banners on crowd barriers, team chairs under umbrellas, the crew in orange."),
        ("dev/shots/events/beach_4_far.png", "Looking back at the referee's side: palms, the inflatable arch, feather flags and a camera on its scaffold."),
        ("dev/shots/events/badminton_4_before_chair.png", "Badminton, before: boards with invented names in plain type."),
        ("dev/shots/events/badminton_4_chair.png", "After: the Nusantara Badminton Open. Sponsor logos on the LED boards, the flag in the crowd, supporters' banners along the stand."),
        ("dev/shots/events/badminton_4_wide.png", "The hall, with the event's logo on the video wall."),
    ]),
    ("screens-badminton", "Badminton", "The first sport, and the one every system was built on.", [
        ("sports", "Choosing a sport. Each card is a picture rendered from the game itself."),
        ("_shot_menu_main", "The title screen, over the hall."),
        ("format_badminton", "Singles or doubles, which are different jobs for the umpire."),
        ("brief_tournament", "A pre-match briefing: the tournament needs RED to go through. Pressure, never a bribe."),
        ("lesson_meter_badminton", "The last page of the lesson, YOUR NAME, which explains the reputation meter."),
        ("_shot_play", "A doubles rally, seen from the umpire's chair."),
        ("court_correct", "Service court: a correct line-up, server and receiver diagonally opposite."),
        ("court_wrong_server", "Service court error: the server in the wrong box, level with the receiver."),
        ("_shot_cam_2cm_out", "The line camera on a shuttle 2 cm out. Clear on big margins, deliberately ambiguous on close ones."),
        ("_shot_review_asked", "A Hawk-Eye challenge, available from the national championship up."),
        ("bubble", "The hall talks: speech bubbles over spectators, always about the umpire, never about the shuttle."),
        ("smash_rally_1", "Meshy's text-to-motion smash in a real rally, at full stretch."),
        ("windup", "The smash wind-up (left four frames) running into the smash (right four)."),
        ("commentary_badminton", "The Courtside Live caption, bottom left, clear of the reputation meter."),
        ("badminton_replay_flight", "The worst calls replayed at the final whistle: the flight."),
        ("badminton_replay_close", "Then the close-up, with what you called and what was true."),
        ("badminton_ending", "The result screen, the only screen allowed to state the truth."),
        ("badminton_paper_front", "The Morning Rally's front page, when a career ends."),
        ("history", "Every match so far, across all six sports."),
    ]),
    ("screens-tennis", "Tennis", "Chair umpire at the net, Fast4 at the first venues, and ends that change.", [
        ("format_tennis", "Singles or doubles: the tramlines are out in singles."),
        ("tennis_serve", "Tennis's own serve, watched from the chair."),
        ("tennis_call", "Waiting for the call, with the ball camera up."),
        ("line_judge_call", "The line judge's call, shown on the HUD as well as over their head."),
        ("tennis_above", "The court from above: stands along both sidelines, line judges at opposite corners."),
        ("commentary_tennis", "The commentators' caption in tennis."),
    ]),
    ("screens-table-tennis", "Table tennis", "No line judges, and that is the point. The umpire sits level with the table.", [
        ("cut_table_tennis_walk_on_22.0", "The match under way, from the umpire's low chair beside the net."),
        ("table_tennis_replay_flight", "Worst-call replay: the flight over the table."),
        ("table_tennis_replay_close", "The close-up: the serve clipped the net and was good, so it was a let."),
        ("table_tennis_ending", "Taken off, at a national ranking event."),
        ("table_tennis_paper_inside", "The Morning Rally's inside page."),
    ]),
    ("screens-beach", "Beach volleyball", "Two a side on sand, touch calls and the antenna.", [
        ("beach_rally", "A rally from the referee's stand."),
        ("beach_call", "The ball camera on a landing."),
        ("beach_judges", "Line judges at the corners of the sand."),
        ("beach_review", "A touch review: CALL OVERTURNED."),
        ("reputation_meter", "The reputation meter falling after a call."),
        ("beach_paper_inside", "The paper, when the calls went BLUE's way."),
    ]),
    ("screens-indoor", "Indoor volleyball", "Six a side, rotation, and the liberos in contrasting colours.", [
        ("indoor_rally", "A rally; the liberos wear yellow."),
        ("indoor_serve", "The serve."),
        ("vb_serve_frames", "\"Volleyball 1\": the serve keyed by hand from Luqman's Meshy screen recording."),
    ]),
    ("screens-takraw", "Sepak takraw", "The sixth sport, added 2026-09-15 by ISTAF's 2024 Law of the Game: regu and doubles, the serving side's feet held in painted circles until the kick, sets to 15 with setting up to 17, and no whistle.", [
        ("dev/ref/events/logo_sepak_takraw.png", "OpenArt (GPT Image 2): the Titiwangsa Sepak Takraw Champions Cup logo. Invented event, modelled on the 2026 World Cup final at Stadium Titiwangsa."),
        ("dev/ref/takraw/portrait_takraw_raw.png", "OpenArt (Nano Banana 2): the sixth athlete, drawn with the other five as its style reference."),
        ("sports", "The sport menu with six cards, fitting a 1280-pixel window."),
        ("format_takraw", "REGU or DOUBLES: three a side with a tekong and two inside players, or two a side served from behind the back line."),
        ("takraw_lineup", "From the referee's chair before the serve: the tekong in the service circle, the inside players in their quarter circles at the net."),
        ("takraw_kick", "An inside player has thrown; the tekong kicks the serve."),
        ("takraw_spike", "The bicycle-kick spike over a 1.52 m net, from the side."),
        ("takraw_landing", "The landing, with the overhead camera on the line."),
        ("takraw_foot_fault", "A service fault: the tekong's standing foot outside the circle. Drawn where the foot really is, and priced by how far out."),
        ("hud_takraw", "The score bug top left with an orange serve arrow, as ISTAF's world feed shows it."),
        ("st_poses_side", "The seven sepak takraw clips keyed in Blender (tools/meshy/takraw_clips.py): serve, throw, receive, header, set, spike, block."),
        ("dev/shots/events/takraw_0_wide.png", "Kampung open: a community hall, green mat, a few printed boards, one camera."),
        ("dev/shots/events/takraw_2_wide.png", "State games: a blue mat and hall, white sponsor boards, officials' table, flags."),
        ("dev/shots/events/takraw_4_wide.png", "Champions cup final: raspberry-pink mat, red padded posts, the screen, an LED ribbon, the assistant referee at the far post."),
        ("dev/shots/events/takraw_4_chair.png", "The final from the chair."),
    ]),
    ("screens-behind", "Behind the scenes", "Pictures taken to check the work rather than to show it.", [
        ("_shot_models", "An early model test, before the characters were forged in Blender."),
        ("_shot_meshy", "An early Meshy import, at the wrong scale: why models.gd measures everything."),
        ("vb_poses", "Volleyball clips posed in a row, to catch inverted arms and look-alike poses."),
        ("tennis_serve_poses", "The tennis serve in five phases: stance, toss, trophy, contact, follow-through."),
        ("judge_signals_out", "A line judge's OUT signal."),
        ("seat_before", "The stadium seat before simplifying it for 60 fps."),
        ("seat_after", "And after: the hall looks the same at a fraction of the triangles."),
        ("fps_everything_on", "The frame-rate measurement scene, everything switched on."),
        ("_shot_career_up", "The career screen after a promotion."),
        ("brief_grudge", "A grudge carried between matches: \"You know one of them\"."),
    ]),
    ("packaging", "Packaging", "What a player sees before the game starts: the disk image the Mac build installs from, dressed on 2026-09-17, and the icon the app wears. Both are drawn by tools/build/make_art.py from the game's own colours and title logo.", [
        ("tools/build/dmg/background.tiff", "The disk image window, 640x420. Finder places the game at 168,236 and the Applications shortcut at 472,236 — either side of the net, with the arrow crossing it. The court is a real doubles court: 13.4 m by 6.1 m, service lines 1.98 m from the net. This is the artwork, not a photograph of the window: the machine this was built on has no Screen Recording permission, so the window itself cannot be photographed."),
        ("assets/icon.png", "The app icon, 1024 px: the whistle from the title logo on a tile in the court mat's green. It replaced Godot's robot, which every build wore until then because application/icon was empty in both export presets. Crisp at the sizes Finder and the Dock use; soft here, because the whistle is only 136 px in the logo and there is no larger original."),
    ]),
]

# Cutscenes, sport by sport, with the procedure each follows and whether Luqman has
# reviewed it yet. (id, sport, status, source, rules, scenes); a scene is
# (title, when, [(file, time, caption), ...]).
CUTSCENES = [
    ("cutscenes-badminton", "Badminton", "Built 2026-09-15",
     "BWF Instructions to Technical Officials (ITTO) and the Umpire & Service Judge Instructions.",
     [("ITTO 5.1", "The umpire leads the players onto court."),
      ("Slides 9-12", "Umpire on the singles sideline, handshakes, one step in for the toss."),
      ("ITTO 5.3.1", "\"Ladies and gentlemen, on my right …, on my left …\""),
      ("ITTO 5.6.5", "Handshakes at the end, and the result announced only after them.")],
     [("Walk-on", "Before the first serve", [
         ("cut_walk_on_08.5", "8.5 s", "The umpire leads the players on."),
         ("cut_walk_on_12.0", "12.0 s", "Handshakes along the line."),
         ("cut_walk_on_15.5", "15.5 s", "The toss."),
         ("cut_walk_on_20.5", "20.5 s", "The announcement from the chair.")]),
      ("Match won", "After the last point", [
         ("cut_match_won_03.5", "3.5 s", "Winners celebrate, losers slump."),
         ("cut_match_won_06.0", "6.0 s", "Handshakes over the net."),
         ("cut_match_won_10.5", "10.5 s", "Then with the umpire in the chair.")]),
      ("Taken off", "When the hall has had enough", [
         ("cut_taken_off_03.5", "3.5 s", "The tournament referee comes onto court."),
         ("cut_taken_off_07.5", "7.5 s", "Down from the chair and shown the way out."),
         ("cut_taken_off_11.5", "11.5 s", "Walked off.")]),
      ("Moved up", "On CONTINUE after a promotion", [
         ("cut_moved_up_04.5", "4.5 s", "The new hall, floor to rafters, with its name.")])]),
    ("cutscenes-tennis", "Tennis", "Built 2026-09-15, waiting for Luqman's review",
     "ITF Duties and Procedures for Officials 2026.",
     [("D.4", "The chair umpire is on court before the players arrive."),
      ("D.5b", "The toss is made in front of both players, before the warm-up."),
      ("G.2a", "Introduction from the chair: to the left of the chair …, to the right …"),
      ("G.1a", "\"Time\", then \"… to serve, play\"."),
      ("G.4h", "\"Game, set and match …\" with every set's score, winner's games first."),
      ("T", "The Supervisor decides a default, so the Supervisor comes on court.")],
     [("Walk-on", "Before the first serve", [
         ("cut_tennis_walk_on_01.0", "1.0 s", "The court before anyone is on it."),
         ("cut_tennis_walk_on_07.0", "7.0 s", "The umpire is already waiting at the chair."),
         ("cut_tennis_walk_on_12.5", "12.5 s", "The toss, umpire between the two players."),
         ("cut_tennis_walk_on_doubles_17.0", "17.0 s, doubles", "Both pairs at the toss."),
         ("cut_tennis_walk_on_19.5", "19.5 s", "The introduction from the chair."),
         ("cut_tennis_walk_on_22.0", "22.0 s", "\"Time. BLUE to serve, play\", from behind the server.")]),
      ("Match won", "After the last point", [
         ("cut_tennis_match_won_03.5", "3.5 s", "Game, set and match RED, 6-4 6-3."),
         ("cut_tennis_match_won_06.0", "6.0 s", "Handshake across the net."),
         ("cut_tennis_match_won_doubles_06.0", "6.0 s, doubles", "Two handshakes across the net."),
         ("cut_tennis_match_won_11.0", "11.0 s", "A handshake with the umpire beside the chair.")]),
      ("Taken off", "When the hall has had enough", [
         ("cut_tennis_taken_off_04.0", "4.0 s", "The Supervisor walks out to the chair."),
         ("cut_tennis_taken_off_08.5", "8.5 s", "Down from the chair and pointed to the exit."),
         ("cut_tennis_taken_off_12.5", "12.5 s", "Walked off court.")]),
      ("Moved up", "On CONTINUE after a promotion", [
         ("cut_tennis_moved_up_02.5", "2.5 s", "From court level beside the net …"),
         ("cut_tennis_moved_up_06.5", "6.5 s", "… up over the new court.")])]),
    ("cutscenes-table-tennis", "Table tennis", "Built 2026-09-15, waiting for Luqman's review",
     "ITTF Handbook for Match Officials, 16th edition (2019).",
     [("Entry", "The umpire team enters by the corner nearest the umpire's chair; at feature matches the players walk in with them."),
      ("App. A 6-7", "Rackets checked, then a coin or disc tossed in front of both players for service and ends."),
      ("p.45", "The umpire sits in the chair for the practice period."),
      ("Start", "\"Time\", \"… versus …\", \"First game\", point to the server, \"… to serve\", \"Love all\"."),
      ("Post-match", "\"Game and match to …\", \"… wins 3 games to 1\"; the umpire leads the way out."),
      ("Not shown", "The assistant umpire: this game has no second official in table tennis.")],
     [("Walk-on", "Before the first serve", [
         ("cut_table_tennis_walk_on_04.5", "4.5 s", "The umpire comes in through the corner by the chair."),
         ("cut_table_tennis_walk_on_07.0", "7.0 s", "The players follow."),
         ("cut_table_tennis_walk_on_10.0", "10.0 s", "Rackets checked beside the net."),
         ("cut_table_tennis_walk_on_14.5", "14.5 s", "The toss, in front of both players."),
         ("cut_table_tennis_walk_on_17.0", "17.0 s", "Two minutes' practice, the umpire in the chair."),
         ("cut_table_tennis_walk_on_19.5", "19.5 s", "\"Time. RED versus BLUE. First game, RED to serve, love all.\"")]),
      ("Match won", "After the last point", [
         ("cut_table_tennis_match_won_02.5", "2.5 s", "Game and match to RED: RED wins 3 games to 0."),
         ("cut_table_tennis_match_won_04.8", "4.8 s", "To the side of the table at the net."),
         ("cut_table_tennis_match_won_06.2", "6.2 s", "The players shake hands."),
         ("cut_table_tennis_match_won_08.0", "8.0 s", "And the umpire, up from the chair, shakes both.")]),
      ("Taken off", "When the hall has had enough", [
         ("cut_table_tennis_taken_off_02.5", "2.5 s", "The referee comes to the table."),
         ("cut_table_tennis_taken_off_04.5", "4.5 s", "Beside the umpire's chair."),
         ("cut_table_tennis_taken_off_06.5", "6.5 s", "Down from the chair and pointed to the corner.")]),
      ("Moved up", "On CONTINUE after a promotion", [
         ("cut_table_tennis_moved_up_02.5", "2.5 s", "From table height …"),
         ("cut_table_tennis_moved_up_06.5", "6.5 s", "… up over the barriers of the new venue.")])]),
    ("cutscenes-indoor", "Indoor volleyball", "Built 2026-09-15, waiting for Luqman's review",
     "FIVB Refereeing Guidelines and Instructions (2024), International Playing Protocol, and the Official Volleyball Rules 2025-2028.",
     [("Rule 7.1", "The 1st referee carries out the toss in front of the scorer's table, with both captains."),
      ("Protocol", "The teams line up on the end lines; at the whistle they walk forward and shake hands with their opposite number at the net."),
      ("Protocol", "The referees are presented in the middle of the court by the net; the 1st referee then goes to the stand."),
      ("After", "The teams come along the sidelines to shake the referees' hands, then along the net with their opponents."),
      ("Delegate", "Removing a referee would fall to the Game Technical Delegate."),
      ("Not shown", "The 2nd referee: this game has only the 1st referee in play.")],
     [("Walk-on", "Before the first service", [
         ("cut_indoor_walk_on_04.5", "4.5 s", "The toss with both captains, before the warm-up."),
         ("cut_indoor_walk_on_10.0", "10.0 s", "The teams on the end lines."),
         ("cut_indoor_walk_on_12.5", "12.5 s", "At the whistle, forward to shake hands under the net."),
         ("cut_indoor_walk_on_17.0", "17.0 s", "The first referee presented."),
         ("cut_indoor_walk_on_19.5", "19.5 s", "On the stand: the whistle for the first service.")]),
      ("Match won", "After the last point", [
         ("cut_indoor_match_won_01.5", "1.5 s", "RED win, with every set's score."),
         ("cut_indoor_match_won_06.0", "6.0 s", "The teams come to the referee in front of the stand."),
         ("cut_indoor_match_won_08.5", "8.5 s", "And along the net with their opponents.")]),
      ("Taken off", "When the hall has had enough", [
         ("cut_indoor_taken_off_04.0", "4.0 s", "The Technical Delegate walks to the stand."),
         ("cut_indoor_taken_off_06.5", "6.5 s", "Down from the stand and pointed off."),
         ("cut_indoor_taken_off_10.5", "10.5 s", "Walked off court.")]),
      ("Moved up", "On CONTINUE after a promotion", [
         ("cut_indoor_moved_up_06.5", "6.5 s", "The new hall, from the floor to above the court.")])]),
    ("cutscenes-takraw", "Sepak takraw", "Built 2026-09-15, waiting for Luqman's review",
     "ISTAF Law of the Game 2024 (Law 8, the toss; Law 14.3, the Official Referee), Sepak Takraw Canada's match protocol, and the Thai Department of Physical Education referee manual (2012).",
     [("Law 8", "The Court Referee tosses the coin in front of both captains; the winner chooses to serve."),
      ("Protocol", "The teams are announced from behind their back lines, walk round the court and shake hands over the middle of the net."),
      ("Manual", "\"Players of both teams, shake hands.\" The referee then takes the chair and calls the score; there is no whistle."),
      ("After", "The result announced, the referees' hands shaken, then each other's over the net."),
      ("Law 14.3", "Only the Official Referee may stop a match, so the Official Referee takes a removed referee off.")],
     [("Walk-on", "Before the first service", [
         ("cut_takraw_walk_on_04.5", "4.5 s", "The teams announced from behind their back lines."),
         ("cut_takraw_walk_on_10.0", "10.0 s", "Hands shaken over the net."),
         ("cut_takraw_walk_on_14.5", "14.5 s", "The court referee's toss with both captains."),
         ("cut_takraw_walk_on_17.0", "17.0 s", "The referee on the chair: love all, and no whistle.")]),
      ("Match won", "After the last point", [
         ("cut_takraw_match_won_01.5", "1.5 s", "RED win, with every set's score."),
         ("cut_takraw_match_won_08.5", "8.5 s", "Hands shaken over the net."),
         ("cut_takraw_match_won_11.0", "11.0 s", "And the referee's.")]),
      ("Taken off", "When the hall has had enough", [
         ("cut_takraw_taken_off_04.0", "4.0 s", "The Official Referee comes to the chair."),
         ("cut_takraw_taken_off_10.5", "10.5 s", "Walked off court.")]),
      ("Moved up", "On CONTINUE after a promotion", [
         ("cut_takraw_moved_up_06.5", "6.5 s", "The new hall, from the floor to above the court.")])]),
    ("cutscenes-beach", "Beach volleyball", "Built 2026-09-15, waiting for Luqman's review",
     "FIVB Beach Volleyball Refereeing Guidelines and Instructions (2023), Official Match Protocol.",
     [("-5 min", "Coin toss in front of the scorer's table."),
      ("-1 min", "The 1st referee to the referee's chair; each player announced and entering onto the rear of the court."),
      ("0 min", "After the last entry, the whistle and a handshake under the net."),
      ("End", "Hands shaken with opponents and referees near the 1st referee's chair, then across the court to the scorer's table."),
      ("Delegate", "Removing a referee belongs to the FIVB Technical Delegate."),
      ("Not shown", "The 2nd referee, as indoors.")],
     [("Walk-on", "Before the first service", [
         ("cut_beach_walk_on_04.5", "4.5 s", "The coin toss, five minutes before play."),
         ("cut_beach_walk_on_12.5", "12.5 s", "Each player announced onto the rear of the court."),
         ("cut_beach_walk_on_14.5", "14.5 s", "The whistle, and hands shaken under the net."),
         ("cut_beach_walk_on_19.5", "19.5 s", "RED to serve, from the referee's stand.")]),
      ("Match won", "After the last point", [
         ("cut_beach_match_won_03.5", "3.5 s", "RED win: 2 sets to 0 and each set's score."),
         ("cut_beach_match_won_08.5", "8.5 s", "Handshakes by the referee's chair."),
         ("cut_beach_match_won_11.0", "11.0 s", "Then across the court to the scorer's table.")]),
      ("Taken off", "When the crowd has had enough", [
         ("cut_beach_taken_off_04.0", "4.0 s", "The Technical Delegate comes to the stand."),
         ("cut_beach_taken_off_08.5", "8.5 s", "Pointed off."),
         ("cut_beach_taken_off_10.5", "10.5 s", "Walked off the sand.")]),
      ("Moved up", "On CONTINUE after a promotion", [
         ("cut_beach_moved_up_06.5", "6.5 s", "The new venue, from the sand up over the stands.")])]),
]

CUTSCENES_TO_COME = []

# The knowledge base, in reading order. (id, title, file, fold level) — sections at the fold
# level fold away, so a 96 KB decision log can still be skimmed by its headings.
NOTES = [
    ("idea", "Idea", "01-idea.md", None),
    ("planning", "Planning", "02-planning.md", 2),
    ("milestones", "Milestones", "03-milestones.md", 2),
    ("decisions", "Decisions", "06-decisions.md", 2),
    ("methods", "Methods", "04-methods.md", 2),
    ("relations", "Relations", "05-relations.md", None),
    ("references", "References", "07-references.md", 2),
]


# --- markdown ------------------------------------------------------------------------------

def inline(text):
    """The inline half of markdown, on already-escaped text."""
    codes = []

    def keep(m):
        codes.append(m.group(1))
        return f"\x00{len(codes) - 1}\x00"

    text = re.sub(r"`([^`]+)`", keep, text)
    text = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)",
                  lambda m: f'<a href="{m.group(2)}">{m.group(1)}</a>'
                  if m.group(2).startswith(("http://", "https://")) else m.group(1), text)
    text = re.sub(r"(?<![\w&])(https?://[^\s<)]+)", r'<a href="\1">\1</a>', text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"~~(.+?)~~", r"<del>\1</del>", text)
    text = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?!\w)", r"<em>\1</em>", text)
    text = re.sub(r"(?<![\w])_(?!\s)(.+?)(?<!\s)_(?![\w])", r"<em>\1</em>", text)
    return re.sub(r"\x00(\d+)\x00", lambda m: f"<code>{codes[int(m.group(1))]}</code>", text)


def slug(text, taken):
    base = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:60] or "section"
    name, n = base, 2
    while name in taken:
        name, n = f"{base}-{n}", n + 1
    taken.add(name)
    return name


def markdown(source, prefix, taken, fold=None, drop_title=True):
    """Converts one notes file. Headings at `fold` open a <details> that holds everything
    until the next heading at that level or above."""
    source = re.sub(r"\A---\n.*?\n---\n", "", source, flags=re.S)
    lines = source.split("\n")
    out, para, lists, open_folds = [], [], [], 0
    i = 0

    def flush_para():
        if para:
            out.append("<p>" + inline(html.escape(" ".join(para), quote=False)) + "</p>")
            para.clear()

    def close_lists(to=0):
        while len(lists) > to:
            out.append(f"</{lists.pop()[0]}>")

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if stripped.startswith("```"):
            flush_para(); close_lists()
            block = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                block.append(lines[i])
                i += 1
            out.append("<pre><code>" + html.escape("\n".join(block)) + "</code></pre>")
            i += 1
            continue

        heading = re.match(r"^(#{1,4})\s+(.*)$", line)
        if heading:
            flush_para(); close_lists()
            level = len(heading.group(1))
            title = heading.group(2).strip()
            if level == 1 and drop_title:
                i += 1
                continue
            if fold is not None and level <= fold:
                while open_folds:
                    out.append("</div></details>")
                    open_folds -= 1
            anchor = slug(f"{prefix}-{title}", taken)
            if fold is not None and level == fold:
                out.append(f'<details class="fold" id="{anchor}"><summary><span>'
                           f"{inline(html.escape(title, quote=False))}</span></summary><div>")
                open_folds += 1
            else:
                tag = min(level + 1, 5)
                out.append(f'<h{tag} id="{anchor}">{inline(html.escape(title, quote=False))}</h{tag}>')
            i += 1
            continue

        if stripped.startswith("|") and i + 1 < len(lines) and re.match(r"^\s*\|[\s:|-]+\|\s*$", lines[i + 1]):
            flush_para(); close_lists()
            def cells(row):
                return [c.strip() for c in row.strip().strip("|").split("|")]
            head = cells(line)
            i += 2
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(cells(lines[i]))
                i += 1
            out.append('<div class="table"><table><thead><tr>' + "".join(
                f"<th>{inline(html.escape(c, quote=False))}</th>" for c in head) + "</tr></thead><tbody>")
            for row in rows:
                out.append("<tr>" + "".join(
                    f"<td>{inline(html.escape(c, quote=False))}</td>" for c in row) + "</tr>")
            out.append("</tbody></table></div>")
            continue

        item = re.match(r"^(\s*)([-*]|\d+\.)\s+(\[[ xX]\]\s+)?(.*)$", line)
        if item:
            flush_para()
            depth = len(item.group(1)) // 2
            kind = "ol" if item.group(2)[0].isdigit() else "ul"
            while len(lists) > depth + 1:
                out.append(f"</{lists.pop()[0]}>")
            if len(lists) == depth + 1 and lists[-1][0] != kind:
                out.append(f"</{lists.pop()[0]}>")
            if len(lists) < depth + 1:
                out.append(f"<{kind}>")
                lists.append((kind, depth))
            box = item.group(3)
            mark = ""
            if box:
                mark = '<span class="box done">done</span> ' if "x" in box.lower() else '<span class="box">to do</span> '
            text = item.group(4)
            # A continuation line indented under the item belongs to it.
            while i + 1 < len(lines) and lines[i + 1].startswith(" " * (len(item.group(1)) + 2)) \
                    and lines[i + 1].strip() and not lines[i + 1].strip().startswith("|") \
                    and not re.match(r"^\s*([-*]|\d+\.)\s+", lines[i + 1]):
                i += 1
                text += " " + lines[i].strip()
            out.append(f"<li>{mark}{inline(html.escape(text, quote=False))}</li>")
            i += 1
            continue

        if stripped.startswith(">"):
            flush_para(); close_lists()
            quote = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote.append(lines[i].strip()[1:].strip())
                i += 1
            out.append("<blockquote>" + inline(html.escape(" ".join(quote), quote=False)) + "</blockquote>")
            continue

        if re.match(r"^\s*(---|\*\*\*)\s*$", line):
            flush_para(); close_lists()
            i += 1
            continue

        if not stripped:
            flush_para()
            if not (i + 1 < len(lines) and re.match(r"^\s+([-*]|\d+\.)\s+", lines[i + 1])):
                close_lists()
            i += 1
            continue

        if lists and line.startswith("  ") and not stripped.startswith("|"):
            # Loose text under a list item.
            out[-1] = out[-1].replace("</li>", " " + inline(html.escape(stripped, quote=False)) + "</li>")
            i += 1
            continue

        close_lists()
        para.append(stripped)
        i += 1

    flush_para(); close_lists()
    while open_folds:
        out.append("</div></details>")
        open_folds -= 1
    return "\n".join(out)


# --- pictures ----------------------------------------------------------------------------

_cache = pathlib.Path(tempfile.gettempdir()) / "referee-docs-images"
_cache.mkdir(exist_ok=True)
missing = []


def picture(name):
    """(data URI, date) for a screenshot, or (None, None) when it is not there."""
    path = PROJECT / name if "/" in name else SHOTS / f"{name}.png"
    if not path.exists():
        missing.append(name)
        return None, None
    stamp = int(path.stat().st_mtime)
    jpeg = _cache / f"{path.stem}-{stamp}.jpg"
    if not jpeg.exists():
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", str(IMAGE_QUALITY),
                        "-Z", str(IMAGE_WIDTH), str(path), "--out", str(jpeg)],
                       check=True, capture_output=True)
    data = base64.b64encode(jpeg.read_bytes()).decode()
    return f"data:image/jpeg;base64,{data}", datetime.date.fromtimestamp(stamp).isoformat()


def figure(name, caption, label=""):
    uri, date = picture(name)
    if uri is None:
        return (f'<figure class="shot missing"><div class="gap">Screenshot not taken yet: '
                f"<code>{html.escape(name)}</code></div><figcaption>{html.escape(caption)}</figcaption></figure>")
    stamp = f'<span class="tc">{html.escape(label)}</span>' if label else ""
    return (f'<figure class="shot"><img src="{uri}" alt="{html.escape(caption)}" loading="lazy" '
            f'width="{IMAGE_WIDTH}" height="{IMAGE_WIDTH * 9 // 16}"><figcaption>{stamp}'
            f'<span>{html.escape(caption)}</span><span class="date">{date}</span></figcaption></figure>')


def grid(figures):
    return f'<div class="shots{" odd" if len(figures) % 2 else ""}">{"".join(figures)}</div>'


# --- the facts that can be counted ---------------------------------------------------------

def git(*args):
    return subprocess.run(["git", *args], cwd=PROJECT, capture_output=True, text=True).stdout


def counts():
    return [
        ("Sports", "6"),
        ("Scripts", str(len(list((PROJECT / "scripts").glob("*.gd"))))),
        ("Checks", str(len(list((PROJECT / "dev" / "checks").glob("*.gd"))))),
        ("Looks", str(len(list((PROJECT / "dev" / "looks").glob("*.gd"))))),
        ("Commits", git("rev-list", "--count", "HEAD").strip()),
        ("Decisions", str(len(re.findall(r"^## ", (KNOWLEDGE / "06-decisions.md").read_text(), re.M)))),
    ]


def header_comment(path):
    lines = []
    for line in path.read_text().split("\n"):
        if line.startswith("##"):
            text = line[2:].strip()
            if not text and lines:
                break
            if text:
                lines.append(text)
        elif lines:
            break
    return " ".join(lines)


def catalogue(folder):
    rows = []
    for path in sorted((PROJECT / "dev" / folder).glob("*.gd")):
        rows.append(f"<tr><td><code>{path.stem}</code></td>"
                    f"<td>{inline(html.escape(header_comment(path) or '—', quote=False))}</td></tr>")
    return '<div class="table"><table><thead><tr><th>Scene</th><th>What it asks</th></tr></thead><tbody>' \
        + "".join(rows) + "</tbody></table></div>"


def history():
    rows = []
    for line in git("log", "--date=short", "--pretty=format:%h\t%ad\t%s").split("\n"):
        if not line:
            continue
        sha, date, subject = line.split("\t", 2)
        merge = " merge" if subject.lower().startswith("merge") else ""
        rows.append(f'<tr class="{merge.strip()}"><td><code>{sha}</code></td><td class="nowrap">{date}</td>'
                    f"<td>{html.escape(subject)}</td></tr>")
    return '<div class="table"><table><thead><tr><th>Commit</th><th>Date</th><th>Change</th></tr></thead><tbody>' \
        + "".join(rows) + "</tbody></table></div>"


# --- the page ----------------------------------------------------------------------------------

PIPELINE = [
    ("Idea", "What is the game about, and what must it never do?", "01-idea.md, asked of Luqman before building"),
    ("Plan", "Scope, phases, risks, and the order things get built in.", "02-planning.md"),
    ("Research", "How the real sport does it, from its governing body's own documents: BWF, ITF, ITTF and FIVB.", "07-references.md"),
    ("Build", "GDScript in Godot 4.7.2; characters and clips in Blender; motion from Meshy; props from Sketchfab; sound through sfx.", "scripts/, tools/"),
    ("Check", "Headless scenes that end in PASS or FAIL, including the negative case.", "dev/checks/"),
    ("Look", "Screenshots at exact moments, read back and judged by eye.", "dev/looks/, dev/shots/"),
    ("Branch and merge", "One branch per piece of work, merged into main at Luqman's word.", "git"),
    ("Export", "macOS universal and Windows release builds.", "export_presets.cfg, build/"),
    ("Play and review", "Luqman plays and reports back; the notes record what was decided.", "log/, 06-decisions.md"),
]

TOOLS = [
    ("Godot 4.7.2", "Engine. Everything but the menus is built in code; the project runs headless for checks."),
    ("GDScript", "All game logic: 66 scripts on one shared match spine."),
    ("Blender", "character_forge.py builds the athletes; rig_clips.py merges hand-keyed and Meshy clips into each character."),
    ("Meshy AI", "Rigged characters, walk and run cycles, and the text-to-motion smash."),
    ("Sketchfab", "Stadium seats, props and the line judge, normalised by models.gd and props.gd."),
    ("sfx (Freesound, Kenney)", "CC0 sound only, with every file's source recorded in assets/audio/SOURCES.md."),
    ("git and GitHub", "Private repository juslangit/referee-for-fun; branch per feature."),
    ("Knowledge base", "The project notes this page is built from, kept outside the repo."),
]


def page():
    taken = set()
    overview = (KNOWLEDGE / "00-overview.md").read_text()
    thesis = re.search(r"^> (.+?)(?=\n\n)", overview, re.S | re.M)
    thesis = " ".join(l.lstrip("> ").strip() for l in thesis.group(0).split("\n")) if thesis else ""
    built = datetime.date.today().isoformat()

    toc, body = [], []

    # Cover
    stats = "".join(f'<div class="stat"><b>{v}</b><span>{k}</span></div>' for k, v in counts())
    uri, _ = picture("docs/rally.png")
    hero = (f'<img class="hero" src="{uri}" alt="A badminton rally from the chair" '
            f'width="{IMAGE_WIDTH}" height="495">') if uri else ""
    body.append(f'''
<header class="cover" id="top">
  <p class="eyebrow"><b>Referee For Fun</b><span>Project record · built {built}</span></p>
  <h1>Referee For Fun</h1>
  <p class="thesis">{inline(html.escape(thesis, quote=False))}</p>
  <div class="stats">{stats}</div>
  {hero}
</header>''')

    # Pipeline
    toc.append(("pipeline", "Pipeline", []))
    steps = "".join(f'<li><b>{html.escape(a)}</b><span>{html.escape(b)}</span><code>{html.escape(c)}</code></li>'
                    for a, b, c in PIPELINE)
    tools = "".join(f"<tr><td><strong>{html.escape(a)}</strong></td><td>{html.escape(b)}</td></tr>" for a, b in TOOLS)
    body.append(f'''
<section class="chapter" id="pipeline">
  <p class="kicker">How the game gets made</p>
  <h2>Pipeline</h2>
  <p class="lede">Every feature has gone round the same loop: decide what the game must and must not do, look up how the real sport does it, build it, prove it with a headless check, look at it, and only then merge it. The notes further down are the record of each pass.</p>
  <ol class="pipeline">{steps}</ol>
  <h3 id="tools">Tools</h3>
  <div class="table"><table><tbody>{tools}</tbody></table></div>
</section>''')

    # Screens
    subs = []
    parts = []
    for gid, title, intro, shots in GALLERIES:
        subs.append((gid, title))
        parts.append(f'<section class="gallery" id="{gid}"><h3>{html.escape(title)}</h3>'
                     f'<p class="note">{html.escape(intro)}</p>{grid([figure(n, c) for n, c in shots])}</section>')
    toc.append(("screens", "Screens", subs))
    body.append(f'''
<section class="chapter" id="screens">
  <p class="kicker">What the player sees</p>
  <h2>Screens</h2>
  <p class="lede">Screenshots from the game, sport by sport. Each carries the date it was taken: older ones show the game as it was then, and are kept as a record rather than replaced.</p>
  {"".join(parts)}
</section>''')

    # Cutscenes
    subs, parts = [], []
    for cid, sport, status, source, rules, scenes in CUTSCENES:
        subs.append((cid, sport))
        rule_rows = "".join(f'<li><span class="ref">{html.escape(r)}</span><span>{html.escape(t)}</span></li>'
                            for r, t in rules)
        scene_parts = "".join(
            f'<div class="scene"><h4>{html.escape(t)} <small>{html.escape(w)}</small></h4>'
            f'{grid([figure(n, c, label) for n, label, c in frames])}</div>'
            for t, w, frames in scenes)
        parts.append(f'''<section class="gallery" id="{cid}">
  <h3>{html.escape(sport)} <span class="status">{html.escape(status)}</span></h3>
  <p class="note">Staged from the {html.escape(source)}</p>
  <ul class="rules">{rule_rows}</ul>
  {scene_parts}
</section>''')
    to_come = ", ".join(CUTSCENES_TO_COME)
    toc.append(("cutscenes", "Cutscenes", subs))
    body.append(f'''
<section class="chapter" id="cutscenes">
  <p class="kicker">The four moments the chair cannot show</p>
  <h2>Cutscenes</h2>
  <p class="lede">Walk-on, match won, taken off and moved up, shot like television and skippable with SPACE. Every sport follows its own governing body's real procedure.{(" Still to come: " + html.escape(to_come) + ".") if to_come else ""}</p>
  {"".join(parts)}
</section>''')

    # The notes
    for nid, title, name, fold in NOTES:
        path = KNOWLEDGE / name
        if not path.exists():
            continue
        text = path.read_text()
        converted = markdown(text, nid, taken, fold)
        heads = [h for h in re.findall(r"^## (.+)$", re.sub(r"```.*?```", "", text, flags=re.S), re.M)]
        folds = ' <button class="unfold" type="button" data-for="%s">Open all</button>' % nid if fold else ""
        toc.append((nid, title, []))
        body.append(f'''
<section class="chapter notes" id="{nid}">
  <p class="kicker">{html.escape(name)} · {len(heads)} sections{folds}</p>
  <h2>{html.escape(title)}</h2>
  <div class="prose">{converted}</div>
</section>''')

    # Logs
    logs = sorted((p for p in (KNOWLEDGE / "log").glob("*.md") if not p.name.startswith("_")), reverse=True)
    entries = "".join(
        f'<details class="fold" id="log-{p.stem}"><summary><span>{p.stem}</span></summary>'
        f'<div>{markdown(p.read_text(), "log-" + p.stem, taken, None)}</div></details>'
        for p in logs)
    toc.append(("log", "Session log", []))
    body.append(f'''
<section class="chapter notes" id="log">
  <p class="kicker">log/ · {len(logs)} sessions <button class="unfold" type="button" data-for="log">Open all</button></p>
  <h2>Session log</h2>
  <div class="prose">{entries}</div>
</section>''')

    # Catalogues
    toc.append(("checks", "Checks and looks", []))
    body.append(f'''
<section class="chapter" id="checks">
  <p class="kicker">dev/checks and dev/looks, from each scene's own header</p>
  <h2>Checks and looks</h2>
  <p class="lede">A check runs headless and ends in a verdict. A look takes screenshots for a person to judge. Both are scenes under <code>res://dev/</code>, which save to their own career and settings files.</p>
  <details class="fold"><summary><span>Checks</span></summary><div>{catalogue("checks")}</div></details>
  <details class="fold"><summary><span>Looks</span></summary><div>{catalogue("looks")}</div></details>
</section>''')
    toc.append(("history", "Git history", []))
    body.append(f'''
<section class="chapter" id="history">
  <p class="kicker">git log, newest first</p>
  <h2>Git history</h2>
  <details class="fold"><summary><span>Every commit</span></summary><div>{history()}</div></details>
</section>''')

    nav = []
    for tid, title, subs in toc:
        inner = "".join(f'<li><a href="#{sid}">{html.escape(st)}</a></li>' for sid, st in subs)
        nav.append(f'<li><a href="#{tid}">{html.escape(title)}</a>{f"<ul>{inner}</ul>" if inner else ""}</li>')

    return TEMPLATE.replace("{{NAV}}", "".join(nav)).replace("{{BODY}}", "".join(body))


TEMPLATE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Referee For Fun Record</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@600;700&family=IBM+Plex+Mono:wght@500&family=IBM+Plex+Sans:ital,wght@0,400;0,500;0,600;1,400&display=swap">
<style>
:root {
  --ground: #F3F6FA; --surface: #FFFFFF; --ink: #14202E; --muted: #56667A; --line: #D6DFE9;
  --court: #2C68AC; --court-soft: #E3ECF7; --caption: #FFC22E; --caption-ink: #1A1400;
  --done: #2E7D4F; --display: "Barlow Condensed", "Arial Narrow", "Helvetica Neue", Arial, sans-serif;
  --body: "IBM Plex Sans", "Helvetica Neue", Arial, sans-serif; --mono: "IBM Plex Mono", ui-monospace, Menlo, monospace;
  color-scheme: light;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { --ground: #0D1621; --surface: #142131; --ink: #E7EDF4; --muted: #95A5B8;
    --line: #253649; --court: #6AA6E8; --court-soft: #18304A; --done: #6CC592; color-scheme: dark; }
}
:root[data-theme="dark"] { --ground: #0D1621; --surface: #142131; --ink: #E7EDF4; --muted: #95A5B8;
  --line: #253649; --court: #6AA6E8; --court-soft: #18304A; --done: #6CC592; color-scheme: dark; }
* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
@media (prefers-reduced-motion: reduce) { html { scroll-behavior: auto; } }
body { margin: 0; background: var(--ground); color: var(--ink); font: 400 16px/1.6 var(--body); padding-inline: 20px; }
a { color: var(--court); }
a:focus-visible, button:focus-visible, summary:focus-visible { outline: 2px solid var(--court); outline-offset: 2px; }
.layout { max-width: 1320px; margin: 0 auto; display: grid; grid-template-columns: 220px minmax(0, 1fr); gap: 48px; padding-block: 32px 96px; }
nav.toc { position: sticky; top: calc(env(safe-area-inset-top, 0px) + 20px); align-self: start; max-height: calc(100vh - 40px); overflow-y: auto; font-size: 14px; }
nav.toc > ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 4px; }
nav.toc > ul > li > a { font: 700 16px/1.3 var(--display); letter-spacing: .06em; text-transform: uppercase; color: var(--ink); text-decoration: none; }
nav.toc ul ul { list-style: none; margin: 2px 0 8px; padding: 0 0 0 10px; border-left: 1px solid var(--line); display: grid; gap: 1px; }
nav.toc ul ul a { color: var(--muted); text-decoration: none; }
nav.toc a:hover { color: var(--court); }
main { display: grid; gap: 72px; min-width: 0; }
.eyebrow { display: inline-flex; gap: 10px; align-items: center; margin: 0; font: 700 14px/1 var(--display); letter-spacing: .12em; text-transform: uppercase; }
.eyebrow b { background: var(--caption); color: var(--caption-ink); padding: 5px 9px; }
.eyebrow span { color: var(--muted); }
h1 { font: 700 clamp(44px, 7vw, 84px)/.92 var(--display); text-transform: uppercase; margin: 14px 0 12px; text-wrap: balance; }
.thesis { max-width: 68ch; margin: 0; font-size: 18px; }
.stats { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 0; margin: 28px 0; border-block: 2px solid var(--ink); }
.stat { padding: 12px 14px; display: grid; gap: 2px; border-left: 1px solid var(--line); }
.stat:first-child { border-left: 0; padding-left: 0; }
.stat b { font: 700 34px/1 var(--display); font-variant-numeric: tabular-nums; }
.stat span { font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }
.hero { width: 100%; max-width: 100%; height: auto; display: block; }
.chapter { display: grid; gap: 14px; scroll-margin-top: 16px; }
.kicker { margin: 0; font-size: 13px; color: var(--muted); display: flex; flex-wrap: wrap; gap: 12px; align-items: center; }
h2 { font: 700 48px/1 var(--display); text-transform: uppercase; margin: 0 0 6px; padding-bottom: 10px; border-bottom: 2px solid var(--ink); }
h3 { font: 700 30px/1.05 var(--display); text-transform: uppercase; margin: 24px 0 4px; scroll-margin-top: 16px; }
h4 { font: 700 21px/1.1 var(--display); text-transform: uppercase; letter-spacing: .02em; margin: 18px 0 8px; }
h4 small { font: 400 14px var(--body); text-transform: none; color: var(--muted); margin-left: 8px; }
h5 { font: 600 16px/1.3 var(--body); margin: 18px 0 4px; }
.lede, .note { max-width: 70ch; margin: 0; color: var(--muted); }
.gallery { scroll-margin-top: 16px; display: grid; gap: 8px; }
.status { font: 500 12px/1 var(--mono); text-transform: none; letter-spacing: 0; color: var(--court); background: var(--court-soft); padding: 4px 8px; vertical-align: middle; }
.shots { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px; margin-top: 10px; }
.shots.odd > .shot:first-child { grid-column: 1 / -1; }
.shots.odd > .shot:first-child img { max-height: 520px; object-fit: cover; }
.shot { margin: 0; display: grid; gap: 6px; align-content: start; }
.shot img { display: block; width: 100%; max-width: 100%; height: auto; background: var(--line); }
.shot figcaption { font-size: 14px; line-height: 1.4; display: grid; grid-template-columns: auto 1fr auto; gap: 10px; align-items: baseline; }
.tc, .date { font: 500 12px/1 var(--mono); color: var(--muted); white-space: nowrap; font-variant-numeric: tabular-nums; }
.missing .gap { aspect-ratio: 16 / 9; display: grid; place-items: center; border: 1px dashed var(--line); color: var(--muted); font-size: 14px; padding: 16px; text-align: center; }
.rules { list-style: none; margin: 8px 0 0; padding: 0; display: grid; gap: 6px; max-width: 80ch; }
.rules li { display: grid; grid-template-columns: 92px 1fr; gap: 12px; font-size: 14.5px; }
.ref { font: 500 12px/1.7 var(--mono); color: var(--court); background: var(--court-soft); text-align: center; align-self: start; }
.pipeline { list-style: none; counter-reset: step; margin: 10px 0 0; padding: 0; display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0; border-top: 1px solid var(--line); border-left: 1px solid var(--line); }
.pipeline li { counter-increment: step; padding: 14px 16px 16px; display: grid; gap: 4px; align-content: start; border-right: 1px solid var(--line); border-bottom: 1px solid var(--line); background: var(--surface); }
.pipeline b { font: 700 20px/1 var(--display); text-transform: uppercase; }
.pipeline b::before { content: counter(step) "  "; color: var(--court); font-family: var(--mono); font-size: 13px; font-weight: 500; }
.pipeline span { font-size: 14.5px; }
.pipeline code { font-size: 12px; color: var(--muted); justify-self: start; }
.prose { max-width: 82ch; display: grid; gap: 0; }
.prose p, .prose ul, .prose ol, .prose blockquote, .prose pre, .prose .table { margin: 0 0 12px; }
.prose ul, .prose ol { padding-left: 22px; }
.prose li { margin: 3px 0; }
.prose blockquote { border-left: 3px solid var(--caption); padding: 4px 0 4px 14px; color: var(--muted); }
code { font: 500 .86em var(--mono); background: var(--court-soft); padding: 1px 4px; overflow-wrap: anywhere; }
pre { background: var(--surface); border: 1px solid var(--line); padding: 12px 14px; overflow-x: auto; }
pre code { background: none; padding: 0; overflow-wrap: normal; white-space: pre; }
.table { overflow-x: auto; }
table { border-collapse: collapse; width: 100%; font-size: 14px; }
th, td { text-align: left; vertical-align: top; padding: 7px 10px; border-bottom: 1px solid var(--line); }
th { font: 700 14px/1.2 var(--display); letter-spacing: .08em; text-transform: uppercase; color: var(--muted); border-bottom: 2px solid var(--ink); }
.chapter > .table td:first-child { width: 220px; }
tr.merge td { color: var(--muted); }
.nowrap { white-space: nowrap; font-variant-numeric: tabular-nums; }
del { color: var(--muted); }
.box { font: 500 11px/1 var(--mono); padding: 2px 5px; border: 1px solid var(--line); color: var(--muted); vertical-align: 1px; }
.box.done { color: var(--done); border-color: var(--done); }
details.fold { border-bottom: 1px solid var(--line); scroll-margin-top: 16px; }
details.fold > summary { cursor: pointer; list-style: none; padding: 10px 0; display: flex; gap: 10px; align-items: baseline; font: 600 16px/1.35 var(--body); }
details.fold > summary::-webkit-details-marker { display: none; }
details.fold > summary::before { content: "+"; font: 500 14px var(--mono); color: var(--court); width: 12px; flex: none; }
details.fold[open] > summary::before { content: "\\2212"; }
details.fold > div { padding: 2px 0 18px 22px; }
.unfold { font: 600 12px/1 var(--body); color: var(--court); background: var(--surface); border: 1px solid var(--line); padding: 5px 9px; cursor: pointer; }
.unfold:hover { border-color: var(--court); }
@media (max-width: 980px) {
  .layout { grid-template-columns: 1fr; gap: 24px; }
  nav.toc { position: static; max-height: none; border-bottom: 2px solid var(--ink); padding-bottom: 14px; }
  nav.toc > ul { grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); }
  nav.toc ul ul { display: none; }
  .stats { grid-template-columns: repeat(3, minmax(0, 1fr)); }
  .stat:nth-child(4) { border-left: 0; padding-left: 0; }
  .pipeline { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (max-width: 560px) {
  .shots { grid-template-columns: 1fr; }
  .pipeline { grid-template-columns: 1fr; }
  h2 { font-size: 38px; }
  .rules li { grid-template-columns: 1fr; gap: 2px; }
  .ref { justify-self: start; padding: 0 6px; }
  .shot figcaption { grid-template-columns: 1fr; gap: 2px; }
}
</style>
</head>
<body>
<div class="layout">
  <nav class="toc" aria-label="Contents"><ul>{{NAV}}</ul></nav>
  <main>{{BODY}}</main>
</div>
<script>
document.querySelectorAll(".unfold").forEach(function (button) {
  button.addEventListener("click", function () {
    var section = document.getElementById(button.dataset.for);
    var folds = section.querySelectorAll("details.fold");
    var opening = button.textContent === "Open all";
    folds.forEach(function (d) { d.open = opening; });
    button.textContent = opening ? "Close all" : "Open all";
  });
});
// A link to something inside a closed fold opens the fold.
function openTarget() {
  var target = location.hash && document.getElementById(decodeURIComponent(location.hash.slice(1)));
  for (var node = target; node; node = node.parentElement) {
    if (node.tagName === "DETAILS") node.open = true;
  }
  if (target) target.scrollIntoView();
}
window.addEventListener("hashchange", openTarget);
openTarget();
</script>
</body>
</html>
"""



if __name__ == "__main__":
    import sys
    OUT.parent.mkdir(exist_ok=True)
    document = page()
    OUT.write_text(document)
    if "--publish" in sys.argv:
        subprocess.run(["docs-site", "publish"], check=True)
    size = OUT.stat().st_size / 1024 / 1024
    print(f"wrote {OUT.relative_to(PROJECT)}  ({size:.1f} MB)")
    if missing:
        print("screenshots not found (shown as gaps):", ", ".join(missing))
