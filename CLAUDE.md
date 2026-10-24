# Notes for Claude

- **Version:** every pushed change advances the game version. Run `tools/bump_version.sh`
  (patch number, e.g. 0.7.3 -> 0.7.4) before committing; bigger features may bump the minor
  number by hand. Also add an entry for the new version to `scripts/patch_notes.gd` (the PATCH NOTES page in Settings); the script updates the version in README.md itself. The version shows in the main menu and on the first line of every match log.
- Match logs (playtest reports pasted by the user) start with `PocketRTS vX.Y.Z match log`.
- **Design:** read `docs/design_principles.md` (fairness, anti-snowball, meaningful base building)
  before balance, economy, AI or building changes; the owner wants these followed.

## Backlog (owner's list, easiest first; jobs marked "branch" were stopped half done: their worktrees are in .claude/worktrees/, resume with their agent or merge the branch)

- UI: move the zoom bar off the minimap into a small UI; small music player (next track, list of all songs to pick). (branch worktree-agent-afc321a811e072d5a)
- BUG: a labourer leading a horse from the Breeder to the recruit gets stuck / has pathfinding trouble (seen in 0.12.9 playtests).
- Starting resource buildings hugging the plateau edge, fairly mirrored; balloon destruction kills all passengers and leaves corpses. (branch worktree-agent-a196928da4db82c4b)
- Farm: true 6x6 square, no bottom fence, mill centred; builder hammer animation (arm only); cliff readability from both heights. (branch worktree-agent-a7cbf06f1b14d4af1)
- Lag: units ~360 ms/s late game, hud/selection 45-110 ms/s and hud draw ~120 ms/s on the tablet profile, command card rebuilt 18x/s, fog/units, one 12 s frame in a long match. (branch worktree-agent-a4e52e95e6eea66eb)
- AI: Crown lost ALL workers at ~6:00 in a Greenhold game (supply 0/60, workers 0) after Raptors counterattacked: check the "workers pitch in when army < 3" defence and escort workers; real attackers still pull every worker.
- AI: Brood AI on Rush built no army by 4:30 after the capital/income nerf (all grubs): check rush AI under the halved income. (The Crown no longer walls late: see the wall work below.)
- Crown late-game economy: soil runs out (~10 min), 1-2k unspent gold at the supply cap, saltpetre. Brood retest after the capital rework (Crown rush vs Brood economy; Hard Timing Attack on Amberfall Vale).
- AI wall timing and scouting: DONE for the Crown Musketeer opening (AI._wall_wanted/_wall_off/adopt_site, AIScout rush evidence by faction; tools/test_ai_wall_vs_rush.gd: wall at ~2:00 behind the Barracks and Mill, 3 Musketeers by ~2:30, vs the owner's extreme rush). Still open: the walled Brood AI scouting by a patrolling grub at the ramp foot, Clockwork's equivalent, and a Crown that holds 3 Musketeers by 2:00 (needs the early farm income, which pays in lumps).
- Queen animation; Armoury art polish (patch wobble, yellow specks, dummy target colour); wall balance check; optional player build grid; loosen the 24-tile limit in tools/test_ai_placement.gd.
- MUSIC: the Crown has 20 pieces (9 calm incl. 3 waltzes, 11 battle incl. fife marches and the snare-solo marches; tools/music/crown_court.py hand-composed, crown_marches.py = marches on the snare solos); the game picks by moment (Music.ROLES: opening piece at match start, skirmish pieces for a mild fight, full battle when heat > 14, calm otherwise). The Brood and Clockwork have 10 each and no opening/skirmish roles: they need ~20 pieces each in the same shape (open, skirmish, battle, calm) and an "army" select sound (voice/<faction>_army) for mixed selections. Menu overtures are shared (9).
- Capital rework decisions to confirm: cancel gives no egg but biomass is refunded; one 10,500 ground reserve at the capital.

## Current work

- Animation packs are done (Barracks drills, Breeder coats, Armoury experiments in game); the Queen is a still sprite at the Brood capital. Status table: `docs/animation_packs.md`.
