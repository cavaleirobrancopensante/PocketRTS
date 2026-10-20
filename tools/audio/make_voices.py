"""PocketRTS voices (groups F, G, H of AUDIO_PROMPTS.md): unit lines, announcers, AI taunts.

    KOKORO_DIR=/path/to/models python3 tools/audio/make_voices.py [filter ...]
    python3 tools/audio/make_voices.py --models /path/to/models [filter ...]

The model dir must contain kokoro-v1.0.onnx and voices-v1.0.bin from
https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.0 (keep them out of the repo).
Needs: pip install kokoro-onnx soundfile librosa pyworld numba scipy

Crown: Kokoro British voices + warmth EQ and room reverb (herald/general: deeper, slower, bigger hall).
Clockwork: Kokoro voice -> WORLD resynthesis with a flat monotone pitch, ring modulation, chorus and a
metallic comb filter. Brood: units are synthesised creature calls (no words); the hive-mind lines are
WORLD-whispered TTS layered at several pitch shifts with hiss.
Output: mono 44.1 kHz 16-bit WAV, trimmed, peak -3 dBFS, under 2.5 s.
"""
import os
import sys
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dsp import *  # noqa: E402,F401,F403
import make_sfx2 as fx  # noqa: E402  (creature/screech/chitter building blocks)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "voice")
MAX_LEN = 2.4
PEAK = -3.0

_kokoro = None


def kokoro():
    global _kokoro
    if _kokoro is None:
        from kokoro_onnx import Kokoro
        d = os.environ.get("KOKORO_DIR")
        if "--models" in sys.argv:
            d = sys.argv[sys.argv.index("--models") + 1]
        if not d:
            sys.exit("set KOKORO_DIR or pass --models <dir> (kokoro-v1.0.onnx + voices-v1.0.bin)")
        _kokoro = Kokoro(os.path.join(d, "kokoro-v1.0.onnx"), os.path.join(d, "voices-v1.0.bin"))
    return _kokoro


def trim(x, db=-38, start_db=None, pre=0.01):
    """Cut leading/trailing silence. start_db: separate (tighter) threshold for the start."""
    a = np.abs(x)
    env = np.convolve(a, np.ones(256) / 256, mode="same")   # smoothed: don't stop inside a word gap
    pk = env.max() + 1e-12
    idx = np.nonzero(env > pk * 10 ** (db / 20))[0]
    if not len(idx):
        return x
    st = idx[0]
    if start_db is not None:
        st = np.nonzero(env > pk * 10 ** (start_db / 20))[0][0]
    s = max(0, st - int(pre * SR))
    e = min(len(x), idx[-1] + int(0.03 * SR))
    return x[s:e]


def tts(text, voice, speed=1.0, semis=0.0):
    """Kokoro -> 44.1 kHz, trimmed. Raises speed automatically if the line gets too long."""
    lang = "en-gb" if voice[0] == "b" else "en-us"
    for sp in [speed, speed * 1.12, speed * 1.25, speed * 1.4]:
        y, sr = kokoro().create(text, voice=voice, speed=min(sp, 1.6), lang=lang)
        y = resample_poly(np.asarray(y, dtype=np.float64), 147, 80)  # 24k -> 44.1k
        y = trim(y)
        if len(y) / SR <= MAX_LEN - 0.25:
            break
    if semis:
        import librosa
        y = librosa.effects.pitch_shift(y, sr=SR, n_steps=semis)
    return y


def out_write(rel, x, peak=PEAK, max_len=MAX_LEN):
    x = trim(x, -44, start_db=-26, pre=0.006)
    if len(x) / SR > max_len:      # dry speech is already <= MAX_LEN-0.25 s: cut the reverb tail
        x = x[:N(max_len)].copy()
        f = N(0.2)
        x[-f:] *= np.linspace(1, 0, f) ** 2
    x = finish(x, peak, fade_in=0.003, fade_out=0.03, trim=False)
    # the longer announcer/taunt lines go out as Ogg Vorbis to keep the build small (game loads .wav or .ogg)
    ext = ".ogg" if rel.startswith(("announcer/", "taunt/")) else ".wav"
    path = os.path.join(OUT, rel + ext)
    other = os.path.join(OUT, rel + (".wav" if ext == ".ogg" else ".ogg"))
    if os.path.exists(other):
        os.remove(other)
    (write_ogg if ext == ".ogg" else write_wav)(path, x)
    print("ok", rel, f"{len(x) / SR:.2f}s", flush=True)


# ------------------------------------------------------------------ processing chains

def warm_room(x, rng, rt=0.35, wet=0.12, warmth=0.35):
    x = x + warmth * lp(x, 260)          # low-mid warmth
    x = x - 0.25 * hp(x, 7500)           # soften sibilance a touch
    return reverb(x, rng, rt=rt, wet=wet, pre=0.012, damp=5000)


def herald(x, rng):
    x = x + 0.5 * lp(x, 220)
    x = reverb(x, rng, rt=1.1, wet=0.2, pre=0.025, damp=4500)
    return x


def robot(x, rng, f0=105.0, ring=80.0, ring_mix=0.35, comb_ms=3.3, comb_g=0.45, chorus=True):
    import pyworld as pw
    xs = np.ascontiguousarray(x.astype(np.float64))
    f, t = pw.harvest(xs, SR, f0_floor=60, f0_ceil=500, frame_period=5.0)
    sp = pw.cheaptrick(xs, f, t, SR)
    ap = pw.d4c(xs, f, t, SR)
    voiced = f > 0
    flat = np.where(voiced, f0, 0.0)            # pitch-flattened monotone
    y = pw.synthesize(flat, sp, ap, SR, 5.0)[:len(x)]
    y = fit(y, len(x) / SR + 1e-9)[:len(x)]
    tt = np.arange(len(y)) / SR
    rm = y * np.sin(2 * np.pi * ring * tt)
    y = (1 - ring_mix) * y + ring_mix * rm
    if chorus:
        d1 = int(0.011 * SR)
        y2 = np.concatenate([np.zeros(d1), y])[:len(y)]
        y = y + 0.35 * y2
    y = comb(y, comb_ms / 1000, comb_g)
    y = comb(y, comb_ms * 1.61 / 1000, comb_g * 0.6)
    y = bp(y, 160, 7000)
    return reverb(y, rng, rt=0.25, wet=0.1, pre=0.005, damp=7000)


def whisper(x):
    import pyworld as pw
    xs = np.ascontiguousarray(x.astype(np.float64))
    f, t = pw.harvest(xs, SR, f0_floor=60, f0_ceil=500, frame_period=5.0)
    sp = pw.cheaptrick(xs, f, t, SR)
    ap = np.ones_like(sp) * 0.999
    y = pw.synthesize(np.zeros_like(f), sp, ap, SR, 5.0)
    return fit(y, len(x) / SR + 1e-9)[:len(x)]


def hive(x, rng):
    """Layered whisper with downward pitch shifts and hiss: intelligible but inhuman."""
    import librosa
    w = whisper(x)
    w = w / (np.max(np.abs(w)) + 1e-9)
    layers = [(0, 0.6, 0.0), (-4, 0.75, 0.01), (-8, 0.5, 0.02), (-12, 0.25, 0.03)]
    out = np.zeros(len(w) + N(0.1))
    for st, g, dly in layers:
        y = librosa.effects.pitch_shift(w, sr=SR, n_steps=st) if st else w
        out = place(out, y * g, dly)
    # add a quiet dry voice an octave down for intelligibility
    dry = librosa.effects.pitch_shift(x / (np.max(np.abs(x)) + 1e-9), sr=SR, n_steps=-7)
    out = place(out, dry * 0.35, 0.004)
    env = np.convolve(np.abs(out), np.ones(1024) / 1024, mode="same")
    hiss = hp(noise(rng, len(out) / SR + 1e-9)[:len(out)], 3500) * env * 0.6
    out = out + hiss
    return reverb(out, rng, rt=0.8, wet=0.16, pre=0.02, damp=5000)


# ------------------------------------------------------------------ line tables

CROWN_UNITS = {
    # unit: (voice, speed, semitones, lines)
    "labourer": ("bm_daniel", 1.05, 0.8, {
        "select": ["Aye?", "Work to do?", "Hands ready."],
        "move": ["On my way.", "Right then.", "Going."],
        "attack": ["With a shovel?!", "If I must!"]}),
    "pikeman": ("bm_lewis", 1.0, 0.0, {
        "select": ["Pikes ready.", "Hold the line!", "Yes, sir?"],
        "move": ["Forward.", "Marching.", "Steady pace."],
        "attack": ["Brace!", "Pikes down!"]}),
    "musketeer": ("bm_fable", 1.05, 0.0, {
        "select": ["Powder dry.", "Loaded, sir.", "Musket ready."],
        "move": ["Moving out.", "By the left!", "Aye."],
        "attack": ["Present... fire!", "Take aim!"]}),
    "cannon": ("bm_lewis", 0.95, -1.0, {
        "select": ["Gun crew ready.", "Where to, sir?", "Heavy, this."],
        "move": ["Push!", "Roll her out!", "Heave!"],
        "attack": ["Fire in the hole!", "Give them iron!"]}),
    "missionary": ("bf_emma", 0.92, 0.0, {
        "select": ["Peace be with you.", "Who is hurt?", "I am here."],
        "move": ["I will go.", "Lead me.", "With faith."]}),
}

CLOCK_UNITS = {
    # unit: (voice, speed, robot f0, ring Hz, lines)  -- None = synthesised non-verbal line
    "winder": ("bm_fable", 1.0, 150, 95, {
        "select": ["Tick-tock.", "Spring tension nominal.", "Awaiting instruction."],
        "move": ["Relocating.", "Acknowledged.", "Proceeding."],
        "attack": ["Unsuitable task.", "Very well."]}),
    "gearknight": ("bm_george", 1.0, 95, 70, {
        "select": ["Blade sharpened.", "For the Great Clock.", "Ready."],
        "move": ["Advancing.", "Gears turning.", "As commanded."],
        "attack": ["Engaging.", "Cut them down."]}),
    "bolt": ("am_adam", 1.05, 120, 85, {
        "select": ["Bolts loaded.", "Target?", "Tension set."],
        "move": ["Moving.", "Repositioning.", "Confirmed."],
        "attack": ["Loosing!", "Bolt away."]}),
    "steam_walker": ("am_onyx", 0.92, 85, 60, {
        "select": ["Pressure at maximum.", "Boilers are hot.", None],
        "move": ["Stomping forward.", "Underway.", None],
        "attack": ["Venting fury!", "Crush them all."]}),
    "tesla_cart": ("am_puck", 1.05, 135, 100, {
        "select": ["Charge holding.", "Capacitors full.", None],
        "move": ["Packing up.", "Rolling.", "Unit mobile."],
        "attack": ["Discharging!", "Lightning ready."]}),
}

ANN_BASE = {
    "unit_ready": "Unit ready.",
    "building_done": "Construction complete.",
    "research_done": "Research complete.",
    "under_attack": "Our forces are under attack.",
    "base_attack": "Our base is under attack!",
    "expansion": "New hall established.",
    "building_lost": "A building has fallen.",
    "victory": "Victory!",
    "defeat": "We are defeated.",
}
ANN = {
    "crown": dict(ANN_BASE, no_gold="Not enough gold.", no_res2="Not enough powder.",
                  no_supply="We require more housing."),
    "brood": dict(ANN_BASE, no_gold="Not enough food.", no_res2="Not enough essence.",
                  no_supply="More clutches needed."),
    "clock": dict(ANN_BASE, no_gold="Insufficient ore.", no_res2="Insufficient energy.",
                  no_supply="More springs required."),
}

TAUNTS = {
    "crown": ["You face the King's own regiment.", "Volley fire!", "Retreat... regroup!",
              "Long live the Crown!", "Hold the line, lads!", "Your ranks will break.",
              "For King and country!", "Well fought. Not well enough."],
    "brood": ["We are many.", "Your walls will feed us.", "We hunger.", "Hssss...",
              "We are everywhere.", "The swarm remembers.", "Your flesh is ours.", "We grow."],
    "clock": ["Your defeat has been calculated.", "Efficiency: rising.", "Recalculating.",
              "Time is on our side.", "Resistance is inefficient.", "Your time has run out.",
              "All gears in motion.", "Calculation complete."],
}


# ------------------------------------------------------------------ Brood creature calls

def brood_line(unit, kind, i, rng):
    p = [1.0, 0.9, 1.12][i % 3]
    if unit == "grub":
        if kind == "select":
            out = np.zeros(1)
            for k in range(2 + i):
                c = fx.creature(rng, 0.09, 1100 * p * rng.uniform(0.9, 1.2), 1500 * p, (2200, 3600, 5200), 6, 0.1, 0.2)
                out = place(out, c * adsr(0.09, 0.01, 0.02, 0.8, 0.04), k * 0.11)
            return out
        sq = fx.creature(rng, 0.35, 1300 * p, 900 * p, (2000, 3300, 4800), 6, 0.2, 0.4, shape=0.7)
        sq *= adsr(0.35, 0.01, 0.05, 0.8, 0.15)
        return mix(sq, fit(grains(rng, 0.35, 60, (0.02, 0.05), 200, 500, src="bubble"), 0.35) * 0.5)
    if unit == "raptor":
        if kind == "select":
            out = fit(fx.chitter(rng, 0.5, 30, 3000 * p, 3), 0.5) * adsr(0.5, 0.01, 0.1, 0.8, 0.15)
            return place(out, fx.screech(rng, 0.12, 2400 * p, 3000 * p, 0.5) * 0.25, 0.3)
        if kind == "move":
            h = bp(noise(rng, 0.45), 2500, 7000) * adsr(0.45, 0.02, 0.1, 0.7, 0.2)
            return h + fit(fx.chitter(rng, 0.45, 40, 3600 * p, 2), 0.45) * 0.5
        return fx.screech(rng, 0.45, 3200 * p, 2200 * p, 0.8)
    if unit == "spitter":
        if kind == "select":
            c = fx.creature(rng, 0.45, 95 * p, 75 * p, (420, 950, 2300), 5, 0.9, 0.5)
            c *= adsr(0.45, 0.02, 0.1, 0.8, 0.2) * (1 + 0.6 * np.sin(2 * np.pi * 11 * T(0.45)))
            return mix(c, fit(grains(rng, 0.45, 40, (0.03, 0.08), 80, 220, src="bubble"), 0.45) * 0.7)
        if kind == "move":
            sl = svf_bp(noise(rng, 0.5), 400 + 300 * np.sin(2 * np.pi * 3 * T(0.5)), 3) * 0.6
            hs = bp(noise(rng, 0.5), 2000, 6000) * 0.4
            return (sl + hs) * adsr(0.5, 0.03, 0.1, 0.8, 0.2)
        out = np.zeros(1)
        for k in range(2 + i):
            cough = fx.creature(rng, 0.13, 140 * p, 100 * p, (500, 1100, 2500), 4, 1.0, 1.4) * adsr(0.13, 0.005, 0.03, 0.6, 0.06)
            out = place(out, cough, k * 0.15)
        return place(out, fx.splat(rng, 0.25, p) * 0.6, 0.15 * (2 + i))
    if unit == "brute":
        if kind == "select":
            return fx.roar(rng, 0.55, 0.65 * p, 1.0) * np.hanning(N(0.55)) ** 0.3
        if kind == "move":
            out = np.zeros(1)
            for k in range(2):
                sn = formants(noise(rng, 0.18), [(350 * p, 1), (900, 0.5)], 3) * adsr(0.18, 0.01, 0.05, 0.7, 0.08)
                out = place(out, sn, k * 0.22)
            return out
        return fx.roar(rng, 1.3, 0.6 * p, 1.0)
    if unit == "skywing":
        if kind == "select":
            return fx.screech(rng, 0.35, 3800 * p, 3200 * p, 0.4)
        if kind == "move":
            out = np.zeros(1)
            for k in range(3):
                fl = lp(noise(rng, 0.09), 900) * np.sin(np.pi * T(0.09) / 0.09) ** 2
                out = place(out, fl * 0.7, k * 0.12)
            return place(out, fx.screech(rng, 0.25, 3000 * p, 3500 * p, 0.4) * 0.6, 0.15)
        return fx.screech(rng, 0.7, 4200 * p, 1800 * p, 0.7)
    raise KeyError(unit)


BROOD_UNITS = {"grub": ["select", "move"], "raptor": ["select", "move", "attack"],
               "spitter": ["select", "move", "attack"], "brute": ["select", "move", "attack"],
               "skywing": ["select", "move", "attack"]}


def clock_nonverbal(unit, kind, rng):
    if unit == "steam_walker" and kind == "select":      # (hiss)
        h = fx.steam_hiss(rng, 0.8, 0.02, 3.0)
        return place(h, metal_hit(rng, 300, 0.3, decay=15) * 0.3, 0)
    if unit == "steam_walker" and kind == "move":        # (whistle)
        d = 0.7
        t = T(d)
        f = 1450 * (1 + 0.02 * np.sin(2 * np.pi * 6 * t))
        w = np.sin(phase(f)) * 0.6 + 0.3 * np.sin(phase(f * 1.5)) + reson(noise(rng, d), 1450, 20) * 0.5
        return w * adsr(d, 0.05, 0.05, 0.9, 0.2)
    if unit == "tesla_cart" and kind == "select":        # (crackle)
        return fx.tesla_zap(rng, 0.6, 1.1)
    raise KeyError((unit, kind))


# ------------------------------------------------------------------ main

def seed(name):
    return np.random.default_rng(zlib.crc32(name.encode()) & 0xFFFFFFFF)


def want(rel, filters):
    return not filters or any(f in rel for f in filters)


def main(filters):
    # Crown units
    for unit, (voice, speed, semis, lines) in CROWN_UNITS.items():
        for kind, texts in lines.items():
            for i, text in enumerate(texts):
                rel = f"{unit}/{kind}_{i + 1}"
                if not want(rel, filters):
                    continue
                rng = seed(rel)
                x = tts(text, voice, speed, semis)
                if unit == "missionary":
                    x = warm_room(x, rng, rt=0.5, wet=0.12, warmth=0.25)
                else:
                    x = warm_room(x, rng)
                out_write(rel, x)
    # Clockwork units
    for unit, (voice, speed, f0, ring, lines) in CLOCK_UNITS.items():
        for kind, texts in lines.items():
            for i, text in enumerate(texts):
                rel = f"{unit}/{kind}_{i + 1}"
                if not want(rel, filters):
                    continue
                rng = seed(rel)
                if text is None:
                    x = clock_nonverbal(unit, kind, rng)
                else:
                    x = robot(tts(text, voice, speed), rng, f0=f0, ring=ring)
                    x = x / (np.max(np.abs(x)) + 1e-9)
                    if unit == "tesla_cart":
                        x = mix(x, crackle(rng, len(x) / SR, 80, None, 2500) * 0.15)
                    if unit == "steam_walker":
                        x = mix(x, fx.steam_hiss(rng, len(x) / SR, 0.05, 2.0) * 0.06)
                out_write(rel, x)
    # Brood units (non-verbal)
    for unit, kinds in BROOD_UNITS.items():
        for kind in kinds:
            for i in range(2 if kind == "attack" else 3):
                rel = f"{unit}/{kind}_{i + 1}"
                if want(rel, filters):
                    out_write(rel, brood_line(unit, kind, i, seed(rel)))
    # Announcers
    for fac, lines in ANN.items():
        for key, text in lines.items():
            rel = f"announcer/{fac}/{key}"
            if not want(rel, filters):
                continue
            rng = seed(rel)
            if fac == "crown":
                x = herald(tts(text, "bm_george", 0.9, -1.0), rng)
            elif fac == "brood":
                x = hive(tts(text, "bf_isabella", 0.85), rng)
            else:
                x = robot(tts(text, "bf_alice", 0.95), rng, f0=180, ring=90, ring_mix=0.25, comb_g=0.35)
            out_write(rel, x)
    # Taunts
    for fac, texts in TAUNTS.items():
        for i, text in enumerate(texts):
            rel = f"taunt/{fac}/taunt_{i + 1}"
            if not want(rel, filters):
                continue
            rng = seed(rel)
            if fac == "crown":
                x = warm_room(tts(text, "bm_george", 0.95, -1.0), rng, rt=0.5, wet=0.14, warmth=0.45)
            elif fac == "brood":
                if text.startswith("Hss"):
                    d = 1.3
                    x = bp(noise(rng, d), 2500, 8000) * adsr(d, 0.15, 0.2, 0.7, 0.6)
                    x = mix(x, hive(tts("Hsss.", "bf_isabella", 0.7), rng) * 0.6)
                else:
                    x = hive(tts(text, "bf_isabella", 0.85), rng)
            else:
                x = robot(tts(text, "bm_george", 1.0), rng, f0=82, ring=65, ring_mix=0.35)
            out_write(rel, x)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:]]
    if "--models" in args:
        k = args.index("--models")
        del args[k:k + 2]
    main(args)
