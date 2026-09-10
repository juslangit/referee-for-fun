"""Builds every sound in the game from scratch.

    python3 tools/audio/make_sounds.py

Writes 16-bit mono WAVs into assets/audio/. No samples are downloaded and nothing here
is anybody else's work, which is the point: the repo already carries a careful trail of
CC-BY attribution for its models, and a sound library would add another one for eight
short noises that can be built in a page of arithmetic.

It is all one idea. A whistle is two close sine tones beating against each other. A
shuttle being struck is a very short burst of noise with the high end rolled off. A hall
full of people is band-limited noise wobbling slowly in volume, and applause is the same
noise chopped into hundreds of tiny bursts. None of it needs a sample library and none of
it needs numpy — a few hundred thousand floats is nothing.
"""

import array
import math
import os
import random
import struct
import sys
import wave

HERE = os.path.dirname(os.path.realpath(__file__))
OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "referee-for-fun", "assets", "audio")
if not os.path.isdir(os.path.dirname(OUT)):
    OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "audio")

RATE = 22050

# Everything is generated from a fixed seed so that re-running this produces byte-for-byte
# the same files. Otherwise every run shows up as a change in git for no reason at all.
random.seed(20260908)


# --- the pieces everything else is built from -----------------------------------

def silence(seconds):
    return [0.0] * int(seconds * RATE)


def white(seconds):
    return [random.uniform(-1.0, 1.0) for _ in range(int(seconds * RATE))]


def band_pass(samples, centre, resonance=1.4):
    """A Chamberlin state-variable filter — four lines, stable, and good enough.

    Used for everything with noise in it. A crowd is not white noise; it is noise with
    the extreme top and bottom taken off, which is most of what makes it sound like
    people rather than like static.
    """
    # Clamped well below the sample rate. This filter goes unstable somewhere above a
    # sixth of it, and "unstable" here does not mean a bit harsh — the first version of
    # the whistle asked for 6 kHz, the filter ran away, and what came out was a slab of
    # direct current with no tone in it at all. It measured 0 Hz, which is how it was
    # caught without anybody having to listen.
    f = 2.0 * math.sin(math.pi * min(centre, RATE / 6.0) / RATE)
    q = 1.0 / resonance
    low = band = 0.0
    out = []
    for sample in samples:
        high = sample - low - q * band
        band += f * high
        low += f * band
        out.append(band)
    return out


def low_pass(samples, cutoff):
    """A one-pole roll-off. Gentle, but stable at any cutoff, which the state-variable
    filter above is not — and this one is asked for cutoffs right up at the top end."""
    a = 1.0 - math.exp(-2.0 * math.pi * min(cutoff, RATE * 0.49) / RATE)
    out = []
    value = 0.0
    for sample in samples:
        value += a * (sample - value)
        out.append(value)
    return out


def envelope(samples, attack, decay, hold=0.0):
    """Fade in, hold, fade out. The decay is exponential because that is what things
    actually do — a linear fade sounds like somebody pulling a volume knob."""
    total = len(samples)
    rise = max(1, int(attack * RATE))
    flat = int(hold * RATE)
    out = []
    for i, sample in enumerate(samples):
        if i < rise:
            gain = i / rise
        elif i < rise + flat:
            gain = 1.0
        else:
            through = (i - rise - flat) / max(1, total - rise - flat)
            gain = math.exp(-through * decay)
        out.append(sample * gain)
    return out


def mix(*layers):
    longest = max(len(layer) for layer in layers)
    out = [0.0] * longest
    for layer in layers:
        for i, sample in enumerate(layer):
            out[i] += sample
    return out


def gain(samples, amount):
    return [sample * amount for sample in samples]


def normalise(samples, peak=0.89):
    loudest = max(abs(sample) for sample in samples) or 1.0
    return [sample * peak / loudest for sample in samples]


def seamless(samples, overlap=0.35):
    """Folds the tail of a loop back over its head so it can repeat without a click.

    A looping crowd bed is the only sound here that anybody will hear more than once in
    a row, and an audible seam every few seconds is worse than no crowd at all.
    """
    fold = int(overlap * RATE)
    if fold * 2 >= len(samples):
        return samples
    head = samples[:-fold]
    tail = samples[-fold:]
    for i in range(fold):
        through = i / fold
        head[i] = head[i] * through + tail[i] * (1.0 - through)
    return head


def write(name, samples):
    samples = normalise(samples)
    frames = array.array("h", (int(max(-1.0, min(1.0, s)) * 32767) for s in samples))
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(frames.tobytes())
    print("  %-22s %5.2f s  %6.0f KB" % (name, len(samples) / RATE, os.path.getsize(path) / 1024))


# --- the sounds -----------------------------------------------------------------

def whistle():
    """A pea whistle: two tones a few hertz apart, warbling against each other."""
    length = 0.62
    body = []
    for i in range(int(length * RATE)):
        t = i / RATE
        warble = 1.0 + 0.010 * math.sin(2.0 * math.pi * 24.0 * t)
        body.append(
            math.sin(2.0 * math.pi * 3520.0 * warble * t) * 0.62
            + math.sin(2.0 * math.pi * 3546.0 * t) * 0.38
        )
    breath = gain(low_pass(band_pass(white(length), 4200.0, 0.9), 6000.0), 0.14)
    return envelope(mix(body, breath), 0.012, 3.4, hold=length * 0.55)


def racket_hit(hard):
    """The shuttle being struck. A very short crack, brighter and louder on a smash."""
    length = 0.085 if hard else 0.065
    centre = 1750.0 if hard else 1150.0
    crack = band_pass(white(length), centre, 2.6)
    thud = low_pass(white(length), 420.0)
    return envelope(mix(gain(crack, 1.0), gain(thud, 0.5 if hard else 0.35)),
                    0.0008, 11.0 if hard else 13.0)


def shuttle_land():
    """Cork on a mat. Almost nothing — but silence here makes a landing feel unreal."""
    tap = band_pass(white(0.05), 820.0, 2.2)
    return envelope(gain(tap, 0.75), 0.001, 15.0)


def ring(freq, seconds, decay):
    """A damped sine: something hollow that has just been struck and is ringing.

    Nothing else in this file needed one. A shuttle, a volleyball and a tennis ball are
    all solid or stuffed and make a noise with no pitch in it — a burst of filtered
    noise is the whole truth of them. A table tennis ball is a hollow celluloid sphere
    40 mm across, and it **rings**: everybody who has ever heard the sport can hum the
    note. Build it out of noise and it sounds like a small tennis ball rather than like
    ping pong at all.
    """
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        out.append(math.sin(2.0 * math.pi * freq * t) * math.exp(-decay * t))
    return out


def bat_hit():
    """Celluloid on rubber. A short hollow tok with a click of contact on the front."""
    # The two tones are the ball and the blade behind it. A bat is a plywood board with
    # a sheet of sponge rubber on it, so the note it gives back is lower and shorter
    # than the ball's own — which is why a hit and a bounce are told apart by ear.
    body = mix(gain(ring(1180.0, 0.10, 46.0), 0.85),
               gain(ring(1810.0, 0.06, 78.0), 0.30))
    click = gain(band_pass(white(0.02), 3600.0, 2.4), 0.55)
    return envelope(normalise(mix(body, click), 0.82), 0.0006, 26.0)


def table_bounce():
    """The ball on the tabletop: higher, sharper and with the panel ringing under it.

    Deliberately close to `bat_hit` and deliberately not the same. In this sport the bat
    and the table make almost the same noise, which is exactly why the edge ball — a
    click off the top versus a click off the side, two centimetres apart — is the call
    the whole game is built around. If these two were easy to tell apart the sport would
    not need an umpire sitting level with the surface.
    """
    ball = mix(gain(ring(1520.0, 0.09, 52.0), 0.9),
               gain(ring(2270.0, 0.05, 96.0), 0.26))
    panel = gain(low_pass(white(0.045), 700.0), 0.22)
    return envelope(normalise(mix(ball, panel), 0.80), 0.0004, 30.0)


def crowd_bed(centre, wobble, roughness, seconds=6.0):
    # `centre` is where the voices sit; the roll-off above it is derived from it, so an
    # angrier crowd comes out brighter as well as louder without a second knob.
    """A hall full of people talking. Band-limited noise, breathing slowly.

    `roughness` adds a faster flutter on top of the slow swell — a calm crowd murmurs
    evenly, an angry one comes in gusts, and that difference is most of what tells the
    player the room has turned without a single word being said.
    """
    # Band-passed, then rolled off hard on top. The band-pass alone leaves far too much
    # high frequency — measured, the first attempt sat at 3 kHz, which is the sound of
    # static rather than of people. A hall full of bodies and soft furnishings absorbs
    # the top end, and voices do not have much up there to begin with.
    base = low_pass(band_pass(white(seconds), centre, 0.7), centre * 1.9)
    out = []
    for i, sample in enumerate(base):
        t = i / RATE
        swell = 1.0 + wobble * math.sin(2.0 * math.pi * 0.13 * t + 1.1)
        gust = 1.0 + roughness * math.sin(2.0 * math.pi * 0.9 * t + 0.3) * \
            math.sin(2.0 * math.pi * 0.37 * t)
        out.append(sample * swell * gust)
    return seamless(out)


def applause(seconds=2.4):
    """Hundreds of hands. Each clap is a two-millisecond burst; the density rises fast
    and falls away slowly, which is how a real hall claps."""
    out = silence(seconds)
    total = int(seconds * RATE)
    claps = 2200
    for _ in range(claps):
        through = random.random() ** 0.55
        at = int(through * total)
        shape = math.sin(math.pi * min(1.0, through * 1.35)) ** 0.6
        length = random.randint(30, 70)
        loudness = random.uniform(0.25, 1.0) * shape
        for j in range(length):
            if at + j >= total:
                break
            out[at + j] += random.uniform(-1.0, 1.0) * loudness * math.exp(-j / 14.0)
    return envelope(low_pass(band_pass(out, 2100.0, 0.8), 4200.0), 0.02, 2.2,
                    hold=seconds * 0.45)


def groan():
    """The noise a hall makes when it does not believe you. Low, and it swells."""
    length = 1.5
    body = low_pass(band_pass(white(length), 260.0, 1.1), 520.0)
    lower = low_pass(band_pass(white(length), 155.0, 1.3), 330.0)
    out = []
    for i in range(len(body)):
        t = i / RATE
        swell = math.sin(math.pi * min(1.0, t / length)) ** 0.7
        out.append((body[i] * 0.7 + lower[i] * 0.6) * swell)
    return envelope(out, 0.09, 1.6, hold=length * 0.35)


# Every sound this file can build, by the name it is written under.
#
# Named rather than written out one after another because several of these have since
# been replaced in the game by recordings, and re-running the script to add one new
# sound used to resurrect four dead files nothing loads any more. Pass the ones you
# want on the command line; pass nothing and it writes them all, as it always did.
SOUNDS = {
    "whistle.wav": whistle,
    "hit_soft.wav": lambda: racket_hit(False),
    "hit_hard.wav": lambda: racket_hit(True),
    "shuttle_land.wav": shuttle_land,
    "hit_pingpong.wav": bat_hit,
    "land_pingpong.wav": table_bounce,
    "crowd_calm.wav": lambda: crowd_bed(520.0, 0.16, 0.05),
    "crowd_tense.wav": lambda: crowd_bed(760.0, 0.30, 0.34),
    "applause.wav": applause,
    "groan.wav": groan,
}


def main(wanted=None):
    os.makedirs(OUT, exist_ok=True)
    print("writing to %s" % OUT)
    for name, build in SOUNDS.items():
        if wanted and name not in wanted:
            continue
        write(name, build())


if __name__ == "__main__":
    main(sys.argv[1:])
