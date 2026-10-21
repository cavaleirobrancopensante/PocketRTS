# PocketRTS: sound and voice list

Every sound the game uses is listed below, with the file name to save it as and a prompt to paste into a generator.
Drop the files into the named folder and the game picks them up on the next build. Any file that is missing falls back to the built-in synth sound, so you can add them a few at a time.

- **Format:** `.wav` or `.ogg`, mono, 44.1 kHz. Trim silence at the start; game sounds should hit on frame one.
- **Variants:** `_1`, `_2`, `_3` are alternatives. The game picks one at random, so repeated actions don't sound robotic. One variant is enough to start; add more later.
- **Length:** keep UI sounds under 0.5 s, combat under 1.5 s and voice lines under 2 s.

**Count at a glance**

| Group | Files (one variant each) | With all variants |
|---|---|---|
| A. Interface (shared) | 12 | 12 |
| B. Faction interface | 27 | 27 |
| C. Combat | 33 | ~70 |
| D. Work and buildings | 14 | 14 |
| E. Ambience loops | 6 | 6 |
| F. Unit voices | 45 | ~105 |
| G. Faction announcer | 36 | 36 |
| H. AI commander taunts (optional) | 24 | 24 |
| **Total** | **~197** | **~294** |

Start with A, B and the attack and death sounds in C (about 70 files). Those change the feel the most.

---

## A. Interface (shared) → `assets/audio/ui/`

Style suffix for all of these: *"clean, short, warm, wooden and brass fantasy RTS menu sound, no reverb tail"*.

| File | Prompt |
|---|---|
| `click.wav` | Soft wooden button click with a tiny brass tick |
| `hover.wav` | Very quiet paper rustle tick, 0.1 seconds (computer version only) |
| `back.wav` | Lower-pitched wooden click, closing a drawer softly |
| `open_panel.wav` | Parchment map unrolling quickly, 0.3 seconds |
| `toggle.wav` | Small brass switch flick |
| `slider.wav` | Single soft ratchet tick |
| `error.wav` | Dull muted wooden thunk, two quick knocks, "can't do that" |
| `start_match.wav` | War drum hit plus a rising brass swell, 1.5 seconds |
| `pause.wav` | Muffled low gong, short |
| `select_box.wav` | Faint whoosh, chalk drawn across a slate |
| `group_set.wav` | Two rising brass ticks |
| `minimap_ping.wav` | Bright bell ping, a single soft strike |

## B. Faction interface → `assets/audio/<crown|brood|clock>/`

Nine sounds per faction, 27 in total. Use the same file names in each faction folder.

| File | Crown (royal, brass, drums) | Brood (organic, wet, chitin) | Clockwork (gears, steam, electric) |
|---|---|---|---|
| `ready.wav` (unit trained) | Short trumpet flourish, 3 notes | Wet egg sac pops, chirp | Steam hiss plus a ding of a bell |
| `placed.wav` (building placed) | Hammer on wooden stake | Squelching mound of flesh settles | Heavy metal bolt clunks into place |
| `built.wav` (building finished) | Fanfare, 4 brass notes and a snare roll | Deep organic heartbeat swell and a growl | Gear train winding up and ending in a chime |
| `research.wav` (upgrade done) | Quill scratch and a regal bell | Chittering crescendo | Tesla crackle and an ascending tone |
| `no_res.wav` (can't afford) | Coin purse shaken, nearly empty | Hungry gurgling stomach | Spring winding down, sputtering |
| `no_supply.wav` (supply full) | Crowd murmur and a rejected horn blip | Low hiss | Pressure-valve warning whistle |
| `alert.wav` (units under attack) | War horn blast, short | Shrill insect screech | Klaxon, two pulses |
| `base_alert.wav` (base under attack) | Alarm church bell, 3 rapid strikes | Hive-wide rumbling roar | Factory siren, rising |
| `select_building.wav` | Wooden door creak | Wet breathing pulse | Ticking clockwork |

## C. Combat → `assets/audio/combat/`

Per unit: `<unit>_attack`, `<unit>_hit` (the impact on the target) and `<unit>_death`, with variants `_1`, `_2`, `_3` where marked ×3.

**Crown**
- `musketeer_attack` ×2, `cannon_attack`, `cannon_canister`, `mortar_attack`: recordings (tools/audio/import_shots.py).
- `pikeman_attack` ×3: Steel pike thrust, metal scrape, grunt-free.
- `cuirassier_attack` ×3, `cuirassier_move` ×2, `cuirassier_death` ×2: sabre swing and hit, gallop, horse scream and fall (the horse itself, `horse/whinny`, is a recording).
- `cannon_hit` ×2: Cannonball impact, dirt and splinters exploding.
- `crown_death` ×3: Short soldier death cry, muffled, not gory.
- `missionary_heal`: Soft choir "ahh" swell and a cloth bandage wrap, 2 seconds.

**Brood**
- `raptor_attack` ×3: Small reptile claw slash with a snap of jaws.
- `spitter_attack` ×3: Wet acidic spit launched, gurgle and splat.
- `spitter_hit` ×2: Acid sizzling on metal and flesh.
- `brute_attack` ×2: Huge beast slam, heavy thud with a roar.
- `skywing_attack` ×2: Leathery wing dive with a screech.
- `brood_death` ×3: Insectoid creature death squeal, wet collapse.

**Clockwork**
- `gearknight_attack` ×3: Mechanical knight sword strike, clanking armour and a steel ring.
- `bolt_attack` ×3: Heavy crossbow mechanism firing, ratchet then twang.
- `steam_walker_attack` ×2: Steam-powered stomp-and-blast, pressure hiss and a metallic bang.
- `tesla_attack` ×3: Tesla coil arc discharge, sharp electric crack.
- `tesla_deploy`: Machine unfolding, gears and servo whine, 1.5 seconds.
- `clock_death` ×3: Machine breaking apart, springs flying, gears clattering.

**Shared**
- `explosion_small` ×2: Small explosion, short.
- `explosion_big` ×2: Building-sized explosion with debris.
- `building_collapse` ×2: Wooden structure collapsing, crumbling.
- `arrow_whoosh`: Projectile whoosh past.

## D. Work and buildings → `assets/audio/work/`

| File | Prompt |
|---|---|
| `crown_build.wav` | Hammering nails and sawing wood, looping 2 seconds |
| `farm_harvest.wav` | Scythe swish and a wheat bundle tossed onto a cart |
| `mill_grind.wav` | Wooden mill wheel grinding, looping |
| `powder_ready.wav` | Powder keg rolled and set down |
| `brood_build.wav` | Flesh knitting together, wet organic growth loop |
| `grub_feed.wav` | Small creature munching greedily |
| `grub_deliver.wav` | Wet plop into a pile |
| `midden_essence.wav` | Eerie whispering bubble |
| `clock_build.wav` | Wrench ratcheting and welding sparks loop |
| `winder_crank.wav` | Hand crank turning a big spring, ratchet loop |
| `boiler.wav` | Boiler chugging with steam release |
| `crusher.wav` | Stone ore crushed by iron rollers |
| `pylon_charge.wav` | Electric hum building up |
| `husk_power_down.wav` | Machine winding down to silence (for the husk idea) |

## E. Ambience loops → `assets/audio/ambience/`

30-second seamless loops, quiet, played under the music.

- `grass.ogg`: meadow wind, distant birds.
- `autumn.ogg`: rustling dry leaves, crows.
- `desert.ogg`: hot wind, sand hiss.
- `snow.ogg`: cold howling wind, crunching.
- `marsh.ogg`: frogs, bubbling mud, insects.
- `volcanic.ogg`: low rumble, crackling lava.

---

## F. Unit voices → `assets/voice/<unit>/`

Each unit has three files: `select_1..3` (clicked), `move_1..3` (ordered to move) and `attack_1..2` (ordered to attack). Keep each line 0.5 to 1.5 seconds.

Voice direction to paste into the voice tool:

- **Crown:** British-sounding 1700s soldiers; confident, disciplined, a bit of humour.
- **Brood:** not words. Clicks, hisses, chitters and growls, each with a distinct pitch per unit. Make these in a sound-effects generator, not a voice one.
- **Clockwork:** robotic, metallic, slightly vocoded; formal and precise.

| Unit | Select | Move | Attack |
|---|---|---|---|
| Labourer | "Aye?" / "Work to do?" / "Hands ready." | "On my way." / "Right then." / "Going." | "With a shovel?!" / "If I must!" |
| Pikeman | "Pikes ready." / "Hold the line!" / "Sir?" | "Forward." / "Marching." / "Steady pace." | "Brace!" / "Pikes down!" |
| Musketeer | "Powder dry." / "Loaded, sir." / "Musket ready." | "Moving out." / "By the left!" / "Aye." | "Present... fire!" / "Take aim!" |
| Field Cannon | "Gun crew ready." / "Where to, sir?" / "Heavy, this." | "Push!" / "Roll her out!" / "Heave!" | "Fire in the hole!" / "Give 'em iron!" |
| Missionary | "Peace be with you." / "Who is hurt?" / "I am here." | "I will go." / "Lead me." / "With faith." | (none: missionaries don't attack) |
| Grub | Small squeaky chirps | Wet hurried squeak | (none) |
| Raptors | Fast clicking chitter, three voices | Excited hiss | Shriek |
| Spitters | Gurgling croak | Sloshing hiss | Hacking spit-cough |
| Brute | Deep rumbling grunt | Heavy snort | Thunderous roar |
| Skywing | High screech | Wing flap and cry | Diving scream |
| Winder | "Tick-tock." / "Spring tension nominal." / "Awaiting instruction." | "Relocating." / "Acknowledged." / "Proceeding." | "Unsuitable task." / "Very well." |
| Gearknight | "Blade sharpened." / "For the Great Clock." / "Ready." | "Advancing." / "Gears turning." / "As commanded." | "Engaging." / "Cut them down." |
| Bolt Automaton | "Bolts loaded." / "Target?" / "Tension set." | "Moving." / "Repositioning." / "Confirmed." | "Loosing!" / "Bolt away." |
| Steam Walker | "Pressure at maximum." / "Boilers hot." / (hiss) | "Stomping forward." / "Underway." / (whistle) | "Venting fury!" / "Crush them." |
| Tesla Cart | "Charge holding." / "Capacitors full." / (crackle) | "Packing up." / "Rolling." / "Unit mobile." | "Discharging!" / "Lightning ready." |

**Total:** 15 units × about 7 lines = about 105 files.

## G. Faction announcer → `assets/voice/announcer/<faction>/`

One narrator per faction: a royal herald for the Crown, a hissing hive-mind whisper for the Brood and a calm automaton voice for the Clockwork. Twelve lines each:

`unit_ready` "Unit ready." · `building_done` "Construction complete." · `research_done` "Research complete." · `under_attack` "Our forces are under attack." · `base_attack` "Our base is under attack!" · `no_gold` "Not enough gold." (Brood: "Not enough food." / Clockwork: "Insufficient ore.") · `no_res2` (Powder / Essence / Energy) · `no_supply` "We require more housing." (Brood: "More clutches needed." / Clockwork: "More springs required.") · `expansion` "New hall established." · `building_lost` "A building has fallen." · `victory` "Victory!" · `defeat` "We are defeated."

## H. AI commander taunts (optional) → `assets/voice/taunt/<faction>/`

Played when the enemy AI attacks you, loses its army, or wins. Eight per faction, 24 in total. Examples:

- **Crown general:** "You face the King's own regiment." / "Volley fire!" / "Retreat... regroup!" / "Long live the Crown!"
- **Brood hive-mind** (whispering, layered): "We are many." / "Your walls will feed us." / "We hunger." / "Hssss..."
- **Clockwork overseer:** "Your defeat has been calculated." / "Efficiency: rising." / "Recalculating." / "Time is on our side."

---

## Free tools

- **Beeps and retro UI tones:** jsfxr (sfxr.me) or ChipTone run in the browser and need no account. Press "random" in a category, tweak, then export the WAV.
- **AI sound effects:**
  - ElevenLabs Sound Effects has a free plan. Its free-tier output is not licensed for commercial use, so it's fine while prototyping; upgrade before selling the game.
  - Stable Audio Open is free to run locally. Commercial use is allowed below a revenue threshold; check the licence.
- **Free recordings:** freesound.org. Filter by the CC0 licence, which needs no credit.
- **Voices (AI):**
  - Kokoro TTS (Apache-2.0): free, runs offline, natural-sounding, and commercial use is allowed.
  - Piper TTS: also free and offline, but sounds more robotic. That is a good fit for the Clockwork once you add a robot filter.
  - ElevenLabs voice design gives the best results but has the same free-tier commercial limits.
- **Your own voice:** record yourself or friends in Audacity (free), then pitch and filter: a vocoder or ring modulator for the Clockwork, pitch-down for Brutes.
- **Editing:** Audacity to trim, normalise (−1 dB), convert to mono and export WAV or OGG.
