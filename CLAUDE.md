# Notes for Claude

- **Version:** every pushed change advances the game version. Run `tools/bump_version.sh`
  (patch number, e.g. 0.7.3 -> 0.7.4) before committing; bigger features may bump the minor
  number by hand. The version shows in the main menu and on the first line of every match log.
- Match logs (playtest reports pasted by the user) start with `PocketRTS vX.Y.Z match log`.
