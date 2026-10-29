"""The Brood's sounds, cut from the owner's creature recordings (art/audio_src/brood/, SOURCES.txt; sent
2026-10-29: "use them at your discretion in the Brood faction"). The owner's rule for the Brood: NO VOICES, only
grunts and animal sounds. docs/brood_sounds.md lists every sound with where it plays.

Every sound below is a list of LAYERS mixed together. A layer is
    (recording, start s, length s, at s, gain, pitch, fade-out s, pitch at the end, lowpass Hz)
  recording  a short name from SRC (below)
  start      where the piece starts in the recording, in seconds
  length     how much of the recording is taken, in seconds
  at         where it goes in the finished sound, in seconds (0 = at the start)
  gain       its level against the other layers (each layer is first levelled to its own peak)
  pitch      1 = as recorded; 0.5 = an octave lower (and twice as long), 1.5 = higher and shorter
  fade-out   seconds of fade at its end (None: a quarter of the piece, at most 0.3 s)
  pitch at the end  (optional) the pitch glides there over the piece: a call sliding down as a creature dies
  lowpass    (optional) a darker, muffled piece (an egg: the creature inside the shell)
Use the helpers (cut, ...) rather than writing tuples. Every layer fades in over 10 ms (most cuts start inside a
call), a quiet lead-in (under 1/20 of the peak) is trimmed off, and the finished sound is levelled to a 0.7 peak.
tools/audio/make_mix.py then sets how loud it plays in the game.

THE CREATURES, by the owner's file names (the line he had in mind):
  Tyrant line   raptor (the owner's older lizard recording, kept), tyrant_challenger (tyrant_challanger.mp3),
                tyrannosaur = the Tyrant Sire (tyrant_sire.mp3), brute (terrifying.mp3, lower)
  Venom line    spitter (spitter.mp3; its spit the venom.mp3 hiss), venom_challenger (venom2.mp3),
                dilophosaurus = the Venom Sire (venom_sire.mp3), mist_toad (weird.mp3, lower: a croaking trill)
  Storm line    hatchlings (the small dino raspy calls, higher), skywing (storm.mp3, higher),
                storm_challenger (storm.mp3), pterodactyl = the Storm Sire (storm.mp3, lower, with the Tyrant's growl)
  the others    grub (weak_grown.mp3, much higher: a small weak call), rootmaw (weak_grown.mp3, lower: a swamp
                lizard's growl), mound_turtle (venom2.mp3, much lower: a slow deep groan), brood_mother
                (terrifying.mp3 far lower with weak_grown's moan under it), brood_egg (weak_grown, high and muffled)
  brood_army    a mixed Brood pick: three creatures calling over each other
The same call is pitched DOWN for a big creature and UP for a small one; takes are cut from different parts of the
call and pitched a little apart, so repeats never sound the same.

Names: "voice/<unit>/select_1" writes assets/voice/<unit>/select_1.wav; anything else writes
assets/audio/<name>.wav ("combat/brute_attack_1", "brood/arrive_tyrannosaur"). Numbered takes (_1, _2 ...) are
picked at random by the game (scripts/sfx.gd). Two of the game's older synth sounds are read as layers, never
written: "bite" (assets/audio/bite.wav: the crunch under a blow) and "hatch" (assets/audio/hatch.wav: the shell).

Run:  python3 tools/audio/make_brood_sounds.py [name ...]   (then godot --headless --import, and the levels:
      tools/audio/make_mix.py; keep only the lines of the files remade, see docs/brood_sounds.md)."""
import os
import subprocess
import sys
import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SRC_DIR = os.path.join(ROOT, "art", "audio_src", "brood")
SRC = {"raspy": "freesound_community-small-dino-raspy-calls-39345.mp3", "spit": "spitter.mp3", "storm": "storm.mp3",
       "terr": "terrifying.mp3", "tchal": "tyrant_challanger.mp3", "tsire": "tyrant_sire.mp3", "venom": "venom.mp3",
       "venom2": "venom2.mp3", "vsire": "venom_sire.mp3", "weak": "weak_grown.mp3", "weird": "weird.mp3",
       "bite": "../../../assets/audio/bite.wav", "hatch": "../../../assets/audio/hatch.wav"}
# recordings that clip in places (tyrant_challanger 872 samples at full scale, terrifying 60): a gentle lowpass
# rounds the clipped edges off
SRC_LP = {"tchal": 6500, "terr": 8000, "tsire": 9000}

# ---- where the useful bits are (measured: loudness every 20 ms, onsets, spectral centroid, pitch) ----
# raspy calls: two calls of quick chirps, 0.10-0.50 s (chirps at .10 .21 .31 .39 .49; a quieter tail to 0.9) and
#   1.17-1.56 s (chirps at 1.19 1.28 1.37 1.47); bright (centroid 4-5 kHz)
# spitter: three calls: A 0.48-0.92 (a hissing rattle, ~570 Hz, a pulse every 0.1 s), B 1.02-1.60 (a screech,
#   brightest 1.2-1.6, ~900 Hz), C 2.02-2.80 (a fast chatter, a click every 40 ms)
# storm: one long cry 0.16-2.0 s, fading to 2.5; it throbs every ~0.13 s (onsets .23 .38 .46 .59 .67 .80 .89 1.02
#   1.15 1.24 1.37 1.53 1.66 1.81); quiet (peak 0.29)
# terrifying: one huge roar 0.06-1.75 s, loudest 0.3-1.0 (a few clipped samples)
# tyrant_challanger: a roar 0.10-1.0 s (loudest 0.3-0.7, heavily clipped), dying away to 1.4
# tyrant_sire: a long growling roar 0.08-1.6 s, throbbing every ~0.12 s
# venom: a bright hiss all through its 0.6 s (centroid 7-9 kHz): a spit
# venom2: a croaking growl swelling 0.40-2.0 s (dark, centroid ~1.6 kHz, a pulse every ~0.1 s; loudest 0.7-1.5),
#   then brighter and dying 2.0-2.6
# venom_sire: a growl 0.18-2.5 s, growing to its loudest 1.0-1.8
# weak_grown: a whining growl 0.08-1.2 s, a clear tone near 530 Hz, a pulse every 0.09 s
# weird: a steady, bright warbling call 0.05-1.2 s (centroid ~3 kHz)


def cut(src, start, length, at=0.0, gain=1.0, pitch=1.0, fade=None, to=None, lp=None):
    return (src, start, length, at, gain, pitch, fade, to, lp)


def bite(pitch=1.0, at=0.0, gain=0.6):
    """The crunch of jaws under a blow (the game's older bite)."""
    return cut("bite", 0.0, 0.30, at, gain, pitch, 0.12)


def hiss(pitch=1.0, length=0.30, start=0.03, at=0.0, gain=1.0):
    """The venom hiss: a spit."""
    return cut("venom", start, length, at, gain, pitch, 0.12)


SOUNDS = {
    # ================= UNIT VOICES (assets/voice/<kind>/: the creature's answer when picked or ordered) =================
    # the Grub: weak_grown, much higher: a small, weak, whining call (it is picked all game long: quiet in make_mix)
    "voice/grub/select_1": [cut("weak", 0.20, 0.40, pitch=1.6)],
    "voice/grub/select_2": [cut("weak", 0.55, 0.36, pitch=1.7)],
    "voice/grub/select_3": [cut("weak", 0.85, 0.34, pitch=1.55, to=1.7)],
    "voice/grub/move_1": [cut("weak", 0.30, 0.24, pitch=1.8)],
    "voice/grub/move_2": [cut("weak", 0.70, 0.24, pitch=1.75)],
    "voice/grub/move_3": [cut("weak", 1.00, 0.22, pitch=1.85, to=1.65)],
    "voice/grub/attack_1": [cut("weak", 0.12, 0.30, pitch=1.45, to=1.75)],
    "voice/grub/attack_2": [cut("weak", 0.45, 0.30, pitch=1.5, to=1.8)],
    # the Spitter: its own recording's three calls (rattle, screech, chatter); ordered to attack, a hiss and a screech
    "voice/spitter/select_1": [cut("spit", 0.48, 0.42)],
    "voice/spitter/select_2": [cut("spit", 1.18, 0.40, pitch=1.05)],
    "voice/spitter/select_3": [cut("spit", 2.02, 0.42, pitch=0.97)],
    "voice/spitter/move_1": [cut("spit", 0.60, 0.26, pitch=1.1)],
    "voice/spitter/move_2": [cut("spit", 2.30, 0.26, pitch=1.05)],
    "voice/spitter/move_3": [cut("spit", 1.36, 0.24, pitch=1.12)],
    "voice/spitter/attack_1": [hiss(1.1, 0.22), cut("spit", 1.22, 0.32, at=0.12, gain=0.9)],
    "voice/spitter/attack_2": [hiss(1.2, 0.22, start=0.25), cut("spit", 2.45, 0.32, at=0.12, gain=0.9)],
    # the Venom Challenger: venom2's croaking growl, as recorded; its attack a lower hiss into the growl
    "voice/venom_challenger/select_1": [cut("venom2", 0.62, 0.50)],
    "voice/venom_challenger/select_2": [cut("venom2", 1.05, 0.50, pitch=1.05)],
    "voice/venom_challenger/select_3": [cut("venom2", 1.50, 0.50, pitch=0.97)],
    "voice/venom_challenger/move_1": [cut("venom2", 0.80, 0.32, pitch=1.05)],
    "voice/venom_challenger/move_2": [cut("venom2", 1.25, 0.32, pitch=1.0)],
    "voice/venom_challenger/move_3": [cut("venom2", 1.70, 0.32, pitch=1.08)],
    "voice/venom_challenger/attack_1": [hiss(0.9, 0.26), cut("venom2", 0.95, 0.40, at=0.12, gain=0.9)],
    "voice/venom_challenger/attack_2": [hiss(0.95, 0.26, start=0.28), cut("venom2", 1.35, 0.40, at=0.12, gain=0.9)],
    # the Venom Sire (dilophosaurus): his own growl, a little lower; attack ends on a big hiss
    "voice/dilophosaurus/select_1": [cut("vsire", 0.40, 0.65, pitch=0.92)],
    "voice/dilophosaurus/select_2": [cut("vsire", 1.00, 0.65, pitch=0.9)],
    "voice/dilophosaurus/select_3": [cut("vsire", 1.60, 0.65, pitch=0.94)],
    "voice/dilophosaurus/move_1": [cut("vsire", 0.70, 0.42, pitch=0.92)],
    "voice/dilophosaurus/move_2": [cut("vsire", 1.25, 0.42, pitch=0.9)],
    "voice/dilophosaurus/move_3": [cut("vsire", 1.85, 0.42, pitch=0.95)],
    "voice/dilophosaurus/attack_1": [cut("vsire", 1.10, 0.45, pitch=0.9), hiss(0.8, 0.35, at=0.35, gain=0.8)],
    "voice/dilophosaurus/attack_2": [cut("vsire", 1.50, 0.45, pitch=0.88), hiss(0.75, 0.35, start=0.2, at=0.35, gain=0.8)],
    # the Mist Toad: weird.mp3 lower: a croaking warble (a swamp caster)
    "voice/mist_toad/select_1": [cut("weird", 0.08, 0.40, pitch=0.7)],
    "voice/mist_toad/select_2": [cut("weird", 0.45, 0.40, pitch=0.66)],
    "voice/mist_toad/select_3": [cut("weird", 0.80, 0.40, pitch=0.74)],
    "voice/mist_toad/move_1": [cut("weird", 0.20, 0.26, pitch=0.72)],
    "voice/mist_toad/move_2": [cut("weird", 0.60, 0.26, pitch=0.68)],
    "voice/mist_toad/move_3": [cut("weird", 0.95, 0.24, pitch=0.76)],
    "voice/mist_toad/attack_1": [cut("weird", 0.10, 0.36, pitch=0.62, to=0.8)],
    "voice/mist_toad/attack_2": [cut("weird", 0.70, 0.36, pitch=0.6, to=0.78)],
    # the Tyrant Challenger: his own roar, cut short
    "voice/tyrant_challenger/select_1": [cut("tchal", 0.12, 0.55)],
    "voice/tyrant_challenger/select_2": [cut("tchal", 0.30, 0.50, pitch=1.05)],
    "voice/tyrant_challenger/select_3": [cut("tchal", 0.50, 0.50, pitch=0.97)],
    "voice/tyrant_challenger/move_1": [cut("tchal", 0.22, 0.32, pitch=1.06)],
    "voice/tyrant_challenger/move_2": [cut("tchal", 0.45, 0.32, pitch=1.02)],
    "voice/tyrant_challenger/move_3": [cut("tchal", 0.65, 0.30, pitch=1.08)],
    "voice/tyrant_challenger/attack_1": [cut("tchal", 0.12, 0.45, pitch=0.95)],
    "voice/tyrant_challenger/attack_2": [cut("tchal", 0.30, 0.45, pitch=0.92)],
    # the Tyrant Sire (tyrannosaur): his growling roar, a little lower
    "voice/tyrannosaur/select_1": [cut("tsire", 0.08, 0.70, pitch=0.9)],
    "voice/tyrannosaur/select_2": [cut("tsire", 0.50, 0.70, pitch=0.88)],
    "voice/tyrannosaur/select_3": [cut("tsire", 0.90, 0.65, pitch=0.92)],
    "voice/tyrannosaur/move_1": [cut("tsire", 0.20, 0.45, pitch=0.9)],
    "voice/tyrannosaur/move_2": [cut("tsire", 0.70, 0.45, pitch=0.88)],
    "voice/tyrannosaur/move_3": [cut("tsire", 1.10, 0.42, pitch=0.93)],
    "voice/tyrannosaur/attack_1": [cut("tsire", 0.08, 0.60, pitch=0.85), cut("terr", 0.40, 0.40, at=0.05, gain=0.35, pitch=0.8)],
    "voice/tyrannosaur/attack_2": [cut("tsire", 0.60, 0.60, pitch=0.82), cut("terr", 0.70, 0.40, at=0.05, gain=0.35, pitch=0.8)],
    # the Brute: terrifying.mp3, lower: a huge horned beast's bellow
    "voice/brute/select_1": [cut("terr", 0.10, 0.55, pitch=0.85)],
    "voice/brute/select_2": [cut("terr", 0.45, 0.55, pitch=0.82)],
    "voice/brute/select_3": [cut("terr", 0.85, 0.55, pitch=0.88)],
    "voice/brute/move_1": [cut("terr", 0.30, 0.36, pitch=0.86)],
    "voice/brute/move_2": [cut("terr", 0.65, 0.36, pitch=0.83)],
    "voice/brute/move_3": [cut("terr", 1.05, 0.34, pitch=0.88)],
    "voice/brute/attack_1": [cut("terr", 0.06, 0.60, pitch=0.8)],
    "voice/brute/attack_2": [cut("terr", 0.35, 0.60, pitch=0.78)],
    # the Brood Mother: terrifying.mp3 far lower, with weak_grown's moan under it (the biggest creature of all)
    "voice/brood_mother/select_1": [cut("terr", 0.15, 0.60, pitch=0.62), cut("weak", 0.30, 0.50, at=0.1, gain=0.4, pitch=0.55)],
    "voice/brood_mother/select_2": [cut("terr", 0.55, 0.60, pitch=0.6), cut("weak", 0.60, 0.50, at=0.1, gain=0.4, pitch=0.55)],
    "voice/brood_mother/select_3": [cut("terr", 0.95, 0.55, pitch=0.64), cut("weak", 0.85, 0.40, at=0.1, gain=0.4, pitch=0.58)],
    "voice/brood_mother/move_1": [cut("terr", 0.30, 0.40, pitch=0.62)],
    "voice/brood_mother/move_2": [cut("terr", 0.70, 0.40, pitch=0.6)],
    "voice/brood_mother/move_3": [cut("terr", 1.10, 0.38, pitch=0.64)],
    "voice/brood_mother/attack_1": [cut("terr", 0.06, 0.60, pitch=0.58), cut("tsire", 0.20, 0.50, at=0.05, gain=0.4, pitch=0.6)],
    "voice/brood_mother/attack_2": [cut("terr", 0.40, 0.60, pitch=0.56), cut("tsire", 0.70, 0.50, at=0.05, gain=0.4, pitch=0.6)],
    # the Rootmaw: weak_grown lower: a swamp lizard's contented growl
    "voice/rootmaw/select_1": [cut("weak", 0.15, 0.45, pitch=0.78)],
    "voice/rootmaw/select_2": [cut("weak", 0.50, 0.45, pitch=0.75)],
    "voice/rootmaw/select_3": [cut("weak", 0.80, 0.42, pitch=0.8)],
    "voice/rootmaw/move_1": [cut("weak", 0.30, 0.30, pitch=0.8)],
    "voice/rootmaw/move_2": [cut("weak", 0.65, 0.30, pitch=0.77)],
    "voice/rootmaw/move_3": [cut("weak", 0.95, 0.28, pitch=0.82)],
    "voice/rootmaw/attack_1": [cut("weak", 0.12, 0.40, pitch=0.72, to=0.85)],
    "voice/rootmaw/attack_2": [cut("weak", 0.55, 0.40, pitch=0.7, to=0.84)],
    # the Mound Turtle: venom2 much lower: a slow, deep groan
    "voice/mound_turtle/select_1": [cut("venom2", 0.70, 0.45, pitch=0.6)],
    "voice/mound_turtle/select_2": [cut("venom2", 1.10, 0.45, pitch=0.58)],
    "voice/mound_turtle/select_3": [cut("venom2", 1.45, 0.45, pitch=0.62)],
    "voice/mound_turtle/move_1": [cut("venom2", 0.85, 0.30, pitch=0.6)],
    "voice/mound_turtle/move_2": [cut("venom2", 1.25, 0.30, pitch=0.58)],
    "voice/mound_turtle/move_3": [cut("venom2", 1.60, 0.30, pitch=0.62)],
    "voice/mound_turtle/attack_1": [cut("venom2", 0.95, 0.40, pitch=0.55, to=0.65)],
    "voice/mound_turtle/attack_2": [cut("venom2", 1.35, 0.40, pitch=0.54, to=0.64)],
    # an Egg picked: the creature inside stirring (weak_grown high, muffled by the shell), now and then the shell creaks
    "voice/brood_egg/select_1": [cut("weak", 0.30, 0.35, pitch=1.9, lp=1100)],
    "voice/brood_egg/select_2": [cut("weak", 0.70, 0.35, pitch=2.0, lp=1000), cut("hatch", 0.0, 0.15, at=0.12, gain=0.3, pitch=1.3, lp=3000)],
    # the Hatchlings: the small dino raspy calls, higher
    "voice/hatchlings/select_1": [cut("raspy", 0.10, 0.40, pitch=1.2)],
    "voice/hatchlings/select_2": [cut("raspy", 1.16, 0.40, pitch=1.25)],
    "voice/hatchlings/select_3": [cut("raspy", 0.20, 0.32, pitch=1.32)],
    "voice/hatchlings/move_1": [cut("raspy", 0.28, 0.22, pitch=1.4)],
    "voice/hatchlings/move_2": [cut("raspy", 1.26, 0.22, pitch=1.38)],
    "voice/hatchlings/move_3": [cut("raspy", 0.38, 0.20, pitch=1.45)],
    "voice/hatchlings/attack_1": [cut("raspy", 1.17, 0.30, pitch=1.3), cut("storm", 0.45, 0.25, at=0.05, gain=0.4, pitch=1.6)],
    "voice/hatchlings/attack_2": [cut("raspy", 0.10, 0.30, pitch=1.35), cut("storm", 0.90, 0.25, at=0.05, gain=0.4, pitch=1.6)],
    # the Skywing: the storm cry, higher (the Storm line's young flyer)
    "voice/skywing/select_1": [cut("storm", 0.20, 0.45, pitch=1.35)],
    "voice/skywing/select_2": [cut("storm", 0.75, 0.45, pitch=1.3)],
    "voice/skywing/select_3": [cut("storm", 1.30, 0.45, pitch=1.4)],
    "voice/skywing/move_1": [cut("storm", 0.45, 0.30, pitch=1.4)],
    "voice/skywing/move_2": [cut("storm", 1.00, 0.30, pitch=1.35)],
    "voice/skywing/move_3": [cut("storm", 1.50, 0.30, pitch=1.45)],
    "voice/skywing/attack_1": [cut("storm", 0.35, 0.40, pitch=1.3, to=1.5)],
    "voice/skywing/attack_2": [cut("storm", 1.10, 0.40, pitch=1.28, to=1.48)],
    # the Storm Challenger: the storm cry as recorded
    "voice/storm_challenger/select_1": [cut("storm", 0.20, 0.55, pitch=1.05)],
    "voice/storm_challenger/select_2": [cut("storm", 0.80, 0.55, pitch=1.0)],
    "voice/storm_challenger/select_3": [cut("storm", 1.35, 0.55, pitch=1.08)],
    "voice/storm_challenger/move_1": [cut("storm", 0.55, 0.35, pitch=1.05)],
    "voice/storm_challenger/move_2": [cut("storm", 1.10, 0.35, pitch=1.0)],
    "voice/storm_challenger/move_3": [cut("storm", 1.60, 0.35, pitch=1.08)],
    "voice/storm_challenger/attack_1": [cut("storm", 0.30, 0.45, pitch=1.0, to=1.2)],
    "voice/storm_challenger/attack_2": [cut("storm", 1.20, 0.45, pitch=0.98, to=1.18)],
    # the Storm Sire (pterodactyl): the storm cry lower, the Tyrant Sire's growl under it for weight
    "voice/pterodactyl/select_1": [cut("storm", 0.20, 0.60, pitch=0.8), cut("tsire", 0.20, 0.50, at=0.05, gain=0.3, pitch=0.85)],
    "voice/pterodactyl/select_2": [cut("storm", 0.85, 0.60, pitch=0.78), cut("tsire", 0.70, 0.50, at=0.05, gain=0.3, pitch=0.85)],
    "voice/pterodactyl/select_3": [cut("storm", 1.40, 0.55, pitch=0.82), cut("tsire", 1.10, 0.45, at=0.05, gain=0.3, pitch=0.87)],
    "voice/pterodactyl/move_1": [cut("storm", 0.50, 0.40, pitch=0.82)],
    "voice/pterodactyl/move_2": [cut("storm", 1.05, 0.40, pitch=0.8)],
    "voice/pterodactyl/move_3": [cut("storm", 1.55, 0.38, pitch=0.84)],
    "voice/pterodactyl/attack_1": [cut("storm", 0.30, 0.55, pitch=0.8, to=0.95), cut("tsire", 0.08, 0.45, at=0.05, gain=0.4, pitch=0.8)],
    "voice/pterodactyl/attack_2": [cut("storm", 1.15, 0.55, pitch=0.78, to=0.93), cut("tsire", 0.60, 0.45, at=0.05, gain=0.4, pitch=0.8)],
    # a MIXED Brood pick (two or more kinds of fighters: Game._select_voice_kind): a little chorus of three creatures
    "voice/brood_army/select_1": [cut("raspy", 0.10, 0.38), cut("spit", 0.50, 0.36, at=0.10, gain=0.6), cut("terr", 0.30, 0.45, at=0.18, gain=0.7, pitch=0.82)],
    "voice/brood_army/select_2": [cut("tchal", 0.20, 0.40, gain=0.8), cut("storm", 0.40, 0.40, at=0.08, gain=0.6, pitch=1.3), cut("venom2", 0.90, 0.40, at=0.20, gain=0.7)],
    "voice/brood_army/select_3": [cut("tsire", 0.20, 0.45, pitch=0.9), cut("raspy", 1.17, 0.36, at=0.12, gain=0.6), cut("spit", 1.20, 0.30, at=0.25, gain=0.5)],
    "voice/brood_army/move_1": [cut("raspy", 0.20, 0.26, gain=0.8), cut("terr", 0.50, 0.30, at=0.06, gain=0.7, pitch=0.85)],
    "voice/brood_army/move_2": [cut("spit", 2.10, 0.26, gain=0.8), cut("tsire", 0.60, 0.32, at=0.06, gain=0.7, pitch=0.9)],
    "voice/brood_army/move_3": [cut("storm", 0.70, 0.28, gain=0.7, pitch=1.3), cut("tchal", 0.40, 0.30, at=0.06, gain=0.8)],
    "voice/brood_army/attack_1": [cut("terr", 0.10, 0.55, pitch=0.85), cut("raspy", 0.10, 0.38, at=0.10, gain=0.5), hiss(1.0, 0.25, at=0.20, gain=0.4)],
    "voice/brood_army/attack_2": [cut("tchal", 0.12, 0.50), cut("spit", 1.22, 0.32, at=0.10, gain=0.5), cut("storm", 0.30, 0.35, at=0.15, gain=0.4, pitch=1.3)],

    # ================= COMBAT (assets/audio/combat/): blows, spits, deaths =================
    # the blows: a short snarl of the creature over the crunch of the old bite (bigger = lower)
    "combat/tyrant_challenger_attack_1": [cut("tchal", 0.30, 0.22, gain=0.7, pitch=1.1, fade=0.08), bite(0.9)],
    "combat/tyrant_challenger_attack_2": [cut("tchal", 0.50, 0.22, gain=0.7, pitch=1.05, fade=0.08), bite(0.85)],
    "combat/tyrant_challenger_attack_3": [cut("tchal", 0.70, 0.22, gain=0.7, pitch=1.12, fade=0.08), bite(0.95)],
    "combat/tyrannosaur_attack_1": [cut("tsire", 0.22, 0.32, gain=0.8, pitch=0.85, fade=0.1), bite(0.7, gain=0.7)],
    "combat/tyrannosaur_attack_2": [cut("tsire", 0.70, 0.32, gain=0.8, pitch=0.82, fade=0.1), bite(0.68, gain=0.7)],
    "combat/brute_attack_1": [cut("terr", 0.30, 0.26, gain=0.8, pitch=0.85, fade=0.1), bite(0.65, gain=0.7)],
    "combat/brute_attack_2": [cut("terr", 0.70, 0.26, gain=0.8, pitch=0.82, fade=0.1), bite(0.62, gain=0.7)],
    # the Brute's charge (Unit: running at its target): his full bellow
    "combat/brute_charge": [cut("terr", 0.06, 0.95, pitch=0.88, fade=0.35)],
    "combat/brood_mother_attack_1": [cut("terr", 0.50, 0.32, gain=0.8, pitch=0.6, fade=0.12), bite(0.55, gain=0.7)],
    "combat/brood_mother_attack_2": [cut("terr", 0.90, 0.32, gain=0.8, pitch=0.58, fade=0.12), bite(0.52, gain=0.7)],
    # the Brood Mother devours an offering: a low growl and two crunches
    "combat/brood_mother_devour": [cut("terr", 0.30, 0.50, gain=0.7, pitch=0.56, fade=0.2), bite(0.5, gain=0.8), bite(0.55, at=0.32, gain=0.6)],
    "combat/rootmaw_attack_1": [cut("weak", 0.50, 0.26, gain=0.7, pitch=0.8, fade=0.1), bite(0.8)],
    "combat/rootmaw_attack_2": [cut("weak", 0.90, 0.26, gain=0.7, pitch=0.78, fade=0.1), bite(0.78)],
    "combat/mound_turtle_attack_1": [cut("venom2", 1.00, 0.26, gain=0.7, pitch=0.62, fade=0.1), bite(0.5, gain=0.7)],
    "combat/mound_turtle_attack_2": [cut("venom2", 1.40, 0.26, gain=0.7, pitch=0.6, fade=0.1), bite(0.48, gain=0.7)],
    "combat/pterodactyl_attack_1": [cut("storm", 0.45, 0.28, gain=0.7, pitch=0.85, fade=0.1), bite(0.75)],
    "combat/pterodactyl_attack_2": [cut("storm", 1.20, 0.28, gain=0.7, pitch=0.82, fade=0.1), bite(0.72)],
    "combat/storm_challenger_attack_1": [cut("storm", 0.60, 0.24, gain=0.7, pitch=1.1, fade=0.08), bite(0.95)],
    "combat/storm_challenger_attack_2": [cut("storm", 1.40, 0.24, gain=0.7, pitch=1.08, fade=0.08), bite(0.92)],
    "combat/hatchlings_attack_1": [cut("raspy", 0.20, 0.12, gain=0.8, pitch=1.3, fade=0.05), bite(1.3, gain=0.5)],
    "combat/hatchlings_attack_2": [cut("raspy", 1.27, 0.12, gain=0.8, pitch=1.35, fade=0.05), bite(1.35, gain=0.5)],
    # the Mist Toad's weak lick, and its TONGUE lashing out (it pulls its victim in)
    "combat/mist_toad_attack_1": [cut("weird", 0.30, 0.16, gain=0.6, pitch=0.8, fade=0.06), bite(1.2, gain=0.5)],
    "combat/mist_toad_attack_2": [cut("weird", 0.90, 0.16, gain=0.6, pitch=0.78, fade=0.06), bite(1.25, gain=0.5)],
    "combat/mist_toad_tongue_1": [cut("weird", 0.10, 0.35, pitch=0.62, to=1.0, fade=0.12), bite(1.1, at=0.22, gain=0.5)],
    "combat/mist_toad_tongue_2": [cut("weird", 0.60, 0.35, pitch=0.6, to=0.98, fade=0.12), bite(1.15, at=0.22, gain=0.5)],
    # the spits: the venom hiss (Game.acid_shot: combat/<kind>_attack), lower for the bigger spitters
    "combat/spitter_attack_1": [hiss(1.15, 0.28)],
    "combat/spitter_attack_2": [hiss(1.25, 0.28, start=0.22)],
    "combat/spitter_attack_3": [hiss(1.05, 0.28, start=0.12)],
    "combat/venom_challenger_attack_1": [hiss(0.95, 0.38), cut("venom2", 1.00, 0.25, gain=0.35, fade=0.1)],
    "combat/venom_challenger_attack_2": [hiss(0.92, 0.38, start=0.15), cut("venom2", 1.40, 0.25, gain=0.35, fade=0.1)],
    "combat/dilophosaurus_attack_1": [hiss(0.85, 0.45), cut("vsire", 0.50, 0.30, gain=0.4, pitch=0.9, fade=0.1)],
    "combat/dilophosaurus_attack_2": [hiss(0.8, 0.45, start=0.1), cut("vsire", 1.20, 0.30, gain=0.4, pitch=0.9, fade=0.1)],
    # deaths: the creature's call sliding down as it dies (bigger = lower and longer)
    "combat/grub_death_1": [cut("weak", 0.30, 0.40, pitch=1.6, to=1.05, fade=0.2)],
    "combat/grub_death_2": [cut("weak", 0.70, 0.40, pitch=1.55, to=1.0, fade=0.2)],
    "combat/grub_death_3": [cut("weak", 0.95, 0.35, pitch=1.65, to=1.1, fade=0.2)],
    "combat/spitter_death_1": [cut("spit", 1.20, 0.45, pitch=1.0, to=0.68, fade=0.2)],
    "combat/spitter_death_2": [cut("spit", 0.50, 0.42, pitch=1.0, to=0.7, fade=0.2)],
    "combat/spitter_death_3": [cut("spit", 2.20, 0.45, pitch=0.98, to=0.66, fade=0.2)],
    "combat/venom_challenger_death_1": [cut("venom2", 1.00, 0.60, pitch=1.0, to=0.68, fade=0.25)],
    "combat/venom_challenger_death_2": [cut("venom2", 1.50, 0.60, pitch=0.98, to=0.66, fade=0.25)],
    "combat/dilophosaurus_death_1": [cut("vsire", 1.40, 0.85, pitch=0.9, to=0.58, fade=0.35)],
    "combat/dilophosaurus_death_2": [cut("vsire", 0.90, 0.85, pitch=0.88, to=0.56, fade=0.35)],
    "combat/mist_toad_death_1": [cut("weird", 0.50, 0.45, pitch=0.75, to=0.5, fade=0.2)],
    "combat/mist_toad_death_2": [cut("weird", 0.15, 0.45, pitch=0.72, to=0.48, fade=0.2)],
    "combat/mist_toad_death_3": [cut("weird", 0.80, 0.40, pitch=0.78, to=0.52, fade=0.2)],
    "combat/tyrant_challenger_death_1": [cut("tchal", 0.50, 0.65, pitch=1.0, to=0.7, fade=0.3)],
    "combat/tyrant_challenger_death_2": [cut("tchal", 0.25, 0.65, pitch=0.97, to=0.68, fade=0.3)],
    "combat/tyrannosaur_death_1": [cut("tsire", 0.90, 0.70, pitch=0.85, to=0.55, fade=0.35), cut("terr", 1.0, 0.6, at=0.1, gain=0.3, pitch=0.6)],
    "combat/tyrannosaur_death_2": [cut("tsire", 0.40, 0.70, pitch=0.82, to=0.53, fade=0.35), cut("terr", 0.6, 0.6, at=0.1, gain=0.3, pitch=0.6)],
    "combat/brute_death_1": [cut("terr", 0.90, 0.65, pitch=0.8, to=0.55, fade=0.3)],
    "combat/brute_death_2": [cut("terr", 0.50, 0.65, pitch=0.78, to=0.54, fade=0.3)],
    "combat/brute_death_3": [cut("terr", 1.20, 0.55, pitch=0.82, to=0.56, fade=0.3)],
    "combat/brood_mother_death": [cut("terr", 0.40, 0.90, pitch=0.62, to=0.42, fade=0.5), cut("weak", 0.20, 0.80, at=0.2, gain=0.5, pitch=0.55, to=0.4)],
    "combat/rootmaw_death_1": [cut("weak", 0.60, 0.55, pitch=0.8, to=0.55, fade=0.25)],
    "combat/rootmaw_death_2": [cut("weak", 0.25, 0.55, pitch=0.78, to=0.54, fade=0.25)],
    "combat/mound_turtle_death_1": [cut("venom2", 0.90, 0.60, pitch=0.62, to=0.45, fade=0.3)],
    "combat/mound_turtle_death_2": [cut("venom2", 1.40, 0.60, pitch=0.6, to=0.44, fade=0.3)],
    "combat/brood_egg_death_1": [cut("hatch", 0.0, 0.45, pitch=0.75, fade=0.2), cut("weak", 0.30, 0.30, at=0.05, gain=0.5, pitch=1.8, to=1.2, lp=2500)],
    "combat/brood_egg_death_2": [cut("hatch", 0.0, 0.45, pitch=0.7, fade=0.2), cut("weak", 0.70, 0.30, at=0.05, gain=0.5, pitch=1.85, to=1.25, lp=2500)],
    "combat/hatchlings_death_1": [cut("raspy", 1.17, 0.36, pitch=1.3, to=0.9, fade=0.15)],
    "combat/hatchlings_death_2": [cut("raspy", 0.12, 0.36, pitch=1.32, to=0.92, fade=0.15)],
    "combat/skywing_death_1": [cut("storm", 1.00, 0.50, pitch=1.35, to=0.9, fade=0.2)],
    "combat/skywing_death_2": [cut("storm", 0.40, 0.50, pitch=1.3, to=0.88, fade=0.2)],
    "combat/skywing_death_3": [cut("storm", 1.50, 0.45, pitch=1.4, to=0.92, fade=0.2)],
    "combat/storm_challenger_death_1": [cut("storm", 0.80, 0.60, pitch=1.1, to=0.75, fade=0.25)],
    "combat/storm_challenger_death_2": [cut("storm", 1.30, 0.60, pitch=1.08, to=0.73, fade=0.25)],
    "combat/pterodactyl_death_1": [cut("storm", 0.60, 0.85, pitch=0.85, to=0.55, fade=0.35), cut("tsire", 0.8, 0.5, at=0.15, gain=0.3, pitch=0.7)],
    "combat/pterodactyl_death_2": [cut("storm", 1.20, 0.75, pitch=0.82, to=0.54, fade=0.35), cut("tsire", 0.4, 0.5, at=0.15, gain=0.3, pitch=0.7)],

    # ================= THE SIRES, MATURING (assets/audio/brood/) =================
    # a Sire's ARRIVAL at his lure (BroodRoot.cocoon_tick: the cue, as a building's bell): his whole call
    "brood/arrive_tyrannosaur": [cut("tsire", 0.05, 1.62, pitch=0.95, fade=0.5)],
    "brood/arrive_dilophosaurus": [cut("vsire", 0.15, 2.30, pitch=0.97, fade=0.7)],
    "brood/arrive_pterodactyl": [cut("storm", 0.15, 1.95, pitch=0.88, fade=0.6), cut("tsire", 0.08, 1.0, at=0.1, gain=0.25, pitch=0.85, fade=0.4)],
    # a father BREATHES on an egg (BroodNew: the egg turns red): a short, soft piece of his call
    "brood/breath_tyrannosaur": [cut("tsire", 0.30, 0.60, pitch=0.8, fade=0.3)],
    "brood/breath_dilophosaurus": [cut("vsire", 1.00, 0.60, pitch=0.85, fade=0.3)],
    "brood/breath_pterodactyl": [cut("storm", 0.50, 0.60, pitch=0.75, fade=0.3)],
    # a young one MATURES into its Challenger (BroodMature): the grown creature's first call
    "brood/mature_tyrant_challenger": [cut("tchal", 0.08, 1.25, fade=0.45)],
    "brood/mature_venom_challenger": [hiss(0.9, 0.35), cut("venom2", 0.50, 1.40, at=0.15, fade=0.5)],
    "brood/mature_storm_challenger": [cut("storm", 0.15, 1.30, fade=0.45)],
    # the old synth "roar" (the fallback of every roar cue) is now a real one
    "roar": [cut("terr", 0.05, 1.30, pitch=0.95, fade=0.45)],
}


_cache = {}


def rd(name):
    if name not in _cache:
        cmd = ["ffmpeg", "-v", "quiet", "-i", os.path.normpath(os.path.join(SRC_DIR, SRC[name])), "-f", "f32le",
               "-ar", str(SR), "-ac", "1", "-"]
        x = np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, np.float32).astype(np.float64)
        if name in SRC_LP:
            x = sosfilt(butter(2, SRC_LP[name], "low", fs=SR, output="sos"), x)
        _cache[name] = x
    return _cache[name]


def layer(src, start, length, pitch, fade, to=None, lp=None):
    x = rd(src)
    a = int(start * SR)
    seg = x[a:a + int(length * SR)].copy()
    p0, p1 = pitch, (to if to is not None else pitch)
    if p0 != 1.0 or p1 != 1.0:      # resample: higher and shorter, or lower and longer; gliding from p0 to p1
        t = np.arange(len(seg), dtype=np.float64)
        rate = p0 + (p1 - p0) * t / len(seg)              # input samples per output sample, at each input sample
        n_at = np.concatenate([[0.0], np.cumsum(1.0 / rate)[:-1]])    # the output sample each input sample lands on
        pos = np.interp(np.arange(int(n_at[-1])), n_at, t)
        seg = np.interp(pos, t, seg)
    if lp:
        seg = sosfilt(butter(2, lp, "low", fs=SR, output="sos"), seg)
    fi = min(int(0.010 * SR), len(seg) // 4)
    seg[:fi] *= np.linspace(0, 1, fi)
    fo = int((fade if fade is not None else min(0.3, len(seg) / SR / 4)) * SR)
    fo = min(fo, len(seg))
    if fo > 0:
        seg[-fo:] *= np.linspace(1, 0, fo) ** 1.5
    return seg / (np.abs(seg).max() + 1e-9)


def build(layers):
    parts = [(int(l[3] * SR), layer(l[0], l[1], l[2], l[5], l[6], l[7], l[8]) * l[4]) for l in layers]
    n = max(at + len(p) for at, p in parts)
    out = np.zeros(n)
    for at, p in parts:
        out[at:at + len(p)] += p
    out = sosfilt(butter(2, 50, "high", fs=SR, output="sos"), out)      # (no rumble below 50 Hz)
    # a quiet lead-in (under 1/20 of the peak, -26 dB) is trimmed: the creature answers at once
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
        assert name not in ("bite", "hatch"), "the old bite and hatch are read as layers, never written"
        x = build(layers)
        save(path_of(name), x)
        print("%-44s %.2f s" % (name, len(x) / SR))


if __name__ == "__main__":
    main(sys.argv[1:])
