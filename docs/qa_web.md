# QA: the web version and the interface (0.14.64)

One QA machine of the "full ham" test. This one looked at the web build and the interface, as a player sees them.
Screenshots are in `docs/shots/qa_web/`.

## How it was tested

- The web build was made the way CI makes it: `tools/web/build_web.sh` with Godot 4.7 and its web templates.
- It was served on this machine and played in Chromium through Playwright, with software WebGL.
- Two sizes: a computer at 1600 by 900, and a phone held sideways at 915 by 412, with touch.
- Every console message, page error and failed request was kept.
- The live site could not be reached from here, so everything was local.

## What was checked

- The loading page, the first-run "Where are you playing?" page and the main menu, at both sizes.
- Skirmish setup with each faction. A skirmish as the Crown on the computer, as the Brood and the Clockwork on the phone, against the computer.
- In a match: selecting workers, placing a Cottage, training a Labourer and a grub, the Burrow growing into a Warren, the in-game MENU with its music player, pause and resume, surrender, CONTINUE after closing the tab.
- The REPLAYS page and the replay viewer: play, 4x, a timeline jump, the fog choice, quit.
- HOW TO PLAY, the EDITOR page, the sandbox, the Clockwork lab, the map editor, MATCH LOGS.
- SETTINGS and every page in it: patch notes, music player, animation viewer, interface layout and hotkeys, playing on.
- Português and Español: the main menu, the skirmish setup, the in-game HUD and menu, the replays page.

## Load time

- First visit to the main menu: about 5 seconds on the computer and 8 on the phone, from a local server. A real visit adds the download, about 60 MB the first time (see `docs/web_load.md`).
- Next visits: about 4 to 5 seconds. Nothing big is downloaded again: Cache Storage works.
- Starting a match stalls for about 7 seconds on the computer and 13 on the phone, between START and the map. This is with software WebGL, so a real device should be faster. It is worth timing on the owner's phone.
- Music came in piece by piece when wanted. No music or sound request failed.

## Console

- No script errors on the menus, and no failed requests.
- One engine error in a Crown match at about 2 minutes: "Error calling method from 'any': Cannot convert argument 1 from Object to Object". It comes from an `any(func(u: Unit) ...)` call meeting a freed unit in the array. It did not stop the match. Not fixed: there are many such calls, and I could not tell which one from the browser. It needs a desktop run with the debugger to find the line.
- "GPU stall due to ReadPixels" warnings come from Chromium's software WebGL, not from the game.

## Problems found, and what was done

1. **The crash page after every normal web visit.** Fixed.
   The game writes `user://running.txt` while it runs, and only removes it on a close notification. A browser sends none when a tab is closed, reloaded or swiped away. So the next visit showed THE GAME CLOSED UNEXPECTEDLY, every time. Confirmed in the browser before the fix: after closing the tab, and after a reload.
   Now, on the web, the marker lives in the page's localStorage, which writes at once. The page removes it when it is hidden or left, and puts it back when it shows again. If the engine died first (a WebAssembly abort), the marker stays, so a real crash is still reported. A leftover `running.txt` from an web build before 0.14.64 is removed quietly.
   Checked in the browser: close, reload, close during a match, on the computer and the phone: no crash page. After a forced engine error and a close: the crash page shows. Screenshot: `crash_page_after_abort.jpg`.
   One scripted run of the forced-error case did not keep the marker; a direct repeat did. Worth a look if real crashes seem to go unreported.
   Also: on the web the report has no previous engine log, since the browser keeps none.

2. **Map editor buttons dead after painting with a mouse.** Fixed, with a test.
   After you paint, BACK, HELP, SAVE and the rest did nothing. The editor ate the mouse release over its panel. With a touch, BACK did nothing on a phone, for the same reason.
   Test: `tools/test_map_editor_buttons.gd` (fails before the fix, passes after). The phone case was checked in the browser, because a headless test cannot send taps to buttons.

3. **Patch notes ran off the screen.** Fixed.
   Each item was one long line, cut at the right edge at both sizes. On the phone the page was taller than the screen. Now the lines wrap and the list fits. Screenshots: `pc_patch_notes_before.jpg`, `phone_patch_notes_after.jpg`.

4. **The in-game MENU did not fit a phone.** Fixed.
   On a phone held sideways, BACK TO THE MATCH sat under the bottom edge, and the volume bars ran through their words. Now the buttons fit, and the words sit above the bars. Screenshots: `phone_ingame_menu_before.jpg`, `phone_ingame_menu_after.jpg`.

5. **MATCH LOGS and the crash report had no panel.** Fixed.
   Their text sat straight on the busy menu picture and was hard to read; long lines were cut. They now sit on a panel like the other pages, and the lines wrap. Screenshot: `pc_match_logs_before.jpg`.

6. **The hotkey list had its note drawn over it.** Fixed.
   In SETTINGS, INTERFACE LAYOUT, HOTKEYS, the note "Built-in layouts can't be changed" was drawn across the middle of the list. It now sits below it. Screenshot: `pc_hotkeys_overlap_before.jpg`.

7. **Long dropdown labels were cut.** Fixed.
   In the sandbox, the map read "RANDOM 2V2 MA", without its arrow. Dropdown text now shrinks to fit. Screenshot: `pc_sandbox_map_cut.jpg`.

8. **IDLE, ARMY, MAKE cut in Spanish and Portuguese on a phone.** Improved.
   "PRODUCIR" and "EJÉRCITO" were too wide for their buttons. They may now shrink further. Screenshot: `phone_es_hud.jpg`.

9. **Replays showed English names.** Fixed, with a test.
   In Portuguese and Spanish, the replays list said "P1 Crown (you)" and "(easy AI)". They now show in the language in use. Test: `tools/test_replay_names_local.gd`. Screenshot: `phone_replays_es_after.jpg`.

## Not fixed: for the owner or a later job

- **The replay viewer on a phone.** Screenshot: `phone_replay_viewer_es.jpg`. The players' lines at the top left run under the clock. The speed and timeline bar sits in the middle of the screen, over the map. Some words stay in English in Spanish: "The Crown", "supply", "VISTA: Free · all vision". This needs a layout pass of the replay bar, which the replays job owns.
- **The camera at match start.** It begins to one side of the Town Hall, a short way off. On the computer the base was at the left edge of the screen. It is set in `game.gd` (`me.global_position + Vector2(160, 40)`). It was left alone because it may be on purpose.
- **The Clockwork lab's help text** covers the top left of the map on the computer. Screenshot: `pc_clockwork_lab.jpg`. It is a test page, so this was left alone.
- **The match start stall**, about 7 to 13 seconds here. See load time above.
- **The engine error from `any()`.** See the console section.

## Decisions taken while the owner was away

- On the web the "still running" marker moved to localStorage, instead of trying to delete a file while the page closes. The IndexedDB write behind `user://` may never finish while a page closes. localStorage writes at once.
- Fixes were kept small and local, in the menus and the editor. No balance, AI or game rule was touched.
- The version went to 0.14.64 (tested as 0.14.54 on top of 0.14.53, then merged with main), with patch notes in English, Portuguese and Spanish.
