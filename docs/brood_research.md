# The Brood's research (0.20.0)

The owner's decisions: docs/brood_research_draft.md ("DECIDED (owner, 2026-10-29 18:59)") and docs/idea_brood_mobile_buildings.md (18:31). Code: scripts/brood_research.gd (BroodResearch), the data in Defs.RESEARCH (the `nb_*` keys, "at" = the creature), hooks in scripts/brood_new.gd, unit.gd, game.gd, ui/hud.gd, ai_brood_new.gd. Test: tools/test_brood_new.gd section 21. Pictures: docs/shots/brood_research/ (tools/shot_brood_research.gd). Icons: the owner's ChatGPT drawings (0.20.2, art/ui/icons4/, tools/import_round14.py; the code-made placeholders of 0.20.0 are gone).

## How it works

- The Brood has no buildings, so its ROOTED creatures research. Each Sire, rooted on his nest, researches his own line's upgrades on his card; the Brood Mother the ones for every creature. One at a time each, paid up front, as the Crown's and the Clockwork's research. When done it is a tech flag (players[t]["tech"]), the same as theirs: saves, online and replays keep it.
- The research in hand is on the creature itself (nb "rs" and "rs_t"), so a save, the online snapshot and a replay carry it with him.
- A SIRE RESEARCHING fathers NO eggs: the Mother can't lay an egg of his line ("The Tyrant Sire is researching: no eggs of his line until he is done."); eggs already in his nest wait for him (their 25 s count holds, so none turns into a grub). His fertilising loop keeps playing, so a scout sees him busy. His card shows RESEARCHING · its name, the time left and the bar in place of his eggs, a bar over him, and STOP RESEARCH.
- THE MOTHER KEEPS LAYING while she researches (Claude's choice, as asked: confirm). She can't GROW while she researches, nor research while she grows (one job at a time for her, as a hall's upgrade).
- STOP RESEARCH, or getting up (UPROOT, a Toad's tongue, anything that unroots him): it stops, paid back in full. KILLED mid-research: the progress is lost and the price paid back, as the game does for a building that falls with research in its queue (Building.die). Research already done stays.
- The computer (scripts/ai_brood_new.gd, `_nb_research`): never with enemies at her or while saving for her growth; only with the price and 150 food to spare (300 on Easy); one Sire researching at a time (the other lines keep laying); BIGGER CLUTCH on the Raptors early (from 3:00 with a small army), PACK HUNT when an attack is coming (army at 60% of the wave) or going, BATTERING HORNS at stage 3 with 2 Brutes, the Venom line's clutch with 4 Spitters, LONG SPIT and SLITHER with 6 of the line and 400 food, UPDRAFT with 4 Skywings, QUICK ROOTS from 8:00 (stage 2), SWAMP MENDING from 10:00. Its spoils were the bottleneck (every research costs some): it now offers up Raptors (a home guard of 3, not 6) to get the 20 spoils for its first BIGGER CLUTCH, and keeps spoils for her stage 3 only once it has 60% of them.

## The numbers

| Research | At | Needs | Cost | Time | Effect |
| --- | --- | --- | --- | --- | --- |
| BIGGER CLUTCH | Tyrant Sire | stage 1 | 100 food + 15 spoils | 40 s | Raptors 3 to an egg (75 food) instead of 2 (50) |
| PACK HUNT | Tyrant Sire | stage 1 | 75 + 15 | 35 s | Raptor 96 -> 114, Tyrant Challenger 84 -> 98, the Tyrant Sire 64 -> 75 (0.20.1) |
| BATTERING HORNS | Tyrant Sire | stage 3 | 125 + 40 | 50 s | Brute building bonus x2.5 -> x3.5 |
| BIGGER CLUTCH | Venom Sire | stage 1 | 100 + 15 | 40 s | Spitters 3 to an egg (135 + 8) instead of 2 (90 + 5) |
| SLITHER | Venom Sire | stage 1 | 75 + 15 | 35 s | Spitter 68 -> 78, Venom Challenger 58 -> 67 (+15%) |
| LONG SPIT | Venom Sire | stage 1 | 100 + 25 | 45 s | Spitter and Venom Challenger range 165 -> 190, a Musketeer's (0.20.1; was 170 -> 205 and 180 -> 215) |
| BIGGER CLUTCH | Storm Sire | stage 2 | 100 + 15 | 40 s | Hatchlings 3 to an egg (refused until they exist) |
| UPDRAFT | Storm Sire | stage 2 | 75 + 15 | 35 s | flyers +15% while flying: Skywing 118 -> 136, the Storm Sire 110 -> 127 (0.20.1) (Hatchlings +18, Storm Challenger +16 when they come) |
| QUICK ROOTS | Brood Mother | stage 2 | 100 + 30 | 45 s | root and uproot in half the time (her 4 -> 2 s, the others 2.5 -> 1.25 s) |
| SWAMP MENDING | Brood Mother | stage 2 | 100 + 30 | 45 s | on her side's swamp, not hit for 4 s: +1.2% of max health a second, at least 1, at most 6, on top of the swamp's 2 |

(The Storm Sire opens at stage 2, so his research does too.)

Other changes:
- YOUNG TWO TO AN EGG: Raptors now spawn 2 for 50 food (were 3 for 75); Spitters were already 2 (90 + 5). With BIGGER CLUTCH the egg holds 3 and costs 3/2 as much: the price per young is the same (a Spitter's spoils round 7.5 up to 8). The number is fixed when the egg is laid (an egg laid before the research still hatches 2; its price is what was paid). Maturing a young one still costs the same ([75, 10] and [105, 17]).
- STANDARD SPEEDS LOWERED (PACK HUNT's brake): Raptor 108 -> 96, Tyrant Challenger 92 -> 84.
- TARGETS: Spitters no longer shoot flyers (Defs anti_air removed; the about texts say so). The Venom Challenger and the Venom Sire still do; the Skywing hunts them in the air. Hatchlings (air only) and the Storm Challenger (air and ground) are noted in Defs.NB for when they are built.
- The Swamp Mending heal for some creatures: a Raptor +1 hp/s (3 in all on the swamp), a Spitter +1, a Tyrant Challenger +1.6, a Brute +2.9, a Venom Challenger +2.6, a Sire or the Mother +6 (capped). "Not hit for 4 s" is Claude's choice: it heals between fights, not in them (no regen win in a brawl on her swamp).

## BATTERING HORNS against the Crown's gate (tools/test_brute_siege.gd, Greenhold ramp, nobody defending)

| Attackers | x2.5 (before) | x3.5 (Battering Horns) |
| --- | --- | --- |
| 1 Brute | 14.9 s from the order (9.7 s hitting) | 12.5 s (7.3 s hitting) |
| 4 Brutes | 7.2 s (2.4 s hitting) | 6.2 s (1.5 s hitting) |
| 6 Raptors (one Brute's price) | 20.8 s | 20.8 s |

A gate already falls fast to Brutes; the research cuts about a quarter of the hitting time. Most of the time is the walk up. Fair but not instant against an undefended gate; with Musketeers on the wall, a Brute (240 hp) takes about as long to die as before. If it feels too much, x3.0 is the easy dial (Defs.RESEARCH nb_battering_horns "bonus").

## Two 12-minute computer games (tools/sim_brood_new.gd, Hollowfen, seed 4242, Hard foe)

- Brood v Crown: Bigger Clutch at 6:52 (done 7:32), Pack Hunt at 7:33 (done 8:08); waves at 6:56 and 8:45; at 12:00 the Brood has 24 Raptors, 6 Rootmaws, 6 turtles, stage 2, the Crown 74 supply.
- Brood v Clockwork: Bigger Clutch at 7:04 (done 7:44); waves at 7:01, 9:02 and 11:12; at 12:00 the Brood has 21 Raptors, stage 2.
- The Brood still fights and is alive in both; it trades badly against the Hard computers (losses 114 and 119 against 14 and 50 kills), as it did before this job (the first runs, with no research, were the same picture). Its research comes late because its spoils income is thin (docs/brood_new.md: "does not use spoils for much").

## Tests

tools/test_brood_new.gd section 21: 2 to an egg and the prices; the Sire's card (BATTERING HORNS greyed with its reason) and a tooltip with name, effect, cost and time; BIGGER CLUTCH paid, RESEARCHING on his card, no Raptor eggs meanwhile, STOP RESEARCH, his loop playing; then 75 for 3 and 3 hatched; maturing prices unchanged; the Venom clutch 135 + 8; the Hatchlings' data; every effect (speeds, Updraft only flying, Brutes x3.5 (Defs untouched), Long Spit on new and matured units, Quick Roots, Swamp Mending and its 4 s rule); a Spitter can't hit a balloon, a Venom Challenger can; the Mother researching and still laying, GROW waiting; a Sire killed mid-research (paid back, Bigger Clutch kept); uprooted mid-research; the snapshot carrying it; the computer (Bigger Clutch first, one Sire at a time, other lines laid); a save mid-research continued and finished. All pass. Also run: test_brood_new_defence (only its known rooted Musketeer failure), test_unit_stats, test_files, test_i18n, test_replay, test_stun_mark: pass.

## The owner's answers (2026-10-29 20:09; done in 0.20.1, branch brood-answers)

- **LONG SPIT**: the standard range must be SHORTER than the Musketeer's (190, Defs.UNITS musketeer "range") and the
  upgrade brings it to the SAME range, not beyond. Done: the Spitter and the Venom Challenger 165 as standard (were
  170 and 180), LONG SPIT +25 = 190. The Venom Challenger's about text no longer says "a little farther". Texts in
  en/pt/es.
- **PACK HUNT also speeds up the Tyrant Sire, UPDRAFT the Storm Sire (the same %)**: the Tyrant Sire +11 (64 -> 75,
  +17%, between the Raptor's +19% and the Challenger's +17%), the Storm Sire +17 while flying (110 -> 127, +15%, the
  Skywing's +15%). Defs.RESEARCH "speed"; texts updated.
- **BATTERING HORNS x3.5 and SWAMP MENDING stay for now** ("needs more testing"). **The Mother can't grow and research
  at once** (stays).
- **Who sees a Sire's research?** The owner: only his own side (and allies); an enemy must NOT see the bar or the
  label or what is researched, only his production animation; spectators may see everything.
  - BEFORE 0.20.1 it already did not show to an enemy: the bar and label over him were drawn only for his own side
    and spectators (BroodNew.draw `mine`), his card's progress line (hud `nb_prog`) only for his own side and
    spectators, his research buttons, STOP RESEARCH and their tooltips only on his own side's card, nothing on the
    minimap, the start sound and the "researched" message only for his side. But his ALLIES did not see it either.
  - 0.20.1: BroodResearch.shown_to (his side, allies, spectators) decides; BroodNew.bar_over is what is drawn over a
    rooted creature for the viewer (research only when shown_to); an ally's card shows his research line. Tested
    (tools/test_brood_new.gd part 22: an enemy selecting him sees no bar, label, card line, button or tooltip, only
    his loop playing; an ally and a spectator see it).

## Open questions for the owner (earlier)

1. ANSWERED: she can't grow and research at once (stays); she keeps laying while she researches.
2. ANSWERED: Swamp Mending stays as it is for now ("needs more testing").
3. ANSWERED (above): LONG SPIT now ends at the Musketeer's 190.
4. ANSWERED: BATTERING HORNS stays x3.5 for now ("needs more testing").
5. ANSWERED (above): both now speed up their Sire too.
6. The Storm Sire's BIGGER CLUTCH is shown but refused ("Not in the Brood yet.") until the Hatchlings exist; its data and the 3-to-an-egg rule are in and tested.
7. The research icons are code placeholders (the creature's portrait with a badge); ChatGPT prompts 43-52 in docs/command_icons_audit.md.
8. The computer researches late (about 7:00) because of its spoils; a bigger spoils income for it (or cheaper spoils on the first research) would bring it earlier.
