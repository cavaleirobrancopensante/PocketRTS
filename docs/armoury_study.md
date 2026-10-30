# The Armoury study (2026-10-30, v0.23.0)

The owner asked, before the Marching Band goes in (docs/marching_band.md): list every Armoury research, measure what each
is worth in a fight, find where the band would overlap, and PROPOSE how the Armoury could change so the band has its own
role. **No Armoury number was changed.** Rules followed: docs/design_principles.md 1 (fairness, few intuitive modifiers),
2 (pro-snowball upgrades need a brake) and 4 (every choice an opportunity cost).

Harness: `tools/study_armoury_band.gd` (all runs: `tools/study_armoury_band.sh <dir> 4 4`, tables:
`python3 tools/study_armoury_band_report.py docs/armoury_study_data`). Raw fights: `docs/armoury_study_data/*.jsonl`.

## 1. Every Armoury research (Defs.RESEARCH, "at": armoury)

All nine are Crown research at the Armoury (150 gold, 40 s; needs a Barracks). EQUIPMENT (Armour, the three locks, the
bayonet, the pouch) only unlocks a REFIT: each soldier walks to a Barracks, Armoury or Powder Wagon and pays a fee (2 s);
new Musketeers come out with the locks and the bayonet (fees added to their price), not with the pouch. DRILLS (Prepared
Charges, Quadrant, Cavalry Charge) apply at once to every unit of their kinds, for nothing.

| research | cost (gold + powder) | time | needs | fee a man | exact effect |
|---|---|---|---|---|---|
| Armour | 125 + 50 | 45 s | Foundry | Musketeer 12 + 4 powder, Horseman / Officer 30 | Musketeer -> Guardsman: +1 armour, +20 health (70 -> 90). Horseman -> Cuirassier: +1 armour, +30 health, a little slower. Unlocks the armoured recruits at the Barracks |
| Matchlock | 50 + 10 | 30 s | - | 8 | reload x0.90 (2.8 s -> 2.52 s) |
| Flintlock | 75 + 25 | 40 s | Matchlock, Foundry | 12 | reload x0.80 of the base (2.24 s) |
| Caplock | 100 + 40 | 50 s | Flintlock | 16 | reload x0.70 of the base (1.96 s) |
| Socket Bayonet | 40 + 0 | 20 s | - | 3 | bayonet 18 -> 24 damage, thrust cooldown 1.0 -> 0.85 s |
| Shot Pouch | 60 + 20 | 25 s | - | 5 | carries 20 shots instead of 10 (Musketeers, Guardsmen, Dragoons) |
| Prepared Charges | 100 + 40 | 40 s | Foundry | drill | Field Cannon and Mortar reload x0.80 |
| Gunner's Quadrant | 125 + 30 | 45 s | Prepared Charges | drill | Field Cannon and Mortar +1 tile range (+32 px) |
| Cavalry Charge | 60 + 0 | 25 s | - | drill | after ~2 s at the gallop a Horseman's / Cuirassier's next sabre blow hits x2 and throws back (stun 0.6 s) |

The whole lock line costs 225 gold + 75 powder of research plus 16 gold a man (a 15-man line: 240 more).

### What the locks do to a Musketeer's fire (worked out from the code)

A shot's cycle is aim 0.4 s + strike 0.35 s + the cooldown (Unit._cooldown). Hit chance 85% (Game.musket_shot), 20 damage.

| kit | cooldown | cycle | shots a minute | damage a minute | vs none |
|---|---|---|---|---|---|
| none | 2.80 s | 3.55 s | 16.9 | 287 | - |
| Matchlock | 2.52 s | 3.27 s | 18.3 | 312 | +8.6% |
| Flintlock | 2.24 s | 2.99 s | 20.1 | 341 | +18.7% |
| Caplock | 1.96 s | 2.71 s | 22.1 | 376 | +31.0% |
| band's fife, secondary (cooldown runs x1.05) | 2.67 s | 3.42 s | 17.6 | 299 | +3.9% |
| band's FIFE SOLO (x1.30) | 2.15 s | 2.90 s | 20.7 | 351 | +22.2% |
| Matchlock + FIFE SOLO | 1.94 s | 2.69 s | 22.3 | 379 | +32.0% |
| Caplock + FIFE SOLO | 1.51 s | 2.26 s | 26.6 | 452 | +57.2% |

The fife's reload MULTIPLIES with the lock's (the cooldown runs faster; Unit tick), so they stack: a Caplock line in a fife
solo fires 57% faster than a bare line. That is the main overlap.

## 2. The fights

Controlled fights on open ground (dune_sea's middle, the computers off): 15 Musketeers in two ranks on HOLD against an enemy
block that attack-moves in, about 1200 resources a side (Raptors 25 each, Clock Soldiers 70, enemy Musketeers 70).
"same": always 15 men (the kit's raw worth); "eq": as many men as 1200 buys with the kit's refit fees (the cost trade; the
research itself is not counted: it is paid once). AG: 10 mid-kit Musketeers + 2 Field Cannons. AC: 8 Horsemen attack-moving
in. 4 seeds each. MARGIN = what is left of the Crown minus what is left of the enemy (resources by health): above 0 the
Crown is ahead; (Δ) = against the row's baseline (none / guns / horse).

**Noise:** a fight is not exactly repeatable (frame timing) and Raptor fights swing most: the same 15-man fight run twice
differed by up to ~240 in margin (MB_none and MB_eq_none in docs/marching_band.md are the same setup). Only Δ larger than
about ±250 against Raptors and ±150 against Musketeers or Clock Soldiers is a real effect.

| config | men | vs Raptors: won · Crown lost / enemy killed · margin ±sd (Δ) | vs Clock Soldiers | vs Musketeers (attacking) |
|---|---|---|---|---|
| AR_same_none | 15 | 0/4 · 1050/669 · -431 ±123 | 4/4 · 210/1190 · +763 ±71 | 0/4 · 1050/315 · -734 ±81 |
| AR_same_matchlock | 15 | 1/4 · 1092/800 · -268 ±401 (+163) | 4/4 · 292/1190 · +815 ±219 (+52) | 0/4 · 1170/332 · -702 ±73 (+33) |
| AR_same_flintlock | 15 | 1/4 · 1128/825 · -267 ±339 (+164) | 4/4 · 226/1190 · +888 ±184 (+126) | 0/4 · 1230/368 · -677 ±51 (+58) |
| AR_same_caplock | 15 | 1/4 · 1204/856 · -248 ±274 (+183) | 4/4 · 236/1190 · +961 ±184 (+198) | 0/4 · 1290/350 · -704 ±140 (+30) |
| AR_same_bayonet | 15 | 3/4 · 748/1062 · +80 ±369 (+511) | 4/4 · 201/1190 · +819 ±128 (+56) | 0/4 · 1095/315 · -729 ±29 (+5) |
| AR_same_armour | 15 | 4/4 · 452/1200 · +659 ±63 (**+1090**) | 4/4 · 236/1190 · +954 ±124 (+192) | 0/4 · 1290/752 · -407 ±38 (+328) |
| AR_same_pouch | 15 | 3/4 · 769/1106 · +105 ±282 (+536?) | 4/4 · 319/1190 · +700 ±216 (-62) | 0/4 · 1125/315 · -769 ±127 (-35) |
| AR_same_mid (Matchlock + Bayonet) | 15 | 2/4 · 972/956 · -50 ±361 (+381) | 4/4 · 142/1190 · +970 ±81 (+207) | 0/4 · 1215/368 · -692 ±104 (+43) |
| AR_same_late (Caplock, Bayonet, Armour, Pouch) | 15 | 4/4 · 522/1200 · +933 ±117 (+1364) | 4/4 · 82/1190 · +1429 ±95 (+666) | 0/4 · 1650/718 · -412 ±69 (+323) |
| AR_eq_none | 17 | 3/4 · 718/1088 · +259 ±408 | 4/4 · 192/1190 · +908 ±82 | 0/4 · 1190/472 · -526 ±140 |
| AR_eq_matchlock | 15 | 3/4 · 878/1044 · +14 ±368 (-245) | 4/4 · 234/1190 · +820 ±179 (-88) | 0/4 · 1170/298 · -722 ±60 (-195) |
| AR_eq_flintlock | 15 | 1/4 · 1128/819 · -268 ±324 (-528) | 4/4 · 184/1190 · +941 ±87 (+33) | 0/4 · 1230/455 · -614 ±100 (-88) |
| AR_eq_caplock | 14 | 0/4 · 1204/644 · -473 ±163 (-732) | 4/4 · 408/1190 · +680 ±121 (-228) | 0/4 · 1204/385 · -679 ±212 (-153) |
| AR_eq_bayonet | 16 | 2/4 · 931/1056 · +59 ±356 (-200) | 4/4 · 219/1190 · +866 ±98 (-42) | 0/4 · 1168/385 · -674 ±91 (-148) |
| AR_eq_armour | 14 | 4/4 · 624/1200 · +432 ±54 (+173) | 4/4 · 387/1190 · +709 ±84 (-199) | 0/4 · 1204/490 · -600 ±88 (-73) |
| AR_eq_pouch | 16 | 2/4 · 975/988 · -14 ±401 (-273) | 4/4 · 206/1190 · +872 ±160 (-36) | 0/4 · 1200/350 · -674 ±84 (-148) |
| AR_eq_mid | 15 | 3/4 · 830/1100 · +152 ±322 (-107) | 4/4 · 223/1190 · +933 ±114 (+25) | 0/4 · 1215/350 · -704 ±70 (-178) |
| AR_eq_late | 11 | 0/4 · 1210/769 · -367 ±227 (-626) | 4/4 · 358/1190 · +716 ±145 (-192) | 0/4 · 1210/350 · -760 ±83 (-233) |
| AG_guns (10 mid + 2 cannons) | 10 | 4/4 · 182/1200 · +959 ±149 | 4/4 · 61/1190 · +1090 ±130 | 3/4 · 895/1032 · +172 ±371 |
| AG_charges | 10 | 4/4 · 182/1200 · +961 ±210 (+2) | 4/4 · 101/1190 · +1038 ±126 (-52) | 4/4 · 741/1190 · +364 ±258 (+191) |
| AG_quadrant (+ Charges) | 10 | 4/4 · 243/1200 · +859 ±261 (-100) | 4/4 · 61/1190 · +1083 ±88 (-6) | 4/4 · 486/1190 · +674 ±111 (**+502**) |
| AC_horse (8 Horsemen) | - | 0/4 · 1240/369 · -730 ±37 | 0/4 · 1080/682 · -332 ±86 | 0/4 · 1000/0 · -1190 |
| AC_charge | - | 0/4 · 1240/375 · -735 ±41 (-4) | 0/4 · 1180/700 · -355 ±94 (-23) | 0/4 · 980/0 · -1190 (+0) |

(The 15-man line crushes 1200 of Clock Soldiers whatever its kit, and the attacking Musketeers beat it whatever its kit:
those columns show the size of an effect, not who wins. The band's fights, docs/marching_band.md, use closer sizes.)

### What each research is worth

- **Armour is by far the strongest** per man: +1090 against Raptors (a Raptor's 6-damage bite loses a sixth to the armour
  point, and the Guardsman has 90 health: about 1.8x as many bites to kill), +330 against the musket line, +190 against
  Clock Soldiers. Even paid for (14 men instead of 17) it gains against Raptors. It is the one upgrade that makes the line
  survive up close, against the Crown's identity ("in trouble up close"): worth a look on its own (not part of this job).
- **The locks are modest per fight** and lose at equal cost: raw +160..+200 (Raptors, Clock Soldiers), +30..+60 against
  muskets; paid for (their fees mean fewer men) Matchlock -245, Flintlock -528, Caplock -732 against Raptors. A faster
  reload pays in a LONG fight or a big army (the research is paid once, the fees are small next to a man), not in one
  1200 clash. Their real worth: permanent, global, no risk.
- **Socket Bayonet**: +510 against Raptors (noisy), nothing against muskets: a melee upgrade, as meant.
- **Shot Pouch**: nothing in a single fight (10 shots last a 15-30 s fight; the +536 against Raptors is noise: -273 at cost);
  it pays in long fights and sieges away from powder.
- **Prepared Charges**: nothing against a melee rush (the guns fire two or three shots before contact), +190 against a musket
  line. **Gunner's Quadrant**: +500 against a musket line (the guns out-range it and fire before it closes), nothing against
  melee.
- **Cavalry Charge**: nothing measurable in a head-on fight (the charge is the first blow after a gallop: one blow a pass);
  its worth is in raids and hit-and-run passes, which this harness doesn't play.

## 3. Where the band overlaps

| band | Armoury | overlap |
|---|---|---|
| FIFE: reload speed (+5% secondary, +30% solo) | Matchlock / Flintlock / Caplock: reload x0.9 / 0.8 / 0.7; Prepared Charges: guns x0.8 | **direct**: same stat, they multiply (Caplock + fife solo +57% fire rate, table above) |
| PIPES: melee damage (+7%, +35%) | Socket Bayonet: +6 damage, 15% faster; Cavalry Charge: x2 first blow | same stat (melee), stacks; the pipes also lift the sabres and the charge blow |
| DRUMS: movement speed (+5%, +25%) | none (Armour makes the Cuirassier slower) | none; the drums partly undo the Cuirassier's armour slowness and help a charge build up |
| (no defensive instrument) | Armour: +1 armour, +health | none |

## 4. Proposals for the Armoury (NOT done: the owner's call)

The owner's aim: the band should have its OWN role, not be "another reload upgrade". Two ways, in order of preference:

**P1 (my pick). The locks give ACCURACY and REACH; the fife owns RELOAD.** Each lock keeps its price but changes stat:
- Matchlock: hit chance 85% -> 89%, Flintlock: 92%, Caplock: 95% (Game.musket_shot's 0.85 becomes the lock's), and the
  Caplock also +16 px reach (half a tile). Damage a minute: +4.7%, +8.2%, +11.8% (+ reach) instead of +8.6 / +18.7 / +31%.
- That is weaker than today's locks, so make them cheaper: Matchlock 40 + 0, Flintlock 60 + 15, Caplock 80 + 25, fees 4 /
  6 / 8. Their worth stays permanent and global (accuracy also means fewer wasted shots of powder: a logistics gain the
  Crown's economy cares about).
- The fife's solo is then THE reload burst: +30% for 8 s, on top of better aim. No stacking of two reload multipliers, so
  a late Crown line can't reach +57% fire rate.
- It fits the period better too (a flintlock's real gain over a matchlock was reliability and aimed fire, not loading
  speed) and keeps "pound them at range" with the Crown.
- Prepared Charges (the guns' reload) stays: the band's ring is meant for the line, and the guns behind it are often
  outside it.

**P2 (smallest change). Keep the locks; the fife stacks but smaller.** The fife's solo +20% (instead of +30%) and its
secondary +3%: Caplock + solo = 1.96/1.2 = 1.63 s, +49% fire rate (instead of +57%). Simple, but the band then mostly
"tops up" the Armoury and the fife is the weakest solo.

Either way: the **pipes** are fine stacking with the Socket Bayonet (melee is the Crown's weak spot; the solo covers it for 8
s, it doesn't remove it), and the **drums** have no overlap. If the Armoury's nine researches are spread over other buildings
(the owner's open question, CLAUDE.md backlog), the lock line could move to the Powder Mill or Foundry with P1's accuracy
role, and the Armoury keep Armour, the bayonet and the pouch.
