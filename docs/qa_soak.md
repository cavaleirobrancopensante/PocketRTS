# QA soak: long games on every map and every mode (2026-10-27)

One QA machine, about two hours, on branch `qa-soak` from main 0.14.53. Main moved on to 0.14.63 meanwhile; it was merged in, so these fixes are 0.14.64.
Short sentences, to be read aloud.

## How the games were run

A new runner, `tools/qa_soak_game.gd`, plays one computer-only game on any map with any number of players.
It hides the HUD and plays as fast as the machine allows.
It keeps the result, the length, the match log, and a list of trouble:
idle workers for minutes, no new building for minutes with money in the bank, a computer that never attacks,
units under a move order that stay put for three minutes, long supply blocks, income at zero while soil is left,
and frames slower than 100 ms.

The machine has two cores, so two games ran at once.
To fit the two hours, each game had a wall-clock limit: 10 minutes for 3v3, 4v4 and free-for-all, 8 for 2v2, 5 for 1v1.
So most big games were stopped between minute 12 and minute 20 of game time, not at 30.
Frame times are inflated: two games and the mode tests shared two cores.

Games 1 to 6 ran on plain 0.14.53. Games 7 to 15 started while the fixes below were going in, so some of them ran with part of the fixes.

## Every game played

| # | Map | Mode | Players (faction, level) | Result | Game time | Trouble seen |
|---|-----|------|--------------------------|--------|-----------|--------------|
| 1 | Sundered Realm | 4v4 | Crown, Brood, Clockwork, Crown (all Hard) vs Brood, Clockwork, Crown, Brood (all Hard) | stopped, no winner | 12:00 | missing trim-mask picture error; 16 run-down Clock Soldiers; worst frame 342 ms |
| 2 | Kingsfield | 3v3 | Crown, Brood, Clockwork vs Clockwork, Crown, Brood (all Hard) | stopped | 15:31 | same picture error; 34 run-down Clock Soldiers; 20 Clutch Mounds placed and dropped |
| 3 | Pinewall Marches | 3v3 | Brood, Clockwork (Normal), Crown vs Crown, Brood (Normal), Clockwork | stopped | 15:46 | 163 Clutch Mounds placed and dropped; both Brood never attacked |
| 4 | Twin Crowns | 2v2 | Crown, Brood vs Clockwork, Crown (Hard) | stopped | 19:25 | one SCRIPT ERROR (a raised soldier and a gone horse); Brood first attack at 16:00 |
| 5 | Jade Wilds | 2v2 | Brood, Clockwork vs Crown, Brood (Hard) | stopped | 19:12 | Brood (economy) never attacked and was beaten at 13:10 |
| 6 | Shattered Coast | 2v2 | Clockwork, Crown vs Brood, Clockwork (Normal) | stopped | 19:50 | nothing new |
| 7 | Ember Reach | 2v2 | Crown, Clockwork vs Brood, Crown (Hard) | stopped | 13:13 | Crown with 3+ idle workers for 160 s (its main's soil was spent) |
| 8 | Whitecap Pass | 2v2 | Brood, Crown (Normal) vs Clockwork (Normal), Brood | stopped | 13:54 | nothing new |
| 9 | Jade Wilds | free-for-all (4) | Crown, Brood, Clockwork, Crown (Normal) | P4 Crown won | 18:33 | a Crown supply block of about 2 minutes that ended by itself |
| 10 | Twin Crowns | free-for-all (4) | Brood, Clockwork, Crown, Clockwork (Hard) | P3 Crown won | 17:32 | nothing new |
| 11 | Kestrel Rise | 1v1 | Crown vs Clockwork (Easy) | Crown won | 14:09 | nothing new |
| 12 | Cinder Steps | 1v1 | Brood vs Clockwork (Normal) | Clockwork won | 11:33 | Brood (economy) never attacked |
| 13 | Redrock Canyon | 1v1 | Clockwork (Easy) vs Crown (Normal) | stopped | 24:22 | 40 run-down Clock Soldiers; Crown with idle workers late |
| 14 | Greenhold | free-for-all (4, classic map) | Crown, Brood, Clockwork (Hard), Brood (Normal) | P3 Clockwork won | 17:16 | one ERROR in the Brood swarm (a freed Raptor) |
| 15 | Ember Reach | 1 vs 2 | Clockwork (Hard) vs Crown and Brood (Easy) | the two Easy won | 11:34 | nothing new |

Every faction played on every map size: 1v1, 2v2, 3v3, 4v4 and free-for-all.
No game hung. Every game either ended or was stopped by its time limit.
No game had income at zero while soil was left, and no computer stopped building for long.

Six shorter re-runs, 5 to 6 minutes each, checked the fixes: Pinewall Marches 3v3 three times, Twin Crowns 2v2 twice and Greenhold free-for-all once, the last two with every fix in.
None had a script error. Two had sound errors for files that came with the merge from main before this machine had imported them; that is this machine's import cache, not the game. The last two had no errors at all.
On Pinewall Marches the dropped sites went from 163 in 15 minutes to 8 in 10 minutes.

## Every mode checked

- Save and CONTINUE, once per faction (`tools/test_qa_save_continue.gd`): a match is autosaved at 4 minutes, the menu offers CONTINUE, and the units, buildings, money and clock all come back exactly. The computer is back and keeps earning. All passed.
- SANDBOX (`tools/test_qa_sandbox_lab.gd`): a 4-player sandbox. The panel's buttons work: +1000, +200, fog, speed, control of another player, AI off and on, kill all. Every unit and building of every faction was put down for every player, 124 units and 104 buildings, and the match played on. All passed.
- CLOCKWORK LAB (same test, Main.start_lab): the gear field and its units are set out, the computer is peaceful, and nothing was attacked in four minutes. All passed.
- MAP EDITOR (`tools/test_qa_editor_play.gd`): a new map is made, two starts placed, CHECK lists a bare map's problems, the map is saved and loads back, PLAY takes it to the skirmish, and two computers play on it. All passed.
- MAP CHECK on every built-in map, the nine classic ones and the eighteen named ones (`tools/check_maps.gd`): 27 of 27 pass.
- REPLAYS, once per faction pairing (`tools/test_replay.gd`, now with `a:` and `b:` faction arguments and a check of the second player's fog): recording, the list, the viewer, seeking back and forth, pause, speed, each player's fog, a cut file and an old version. All passed for Crown vs Brood, Brood vs Clockwork and Clockwork vs Crown, and again for Clockwork vs Brood after the merge.
- Online co-op (`tools/test_online.sh coop`): host ALL OK, guest ALL OK, on 0.14.53 and again after the merge. The one "LOBBY FAILED: could not reach the relay" line comes after the test, when the relay is shut down.
- Watching the computers (`tools/test_qa_watch.gd`): a 4-player free-for-all with the spectator. All vision, each player's vision (fog hides the others), follow each player (the camera moves by itself), and the hotkeys 0 to 4. All passed.

## Bugs found and fixed

1. A missing picture. The dismounted Cuirassier's east-walk trim mask was deleted long ago, but its `.import` file stayed. So the game believed the picture existed, tried to load it, and printed three errors in matches. Fixed: the stray `.import` is gone, and `tools/import_vet_trim.py` now removes the `.import` of any mask it no longer writes. Test: `tools/test_orphan_imports.gd` (no `.import` without its picture under assets).
2. A camera warning in every match. Physics interpolation is on, so Godot switched the camera to physics updates and printed a WARNING each time. Fixed: the camera is set that way from the start. Nothing changes on screen.
3. A raised soldier and a gone horse. A Crown soldier raised by a Missionary still had his old order to fetch a horse, and the horse was gone. Stopping him hit a SCRIPT ERROR half way, so his old work was not cleared. Fixed: the check for a living horse now comes first. Test: `tools/test_reset_work_freed_horse.gd`.
4. The Brood placing and dropping a Clutch Mound every second. When raiders stood near, the grub sent to build fled, nobody was coming, the site was dropped and refunded, and the computer placed it again at once. Up to 163 times in one game. Feeding Pits did the same, every two seconds. Fixed: a site dropped this way keeps the computer's look-again wait, and the computer waits 8 seconds before it places that kind again (AI._construct, and the Brood's supply mounds). In the last re-run on Pinewall Marches there were 8 drops in 10 minutes, at least ten seconds apart. Test: `tools/test_ai_abandoned_site.gd`.
5. The Brood swarm losing its whole group. A swarm group could hold a Raptor that had been freed, for example eaten by a grub. The group was filtered with a typed check, which fails on a freed object, so the whole group came back empty and the wave was called off. Fixed: the check no longer types its argument. The same small change was made to the other lists the computer keeps from tick to tick: escorts, guards, raiders, the extreme-rush wave, the Brood's lookouts, and a building's crew. Test: `tools/test_ai_swarm_freed.gd`.
6. A rally point on a unit that turns into something else. If a building's rally followed a unit that was freed without dying, such as a grub that became a building or a man who mounted, the building's tick hit a SCRIPT ERROR every frame and stopped half way. Fixed: the rally lets go and stays where the unit was. The trained units' rally code got the same guard. Test: `tools/test_rally_freed_unit.gd`.

These fixes change no balance number.
After the merge with main, every new test, the four mode tests and the horse, hauler, rush, extreme-rush, wall, Brood-judgement, Clock Soldier shield and file tests pass. They follow the design principles' rule that a punishment should match the mistake.

## Design questions for the owner (not changed)

1. Run-down Clock Soldiers are stranded for good. In almost every game with a Clockwork, Clock Soldiers ran out of wind far from the gear field and stood still for the rest of the match, still under a move order. Up to 40 in one game. The computer sends low-wind soldiers home only when they are not already on a move order, so a soldier on a long march runs out on the way. In gear mode nothing ever winds them again. Is that the intended weakness, or should the computer bring them back sooner, or should something rescue them?
2. The Brood computer rarely attacks in team games. Before a wave it compares its own army with every enemy army it has seen, and it does not count its allies. In 3v3 both Brood computers never attacked in sixteen minutes. In 2v2 one attacked first at 16:00 and another never did. Should allies' armies count, or should the Brood join its ally's attacks?
3. The Crown's main soil runs out around minute 10, and then three or more of its workers stand idle for two to five minutes, until a new Town Hall is up. This is the known late-game economy item in the backlog.
4. Big games are slow. In the 4v4 and 3v3 games the match log's worst frame was 270 to 342 ms, with about 2,000 frames over 50 ms in 12 to 15 minutes, on a headless machine sharing its cores. Units, the game tick and the fog are the largest costs in the log's profile.
5. `tools/test_brood_fixes.gd` fails four checks on main too, before any change here: a grub ordered elsewhere and a grub stopped, and the two Clockwork crate checks. It also runs a very long time. It needs a look by whoever owns it.

## Files

- New tools: `tools/qa_soak_game.gd`, `tools/test_qa_save_continue.gd`, `tools/test_qa_sandbox_lab.gd`, `tools/test_qa_editor_play.gd`, `tools/test_qa_watch.gd`, and the five bug tests above.
- Changed: `scripts/ai.gd`, `scripts/ai_brood.gd`, `scripts/building.gd`, `scripts/game.gd`, `scripts/unit.gd`, `tools/import_vet_trim.py`, `tools/test_replay.gd`, the patch notes.
- The match logs and results stayed on the QA machine.
