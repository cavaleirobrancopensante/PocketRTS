# Command card icon audit (2026-10-26, v0.14.23)

The owner asked for it with the BOMBARD order (fire at a spot): the new order needs an icon in each faction's style, and
some buttons were suspected to show the wrong picture (the Crown Mortar's DEPLOY showed the Clockwork tesla tripod until
0.14.22).

How it was made: `tools/audit_command_icons.gd -- <crown|brood|clockwork>` plays each faction, selects every unit and
building it has (in their other states too: set up, canister, hold fire, landed, holding gas, leading a horse; buildings
with and without research, training, a building site, the worker's build pages, placing a building, a targeted order
waiting) and asks the HUD for the command card, then follows each button's icon the way `Hud._icon` does. A few buttons
the sweep cannot reach in one go (MORE, the research chain's later steps, STOP UPGRADE, CANCEL MORPH, SMALL GEAR, END)
were added by hand. The Clockwork is the gear-mode roster of normal games; the shelved Line roster and the LAB prototype
are at the end.

## Headline

| faction | buttons | fine | another faction's style | sprite crop, no frame | borrowed picture | code-made | missing |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Crown | 76 | 69 | 0 | 0 | 3 (MORE, AUTO REFIT, RESTOCK) | 3 (BOMBARD; the Mortar's DEPLOY and PACK) | 1 (TEAM) |
| Brood | 45 (+1 not reachable) | 32 | 8 (BACK, CANCEL, STOP UPGRADE, DEMOLISH, HOLD, PATROL, RALLY, WORK: all Crown) | 1 (TONGUE) | 3 (MORE, SPIT, TAKE OFF) | 1 (BOMBARD) | 0 |
| Clockwork | 39 (+1 not reachable) | 19 | 10 (BACK, CANCEL, CANCEL MORPH, DEMOLISH, HOLD, PATROL, RALLY, WORK, LEAD, RELEASE: all Crown) | 7 (JUMP, MORPH TO OWL, HIGH LEAP, TICKING OWL, CLOCK SOLDIER, JACK, SWIFT) | 3 (MORE, BIG GEAR, SMALL GEAR) | 0 (the placeholder BOMBARD waits for the Catapult) | 0 |

- The Brood and the Clockwork have their own pictures for six commands only (MOVE, ATTACK, STOP, BUILD, GATHER,
  REPAIR: `assets/icons/brood/`, `assets/icons/clockwork/`). Every other shared command (BACK, CANCEL, DEMOLISH, HOLD,
  PATROL, RALLY, WORK) falls back to the Crown's steel-framed picture: the fleur-de-lis RALLY flag and the bell of WORK
  on a Brood or Clockwork card are the most visible.
- The gear-mode Clockwork's new things (Clock Soldier, Jack, Swift, Ticking Owl, JUMP, MORPH TO OWL, HIGH LEAP, TICKING
  OWL) have no painted icons: the buttons show a crop of the unit's sprite without a frame, and JUMP, HIGH LEAP and the
  JACK train button show the same picture (the Jack firing), as do MORPH TO OWL and TICKING OWL (the Owl).
- One Crown button is blank: TEAM (`horse_team`, how many horses a gun or wagon keeps) has no file.
- Not wrong, but worth knowing: unit portraits of every faction (train buttons) sit in the Crown's steel portrait frame
  (`tools/import_round11.py` framed them all like `musketeer.png`), and buildings are frameless cut-outs; only the
  commands carry the faction frame.
- No button of the current game falls through to the code-drawn Clockwork pictures (`CwArt.icon`) any more: those
  serve only the LAB prototype roster (below).

## How a button finds its picture

`Hud._icon(name)` (scripts/ui/hud.gd) looks, in this order:

1. `assets/icons/<faction>/<name>.png`, for a Brood or Clockwork PLAYER only (the folder follows the faction of the
   person playing, not of the unit: a Crown player never sees these);
2. `assets/icons/<name>.png`, the shared folder, which is the Crown's own style;
3. the stand-in named by `Defs.icon_for` (TEMP_ART: the Dragoon's and the Officer's portraits, the horse commands...);
4. `CwArt.icon(name)`, a picture DRAWN IN CODE: only for the Clockwork prototype roster's units (`CwArt.SHEETS`) and
   for `ab_cw_*` / `ab_siding` commands (a flat dark tile with a brass or spark stripe and a glyph);
5. nothing: the button shows its label on an empty tile.

So a Brood or Clockwork button without a file in its own folder quietly falls back to the Crown picture of the same
name (step 2), and a name with no file at all to a code drawing (4) or a blank (5).

Styles in use:

- **Crown**: a steel bevel frame (grey, small corner pins) round a near-black picture (assets/icons/*.png).
- **Brood and Clockwork**: one shared bronze frame with round corner rivets round a dark navy picture
  (assets/icons/brood/, assets/icons/clockwork/, and the abilities cut from abilities_brood_clockwork.png); the
  faction shows in the PICTURE: creatures, bone and acid for the Brood, brass machines and sparks for the Clockwork.
- **Portraits** (the train buttons): painted unit portraits, all in the steel portrait frame whatever the faction.
- **Buildings** (the build pages): frameless cut-outs of the painted buildings.
- **Sprite crops**: a few icons were cropped from a unit's animation frames (no frame, transparent corners).
- **Code-drawn**: CwArt.icon (flat tile + stripe + glyph), or composited in code from painted pieces.

## Every button, by faction

Picture shown: the file under `assets/` the button really draws. "Crown style" on a Brood or Clockwork card means the shared folder's Crown picture was used because the faction has no file of its own.

### The Crown

| button | where | icon asked | picture shown | verdict |
| --- | --- | --- | --- | --- |
| ABANDON | building site | `stop` | icons/stop.png | fine |
| ARMOUR | unit musketeer | `research_armour` | icons/research_armour.png | fine |
| ARMOURED DRAGOON | building barracks | `armoured_dragoon` | icons/dragoon_armoured.png | fine (TEMP_ART stand-in: dragoon_armoured.png) |
| ARMOURED OFFICER | building barracks | `dismounted_cuirassier` | icons/dismounted_armoured.png | fine (TEMP_ART stand-in: dismounted_armoured.png) |
| ARMOURY | worker build page 0 | `armoury` | icons/armoury.png | fine |
| ATTACK | unit labourer | `attack` | icons/attack.png | fine |
| AUTO REFIT | unit powder_wagon | `musketeer_armoured` | icons/musketeer_armoured.png | **borrowed picture** (the Guardsman's portrait) |
| BACK | worker build page 0 | `back` | icons/back.png | fine |
| BARRACKS | worker build page 0 | `barracks` | icons/barracks.png | fine |
| BAYONET | unit musketeer | `research_bayonet` | icons/research_bayonet.png | fine |
| BOMBARD | unit cannon | `ab_bombard` | icons/ab_bombard.png | **code-made** placeholder |
| BUILD | unit labourer | `build` | icons/build.png | fine |
| CANCEL | building town_hall (training) | `cancel` | icons/cancel.png | fine |
| CANISTER | unit cannon | `ab_canister` | icons/ab_canister.png | fine |
| CAPLOCK | unit musketeer | `research_caplock` | icons/research_caplock.png | fine |
| CHARGE | building armoury | `research_charge` | icons/research_charge.png | fine |
| CHARGES | building armoury | `research_charges` | icons/research_charges.png | fine |
| CHURCH | worker build page 0 | `church` | icons/church.png | fine |
| COTTAGE | worker build page 0 | `cottage` | icons/cottage.png | fine |
| CUIRASSIER | building barracks | `cuirassier` | icons/cuirassier.png | fine |
| DEMOLISH | building cottage | `demolish` | icons/demolish.png | fine |
| DEPLOY | unit mortar | `ab_mortar_deploy` | icons/ab_mortar_deploy.png | **code-made** (composited from painted parts, 0.14.22) |
| DISMOUNT | unit cuirassier | `horse_dismount` | icons/horse_dismount.png | fine |
| DRAGOON | building barracks | `dragoon` | icons/dragoon.png | fine |
| DROP HERE | a targeted order (unload / cast) waiting | `ab_unload` | icons/ab_unload.png | fine |
| END | laying a palisade | `build` | icons/build.png | fine |
| FARM 1/2 | worker build page 0 | `farm` | icons/farm.png | fine |
| FIELD CANNON | building foundry | `cannon` | icons/cannon.png | fine |
| FLINTLOCK | building armoury (after Matchlock) | `research_flintlock` | icons/research_flintlock.png | fine |
| FOUNDRY | worker build page 0 | `foundry` | icons/foundry.png | fine |
| GATE | worker build page 0 | `gate` | icons/gate.png | fine |
| GUARDSMAN | building barracks | `guardsman` | icons/guardsman.png | fine |
| HARNESS | unit cannon | `horse_harness` | icons/horse_harness.png | fine |
| HOLD | unit musketeer | `hold` | icons/hold.png | fine |
| HOLD FIRE | unit musketeer | `fire_at_will` | icons/fire_at_will.png | fine |
| HOLD FIRE | unit musketeer (hold fire) | `hold_fire` | icons/hold_fire.png | fine |
| HORSE | building horse_breeder | `horse` | icons/horse.png | fine |
| HORSE BREEDER | worker build page 0 | `horse_breeder` | icons/horse_breeder.png | fine |
| HORSEMAN | building barracks | `horseman` | icons/horseman.png | fine |
| LABOURER | building town_hall | `labourer` | icons/labourer.png | fine |
| LEAD | unit labourer | `horse_lead` | icons/horse_lead.png | fine |
| LIMBER | unit cannon (other mode) | `ab_limber` | icons/ab_limber.png | fine (one picture for both states) |
| LOAD | unit balloon | `ab_load` | icons/ab_load.png | fine |
| LOCK | building gate | `lock` | icons/lock.png | fine |
| MATCHLOCK | building armoury | `research_matchlock` | icons/research_matchlock.png | fine |
| MISSIONARY | building church | `missionary` | icons/missionary.png | fine |
| MORE | any card with more buttons than fit | `build` | icons/build.png | **borrowed picture** (BUILD's) |
| MORTAR | building foundry | `mortar` | icons/mortar.png | fine |
| MOUNT | unit labourer | `horse_mount` | icons/horse_mount.png | fine |
| MOVE | unit labourer | `move` | icons/move.png | fine |
| MUSKETEER | building barracks | `musketeer` | icons/musketeer.png | fine |
| OBSERVATION BALLOON | building foundry | `balloon` | icons/balloon.png | fine |
| OFFICER | building barracks | `dismounted` | icons/dismounted.png | fine |
| PACK | unit mortar (other mode) | `ab_mortar_deploy` | icons/ab_mortar_deploy.png | **code-made** (composited from painted parts, 0.14.22) |
| PALISADE | worker build page 0 | `wall` | icons/wall.png | fine |
| PATROL | unit musketeer | `patrol` | icons/patrol.png | fine |
| POUCH | unit musketeer | `research_pouch` | icons/research_pouch.png | fine |
| POWDER 0/1 | worker build page 0 | `powder_mill` | icons/powder_mill.png | fine |
| POWDER WAGON | building foundry | `powder_wagon` | icons/powder_wagon.png | fine |
| QUADRANT | building armoury | `research_quadrant` | icons/research_quadrant.png | fine |
| RALLY | building town_hall | `rally` | icons/rally.png | fine |
| RELEASE | unit labourer (leading a horse) | `horse_release` | icons/horse_release.png | fine |
| RELEASE HORSE | unit cannon | `horse_unhitch` | icons/horse_unhitch.png | fine |
| REPAIR | unit labourer | `repair` | icons/repair.png | fine |
| RESTOCK | unit balloon | `ab_supply` | icons/ab_supply.png | **borrowed picture** (SUPPLY's porter; the balloon hauls kegs up a rope) |
| ROTATE | placing a building | `ab_rotate` | icons/ab_rotate.png | fine |
| ROUND SHOT | unit cannon (canister) | `ab_round_shot` | icons/ab_round_shot.png | fine |
| START | placing a building | `build` | icons/build.png | fine |
| STOP | unit labourer | `stop` | icons/stop.png | fine |
| SUPPLY | unit powder_wagon | `ab_supply` | icons/ab_supply.png | fine |
| TEAM | unit cannon | `horse_team` | MISSING | **MISSING** (blank button) |
| TOWN HALL | worker build page 0 | `town_hall` | icons/town_hall.png | fine |
| UNLIMBER | unit cannon | `ab_limber` | icons/ab_limber.png | fine (one picture for both states) |
| UNLOAD | unit balloon | `ab_unload` | icons/ab_unload.png | fine |
| UNLOCK | building gate (locked) | `unlock` | icons/unlock.png | fine |
| WORK | unit labourer | `work` | icons/work.png | fine |

### The Brood

| button | where | icon asked | picture shown | verdict |
| --- | --- | --- | --- | --- |
| ABANDON | building site | `stop` | icons/brood/stop.png | fine |
| ATTACK | unit grub | `attack` | icons/brood/attack.png | fine |
| BACK | worker build page 0 | `back` | icons/back.png | **Crown style** (steel frame, Crown picture) |
| BLOATER | building hive | `bloater` | icons/bloater.png | fine |
| BOMBARD | unit spore_mother | `ab_bombard` | icons/brood/ab_bombard.png | **code-made** placeholder |
| BROOD 0/1 | worker build page 0 | `brood_pen` | icons/brood_pen.png | fine |
| BROODMOUND | building hive level 2 | `broodmound` | icons/broodmound.png | fine |
| BRUTE | building hive | `brute` | icons/brute.png | fine |
| BUILD | unit grub | `build` | icons/brood/build.png | fine |
| BURROW | worker build page 0 | `hive` | icons/hive.png | fine |
| CANCEL | building hive (training) | `cancel` | icons/cancel.png | **Crown style** (steel frame, Crown picture) |
| CLUTCH MOUND | worker build page 0 | `clutch_mound` | icons/clutch_mound.png | fine |
| DEMOLISH | building clutch_mound | `demolish` | icons/demolish.png | **Crown style** (steel frame, Crown picture) |
| DROP HERE | a targeted order (unload / cast) waiting | `ab_unload` | icons/ab_unload.png | not reachable (Crown-only unit) |
| FEEDING 1 | worker build page 0 | `feeding_pit` | icons/feeding_pit.png | fine |
| FOG | unit mist_toad | `ab_fog` | icons/ab_fog.png | fine |
| GORGE PIT | worker build page 0 | `gorge_pit` | icons/gorge_pit.png | fine |
| GRUB | building hive | `grub` | icons/grub.png | fine |
| GRUBS | building hive | `feeding_pit` | icons/feeding_pit.png | fine (the Feeding Pit's picture) |
| HARVEST | unit grub | `ab_harvest` | icons/ab_harvest.png | fine |
| HOLD | unit raptor | `hold` | icons/hold.png | **Crown style** (steel frame, Crown picture) |
| HOLD GAS | unit bloater | `ab_hold_gas` | icons/ab_hold_gas.png | fine (one picture for both states) |
| LAND | unit skywing | `ab_land` | icons/ab_land.png | fine (one picture for both states) |
| MIASMA | unit spore_mother | `ab_miasma` | icons/ab_miasma.png | fine |
| MIST TOAD | building hive | `mist_toad` | icons/mist_toad.png | fine |
| MORE | any card with more buttons than fit | `build` | icons/brood/build.png | **borrowed picture** (BUILD's) |
| MOVE | unit grub | `move` | icons/brood/move.png | fine |
| PATROL | unit raptor | `patrol` | icons/patrol.png | **Crown style** (steel frame, Crown picture) |
| PLACE | placing a building | `build` | icons/brood/build.png | fine |
| RALLY | building hive | `rally` | icons/rally.png | **Crown style** (steel frame, Crown picture) |
| RAPTORS | building hive | `raptor` | icons/raptor.png | fine |
| ROOST | worker build page 0 | `roost` | icons/roost.png | fine |
| ROOT | unit spore_mother | `ab_root` | icons/ab_root.png | fine (one picture for both states) |
| SACRIFICE | unit raptor | `ab_sacrifice` | icons/ab_sacrifice.png | fine |
| SKYWING | building hive | `skywing` | icons/skywing.png | fine |
| SPAWNING DEN | worker build page 0 | `warren` | icons/warren.png | fine |
| SPIT | unit bloater (holding gas) | `ab_hold_gas` | icons/ab_hold_gas.png | **borrowed picture** (HOLD GAS's) |
| SPITTERS | building hive | `spitter` | icons/spitter.png | fine |
| SPORE MOTHER | building hive | `spore_mother` | icons/spore_mother.png | fine |
| STOP | unit grub | `stop` | icons/brood/stop.png | fine |
| STOP UPGRADE | building hive (growing) | `cancel` | icons/cancel.png | **Crown style** (steel frame, Crown picture) |
| TAKE OFF | unit skywing (landed) | `ab_land` | icons/ab_land.png | **borrowed picture** (LAND's, its arrow points down) |
| TONGUE | unit mist_toad | `ab_tongue` | icons/ab_tongue.png | **sprite crop** on a plain grey tile (no Brood frame) |
| UPROOT | unit spore_mother (other mode) | `ab_root` | icons/ab_root.png | fine (one picture for both states) |
| WARREN | building hive | `warren_hall` | icons/warren_hall.png | fine |
| WORK | unit grub | `work` | icons/work.png | **Crown style** (steel frame, Crown picture) |

### The Clockwork (gear mode)

| button | where | icon asked | picture shown | verdict |
| --- | --- | --- | --- | --- |
| ABANDON | building site | `stop` | icons/clockwork/stop.png | fine |
| ASSEMBLY WORKS | worker build page 0 | `assembly_works` | icons/assembly_works.png | fine |
| ATTACK | unit winder | `attack` | icons/clockwork/attack.png | fine |
| BACK | worker build page 0 | `back` | icons/back.png | **Crown style** (steel frame, Crown picture) |
| BIG GEAR | building regulator | `build` | icons/clockwork/build.png | **borrowed picture** (BUILD's workshop) |
| BUILD | unit winder | `build` | icons/clockwork/build.png | fine |
| CANCEL | building clocktower (training) | `cancel` | icons/cancel.png | **Crown style** (steel frame, Crown picture) |
| CANCEL MORPH | unit cuckoo (morphing) | `cancel` | icons/cancel.png | **Crown style** (steel frame, Crown picture) |
| CLOCK AVIARY | worker build page 0 | `cuckoo_house` | icons/cuckoo_house.png | fine |
| CLOCK SOLDIER | building movement_works | `clock_soldier` | icons/clock_soldier.png | **sprite crop**, no frame (the other units have framed painted portraits) |
| CLOCKTOWER | worker build page 0 | `clocktower` | icons/clocktower.png | fine |
| COG 1/2 | worker build page 0 | `cog_press` | icons/cog_press.png | fine |
| DEMOLISH | building regulator | `demolish` | icons/demolish.png | **Crown style** (steel frame, Crown picture) |
| DROP HERE | a targeted order (unload / cast) waiting | `ab_unload` | icons/ab_unload.png | not reachable (Crown-only unit) |
| ESCAPEMENT | worker build page 0 | `escapement` | icons/escapement.png | fine |
| HIGH LEAP | building escapement | `research_high_leap` | icons/research_high_leap.png | **sprite crop**, no frame (the unit's own sprite, not the action) |
| HOLD | unit clock_soldier | `hold` | icons/hold.png | **Crown style** (steel frame, Crown picture) |
| JACK | building movement_works | `jack` | icons/jack.png | **sprite crop**, no frame (the other units have framed painted portraits) |
| JUMP | unit jack | `ab_jump` | icons/ab_jump.png | **sprite crop**, no frame (the unit's own sprite, not the action) |
| LEAD | unit winder | `horse_lead` | icons/horse_lead.png | **Crown style** (steel frame, Crown picture) (a Winder leading a captured horse) |
| MAINSPRING | worker build page 0 | `mainspring` | icons/mainspring.png | fine |
| MORE | any card with more buttons than fit | `build` | icons/clockwork/build.png | **borrowed picture** (BUILD's) |
| MORPH TO OWL | unit cuckoo | `ab_morph_owl` | icons/ab_morph_owl.png | **sprite crop**, no frame (the unit's own sprite, not the action) |
| MOVE | unit winder | `move` | icons/clockwork/move.png | fine |
| MOVEMENT WORKS | worker build page 0 | `movement_works` | icons/movement_works.png | fine |
| PATROL | unit clock_soldier | `patrol` | icons/patrol.png | **Crown style** (steel frame, Crown picture) |
| PLACE | placing a building | `build` | icons/clockwork/build.png | fine |
| RALLY | building clocktower | `rally` | icons/rally.png | **Crown style** (steel frame, Crown picture) |
| RATCHET TURRET | worker build page 0 | `ratchet_turret` | icons/ratchet_turret.png | fine |
| REGULATOR | worker build page 0 | `regulator` | icons/regulator.png | fine |
| RELEASE | unit winder (leading a horse) | `horse_release` | icons/horse_release.png | **Crown style** (steel frame, Crown picture) (a Winder leading a captured horse) |
| REPAIR | unit winder | `repair` | icons/clockwork/repair.png | fine |
| SMALL GEAR | any gear building with a big gear | `build` | icons/clockwork/build.png | **borrowed picture** (BUILD's workshop) |
| STOP | unit winder | `stop` | icons/clockwork/stop.png | fine |
| SWIFT | building cuckoo_house | `cuckoo` | icons/cuckoo.png | **sprite crop**, no frame (the other units have framed painted portraits) |
| THRESHER | building assembly_works | `thresher` | icons/thresher.png | fine |
| TICKING OWL | building cuckoo_house | `research_ticking_owl` | icons/research_ticking_owl.png | **sprite crop**, no frame (the unit's own sprite, not the action) |
| WIND-UP SOLDIERS | building assembly_works | `windup_soldier` | icons/windup_soldier.png | fine |
| WINDER | building clocktower | `winder` | icons/winder.png | fine |
| WORK | unit winder | `work` | icons/work.png | **Crown style** (steel frame, Crown picture) |


### Off in normal games

- The shelved Line roster's Clockwork (Bulwark BRACE, Ornithopter COURIER and OVERLOAD, Stormcaller STORM, Tesla Cart
  DEPLOY, Steam Walker, Arc Thrower) has painted brass icons (`ab_brace`, `ab_courier`, `ab_overload`, `ab_storm`,
  `ab_deploy`, `ab_windup`), unused in gear mode. The Line's own buttons (LINE, LAY, RIDE, the trains) show BUILD's
  picture, and PRESSURE asks for `gauge`, which does not exist (blank).
- The LAB prototype roster (Defs.cw_roster): every unit portrait (Tin Militia, Scrapper, Rail Rifleman, Work Car, Plate
  Wagon, Heavy Locomotive, Carrier Car, Tesla Locomotive, Storm Engine) and every command (SIDING, COUPLE, UNCOUPLE,
  CREW OUT, CREW IN, PLATES, SET UP, PACK, BOARD, DOCK, CARRY, DROP, THUNDER) is drawn in code by `CwArt.icon`.

## The Clockwork's new roster: icons it will need

| unit / idea | buttons | icons |
| --- | --- | --- |
| Pendulum (melee area, in progress) | its train button and portrait (its swing is automatic) | `pendulum` portrait |
| Netter (the stopper, in progress) | train button; NET (fire the chain net at one enemy) | `netter` portrait, `clockwork/ab_net` |
| Swift | train button; MORPH TO OWL; CANCEL MORPH | `cuckoo` portrait (framed), `clockwork/ab_morph_owl`, `clockwork/cancel` |
| Ticking Owl | its portrait on the unit card (it is morphed, never trained); a BOMB at a spot later | `ticking_owl` portrait (framed), `clockwork/ab_owl_bomb` (if it gets one) |
| Spring Catapult (planned) | train button; THROW (fling a Clock Soldier or Pendulum into the enemy); BOMBARD (it uses the new order) | `spring_catapult` portrait, `clockwork/ab_throw`, `clockwork/ab_bombard` |
| Reassembly (planned) | its research; REASSEMBLE on a unit (rebuilt into its pair: Clock Soldier and Jack, Swift and Owl, Netter and Catapult) | `clockwork/research_reassembly`, `clockwork/ab_reassemble` (the target's portrait can sit on the button too) |
| Sweeper (planned) | train button; SWEEP (collect every body around it, on/off); its winding area (on/off) | `sweeper` portrait, `clockwork/ab_sweep`, `clockwork/ab_wind_area` |

## TO DRAW

**Round 13 (2026-10-27): drawn and in the game** (ChatGPT sheets in `art/ui/icons3/`, cut by `tools/import_round13.py`,
the Brood and Clockwork ones set in their faction's own frame): 1-10, 12-17, 19-21, 23-31 and the portraits 33-37, plus
the Netter's, the Spring Catapult's and the Great Winder's portraits, a new Winder portrait, the Mortar's DEPLOY and the
top bar's TENSION picture (`assets/icons/tension.png`, frameless). 11 Brood HOLD and 22 Clockwork HOLD came after
(the first drawings were turned down): a shield with an arrow pointing down like the Crown's, in each faction's
materials (`hold_clockwork.png`, `hold_brood.png`: the owner picked one of two each). Still to draw: 18 SPIT (the sheet drew the Mist Toad instead of the Bloater: `brood/ab_spit.png` is
cut but not used; the Bloater's button keeps HOLD GAS's picture), 32 LEAD / RELEASE, and 38-42 (the coming roster's
abilities). Maybe redrawn: 10 Brood DEMOLISH (a mound with a burst egg, close to the Brood BUILD at small size). Cut but
not used yet: `clockwork/ab_shield.png` and `clockwork/research_shield.png` (the Clock Soldier's shield upgrade).


64x64 icons, one per line: the file it becomes, the style, what it shows. Crown style = steel bevel frame round a
near-black ground (like `assets/icons/attack.png`); Brood and Clockwork style = the bronze frame with round corner rivets
round a dark navy ground (like `assets/icons/brood/attack.png`, `assets/icons/clockwork/attack.png`), the faction in the
picture (Brood: creatures, bone, sinew, acid green; Clockwork: brass machines, springs, gears, clock hands); portrait
style = the steel portrait frame of `assets/icons/musketeer.png`.

The new order (now code-made placeholders: the faction's ATTACK icon with a target ring):

1. `assets/icons/ab_bombard.png`, Crown: a Field Cannon or a Mortar with a shell arcing onto a red target ring on the
   ground (fire at a spot).
2. `assets/icons/brood/ab_bombard.png`, Brood: a rooted Spore Mother lobbing a green spit blob onto an acid-green ring.
3. `assets/icons/clockwork/ab_bombard.png`, Clockwork: the Spring Catapult's arm flinging its load onto a brass ring.

Missing or borrowed (Crown):

4. `assets/icons/horse_team.png`, Crown: TEAM, two harness horses side by side in collars and traces, with a small "+".
5. `assets/icons/more.png`, Crown: MORE, a page turning over with a right arrow (the next page of buttons).
6. `assets/icons/ab_restock.png`, Crown: RESTOCK, a powder keg hauled up on a rope to a balloon's basket.
7. `assets/icons/ab_auto_refit.png`, Crown: AUTO REFIT, an anvil with a breastplate and a musket lock, a small
   circling arrow (done by itself).

The Brood's own commands (now Crown pictures or borrowed):

8. `assets/icons/brood/back.png`: BACK, a curled claw or bone arrow turning back.
9. `assets/icons/brood/cancel.png`: CANCEL, a red X of two claw slashes.
10. `assets/icons/brood/demolish.png`: DEMOLISH, a Brood mound caving in.
11. `assets/icons/brood/hold.png`: HOLD, a raptor crouched low with its claws dug into the ground.
12. `assets/icons/brood/patrol.png`: PATROL, two trails of raptor footprints curving into a loop.
13. `assets/icons/brood/rally.png`: RALLY, a bone totem with a red crest stuck in the ground.
14. `assets/icons/brood/work.png`: WORK, a grub hauling a lump of food (automatic work).
15. `assets/icons/brood/more.png`: MORE, a claw arrow pointing on.
16. `assets/icons/brood/ab_tongue.png`: TONGUE, the Mist Toad's long tongue lashing out at a marked enemy.
17. `assets/icons/brood/ab_take_off.png`: TAKE OFF, a Skywing beating up into the air with an UP arrow (LAND keeps its
    down arrow).
18. `assets/icons/brood/ab_spit.png`: SPIT, a Bloater spitting a glob of acid (HOLD GAS keeps the full sac).

The Clockwork's own commands (now Crown pictures, sprite crops or borrowed):

19. `assets/icons/clockwork/back.png`: BACK, a brass clock hand curving back.
20. `assets/icons/clockwork/cancel.png`: CANCEL (and CANCEL MORPH), two crossed clock hands in red.
21. `assets/icons/clockwork/demolish.png`: DEMOLISH, a gear ring cracking apart, bolts flying.
22. `assets/icons/clockwork/hold.png`: HOLD, a Clock Soldier planted behind its pocket-watch shield.
23. `assets/icons/clockwork/patrol.png`: PATROL, a pendulum swinging between two arrows.
24. `assets/icons/clockwork/rally.png`: RALLY, a small brass beacon or flag on a gear stand.
25. `assets/icons/clockwork/work.png`: WORK, a Winder turning a big winding key (automatic work).
26. `assets/icons/clockwork/more.png`: MORE, a brass arrow on a cog.
27. `assets/icons/clockwork/ab_gear_small.png` and `ab_gear_big.png`: SMALL GEAR and BIG GEAR, a small fast gear (speed
    lines) and a big slow gear (heavy teeth).
28. `assets/icons/clockwork/ab_jump.png`: JUMP, the Jack crouched on its coil spring with a dotted leap arc.
29. `assets/icons/clockwork/ab_morph_owl.png`: MORPH TO OWL, a Swift opening up into a Ticking Owl (Swift, curved
    arrow, Owl).
30. `assets/icons/clockwork/research_high_leap.png`: HIGH LEAP, a compressed spring with an up arrow over a cliff edge.
31. `assets/icons/clockwork/research_ticking_owl.png`: TICKING OWL, the Owl's plans: a blueprint with the owl's outline
    and its pendulum weight.
32. `assets/icons/clockwork/horse_lead.png`, `horse_release.png` (low priority): a Winder's brass hand on a horse's
    reins, and letting go.

Portraits (the steel portrait frame, a bust or three-quarter figure like `musketeer.png`; now frameless sprite crops):

33. `assets/icons/clock_soldier.png`, 34. `assets/icons/jack.png`, 35. `assets/icons/cuckoo.png` (the Swift),
36. `assets/icons/ticking_owl.png`.

The Clockwork's coming roster:

37. `assets/icons/pendulum.png` (portrait): the Pendulum, tower clock body, the blade at the bottom of its swing.
38. `assets/icons/netter.png` (portrait) and `assets/icons/clockwork/ab_net.png`: NET, the spring cannon firing a
    weighted chain net that spreads over a target.
39. `assets/icons/spring_catapult.png` (portrait) and `assets/icons/clockwork/ab_throw.png`: THROW, the catapult's arm
    flinging a Clock Soldier into the enemy.
40. `assets/icons/clockwork/ab_reassemble.png`: REASSEMBLE, a machine coming apart into parts and back together as
    another (a gear, a wrench, two curved arrows); `assets/icons/clockwork/research_reassembly.png`: its plans.
41. `assets/icons/sweeper.png` (portrait), `assets/icons/clockwork/ab_sweep.png`: SWEEP, a rake and hopper gathering
    bodies; `assets/icons/clockwork/ab_wind_area.png`: a big winding key with arcs round it (it winds the army nearby).
42. `assets/icons/clockwork/ab_owl_bomb.png` (if the Owl gets a bomb at a spot): the pendulum weight dropping onto a
    brass ring.

Code needed when the files come in: only the buttons that borrow another button's name today (MORE, SPIT, TAKE OFF,
RESTOCK, AUTO REFIT, SMALL GEAR, BIG GEAR) need their new name (`more`, `ab_spit`, `ab_take_off`, `ab_restock`,
`ab_auto_refit`, `ab_gear_small`, `ab_gear_big`) put in `hud.gd` (`_paged` and the build pages' MORE, `_ability_buttons`,
`_balloon_buttons`, `_auto_refit_button`, the gear swap in `_build_card`). Everything else needs no code: a file in
`assets/icons/brood/` or `assets/icons/clockwork/` wins over the shared one by itself, and a portrait or research icon
dropped in under its existing name replaces the sprite crop.

## The format of a new sheet

How the sheets in `art/ui/icons2/` were made and cut (tools/import_round11.py, tools/import_command_icons.py):

- One ChatGPT image per sheet, a few icons each, on a FLAT dark slate-navy background (about RGB 30, 45, 62; no texture,
  vignette or shadow): `commands_extra.png` 3 columns x 2 rows on 1536 x 1024, `abilities_crown.png` 3 x 3 on
  1254 x 1254, `abilities_brood_clockwork.png` rows of 4, 4 and 3 on 1536 x 1024, the portrait sheets 3 or 4 in a row on
  about 1777 x 885.
- Every icon in its own square frame, all the same size, with wide gaps of background between them (the frames never
  touch).
- The importer finds the frames as the biggest blobs that are not background (`bg_mask`), reads them row by row, left to
  right, and names them from a list in the script (`PORTRAITS`, `BRASS`, `SHEETS`). Steel-framed (Crown) icons: the
  picture inside the frame's black inner line is cut out, made square, box-shrunk to 52 x 52 and set in the game's
  6 px steel bevel (64 x 64). Bronze/brass-framed (Brood, Clockwork) icons: cut at the frame's outer outline and
  box-shrunk whole to 64 x 64; Brood ones are re-framed in the Brood command frame.

So a new sheet should be:

- 3 columns x 2 rows on 1536 x 1024 (6 icons) or 3 x 3 on 1254 x 1254 (9 icons); ONE faction style per sheet (Crown
  steel, or Brood/Clockwork bronze), portraits on a sheet of their own;
- a flat, even slate-navy background, at least about 60 px of it between frames and round the edge;
- square frames of one size, the whole picture inside its frame (nothing crossing it), no text, labels or numbers;
- bold, simple pictures that read at 64 px (one subject, a strong silhouette, the action shown with an arrow or arc
  where it helps), the same light from the upper left as the existing icons;
- the names in reading order given with the sheet, so they go straight into the importer's list.

Output: `assets/icons/<name>.png` (Crown and portraits) or `assets/icons/<faction>/<name>.png` (Brood, Clockwork),
64 x 64, opaque, then `godot --headless --import`.
