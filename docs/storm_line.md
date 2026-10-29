# The Storm line (0.21.0, branch storm-line)

The owner's decisions: docs/idea_brood_mobile_buildings.md (12:20 tiers, 12:40-14:42 young and mature, the Storm
Challenger's name), docs/brood_new.md "THE LINES", docs/brood_research_draft.md "DECIDED (owner, 2026-10-29 18:59)"
(TARGETS: Hatchlings AIR ONLY, the Storm Challenger air and ground; the Storm Sire's BIGGER CLUTCH and UPDRAFT).

**Storm Sire (opens at the Mother's stage 2): HATCHLINGS (stage 2, two to an egg) -> STORM CHALLENGER (stage 3, MATURE).**
The Skywing (the stand-in) is retired.

Code: Defs.UNITS "hatchlings" and "storm_challenger"; Defs.NB "lines" (pterodactyl: hatchlings), "unit_stage",
"mature"; "lines_later" is now empty. Everything else (laying, the nest, fertilising, MATURE, BIGGER CLUTCH, UPDRAFT,
the card) is the existing generic Brood code. Kind-specific bits: Unit._strike (bite / swoop: one blow, the Brood's
jaws), Unit.HOVER_FPS (the hover flap rate), Sfx.VOICE_AS (stand-in sounds), BroodNew.RETIRED_EGGS (old saves),
scripts/ai_brood_new.gd (the computer). Art: tools/import_storm_line.py. Test: tools/test_brood_new.gd section 23.
Pictures: docs/shots/storm_line/ (tools/shot_storm_line.gd).

## The numbers (Claude's choice; design_principles.md 1 and 2)

| | Hatchlings (each) | Storm Challenger | Raptor (each) | Skywing (retired) | Swift (Clockwork) | Storm Sire |
| --- | --- | --- | --- | --- | --- | --- |
| Price | egg of 2: 80 food + 10 spoils (40 + 5 each); 3 with BIGGER CLUTCH: 120 + 15 | 150 + 30 (MATURE: 110 + 25) | egg of 2: 50 | 100 + 40 | 75 cogs + 15 Tension | 200 + 50 |
| Supply | 1 | 2 | 1 | 2 | 2 | 4 |
| Time | 12 s an egg | 9 s moult | 11 s | 16 s | 20 s | 40 s |
| Health / armour | 38 / 0 | 150 / 0 | 36 / 0 | 75 / 0 | 90 / 0 | 700 / 1 |
| Speed (UPDRAFT, flying) | 132 (152) | 120 (138) | 96 | 118 | 118 | 110 (127) |
| Attack (the card's cycle: aim + blow + cooldown) | bite 6, range 20, every 1.3 s: 4.7/s | swoop 16, range 28, every 1.9 s: 8.5/s | 6 every 1.35 s: 4.4/s | spines 11 at 130: 6.9/s | peck 10 at 28: 7.9/s | dive 30 at 30 |
| Hits | FLYERS ONLY | flyers and ground | ground | flyers (landed: ground) | flyers only | both |
| Radius | 8 | 15 | 7 | 13 | 13 | 26 |

Why:
- **Hatchlings are the anti-air niche (the owner: "good against swarming fliers", "niche protection").** A pair is a
  Swift's match in price and supply (90 against 90, 2 against 2): 76 hp against its 90, 9.3 damage a second against
  its 7.9, and faster (132 against 118), so a pair beats a lone Swift, and a flock beats a flock of Swifts as long as
  they are not caught under muskets. A Musketeer's ball (20) takes half a Hatchling, canister and arc balls several:
  fragile, light, a soft counter (spread your shooters, keep your flyers over them). They cannot touch the ground at all
  (the owner's targeting rule), so a Brood that lays them against an army with no flyers wastes its eggs: a clear,
  readable niche, not a must-build. The Ticking Owl cannot hit back (it is ground only): Hatchlings are its answer.
- **Cheap per body, not cheap per value:** 40 + 5 a Hatchling is above a Raptor's 25 (flight over cliffs is worth
  something); BIGGER CLUTCH keeps the price per young (more from one egg, not cheaper: the same rule as the Raptors').
- **The Storm Challenger takes the Skywing's role** (hunts flyers, hits the ground too) with the other Challengers'
  supply (2) and about a Tyrant Challenger's damage rate (8.5 a second against 8.1). It flies over cliffs and water, which is strong
  (it raids, it crosses the walls), so its blow is moderate and it has no armour: anything that shoots flyers
  (Musketeers, canister, Springers, Swifts, Hatchlings) answers it. 150 hp makes it the line's tough body. No damage
  bonus against flyers (keep damage modifiers few: the owner dropped RENDING TALONS); open question below.
- **Price of the mature form = the Challenger's price less the young's share** (as the other Challengers), and the
  stage gate plus the 9 s moult telegraph it (an enemy sees Challengers coming and can punish a moult).
- **UPDRAFT +15% while flying**, as the owner asked for the Sire: Hatchlings +20 (132 -> 152), the Storm Challenger +18
  (120 -> 138), the Storm Sire +17 (110 -> 127). (0.20.0 had placeholders +18 and +16.) Note: the Brood's swamp speed
  bonus (x1.3) applies to its flyers too while over its own swamp (as it did to the Skywing and the Storm Sire).

## The retired Skywing

- No longer laid: it is out of Defs.NB "lines" and "unit_stage" (her card, the help and the AI no longer offer it).
- It stays in Defs.UNITS with its art, sounds and land / take-off code, so OLDER SAVES load with their Skywings (they
  fight as before) and OLDER REPLAYS draw them (replays are snapshots). An older save's Skywing EGG holds Hatchlings when
  loaded (BroodNew.RETIRED_EGGS; it hatches a plain clutch of two; its price was paid). Nothing else refers to it now
  except the old computer helper AI._skywings (only acts on Skywings, harmless).
- The Storm Sire's about text, the help page and UPDRAFT's text now name the Hatchlings and the Storm Challenger.

## The computer (scripts/ai_brood_new.gd)

- `_nb_warrior`: with the Storm Sire rooted beside her (stage 2+) it lays HATCHLINGS while the Storm line (a Challenger
  counts as two) is under 2 for each enemy flyer (HATCH_PER_FLYER, at most HATCH_MAX = 16); at her stage 3 it also
  keeps STORM_WANT = 4 of the line once 6 Raptors and Spitters stand, to mature into Storm Challengers. Its other lines
  go on as before.
- `_nb_mature`: Hatchlings mature like the other young (2 a think, food to spare); with no enemy flyers about it
  matures every one (they are useless against the ground), with flyers about it keeps half as a flock.
- `_nb_research`: the Storm Sire's BIGGER CLUTCH with 4 Hatchlings and 3 enemy flyers about; UPDRAFT with 4 of the line.
- AIScout: the Storm Challenger counts as a fast raider; the Toad's TONGUE may pull an enemy Storm Challenger.

## Art (tools/import_storm_line.py; docs/art_style_inconsistency.md "THE STORM LINE")

The owner's sheets art/redraws/hatchling_{se,s,e,ne,n}_chatgpt.png and storm_challenger_{se,s,e,ne,n}_chatgpt.png
(1536x1024, rows FLY 6, ATTACK 6, DEATH 5): strips walk (the fly loop), idle (the same loop, hovering: 10 frames a
second for the Hatchlings, 7 for the Challenger), attack, death, in five views; the game mirrors the west ones. One
scale per creature: the south-east fly's first frame 28 px wide for a Hatchling (28x27: a Raptor is 33x21) and 75 for
the Challenger (half the Storm Sire's 150). In the air the frames are lined up on the body's middle (as the Storm
Sire's), the two lying death frames on their lowest pixel. Team colour: the red crests and spikes snapped to the team
key; veterancy: their skin masks (tools/import_vet_skin.py: amber, obsidian) like the other creatures.

The owner's frame check, as done:
- Hatchling NE bite frame 3 (head turned toward the camera): kept, it reads at its size.
- The **motion-line marks of the bite frame 4 (and the Challenger's SE swoop frame 4) are ERASED**: at the Hatchling's
  28 px they became one- or two-pixel yellow specks off the beak (read as dirt), and they would pull the body's middle,
  the frame's anchor; the game's own hit spark shows the blow.
- Storm Challenger NE swoop: built from north-east frames only: fly 1, fly 2, swoop 3, 4, 5, fly 1 (the blow on the
  4th frame as in every view). Reads as one dive to the north-east (picture: line_zoom / contact sheet).
- Storm Challenger N swoop: frames 2, 3, 4 flipped top to bottom: the beak now points north in the dive
  (challenger_n_swoop.png). It reads as a dive away from the camera; the flipped frames' shading falls from below
  (barely seen at 75 px). Note: both N FLY rows were drawn with the beak at the bottom of the picture (top-down, as if
  facing south), so the N swoop's flipped frames point the other way from its fly frames; a redraw of the N fly rows
  would make the view consistent.
- Every death ends lying sideways facing east: accepted (the owner).
- Portraits: the owner's framed portraits (art/redraws/hatchling_portrait_chatgpt.png, storm_challenger_portrait_chatgpt.png,
  cut as the Sires'; each draws an extra wing, accepted for now, docs/art_style_inconsistency.md "COULD BE BETTER"); the
  importer falls back to crops of the growth concept's heads without them.

## Sounds

None of their own yet (another job, brood-sounds, is cutting Brood sounds): Sfx.VOICE_AS gives both the retired
Skywing's voice lines and death, and their blows play combat/<kind>_attack if it exists, else the Skywing's bite.
Their own files win as soon as they are added (voice/hatchlings/..., combat/hatchlings_attack, ...).

## Tests

tools/test_brood_new.gd section 23 (the lines, prices, targets, two to an egg in the Storm Sire's nest, BIGGER CLUTCH
three, MATURE locked then a flying Challenger with its kills, UPDRAFT, a flock killing a Swift and ignoring a
Musketeer, a Challenger swooping on a Raptor, an old Skywing egg, the computer), and sections 18 and 21 updated
(Hatchlings in place of Skywings). tools/test_stun_mark.gd pulls a Storm Challenger through the air with the Toad's
TONGUE (was a Skywing).

RESULTS_PLACEHOLDER

## Open questions for the owner

1. The numbers above are first guesses: Hatchlings 38 hp / 6 a bite / 132 speed, the Storm Challenger 150 hp / 16 a
   swoop / 120. Too weak or too strong after a play?
2. Should the Storm Challenger get a bonus against flyers (it "hunts flyers")? Not given: damage modifiers kept few.
3. The N fly rows (beak at the bottom) against the flipped N swoop: redraw the N fly rows facing away?
4. Should Hatchlings stay out of the computer's attack waves (they can only guard against flyers)? Today they go with
   the army, which also protects it from enemy flyers.
