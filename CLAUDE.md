# Notes for Claude

- **Version:** every pushed change advances the game version. Run `tools/bump_version.sh`
  (patch number, e.g. 0.7.3 -> 0.7.4) before committing; bigger features may bump the minor
  number by hand. Also add an entry for the new version to `scripts/patch_notes.gd` (the PATCH NOTES page in Settings); the script updates the version in README.md itself. The version shows in the main menu and on the first line of every match log.
- **Art:** legs and tools drawn in code are tracked in `docs/art_style_inconsistency.md` (the owner wants them redrawn by ChatGPT later for one uniform style); add every new code-drawn edit there.
- Match logs (playtest reports pasted by the user) start with `Holdfast vX.Y.Z match log`.
- **Design:** read `docs/design_principles.md` (fairness, anti-snowball, meaningful base building)
  before balance, economy, AI or building changes; the owner wants these followed.

## Backlog (owner's list, easiest first; jobs marked "branch" were stopped half done: the work is kept on their branch (worktree-agent-*; uncommitted parts were saved as a "WIP snapshot" commit and the worktrees removed to free disk): recreate a worktree from the branch to resume, or merge it)

- UI: a small music player (next track, a list of all songs to pick) inside the in-game MENU, skirmish and online (the zoom bar is already off the minimap). In progress with the online MENU work (wt-online); an older start is on branch worktree-agent-afc321a811e072d5a.
- BUG: a labourer leading a horse from the Breeder to the recruit gets stuck / has pathfinding trouble (seen in 0.12.9 playtests).
- BUG: limbered guns (cannon/mortar with horses) clip through walls and jam at gates, wall ends and cliff blocks; horses bought for a rider or gun walk into the building and vanish. Both fixes were left unmerged (branches fix-limber-gate-wip, fix-horse-vanish-wip on origin); being ported onto main as branch fix-guns-horses.
- Lag: units ~360 ms/s late game, hud/selection 45-110 ms/s and hud draw ~120 ms/s on the tablet profile, command card rebuilt 18x/s, fog/units, one 12 s frame in a long match. (branch worktree-agent-a4e52e95e6eea66eb)
- AI: Crown lost ALL workers at ~6:00 in a Greenhold game (supply 0/60, workers 0) after Raptors counterattacked: check the "workers pitch in when army < 3" defence and escort workers; real attackers still pull every worker.
- AI: Brood AI on Rush built no army by 4:30 after the capital/income nerf (all grubs): check rush AI under the halved income. (The Crown no longer walls late: see the wall work below.)
- Crown late-game economy: soil runs out (~10 min), 1-2k unspent gold at the supply cap, saltpetre. Brood retest after the capital rework (Crown rush vs Brood economy; Hard Timing Attack on Amberfall Vale).
- AI wall timing and scouting: DONE for the Crown Musketeer opening (AI._wall_wanted/_wall_off/adopt_site, AIScout rush evidence by faction; tools/test_ai_wall_vs_rush.gd: wall at ~2:00 behind the Barracks and Mill, 3 Musketeers by ~2:30, vs the owner's extreme rush). Still open: the walled Brood AI scouting by a patrolling grub at the ramp foot, Clockwork's equivalent, and a Crown that holds 3 Musketeers by 2:00 (needs the early farm income, which pays in lumps).
- Art: the dismounted Cuirassier (dismounted_armoured) art is bad: redo it so it matches the mounted Cuirassier (the owner, 2026-10-25). The Armoured Musketeer borrowed its steel back plate meanwhile.
- Queen animation; Armoury art polish (patch wobble, yellow specks, dummy target colour); wall balance check; optional player build grid; loosen the 24-tile limit in tools/test_ai_placement.gd.
- MUSIC: the Crown has 20 pieces (9 calm incl. 3 waltzes, 11 battle incl. fife marches and the snare-solo marches; tools/music/crown_court.py hand-composed, crown_marches.py = marches on the snare solos); the game picks by moment (Music.ROLES: opening piece at match start, skirmish pieces for a mild fight, full battle when heat > 14, calm otherwise). The Brood and Clockwork have 10 each and no opening/skirmish roles: they need ~20 pieces each in the same shape (open, skirmish, battle, calm) and an "army" select sound (voice/<faction>_army) for mixed selections. Menu overtures are shared (9).
- Art (make better): the Cog Press and Mainspring working animations are rough. Press (art/redraws/cog_press_work_v2.png, tools/press_anim/): the flywheel is ChatGPT's painted face turned in code; the steam puff (plain grey circles), the small falling cog and the piston slam are code-drawn and need an art pass. Mainspring (art/redraws/mainspring_work_code.png): cranks, needle and glint are code-drawn; plan is one flat painted crank part from ChatGPT swung in code. Details in docs/art_style_inconsistency.md.
- Capital rework decisions to confirm: cancel gives no egg but biomass is refunded; one 10,500 ground reserve at the capital.

## Current work

- Animation packs are done (Barracks drills, Breeder coats, Armoury experiments in game); the Queen is a still sprite at the Brood capital. Status table: `docs/animation_packs.md`.
