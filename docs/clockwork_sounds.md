# Clockwork sounds

The Clockwork now sounds like clockwork.
Every sound below is cut from the eight recordings the owner sent on 2026-10-27.
They are in `art/audio_src/clockwork/`. SOURCES.txt there names each one. Their licence is the Pixabay Content License.
No sound is synthesised. The pieces are only cut, layered, faded, and sometimes pitched up or down by resampling.

## How to change a sound

Everything is made by one script: `tools/audio/make_clockwork_sounds.py`.
Each sound is one line there. Each piece in it says which recording, where it starts, and how long it is, in seconds.
So "make the Jack's jump longer" is one number: the length in the `combat/jack_jump` lines.
Then run these, in order:

1. `python3 tools/audio/make_clockwork_sounds.py` (or with a name, like `jack_jump`, to remake only those).
2. `godot --headless --import`
3. The levels: `python3 tools/audio/make_mix.py` rewrites the whole table in `scripts/sound_mix.gd`. It also changes some older hand-tuned levels. So keep only the lines of the files you remade, as this job did.

The test is `tools/test_clockwork_sounds.gd`. It plays a Clockwork match and checks that every sound of the script is heard, and that no Clockwork thing still falls back to a generic or Crown sound.

## How the pieces were chosen

The sounds could not be listened to. They were chosen by measuring them: loudness over time, where each hit starts, how bright it is, its pitch, and whether it is a tone or a noise.

- The clang group has twelve single clangs, about one every 0.9 seconds. They are bright, most of the ring is between 6 and 9 kHz. The one at 6.4 seconds is left out: it clips.
- The old clock bell is struck at 1.56 and 3.66 seconds. It rings at 680 Hz with a hum at 320 Hz. It is quiet, with some hiss before the strikes.
- The alarm clock ticks from 1.6 to 7 seconds, one tick every 0.3 seconds. Then the bell rings, from 7.56 to about 17 seconds.
- The crank loop turns about every 1.6 seconds: a burst of ratchet clicks, then a quiet grind.
- The liquid wobble has four springy wobbles. They make the boings.
- The metallic noise is a crash in its first half second, then pieces rattling and settling until 2.7 seconds.
- The spring scrape is one scrape, then a ring that dies away over three seconds.
- The typewriter is keys all through. Its carriage bell rings at 30.33 and 48.44 seconds. The carriage slides back at 49.3 seconds.

## The sounds

"Lower" or "higher" means the piece was pitched down or up. Seconds are in the recording.

| Sound | Where it plays | Cut from (recording, seconds) |
|---|---|---|
| `voice/clock_soldier/select` (3 takes) | You pick a Clock Soldier. A few typewriter keys. | typewriter 0.88 to 1.20 / typewriter 3.93 to 4.23 / typewriter 25.28 to 25.54 |
| `voice/clock_soldier/move` (3 takes) | You send a Clock Soldier somewhere. A quick run of keys. | typewriter 5.29 to 5.69 / typewriter 12.21 to 12.65 / typewriter 22.73 to 23.17 |
| `voice/clock_soldier/attack` (2 takes) | You order a Clock Soldier to attack. Keys, then the carriage bell. | typewriter 37.57 to 37.93 + typewriter 30.33 to 30.88 / typewriter 33.39 to 33.75 + typewriter 48.44 to 48.89 |
| `voice/jack/select` (3 takes) | You pick a Jack. A spring boings. | liquid wobble 0.76 to 1.14 + crank loop 0.12 to 0.26 higher / liquid wobble 1.63 to 1.99 higher / liquid wobble 2.51 to 2.87 + typewriter 18.66 to 18.82 |
| `voice/jack/move` (3 takes) | You send a Jack. A ratchet click and a boing. | crank loop 1.78 to 2.08 higher + liquid wobble 1.63 to 1.95 higher / crank loop 3.25 to 3.55 higher + liquid wobble 2.51 to 2.83 higher / liquid wobble 0.76 to 1.06 higher + liquid wobble 2.51 to 2.81 higher |
| `voice/jack/attack` (2 takes) | You order a Jack to attack. A spring scrape and a click. | spring scrape 0.08 to 0.48 higher + crank loop 5.02 to 5.22 higher / spring scrape 0.10 to 0.50 higher + liquid wobble 1.63 to 1.88 higher |
| `voice/cuckoo/select` (3 takes) | You pick a Swift. Quick high ticks and a little ding. | alarm clock 2.46 to 3.36 higher + typewriter 30.33 to 30.78 higher / alarm clock 3.66 to 4.56 higher + typewriter 48.44 to 48.84 higher / alarm clock 4.86 to 6.06 higher |
| `voice/cuckoo/move` (3 takes) | You send a Swift. Quick high ticks. | alarm clock 2.76 to 3.36 higher / alarm clock 4.26 to 4.86 higher / alarm clock 5.46 to 6.36 higher |
| `voice/cuckoo/attack` (2 takes) | You order a Swift to attack. Ticks and a high ding. | alarm clock 3.06 to 3.66 higher + typewriter 30.33 to 30.73 higher / alarm clock 6.06 to 6.66 higher + typewriter 48.44 to 48.79 higher |
| `voice/ticking_owl/select` (3 takes) | You pick a Ticking Owl. Slow, low ticks. | alarm clock 2.16 to 2.91 lower / alarm clock 3.36 to 4.11 lower / alarm clock 4.56 to 5.16 lower + old clock bell 1.56 to 1.96 lower |
| `voice/ticking_owl/move` (3 takes) | You send a Ticking Owl. Two low ticks. | alarm clock 2.46 to 3.06 lower / alarm clock 3.96 to 4.56 lower / alarm clock 5.16 to 5.76 lower |
| `voice/ticking_owl/attack` (2 takes) | You order a Ticking Owl to attack. Low ticks and a crank. | alarm clock 2.76 to 3.36 lower + crank loop 0.12 to 0.46 lower / alarm clock 5.76 to 6.36 lower + crank loop 1.78 to 2.12 lower |
| `voice/pendulum/select` (3 takes) | You pick a Pendulum. The old clock bell, a little lower. | old clock bell 1.56 to 2.46 lower / old clock bell 3.66 to 4.51 lower / crank loop 3.25 to 3.55 lower + old clock bell 1.56 to 2.11 lower |
| `voice/pendulum/move` (3 takes) | You send a Pendulum. A slow, heavy crank turn. | crank loop 0.12 to 0.46 lower / crank loop 1.78 to 2.12 lower / crank loop 5.02 to 5.38 lower |
| `voice/pendulum/attack` (2 takes) | You order a Pendulum to attack. A crank, then a low clang. | crank loop 3.25 to 3.50 lower + clang group 4.53 to 4.83 lower / crank loop 0.12 to 0.37 lower + clang group 10.68 to 10.98 lower |
| `voice/netter/select` (3 takes) | You pick a Netter. A crank cocks its spring cannon. | crank loop 0.12 to 0.48 lower / crank loop 1.78 to 2.14 lower / crank loop 3.25 to 3.55 lower + typewriter 19.00 to 19.18 |
| `voice/netter/move` (3 takes) | You send a Netter. A crank click and its grind. | crank loop 5.02 to 5.32 + crank loop 0.55 to 0.85 / crank loop 0.12 to 0.36 higher + crank loop 2.15 to 2.45 / crank loop 3.25 to 3.49 + crank loop 3.65 to 3.95 |
| `voice/netter/attack` (2 takes) | You order a Netter to attack. A crank, then the spring lets go. | crank loop 1.78 to 2.06 + spring scrape 0.08 to 0.53 / crank loop 5.02 to 5.30 + spring scrape 0.10 to 0.55 lower |
| `combat/clock_soldier_attack` (3 takes) | Each sword blow of a Clock Soldier. A bright clang. | clang group 0.07 to 0.47 lower / clang group 1.88 to 2.28 lower / clang group 2.75 to 3.15 lower |
| `combat/clock_soldier_death` (2 takes) | A Clock Soldier dies. A crash, pieces rattling, a spring. | metallic noise 0.02 to 0.47 + metallic noise 0.62 to 1.52 + liquid wobble 0.76 to 1.11 / metallic noise 0.02 to 0.47 lower + metallic noise 1.30 to 2.10 + liquid wobble 1.63 to 1.98 |
| `combat/jack_attack` (3 takes) | Each screw a Jack shoots. A fast ratchet spin. | crank loop 0.12 to 0.28 higher / crank loop 1.78 to 1.94 higher / crank loop 3.25 to 3.41 higher |
| `combat/jack_crouch` | A Jack crouches to jump. The spring is pressed. | spring scrape 0.08 to 0.48 lower |
| `combat/jack_jump` (2 takes) | A Jack leaves the ground. A boing. | liquid wobble 0.76 to 1.21 / liquid wobble 2.51 to 2.96 lower |
| `combat/jack_land` (2 takes) | A Jack lands. A low clank with a small boing. | clang group 3.65 to 3.90 lower + liquid wobble 1.63 to 1.88 higher / clang group 8.28 to 8.53 lower + liquid wobble 0.05 to 0.30 higher |
| `combat/jack_death` (2 takes) | A Jack dies. A crash and a big boing. | metallic noise 0.02 to 0.37 + liquid wobble 0.76 to 1.21 + metallic noise 0.90 to 1.50 / metallic noise 0.02 to 0.37 higher + liquid wobble 2.51 to 2.96 + metallic noise 1.60 to 2.20 |
| `combat/ratchet_turret_attack` (2 takes) | Each screw the Ratchet Turret shoots. A heavier ratchet and a clang. | crank loop 0.12 to 0.38 lower + clang group 0.91 to 1.16 lower / crank loop 5.02 to 5.28 lower + clang group 7.40 to 7.65 lower |
| `combat/cuckoo_attack` (3 takes) | Each peck of a Swift. One high typewriter key. | typewriter 18.66 to 18.80 higher / typewriter 19.00 to 19.14 higher / typewriter 9.66 to 9.80 higher |
| `combat/cuckoo_death` (2 takes) | A Swift dies. A small high crash and a ding. | metallic noise 0.02 to 0.37 higher + metallic noise 0.62 to 1.32 higher + typewriter 30.33 to 30.73 higher / metallic noise 0.02 to 0.37 higher + metallic noise 1.40 to 2.10 higher + typewriter 48.44 to 48.79 higher |
| `combat/ticking_owl_attack` (2 takes) | The Owl's talons strike a unit. A lower clang and a crash. | clang group 9.08 to 9.43 lower + metallic noise 0.02 to 0.27 lower / clang group 11.64 to 11.99 lower + metallic noise 0.02 to 0.27 lower |
| `combat/owl_morph` | A Swift starts to MORPH TO OWL. One turn of the crank. | crank loop 0.10 to 1.58 |
| `combat/owl_ready` | The Owl is ready. A strike of the old bell. | old clock bell 3.66 to 5.06 |
| `combat/owl_drop` | The Owl lets its weight go. A springy wobble. | liquid wobble 0.05 to 0.35 higher |
| `combat/owl_bomb` (2 takes) | The weight lands on a building. A heavy, low clang and clatter. | clang group 4.53 to 4.98 lower + metallic noise 0.02 to 0.47 lower + metallic noise 0.62 to 1.42 lower / clang group 10.68 to 11.13 lower + metallic noise 0.02 to 0.47 lower + metallic noise 1.40 to 2.20 lower |
| `combat/ticking_owl_death` (2 takes) | A Ticking Owl dies. A low crash, ticks, clatter. | metallic noise 0.02 to 0.47 lower + alarm clock 3.36 to 3.96 lower + metallic noise 0.62 to 1.42 lower / metallic noise 0.02 to 0.47 lower + liquid wobble 1.63 to 2.03 lower + metallic noise 1.40 to 2.20 lower |
| `combat/pendulum_attack` (3 takes) | Each blow of the Pendulum. A clang an octave down with a thud. | clang group 4.53 to 4.93 lower + metallic noise 0.02 to 0.37 lower / clang group 10.68 to 11.08 lower + metallic noise 0.02 to 0.37 lower / clang group 0.91 to 1.31 lower + metallic noise 0.02 to 0.37 lower |
| `combat/pendulum_death` (2 takes) | A Pendulum falls. A low crash, a low bell, clatter. | metallic noise 0.02 to 0.47 lower + old clock bell 1.56 to 2.16 lower + metallic noise 0.62 to 1.37 lower / metallic noise 0.02 to 0.47 lower + old clock bell 3.66 to 4.26 lower + metallic noise 1.30 to 2.05 lower |
| `combat/netter_attack` (2 takes) | The Netter fires its net. The spring scrapes and boings. | spring scrape 0.08 to 0.48 higher + liquid wobble 1.63 to 1.98 / spring scrape 0.10 to 0.50 higher + liquid wobble 0.76 to 1.11 |
| `combat/netter_hit` (2 takes) | The net lands on its target. Chains rattling. | metallic noise 0.62 to 1.32 higher + metallic noise 0.02 to 0.22 higher / metallic noise 1.30 to 2.00 higher + metallic noise 0.02 to 0.22 higher |
| `combat/netter_death` (2 takes) | A Netter dies. A crash, a spring, clatter. | metallic noise 0.02 to 0.47 lower + spring scrape 0.08 to 0.68 lower + metallic noise 0.62 to 1.42 / metallic noise 0.02 to 0.47 lower + liquid wobble 2.51 to 2.91 lower + metallic noise 1.40 to 2.20 |
| `combat/winder_attack` (2 takes) | A Winder hits something. A small clang and a click. | clang group 11.64 to 11.94 + crank loop 0.12 to 0.24 / clang group 8.28 to 8.58 higher + crank loop 3.25 to 3.37 |
| `combat/winder_death` (2 takes) | A Winder dies. A crash, clatter, a little spring. | metallic noise 0.02 to 0.42 higher + metallic noise 0.62 to 1.32 + liquid wobble 0.05 to 0.35 / metallic noise 0.02 to 0.42 higher + metallic noise 1.40 to 2.10 + liquid wobble 1.63 to 1.93 |
| `select/clocktower` (2 takes) | You pick the Clocktower. One strike of the old bell. | old clock bell 1.56 to 3.56 / old clock bell 3.66 to 5.66 |
| `select/cog_press` (2 takes) | You pick a Cog Press. A crank turning. | crank loop 0.10 to 1.20 lower / crank loop 3.23 to 4.33 lower |
| `select/mainspring` | You pick a Mainspring. A spring scraping and ringing. | spring scrape 0.06 to 1.36 |
| `select/escapement` (2 takes) | You pick an Escapement. Four ticks. | alarm clock 2.46 to 3.66 / alarm clock 4.26 to 5.46 |
| `select/regulator` | You pick a Regulator. Slower ticks and a soft bell. | alarm clock 3.06 to 3.96 lower + old clock bell 1.56 to 1.96 |
| `select/movement_works` (2 takes) | You pick a Movement Works. Two clangs and the carriage sliding. | clang group 2.75 to 3.05 lower + clang group 7.40 to 7.75 lower + typewriter 49.30 to 49.90 / clang group 9.08 to 9.38 lower + clang group 1.88 to 2.23 lower + typewriter 49.30 to 49.90 |
| `select/ratchet_turret` | You pick a Ratchet Turret. A ratchet and a clang. | crank loop 1.78 to 2.14 lower + clang group 3.65 to 3.95 lower |
| `select/cuckoo_house` | You pick a Clock Aviary. High ticks and a ding, like a cuckoo clock. | alarm clock 3.66 to 4.56 higher + typewriter 30.33 to 30.83 higher |
| `clock/alert` | Your Clockwork units are attacked. The alarm clock rings. | alarm clock 7.58 to 9.18 |
| `clock/base_alert` | Your Clockwork buildings are attacked. A tick, then the alarm clock rings. | alarm clock 6.92 to 7.22 + alarm clock 11.00 to 12.50 |
| `clock/research` | A Clockwork research is done. One strike of the old bell. | old clock bell 1.56 to 3.66 |
| `clock/built` | A Clockwork building is finished. The carriage slides back and its bell rings. | typewriter 49.30 to 50.15 + typewriter 48.44 to 48.94 |
| `clock/ready` | A Clockwork unit is ready. A ratchet turn and the carriage bell. | crank loop 3.25 to 3.55 + typewriter 30.33 to 30.83 |
| `ratchet` (2 takes) | A Winder picks up, sets down or unfolds a building crate. A ratchet. | crank loop 1.78 to 2.08 higher / crank loop 5.02 to 5.32 higher |
| `work/winder_crank` (3 takes) | A Winder cranks a Cog Press, about every 2 seconds. One turn of the crank. | crank loop 0.10 to 1.70 / crank loop 1.76 to 3.21 / crank loop 3.23 to 4.83 |
| `work/clock_build` (3 takes) | A Winder builds or repairs, about every 2 seconds. A click and a clang. | crank loop 0.12 to 0.32 + clang group 11.64 to 11.94 lower / crank loop 3.25 to 3.45 + clang group 8.28 to 8.58 lower / crank loop 5.02 to 5.22 + clang group 0.07 to 0.37 lower |

## The code that changed

Most sounds needed no code: the game looks for a file by its name.

- `scripts/sfx.gd`: GAP entries for the quick, repeating sounds, so a crowd of them is a clatter, not a wall. A faction's own alarm (`clock/alert`, `clock/base_alert`) is heard like the shared alarm: it is never dropped in a big fight.
- `scripts/game.gd`: the Clockwork plays the alarm clock instead of the shared alarm. Its own base being hit plays `clock/base_alert`. Research done also rings `clock/research`.
- `scripts/unit.gd`: a Winder manning a Cog Press now plays `work/winder_crank`. Before, only the old Ornithopter's winding used it, so the press was silent.

## Decisions made while the owner was away

- The shared attack alarm stays for the Crown and the Brood. Only the Clockwork's is the alarm clock, as the job asked.
- Voices are kept under about a second. The Pendulum's bell is the longest, one second.
- No VOICE_EXTRA was needed: every unit now has its own voice files.
- The Winder also got its own blow and death sounds, and the building crate (`ratchet`) is a real ratchet now. The job did not list them, but they used the old synth sounds.
- `clock/no_res`, `clock/no_supply`, `clock/placed` and `clock/select_building` were left as they are. The game does not play the first three for the Clockwork, and every Clockwork building now has its own pick sound.
- The Spring Catapult is not in the game yet, so it has no sounds. When it is added, a crank turn and a big spring boing from this script would fit.
- One thing seen while testing: a Swift ordered onto a balloon right under it did not peck. It hovered on top of it. Put a little to the side, it pecked at once. This was not changed here.
