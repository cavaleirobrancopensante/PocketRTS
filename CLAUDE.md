# Notes for Claude

- **Version:** every pushed change advances the game version. Run `tools/bump_version.sh`
  (patch number, e.g. 0.7.3 -> 0.7.4) before committing; bigger features may bump the minor
  number by hand. The version shows in the main menu and on the first line of every match log.
- Match logs (playtest reports pasted by the user) start with `PocketRTS vX.Y.Z match log`.
- **Design:** read `docs/design_principles.md` (fairness, anti-snowball, meaningful base building)
  before balance, economy, AI or building changes; the owner wants these followed.

## Current work

- **Finishing the Barracks, Horse Breeder and Armoury animation packs.** The Armoury's nine
  research experiments (inventor on the rooftop) are drawn and in `art/crown/armoury_anim/`; the
  importer and the in-game playback are not written yet. The Barracks (8 units) and Horse Breeder (horse) animations
  are not drawn yet. The rule: a building's animation matches what it is producing or researching
  right now. Plan, frame lists, prompts and status: `docs/animation_packs.md`.
  Update that file's status table when you land a piece, so other agents can tell what is done.
