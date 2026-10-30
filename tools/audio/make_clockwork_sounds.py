"""The Clockwork's sounds, cut from the owner's recordings (art/audio_src/clockwork/, SOURCES.txt; sent
2026-10-27: "some sounds for clockwork for you to parse through and select bits and pieces").

Every sound below is a list of LAYERS mixed together. A layer is
    (recording, start s, length s, at s, gain, pitch, fade-out s)
  recording  a short name from SRC (below)
  start      where the piece starts in the recording, in seconds
  length     how much of the recording is taken, in seconds
  at         where it goes in the finished sound, in seconds (0 = at the start)
  gain       its level against the other layers (each layer is first levelled to its own peak)
  pitch      1 = as recorded; 0.5 = an octave lower (and twice as long), 1.3 = higher and shorter
  fade-out   seconds of fade at its end (None: a quarter of the piece, at most 0.3 s)
  extras     (optional 8th item) a dict: "hp" Hz and "lp" Hz, a soft high-pass / low-pass (an octave's taper);
             "attack" seconds of fade-in (default 4 ms)
Every layer also fades in over 4 ms, so nothing clicks; a quiet lead-in before the sound (under 1/20 of its peak)
is trimmed off. The finished sound is levelled to a 0.7 peak
(never clipped); tools/audio/make_mix.py then sets how loud it plays in the game.
So "make the Springer's jump longer" is one number: the length in its line.

Names: "voice/<unit>/select_1" writes assets/voice/<unit>/select_1.wav; anything else writes
assets/audio/<name>.wav ("combat/springer_jump_1", "select/escapement"). Numbered takes (_1, _2 ...) are
picked at random by the game (scripts/sfx.gd). Plain synthesis is never used: only the recordings,
cut, layered, pitched by resampling and faded.

Run:  python3 tools/audio/make_clockwork_sounds.py   (then godot --headless --import, and
      tools/audio/make_mix.py for the levels in scripts/sound_mix.gd). docs/clockwork_sounds.md lists
      every sound with where it plays."""
import os
import subprocess
import sys
import numpy as np

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SRC_DIR = os.path.join(ROOT, "art", "audio_src", "clockwork")
SRC = {"bell": "old_clock_bell.mp3", "alarm": "alarm_clock.mp3", "crank": "turn_crank_loop.mp3",
       "spring": "metal_spring_scrape.mp3", "clang": "clang_group.mp3", "type": "typewriter.mp3",
       "wobble": "liquid_wobble.mp3", "metal": "metallic_noise.mp3", "stamp": "stamp.mp3", "ostamp": "office_stamp.mp3"}

# ---- where the useful bits are (measured: loudness envelopes, onsets, spectral centroid, pitch) ----
# clang_group: twelve bright single clangs (most of the ring 6-9 kHz), one about every 0.9 s
CLANG = [0.08, 0.92, 1.89, 2.76, 3.66, 4.54, 7.41, 8.29, 9.09, 10.69, 11.65]
# old_clock_bell: two strikes of the bell (680 Hz with a 320 Hz hum), quiet with some hiss before them
BELL = [1.56, 3.66]
# alarm_clock: ticking 1.6-7.0 s (a tick every 0.30 s, tick-tock loud and soft), the bell ringing 7.56-16.9 s
TICK = 1.58            # the first tick
# turn_crank_loop: one turn of the crank every ~1.6 s: a burst of ratchet clicks, then a quiet grind
CRANK = [0.10, 1.76, 3.23, 5.00]
# liquid_wobble: four springy wobbles ("boing")
WOBBLE = [0.05, 0.76, 1.63, 2.51]
# metallic_noise: a crash at 0-0.5 s, then pieces rattling and settling 0.6-2.7 s
# metal_spring_scrape: one scrape of a spring 0.08-0.55 s, ringing on to ~3 s
# stamp (sent 2026-10-28): a rubber stamp hit on a desk, clean single hits at 6.92 and 12.04 s (the others are double knocks)
# office_stamp (sent 2026-10-28): two stamps, 1.21 and 3.15 s (the stamp lifting off 0.26 s after each: cut before it)
# typewriter: key clacks all through; the carriage bell at 30.33 and 48.44 s; the carriage sliding back 49.30 s


def cl(i, pitch=1.0, length=0.5, at=0.0, gain=1.0, fade=None):
    """A clang from the clang group (index into CLANG)."""
    return ("clang", CLANG[i] - 0.01, length, at, gain, pitch, fade)


def crash(pitch=1.0, length=0.45, at=0.0, gain=1.0):
    return ("metal", 0.02, length, at, gain, pitch, 0.25)


def clatter(start=0.62, length=0.9, at=0.25, gain=0.45, pitch=1.0):
    return ("metal", start, length, at, gain, pitch, 0.35)


def boing(i, length=0.4, at=0.0, gain=0.6, pitch=1.0):
    return ("wobble", WOBBLE[i], length, at, gain, pitch, 0.15)


def ticks(n, first=0, pitch=1.0, at=0.0, gain=1.0):
    """n ticks of the alarm clock from tick number `first`."""
    return ("alarm", TICK - 0.02 + 0.30 * first, 0.30 * n, at, gain, pitch, 0.06)


def ratchet(i, length=0.34, at=0.0, gain=1.0, pitch=1.0, fade=0.08):
    """The crank's burst of ratchet clicks number i (CRANK)."""
    return ("crank", CRANK[i] + 0.02, length, at, gain, pitch, fade)


def keys(start, length, at=0.0, gain=1.0, pitch=1.0):
    return ("type", start, length, at, gain, pitch, 0.06)


def ding(i, length=0.55, at=0.0, gain=0.8, pitch=1.0):
    """The typewriter's carriage bell (with the key that rang it)."""
    return ("type", [30.33, 48.44][i], length, at, gain, pitch, 0.25)


def bell(i, length=1.6, at=0.0, gain=1.0, pitch=1.0, fade=0.9):
    """A strike of the old clock bell."""
    return ("bell", BELL[i], length, at, gain, pitch, fade)


def tower_bell(i, length=1.0, at=0.0, gain=1.0, pitch=1.0, fade=0.75):
    """The Clocktower's pick (owner, 2026-10-30: "a bit annoying... something off"): the bell strike, shorter and
    gentler than bell(): its low hum (99 and 326 Hz, a drone under the strike) rolled off below ~300 Hz, the clangy
    upper partials (1.1-1.7 kHz) softened above 1.3 kHz, a 12 ms attack instead of the hammer's click, and the long
    ring cut to about a second."""
    return ("bell", BELL[i], length, at, gain, pitch, fade, {"hp": 300, "lp": 1300, "attack": 0.012})


SOUNDS = {
    # ================= UNIT VOICES (assets/voice/<kind>/: the machine's answer when picked or ordered) =================
    # the Clock Soldier: typewriter keys, a sharp little "yes sir" of clacks; attack ends on the carriage bell
    "voice/clock_soldier/select_1": [keys(0.88, 0.32)],
    "voice/clock_soldier/select_2": [keys(3.93, 0.30)],
    "voice/clock_soldier/select_3": [keys(25.28, 0.26)],
    "voice/clock_soldier/move_1": [keys(5.29, 0.40)],
    "voice/clock_soldier/move_2": [keys(12.21, 0.44)],
    "voice/clock_soldier/move_3": [keys(22.73, 0.44)],
    "voice/clock_soldier/attack_1": [keys(37.57, 0.36), ding(0, at=0.30)],
    "voice/clock_soldier/attack_2": [keys(33.39, 0.36), ding(1, 0.45, at=0.30)],
    # the Springer: a spring answering (a wobble's boing) with a ratchet click
    "voice/springer/select_1": [boing(1, 0.38, gain=1.0), ratchet(0, 0.14, at=0.0, gain=0.5, pitch=1.2)],
    "voice/springer/select_2": [boing(2, 0.36, gain=1.0, pitch=1.1)],
    "voice/springer/select_3": [boing(3, 0.36, gain=1.0), keys(18.66, 0.16, at=0.30, gain=0.5)],
    "voice/springer/move_1": [ratchet(1, 0.30, gain=0.8, pitch=1.2), boing(2, 0.32, at=0.18, gain=0.8, pitch=1.2)],
    "voice/springer/move_2": [ratchet(2, 0.30, gain=0.8, pitch=1.2), boing(3, 0.32, at=0.18, gain=0.8, pitch=1.2)],
    "voice/springer/move_3": [boing(1, 0.30, gain=1.0, pitch=1.25), boing(3, 0.30, at=0.22, gain=0.7, pitch=1.4)],
    "voice/springer/attack_1": [("spring", 0.08, 0.40, 0.0, 1.0, 1.2, 0.15), ratchet(3, 0.20, at=0.25, gain=0.6, pitch=1.3)],
    "voice/springer/attack_2": [("spring", 0.10, 0.40, 0.0, 1.0, 1.35, 0.15), boing(2, 0.25, at=0.25, gain=0.6, pitch=1.4)],
    # the Swift: quick bird-like ticks (the alarm clock's ticking, higher and faster) and a little high ding
    "voice/cuckoo/select_1": [ticks(3, 3, pitch=1.4), ding(0, 0.45, at=0.55, gain=0.6, pitch=1.3)],
    "voice/cuckoo/select_2": [ticks(3, 7, pitch=1.5), ding(1, 0.40, at=0.52, gain=0.6, pitch=1.4)],
    "voice/cuckoo/select_3": [ticks(4, 11, pitch=1.6)],
    "voice/cuckoo/move_1": [ticks(2, 4, pitch=1.6)],
    "voice/cuckoo/move_2": [ticks(2, 9, pitch=1.6)],
    "voice/cuckoo/move_3": [ticks(3, 13, pitch=1.8)],
    "voice/cuckoo/attack_1": [ticks(2, 5, pitch=1.6), ding(0, 0.40, at=0.32, gain=0.7, pitch=1.5)],
    "voice/cuckoo/attack_2": [ticks(2, 15, pitch=1.6), ding(1, 0.35, at=0.32, gain=0.7, pitch=1.5)],
    # the Ticking Owl: slow, low ticking (an owl's "who-who"), its attack with a low crank turn
    "voice/ticking_owl/select_1": [ticks(2.5, 2, pitch=0.8)],
    "voice/ticking_owl/select_2": [ticks(2.5, 6, pitch=0.8)],
    "voice/ticking_owl/select_3": [ticks(2, 10, pitch=0.75), bell(0, 0.4, at=0.55, gain=0.5, pitch=0.9, fade=0.3)],
    "voice/ticking_owl/move_1": [ticks(2, 3, pitch=0.75)],
    "voice/ticking_owl/move_2": [ticks(2, 8, pitch=0.75)],
    "voice/ticking_owl/move_3": [ticks(2, 12, pitch=0.7)],
    "voice/ticking_owl/attack_1": [ticks(2, 4, pitch=0.7), ratchet(0, 0.34, at=0.55, gain=0.8, pitch=0.8)],
    "voice/ticking_owl/attack_2": [ticks(2, 14, pitch=0.7), ratchet(1, 0.34, at=0.55, gain=0.8, pitch=0.8)],
    # the Pendulum: the old clock bell (it is a clock tower on legs); moving, a slow heavy crank turn
    "voice/pendulum/select_1": [bell(0, 0.9, pitch=0.9, fade=0.55)],
    "voice/pendulum/select_2": [bell(1, 0.85, pitch=0.85, fade=0.55)],
    "voice/pendulum/select_3": [ratchet(2, 0.30, gain=0.6, pitch=0.7), bell(0, 0.55, at=0.30, pitch=0.8, fade=0.4)],
    "voice/pendulum/move_1": [ratchet(0, 0.34, pitch=0.65)],
    "voice/pendulum/move_2": [ratchet(1, 0.34, pitch=0.65)],
    "voice/pendulum/move_3": [ratchet(3, 0.36, pitch=0.6)],
    "voice/pendulum/attack_1": [ratchet(2, 0.25, pitch=0.65), cl(5, 0.5, 0.30, at=0.35, gain=0.8)],
    "voice/pendulum/attack_2": [ratchet(0, 0.25, pitch=0.65), cl(9, 0.5, 0.30, at=0.35, gain=0.8)],
    # the Netter: a crank cocking the spring cannon; the attack lets the spring go
    "voice/netter/select_1": [ratchet(0, 0.36, pitch=0.9)],
    "voice/netter/select_2": [ratchet(1, 0.36, pitch=0.95)],
    "voice/netter/select_3": [ratchet(2, 0.30, pitch=0.9), keys(19.0, 0.18, at=0.30, gain=0.5)],
    "voice/netter/move_1": [ratchet(3, 0.30, pitch=1.0), ("crank", 0.55, 0.30, 0.25, 0.5, 1.0, 0.1)],
    "voice/netter/move_2": [ratchet(0, 0.24, pitch=1.05), ("crank", 2.15, 0.30, 0.20, 0.5, 1.0, 0.1)],
    "voice/netter/move_3": [ratchet(2, 0.24, pitch=1.0), ("crank", 3.65, 0.30, 0.20, 0.5, 1.0, 0.1)],
    "voice/netter/attack_1": [ratchet(1, 0.28, gain=0.8), ("spring", 0.08, 0.45, 0.24, 1.0, 1.0, 0.2)],
    "voice/netter/attack_2": [ratchet(3, 0.28, gain=0.8), ("spring", 0.10, 0.45, 0.24, 1.0, 0.9, 0.2)],
    # the Spring Ballista: a heavy ratchet and a low spring (a big machine answering)
    "voice/ballista/select_1": [ratchet(0, 0.36, pitch=0.75), ("spring", 0.08, 0.3, 0.2, 0.5, 0.6, 0.2)],
    "voice/ballista/select_2": [ratchet(1, 0.36, pitch=0.7)],
    "voice/ballista/select_3": [ratchet(3, 0.30, pitch=0.75), cl(4, 0.5, 0.3, at=0.28, gain=0.5)],
    "voice/ballista/move_1": [ratchet(2, 0.30, pitch=0.8), ("crank", 0.55, 0.40, 0.25, 0.5, 0.8, 0.1)],
    "voice/ballista/move_2": [ratchet(0, 0.26, pitch=0.85), ("crank", 2.15, 0.40, 0.20, 0.5, 0.8, 0.1)],
    "voice/ballista/move_3": [ratchet(3, 0.26, pitch=0.8), ("crank", 3.65, 0.40, 0.20, 0.5, 0.8, 0.1)],
    "voice/ballista/attack_1": [ratchet(1, 0.28, gain=0.8, pitch=0.8), ("spring", 0.08, 0.5, 0.22, 1.0, 0.7, 0.2)],
    "voice/ballista/attack_2": [ratchet(3, 0.28, gain=0.8, pitch=0.8), ("spring", 0.10, 0.5, 0.22, 1.0, 0.65, 0.2)],
    # the Great Winder: the biggest machine answers with its slow, deep ratchet and the old bell's hum (it winds the army)
    "voice/great_winder/select_1": [ratchet(0, 0.44, pitch=0.6), bell(0, 0.6, at=0.3, gain=0.25, pitch=0.7, fade=0.4)],
    "voice/great_winder/select_2": [ratchet(2, 0.44, pitch=0.58)],
    "voice/great_winder/select_3": [ratchet(1, 0.40, pitch=0.62), ("crank", 0.55, 0.45, 0.30, 0.5, 0.7, 0.15)],
    "voice/great_winder/move_1": [ratchet(3, 0.36, pitch=0.62), ("crank", 2.15, 0.50, 0.25, 0.5, 0.7, 0.15)],
    "voice/great_winder/move_2": [ratchet(0, 0.34, pitch=0.65), ("crank", 3.65, 0.50, 0.22, 0.5, 0.7, 0.15)],
    "voice/great_winder/move_3": [ratchet(1, 0.34, pitch=0.6), ("crank", 0.55, 0.50, 0.22, 0.5, 0.68, 0.15)],
    "voice/great_winder/attack_1": [ratchet(2, 0.36, pitch=0.6), bell(1, 0.5, at=0.3, gain=0.3, pitch=0.7, fade=0.3)],

    # ================= COMBAT (assets/audio/combat/) =================
    # the Clock Soldier's clock-hand sword on brass: bright clangs, a little lower than recorded
    "combat/clock_soldier_attack_1": [cl(0, 0.9, 0.40)],
    "combat/clock_soldier_attack_2": [cl(2, 0.85, 0.40)],
    "combat/clock_soldier_attack_3": [cl(3, 0.95, 0.40)],
    # deaths: a crash of metal, the pieces rattling down, a spring letting go
    "combat/clock_soldier_death_1": [crash(), clatter(), boing(1, 0.35, at=0.45)],
    "combat/clock_soldier_death_2": [crash(0.9), clatter(1.30, 0.8), boing(2, 0.35, at=0.40)],
    # the Springer: its screw shot is a quick ratchet spin; the spring presses, boings on the jump and clanks on landing
    "combat/springer_attack_1": [ratchet(0, 0.16, pitch=1.4, fade=0.05)],
    "combat/springer_attack_2": [ratchet(1, 0.16, pitch=1.4, fade=0.05)],
    "combat/springer_attack_3": [ratchet(2, 0.16, pitch=1.5, fade=0.05)],
    "combat/springer_crouch": [("spring", 0.08, 0.40, 0.0, 1.0, 0.9, 0.12)],
    "combat/springer_jump_1": [boing(1, 0.45, gain=1.0)],
    "combat/springer_jump_2": [boing(3, 0.45, gain=1.0, pitch=0.95)],
    "combat/springer_land_1": [cl(4, 0.6, 0.25, fade=0.15), boing(2, 0.25, at=0.03, gain=0.4, pitch=1.3)],
    "combat/springer_land_2": [cl(7, 0.6, 0.25, fade=0.15), boing(0, 0.25, at=0.03, gain=0.4, pitch=1.3)],
    "combat/springer_death_1": [crash(1.0, 0.35), boing(1, 0.45, at=0.15, gain=1.0), clatter(0.9, 0.6, at=0.45, gain=0.35)],
    "combat/springer_death_2": [crash(1.1, 0.35), boing(3, 0.45, at=0.15, gain=1.0), clatter(1.6, 0.6, at=0.45, gain=0.35)],
    # the Ratchet Turret's big screw: a heavier, slower ratchet with a clang
    "combat/ratchet_turret_attack_1": [ratchet(0, 0.26, pitch=0.9, fade=0.1), cl(1, 0.7, 0.25, gain=0.35, fade=0.15)],
    "combat/ratchet_turret_attack_2": [ratchet(3, 0.26, pitch=0.9, fade=0.1), cl(6, 0.7, 0.25, gain=0.35, fade=0.15)],
    # the Swift's peck: a single typewriter key, higher (a beak tapping on brass)
    "combat/cuckoo_attack_1": [keys(18.66, 0.14, pitch=1.3)],
    "combat/cuckoo_attack_2": [keys(19.00, 0.14, pitch=1.3)],
    "combat/cuckoo_attack_3": [keys(9.66, 0.14, pitch=1.35)],
    "combat/cuckoo_death_1": [crash(1.3, 0.35), clatter(0.62, 0.7, at=0.2, gain=0.4, pitch=1.3), ding(0, 0.4, at=0.25, gain=0.4, pitch=1.4)],
    "combat/cuckoo_death_2": [crash(1.4, 0.35), clatter(1.4, 0.7, at=0.2, gain=0.4, pitch=1.3), ding(1, 0.35, at=0.25, gain=0.4, pitch=1.5)],
    # the Ticking Owl: its talons are a lower clang with a crash; MORPH TO OWL a crank turned; the Owl ready
    # rings the old bell; letting its weight go is a spring; the weight landing a heavy, low clang and clatter
    "combat/ticking_owl_attack_1": [cl(8, 0.7, 0.35), crash(0.9, 0.25, gain=0.5)],
    "combat/ticking_owl_attack_2": [cl(10, 0.7, 0.35), crash(0.8, 0.25, gain=0.5)],
    "combat/owl_morph": [("crank", 0.10, 1.48, 0.0, 1.0, 1.0, 0.3)],
    "combat/owl_ready": [bell(1, 1.4, fade=0.8)],
    "combat/owl_drop": [boing(0, 0.30, gain=1.0, pitch=1.2)],
    "combat/owl_bomb_1": [cl(5, 0.45, 0.45), crash(0.6, 0.45, gain=0.8), clatter(0.62, 0.8, at=0.25, gain=0.5, pitch=0.8)],
    "combat/owl_bomb_2": [cl(9, 0.45, 0.45), crash(0.55, 0.45, gain=0.8), clatter(1.4, 0.8, at=0.25, gain=0.5, pitch=0.8)],
    "combat/ticking_owl_death_1": [crash(0.8, 0.45), ticks(2, 6, pitch=0.7, at=0.15, gain=0.4), clatter(0.62, 0.8, at=0.4, gain=0.45, pitch=0.85)],
    "combat/ticking_owl_death_2": [crash(0.75, 0.45), boing(2, 0.4, at=0.3, gain=0.6, pitch=0.8), clatter(1.4, 0.8, at=0.4, gain=0.45, pitch=0.85)],
    # the Pendulum's blows: heavy, low clangs (an octave down) with a thud of metal
    "combat/pendulum_attack_1": [cl(5, 0.5, 0.40), crash(0.55, 0.35, gain=0.6)],
    "combat/pendulum_attack_2": [cl(9, 0.5, 0.40), crash(0.6, 0.35, gain=0.6)],
    "combat/pendulum_attack_3": [cl(1, 0.48, 0.40), crash(0.5, 0.35, gain=0.6)],
    "combat/pendulum_death_1": [crash(0.5, 0.45), bell(0, 0.6, at=0.10, gain=0.7, pitch=0.75, fade=0.35), clatter(0.62, 0.75, at=0.35, gain=0.5, pitch=0.7)],
    "combat/pendulum_death_2": [crash(0.55, 0.45), bell(1, 0.6, at=0.10, gain=0.7, pitch=0.7, fade=0.35), clatter(1.3, 0.75, at=0.35, gain=0.5, pitch=0.7)],
    # the Netter: the spring cannon lets go (scrape and boing); the chain net lands with a rattle
    "combat/netter_attack_1": [("spring", 0.08, 0.40, 0.0, 1.0, 1.1, 0.15), boing(2, 0.35, at=0.10, gain=0.7)],
    "combat/netter_attack_2": [("spring", 0.10, 0.40, 0.0, 1.0, 1.2, 0.15), boing(1, 0.35, at=0.10, gain=0.7)],
    "combat/netter_hit_1": [clatter(0.62, 0.7, at=0.0, gain=1.0, pitch=1.2), crash(1.3, 0.2, gain=0.4)],
    "combat/netter_hit_2": [clatter(1.30, 0.7, at=0.0, gain=1.0, pitch=1.2), crash(1.4, 0.2, gain=0.4)],
    "combat/netter_death_1": [crash(0.85, 0.45), ("spring", 0.08, 0.6, 0.25, 0.6, 0.8, 0.3), clatter(0.62, 0.8, at=0.4, gain=0.45)],
    "combat/netter_death_2": [crash(0.9, 0.45), boing(3, 0.4, at=0.25, gain=0.6, pitch=0.85), clatter(1.4, 0.8, at=0.4, gain=0.45)],
    # the Spring Ballista (scripts/ballista.gd): the bow's SPRING TWANG (the spring scrape, low) with a heavy clang; the
    # bolt's THUNK where it strikes (a low clang over a crash); its spring wound home (a ratchet's last clicks); the
    # crew's RATCHET CRANK while it winds (one crank turn, played by the cranking crew now and then); its death
    "combat/ballista_attack_1": [("spring", 0.08, 0.55, 0.0, 1.0, 0.62, 0.25), cl(3, 0.55, 0.35, at=0.02, gain=0.6), boing(0, 0.3, at=0.05, gain=0.4, pitch=0.6)],
    "combat/ballista_attack_2": [("spring", 0.10, 0.55, 0.0, 1.0, 0.58, 0.25), cl(6, 0.5, 0.35, at=0.02, gain=0.6), boing(2, 0.3, at=0.05, gain=0.4, pitch=0.55)],
    "combat/ballista_hit_1": [cl(1, 0.45, 0.30, gain=1.0), crash(0.7, 0.25, at=0.0, gain=0.6)],
    "combat/ballista_hit_2": [cl(5, 0.42, 0.30, gain=1.0), crash(0.75, 0.25, at=0.0, gain=0.6)],
    "combat/ballista_wound_1": [ratchet(2, 0.26, pitch=0.85), cl(9, 0.7, 0.2, at=0.18, gain=0.5)],
    "combat/ballista_crank_1": [("crank", CRANK[1], 1.40, 0.0, 1.0, 0.85, 0.25)],
    "combat/ballista_crank_2": [("crank", CRANK[3], 1.30, 0.0, 1.0, 0.85, 0.25)],
    "combat/ballista_death_1": [crash(0.7, 0.5), ("spring", 0.08, 0.8, 0.2, 0.6, 0.5, 0.4), clatter(0.62, 0.9, at=0.4, gain=0.5)],
    "combat/ballista_death_2": [crash(0.75, 0.5), boing(1, 0.5, at=0.2, gain=0.6, pitch=0.5), clatter(1.4, 0.9, at=0.4, gain=0.5)],
    # the Great Winder (scripts/great_winder.gd): a slow heavy RATCHET STEP as its legs come down (once a walk loop), the
    # WINDING CRANK of its key arm while it mends, the BRUSH SWEEP of its rollers (the crank's grind, low, with scraps
    # rattling into the hopper), and its death: a crash, its spring letting go, its parts spilling out
    "combat/great_winder_step_1": [ratchet(1, 0.22, pitch=0.5, gain=0.9), cl(6, 0.35, 0.25, at=0.05, gain=0.35)],
    "combat/great_winder_step_2": [ratchet(3, 0.22, pitch=0.48, gain=0.9), cl(2, 0.35, 0.25, at=0.05, gain=0.35)],
    "combat/great_winder_wind_1": [("crank", CRANK[0], 1.50, 0.0, 1.0, 0.72, 0.25)],
    "combat/great_winder_wind_2": [("crank", CRANK[2], 1.50, 0.0, 1.0, 0.7, 0.25)],
    "combat/great_winder_sweep_1": [("crank", CRANK[0] + 0.55, 0.90, 0.0, 0.8, 0.55, 0.3), clatter(0.9, 0.7, at=0.3, gain=0.5, pitch=0.8)],
    "combat/great_winder_sweep_2": [("crank", CRANK[1] + 0.55, 0.90, 0.0, 0.8, 0.5, 0.3), clatter(1.6, 0.7, at=0.3, gain=0.5, pitch=0.75)],
    "combat/great_winder_death_1": [crash(0.6, 0.6), ("spring", 0.08, 0.9, 0.2, 0.7, 0.45, 0.5), clatter(0.62, 1.2, at=0.4, gain=0.6, pitch=0.8)],
    "combat/great_winder_death_2": [crash(0.65, 0.6), boing(1, 0.6, at=0.25, gain=0.6, pitch=0.45), clatter(1.4, 1.2, at=0.4, gain=0.6, pitch=0.8)],
    # the Winder: a wrench on brass, and his death
    "combat/winder_attack_1": [cl(10, 1.0, 0.30, gain=0.8), ratchet(0, 0.12, gain=0.5)],
    "combat/winder_attack_2": [cl(7, 1.05, 0.30, gain=0.8), ratchet(2, 0.12, gain=0.5)],
    "combat/winder_death_1": [crash(1.05, 0.4), clatter(0.62, 0.7, at=0.3, gain=0.45), boing(0, 0.3, at=0.35, gain=0.5)],
    "combat/winder_death_2": [crash(1.15, 0.4), clatter(1.4, 0.7, at=0.3, gain=0.45), boing(2, 0.3, at=0.35, gain=0.5)],

    # ================= BUILDINGS PICKED (assets/audio/select/<kind>) =================
    # the Clocktower (picked for every Winder it trains, so often): four short strikes of the old bell (tower_bell),
    # the game picks one at random; two pitched a little, one with the alarm clock's tick-tock before it
    "select/clocktower": [tower_bell(0)],
    "select/clocktower_1": [tower_bell(1, 0.95, pitch=0.94)],
    "select/clocktower_2": [tower_bell(0, 0.9, pitch=1.06)],
    "select/clocktower_3": [ticks(2, 1, pitch=0.9, gain=0.45), tower_bell(1, 0.9, at=0.62, pitch=1.0)],
    "select/cog_press": [("crank", 0.10, 1.10, 0.0, 1.0, 0.9, 0.35)],
    "select/cog_press_1": [("crank", 3.23, 1.10, 0.0, 1.0, 0.9, 0.35)],
    "select/mainspring": [("spring", 0.06, 1.30, 0.0, 1.0, 1.0, 0.6)],
    "select/escapement": [ticks(4, 3)],
    "select/escapement_1": [ticks(4, 9)],
    "select/regulator": [ticks(3, 5, pitch=0.8), bell(0, 0.4, at=0.55, gain=0.35, pitch=1.0, fade=0.3)],
    "select/movement_works": [cl(3, 0.75, 0.30), cl(6, 0.7, 0.35, at=0.28, gain=0.8), keys(49.30, 0.6, at=0.05, gain=0.35)],
    "select/movement_works_1": [cl(8, 0.75, 0.30), cl(2, 0.7, 0.35, at=0.28, gain=0.8), keys(49.30, 0.6, at=0.05, gain=0.35)],
    "select/ratchet_turret": [ratchet(1, 0.36, pitch=0.8), cl(4, 0.6, 0.30, at=0.25, gain=0.4)],
    "select/cuckoo_house": [ticks(3, 7, pitch=1.3), ding(0, 0.5, at=0.62, gain=0.8, pitch=1.15)],
    # the Heavy Works (0.14.94): its winch cranked slow and low, then the heavy clank of the crane's load set down
    "select/heavy_works": [("crank", 1.60, 1.00, 0.0, 0.7, 0.9, 0.35), cl(5, 0.5, 0.45, at=0.45, gain=0.9), cl(1, 0.45, 0.5, at=0.7, gain=0.6)],

    # ================= THE FACTION (assets/audio/clock/) and WORK (assets/audio/work/) =================
    # the COG PRESS's stamp as its head hits the cog (Building._press_stamp, every other stroke): the owner's stamp
    # recordings pitched down for weight, with a low clang under them for the brass and iron
    "work/cog_press_stamp_1": [("stamp", 6.91, 0.30, 0.0, 1.0, 0.72, 0.18), cl(5, 0.42, 0.30, at=0.0, gain=0.35)],
    "work/cog_press_stamp_2": [("ostamp", 3.14, 0.24, 0.0, 1.0, 0.7, 0.14), cl(1, 0.45, 0.28, at=0.0, gain=0.3)],
    # the alarm clock ringing: the Clockwork's alarm when its men (alert) or its base (base_alert) are attacked
    "clock/alert": [("alarm", 7.58, 1.6, 0.0, 1.0, 1.0, 0.45)],
    "clock/base_alert": [("alarm", 6.92, 0.3, 0.0, 0.5, 1.0, 0.05), ("alarm", 11.0, 1.5, 0.30, 1.0, 1.0, 0.45)],
    # research done: one strike of the old bell
    "clock/research": [bell(0, 2.1, fade=1.1)],
    # a building finished: the carriage slides back and the typewriter's bell rings
    "clock/built": [keys(49.30, 0.85, gain=0.7), ding(1, 0.5, at=0.55, gain=1.0)],
    # a unit ready: a ratchet turn and the carriage bell
    "clock/ready": [ratchet(2, 0.30, gain=0.8), ding(0, 0.5, at=0.25)],
    # the crate a Winder carries to a site: picked up, set down and unfolding (the old "ratchet", assets/audio/ratchet.wav)
    "ratchet": [ratchet(1, 0.30, pitch=1.1)],
    "ratchet_1": [ratchet(3, 0.30, pitch=1.1)],
    # the Winder cranking a Cog Press (played about every 2 s): one turn of the crank each
    "work/winder_crank": [("crank", CRANK[0], 1.60, 0.0, 1.0, 1.0, 0.25)],
    "work/winder_crank_1": [("crank", CRANK[1], 1.45, 0.0, 1.0, 1.0, 0.25)],
    "work/winder_crank_2": [("crank", CRANK[2], 1.60, 0.0, 1.0, 1.0, 0.25)],
    # the Winder building or repairing: a wrench on brass and a ratchet
    "work/clock_build": [ratchet(0, 0.20, gain=0.6), cl(10, 0.8, 0.30, at=0.15, gain=0.7)],
    "work/clock_build_1": [ratchet(2, 0.20, gain=0.6), cl(7, 0.8, 0.30, at=0.15, gain=0.7)],
    "work/clock_build_2": [ratchet(3, 0.20, gain=0.6), cl(0, 0.85, 0.30, at=0.15, gain=0.7)],
}


_cache = {}


def rd(name):
    if name not in _cache:
        cmd = ["ffmpeg", "-v", "quiet", "-i", os.path.join(SRC_DIR, SRC[name]), "-f", "f32le", "-ar", str(SR), "-ac", "1", "-"]
        _cache[name] = np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, np.float32).astype(np.float64)
    return _cache[name]


def tilt(seg, hp=None, lp=None):
    """A soft high-pass and/or low-pass: the spectrum tapered over one octave (a cosine), no ringing edges."""
    if not hp and not lp:
        return seg
    f = np.fft.rfftfreq(len(seg), 1.0 / SR)
    g = np.ones_like(f)
    if hp:
        k = np.clip(np.log2(np.maximum(f, 1.0) / (hp / 2.0)), 0.0, 1.0)      # 0 at hp/2 .. 1 at hp
        g *= 0.5 - 0.5 * np.cos(np.pi * k)
    if lp:
        k = np.clip(np.log2(np.maximum(f, 1.0) / lp), 0.0, 1.0)              # 1 at lp .. 0 at 2 lp
        g *= 0.15 + 0.85 * (0.5 + 0.5 * np.cos(np.pi * k))                   # (down to -16 dB: softened, not muffled)
    return np.fft.irfft(np.fft.rfft(seg) * g, len(seg))


def layer(src, start, length, pitch, fade, ex=None):
    ex = ex or {}
    x = rd(src)
    a = int(start * SR)
    seg = x[a:a + int(length * SR)].copy()
    if pitch != 1.0:     # resample: higher and shorter, or lower and longer
        n = int(len(seg) / pitch)
        seg = np.interp(np.arange(n) * pitch, np.arange(len(seg)), seg)
    seg = tilt(seg, ex.get("hp"), ex.get("lp"))
    fi = int(float(ex.get("attack", 0.004)) * SR)
    seg[:fi] *= np.linspace(0, 1, fi)
    fo = int((fade if fade is not None else min(0.3, len(seg) / SR / 4)) * SR)
    fo = min(fo, len(seg))
    if fo > 0:
        seg[-fo:] *= np.linspace(1, 0, fo) ** 1.5
    return seg / (np.abs(seg).max() + 1e-9)


def build(layers):
    parts = [(int(l[3] * SR), layer(l[0], l[1], l[2], l[5], l[6], l[7] if len(l) > 7 else None) * l[4]) for l in layers]
    n = max(at + len(p) for at, p in parts)
    out = np.zeros(n)
    for at, p in parts:
        out[at:at + len(p)] += p
    # a quiet lead-in (under 1/20 of the peak, -26 dB) is trimmed: the sound answers at once
    i = max(0, int(np.argmax(np.abs(out) > np.abs(out).max() * 0.05)) - int(0.005 * SR))
    out = out[i:]
    fi = int(0.004 * SR)
    out[:fi] *= np.linspace(0, 1, fi)
    return out / (np.abs(out).max() + 1e-9) * 0.7


def path_of(name):
    if name.startswith("voice/"):
        return os.path.join(ROOT, "assets", name + ".wav")
    return os.path.join(ROOT, "assets", "audio", name + ".wav")


def save(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-v", "quiet", "-f", "f64le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "pcm_s16le", path], input=x.astype(np.float64).tobytes(), check=True)


def main(only=None):
    for name, layers in SOUNDS.items():
        if only and not any(o in name for o in only):
            continue
        x = build(layers)
        save(path_of(name), x)
        print("%-40s %.2f s" % (name, len(x) / SR))


if __name__ == "__main__":
    main(sys.argv[1:])
