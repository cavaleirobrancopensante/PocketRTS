# Brood sounds

The Brood now sounds like reptiles. Its creatures answer with grunts, growls, roars and hisses. There are no words, as the owner asked.
Every new sound is cut from the eleven recordings the owner sent on 2026-10-29 ("use them at your discretion in the Brood faction").
They are in `art/audio_src/brood/`. SOURCES.txt there names each one. The small dino raspy calls are from Pixabay: free to use, no credit needed.
Nothing is synthesised. The pieces are only cut, layered, faded, filtered and pitched up or down by resampling. Two of the game's older sounds are used as layers under the calls: `bite` (a crunch under every blow) and `hatch` (an egg's shell).

## How to change a sound

Everything is made by one script: `tools/audio/make_brood_sounds.py`.
Each sound is one line there. Each piece in it says which recording, where it starts and how long it is, in seconds, and its pitch.
So "make the Brute lower" is one number: the pitch in the `voice/brute` lines.
Then run these, in order:

1. `python3 tools/audio/make_brood_sounds.py` (or with a name, like `brute`, to remake only those).
2. `godot --headless --import`
3. The levels: `python3 tools/audio/make_mix.py` rewrites the whole table in `scripts/sound_mix.gd`. It also changes some older hand-tuned levels, so keep only the lines of the files you remade, as this job did.

The test is `tools/test_brood_sounds.gd`. It checks every sound of the script: the file loads, its length is sensible, and it has a level. It checks that every Brood creature has its select, move and attack answers, its death, and its blow if it fights. Then it plays a Brood match: each creature is picked, sent off, told to attack, fights a Musketeer and dies. It fails if a sound is not heard, or if a Brood creature still plays the sword "clash" or the old generic Brood death.

## Who sounds like what

The owner's file names said which line he had in mind, so each line got its own recording.
When two creatures share a recording, the big one is pitched down and the small one up, and their takes are cut from different parts of it.

| Creature | Recording | How |
|---|---|---|
| Grub | weak_grown | Much higher (x1.6 to 1.85): a small, weak whine. It is the quietest, because it is picked all game long. |
| Raptor | the owner's older lizard recording | Kept as it was. |
| Tyrant Challenger | tyrant_challanger | As recorded, cut short. |
| Tyrant Sire | tyrant_sire | A little lower (x0.9). |
| Brute | terrifying | Lower (x0.8 to 0.88): a huge bellow. |
| Spitter | spitter | Its three calls: a rattle, a screech and a chatter. Its spit is the venom hiss. |
| Venom Challenger | venom2 | As recorded: a croaking growl. |
| Venom Sire | venom_sire | A little lower (x0.9). |
| Mist Toad | weird | Lower (x0.6 to 0.76): a croaking warble. |
| Hatchlings (not in the game yet) | small dino raspy calls | Higher (x1.2 to 1.45). |
| Skywing | storm | Higher (x1.3 to 1.45). |
| Storm Challenger (not in the game yet) | storm | As recorded. |
| Storm Sire | storm, with tyrant_sire under it | Lower (x0.8), the Tyrant's growl underneath for weight. |
| Rootmaw | weak_grown | Lower (x0.75 to 0.8): a swamp lizard's contented growl. |
| Mound Turtle | venom2 | Much lower (x0.55 to 0.62): a slow, deep groan. |
| Brood Mother | terrifying, with weak_grown under it | Far lower (x0.56 to 0.64), with a deep moan underneath. |
| Egg | weak_grown | Very high (x1.9) and muffled: the creature stirring inside its shell. |
| A mixed Brood group | three recordings at once | A little chorus of creatures. |

## How the recordings were measured

The recordings could not be listened to. They were chosen by measuring them: loudness every 20 ms, where each sound starts, how bright it is, and its pitch.

- **small dino raspy calls**: two calls of quick chirps, at 0.10 to 0.50 s and 1.17 to 1.56 s. Bright.
- **spitter**: three calls. A hissing rattle (0.48 to 0.92 s), a screech (1.02 to 1.60 s), and a fast chatter of clicks (2.02 to 2.80 s).
- **storm**: one long cry, 0.16 to 2.0 s, throbbing about every 0.13 s. Quiet.
- **terrifying**: one huge roar, 0.06 to 1.75 s, loudest at 0.3 to 1.0 s. A few samples clip.
- **tyrant_challanger**: a roar, 0.10 to 1.0 s, dying away to 1.4 s. It clips heavily. A gentle filter softens the clipped edges.
- **tyrant_sire**: a long growling roar, 0.08 to 1.6 s, throbbing about every 0.12 s.
- **venom**: a bright hiss through its whole 0.6 s. It became the spit.
- **venom2**: a dark, croaking growl swelling from 0.40 to 2.0 s, then brighter and dying away to 2.6 s.
- **venom_sire**: a growl, 0.18 to 2.5 s, loudest at 1.0 to 1.8 s.
- **weak_grown**: a whining growl, 0.08 to 1.2 s, with a clear tone near 530 Hz.
- **weird**: a steady, bright warbling call, 0.05 to 1.2 s.

## The sounds

"x0.9" is the pitch: under 1 is lower and longer, over 1 is higher and shorter. "x1.0 to 0.7" is a pitch that slides down over the piece. Every death slides down like this. Seconds are in the recording.
Voices have 3 takes for select and move, and 2 for attack. The game picks one at random, so repeats differ.

| Sound | When it plays | Cut from |
|---|---|---|
| `voice/grub/select`, `move`, `attack` | You pick a Grub, send it, or order it to attack. | weak_grown 0.20, 0.55, 0.85 s (0.34 to 0.40 s long) x1.55 to 1.7; move 0.24 s pieces x1.75 to 1.85; attack sliding up x1.45 to 1.8 |
| `voice/spitter/select`, `move`, `attack` | The Spitter answers. | spitter's rattle 0.48, screech 1.18 and chatter 2.02 (0.4 s); move 0.25 s pieces x1.05 to 1.12; attack: venom hiss, then its screech or chatter |
| `voice/venom_challenger/...` | The Venom Challenger answers. | venom2 0.62, 1.05, 1.50 (0.5 s); move 0.32 s; attack: a lower hiss (x0.9) into the growl |
| `voice/dilophosaurus/...` | The Venom Sire answers. | venom_sire 0.40, 1.00, 1.60 (0.65 s) x0.9; move 0.42 s; attack: the growl, then a big low hiss (x0.8) |
| `voice/mist_toad/...` | The Mist Toad answers. | weird 0.08, 0.45, 0.80 (0.4 s) x0.66 to 0.74; move 0.25 s; attack sliding up x0.6 to 0.8 |
| `voice/tyrant_challenger/...` | The Tyrant Challenger answers. | tyrant_challanger 0.12, 0.30, 0.50 (0.5 s); move 0.3 s; attack 0.45 s x0.92 to 0.95 |
| `voice/tyrannosaur/...` | The Tyrant Sire answers. | tyrant_sire 0.08, 0.50, 0.90 (0.7 s) x0.9; move 0.45 s; attack with terrifying under it |
| `voice/brute/...` | The Brute answers. | terrifying 0.10, 0.45, 0.85 (0.55 s) x0.82 to 0.88; move 0.35 s; attack 0.6 s x0.8 |
| `voice/brood_mother/...` | The Brood Mother answers. | terrifying 0.15, 0.55, 0.95 x0.6 + weak_grown x0.55 under it; move 0.4 s; attack with tyrant_sire x0.6 under it |
| `voice/rootmaw/...` | A Rootmaw answers. | weak_grown 0.15, 0.50, 0.80 (0.45 s) x0.75 to 0.8; move 0.3 s; attack sliding up x0.7 to 0.85 |
| `voice/mound_turtle/...` | A Mound Turtle answers. | venom2 0.70, 1.10, 1.45 (0.45 s) x0.58 to 0.62; move 0.3 s; attack x0.55 to 0.65 |
| `voice/brood_egg/select` (2 takes) | You pick an egg. | weak_grown x1.9 to 2.0, muffled (lowpass 1 kHz); the second with a soft creak of the old hatch sound |
| `voice/hatchlings/...` | The Hatchlings answer (ready for when they come). | raspy calls 0.10, 1.16, 0.20 x1.2 to 1.32; move 0.2 s x1.4; attack with a high storm cry under it |
| `voice/skywing/...` | The Skywing answers. | storm 0.20, 0.75, 1.30 (0.45 s) x1.3 to 1.4; move 0.3 s; attack sliding up x1.3 to 1.5 |
| `voice/storm_challenger/...` | The Storm Challenger answers (ready for when it comes). | storm 0.20, 0.80, 1.35 (0.55 s) x1.0 to 1.08; move 0.35 s; attack sliding up |
| `voice/pterodactyl/...` | The Storm Sire answers. | storm 0.20, 0.85, 1.40 (0.6 s) x0.8 + tyrant_sire x0.85 quietly under it; move 0.4 s; attack with the Tyrant's roar under it |
| `voice/brood_army/select`, `move`, `attack` | You pick, or give an order to, two or more kinds of Brood fighters. | A chorus: raspy + spitter + terrifying; tyrant_challanger + storm + venom2; tyrant_sire + raspy + spitter (offset by 0.1 to 0.25 s) |
| `combat/<kind>_attack` | Each blow of the Tyrant Challenger (3 takes), Tyrant Sire, Brute, Brood Mother, Rootmaw, Mound Turtle, Storm Sire, Storm Challenger, Hatchlings and Mist Toad (its lick). | A 0.12 to 0.32 s snarl of the creature's own call, over the old bite pitched to its size (x0.5 for the Mother to x1.35 for the Hatchlings) |
| `combat/spitter_attack` (3 takes) | Every Spitter spit. | venom hiss 0.28 s, x1.05 to 1.25 |
| `combat/venom_challenger_attack`, `combat/dilophosaurus_attack` | Their venom globs (Game.acid_shot now plays each kind's own). | venom hiss x0.92 to 0.95 / x0.8 to 0.85, with a bit of their growl under it |
| `combat/mist_toad_tongue` | The Mist Toad's TONGUE lashes out. | weird 0.35 s sliding up from x0.6 to 1.0, a bite at the end |
| `combat/brute_charge` | A Brute charges at its target. | terrifying 0.06 to 1.01 s x0.88: his whole bellow |
| `combat/brood_mother_devour` | The Brood Mother devours an offering. | terrifying x0.56 with two bites |
| `combat/<kind>_death` | Every Brood creature dies (Raptor kept as it was). | The creature's own call, sliding down by about a third: Grub 0.35 to 0.4 s, Spitter 0.45 s, Brute 0.55 to 0.65 s, the Sires 0.7 to 0.85 s, the Brood Mother 0.9 s of terrifying x0.62 to 0.42 with a moan under it (1.9 s). The egg: the old hatch sound lower with a muffled cry. |
| `brood/arrive_tyrannosaur`, `_dilophosaurus`, `_pterodactyl` | A Sire comes to his lure (the cue: "the Sire arrives"). | tyrant_sire 0.05 to 1.67 s x0.95 / venom_sire 0.15 to 2.45 s x0.97 / storm 0.15 to 2.10 s x0.88 with tyrant_sire under it |
| `brood/breath_<sire>` | A Sire breathes on an egg (the egg turns red). | 0.6 s of his call, lower (x0.75 to 0.85) |
| `brood/mature_<challenger>` | A young creature finishes maturing into its Challenger. | tyrant_challanger 0.08 to 1.33 s / a hiss into venom2 0.50 to 1.90 s / storm 0.15 to 1.45 s |
| `roar` | The fallback for every roar cue. It was a synth sound before. | terrifying 0.05 to 1.35 s x0.95 |

## The code that changed

Most sounds needed no code, because the game looks for a file by its name (`combat/<kind>_attack`, `combat/<kind>_death`, `voice/<kind>/...`). Before this, a creature with no file of its own fell back to the sword "clash" for its blows. That was the Tyrant Challenger, the Sires, the Brood Mother, the Rootmaw, the Mound Turtle and the Mist Toad.

Each change below is one sound line. Only the list of sound names changed, so there is no gameplay change.

- `scripts/game.gd`: `acid_shot` plays `combat/<kind>_attack` first, so each spitter has its own hiss. `_select_voice_kind` and `command_sound` use the new `_army_voice`. A mixed Brood group (two or more kinds of fighters) answers with `voice/brood_army`. The Crown's `crown_army` works as before.
- `scripts/brood_root.gd`: the lure's arrival cue plays `brood/arrive_<sire>` first.
- `scripts/brood_new.gd`: a father's breath plays `brood/breath_<sire>`, and the Mother's devour plays `combat/brood_mother_devour`.
- `scripts/brood_mature.gd`: maturing plays `brood/mature_<kind>`.
- `scripts/unit.gd`: the Mist Toad's tongue plays `combat/mist_toad_tongue`, and the Brute's charge plays `combat/brute_charge`. Both played the Brute's blow before.
- `scripts/sfx.gd`: GAP entries for the new repeating sounds. The Brute's charge is at most once every 1.5 s, and a father's breath once every 1.5 s.

## Decisions made while the owner was away

- **The Raptor keeps the owner's lizard recording** (since 0.7.84) for its voice and deaths. Its blow, the Skywing's spines and the Grub's bite keep their older sounds. Every other Brood voice and death is new. The old insect clips of the Grub, Spitter, Brute, Mist Toad and Skywing are replaced, because the owner wants the Brood reptilian first.
- The Grub's move voice was insect feet. Now it is the same small call, as with every other creature.
- **Who got which recording** follows his file names. The ones he did not name are Claude's choice:
  - weak_grown: the Grub, the Rootmaw, the Egg and under the Mother.
  - terrifying: the Brute and the Mother.
  - weird: the Mist Toad.
  - venom2: the Venom Challenger and the Mound Turtle.
  - the raspy calls: the Hatchlings and the army chorus.
- The Hatchlings and the Storm Challenger are not in the game yet, but their sounds are ready. The game will find them by name when they come.
- The Brood's faction sounds (`brood/alert`, `ready`, `built` ...) and the shared alarm are unchanged. The Brood has no buildings now, and the job was its creatures.
- A rooted creature answers with the same voice as when it walks. Sfx.voice does not know the state.
- `make_brood_voices.py` (the old insect voices) is still there, but running it would bring the insect voices back. Do not run it.

## What the owner could record next

- **A bite or crunch**: real jaws on meat or a bone snapping. Every blow still uses the old synth bite under the creature's snarl.
- **A spit or wet splat**: for the acid landing (`combat/spitter_hit` is still synth).
- **An egg cracking**: a real shell breaking (the hatch sound is still synth).
- **Small chirps or squeaks**: a second small creature, so the Grub and the Raptor's young are not all one recording.
- **Wing flaps**: a big leathery flap for the Storm Sire and the Skywings.
- **Mud and swamp sounds**: a squelch for rooting and uprooting, and a slurp for the Rootmaw drinking the ground.
