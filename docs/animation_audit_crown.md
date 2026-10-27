# Crown animation audit (2026-10-27)

Every Crown unit in every animation, and the Crown buildings' animations, measured and looked at.
Written in short sentences, to be read aloud.

How it was done:

- `tools/anim_audit/measure_crown.py` measures every strip, frame by frame. It finds the box, the feet, the body's centre, the pixel count, stray pixels, half-transparent pixels and the team-colour reds. It flags feet that slide, bodies that jump, size pops, copied views, empty or doubled frames, and how far the figure jumps when one animation hands over to the next. Run it with `--sheets DIR` for contact sheets and `--gifs DIR` for GIFs at game speed.
- I looked at every animation in every view, at 3 to 4 times size, with the west views mirrored the way the game draws them.
- The buildings were filmed in a running game with `tools/shot_building_anim.gd`.
- `tools/anim_audit/fix_crown.py` makes the safe fixes. It is idempotent and runs in `tools/rebuild_art.sh`.
- Pictures are in `docs/shots/anim_audit_crown/`. Files named `fix_*` show before (top row) and after (bottom row). Files named `sheet_*` are contact sheets: one row per view (s, se, e, ne, n, then sw, w, nw mirrored), the cyan line is the ground. Files named `*_game_*` are GIFs at game speed, at 1x and 3x.

## THE TEN MOST IMPORTANT FINDINGS

Ranked by how much fixing them would improve the game, for the effort.

1. **Shots and bayonets point the wrong way.** The Musketeer and the Guardsman aim, fire and thrust to the east in the south, south-east and north-east views too. A line firing down the screen points its muskets sideways. The Officers are worse: aim and fire are one east-facing picture in all five views. These are the most common units and the most watched animation in a fight. Fix: one redraw sheet per unit (prompt A and B below). Pictures: `sheet_musketeer_idle_aim_fire_melee.png`, `musketeer_game_fire_x3.gif`, `sheet_officer_idle_aim_fire_death.png`.
   PARTLY FIXED in 0.14.63: the Musketeer now aims, fires and thrusts toward the south-east and the north-east (ChatGPT painted one direction per request over a pose guide, tools/musket_guide/aim_dirs.py; imported by tools/import_musket_aim_dirs.py). A first try asking for all five views in one sheet drew every row firing east again. Still to do the same way: the Musketeer's south, and the Guardsman's three.
2. **The Armoured Dragoon has only one view.** Its walk is the same three-quarter front gallop in every direction. In the north walk, frames 2 to 10 face the camera while it rides away. North-east is a copy of east, in walk, idle and death. Its death is the same picture in all views. Fix: redraw its walk in five views (prompt D). Picture: `sheet_armoured_dragoon_idle_walk_death.png`, `dragoon_armoured_game_walk_x3.gif`.
3. **The Officers are two different men.** Idle, aim, fire and death show the old narrow man with a white plume. Walk and melee show the new broad man. He changes body when he stops walking. Aim is one frame. The Officer's death is the same east picture in all five views. The Armoured Officer's death has two frames and starts already on the ground. Fix: redraw idle, aim, fire and death on the new man (prompt B).
4. **Deaths that skip the fall.** The riderless Horse starts its death already lying down (frame 1 is 27 px tall, its idle 45). The Armoured Officer and the Missionary start on the ground too. The Missionary has no north death, and its south-east death jumbles (lying, crumpled, standing, lying). The Balloon hangs whole in the air for four frames, then lies on the ground. A death is the moment a player watches most closely. Fix: three to five fall frames each (prompts B, C and F).
5. **Diagonal views that are copies.** Going diagonally shows the wrong drawing: the Field Cannon's walk is the same side view for south-east, east and north-east; the Powder Wagon's north-east is its east; the Cuirassier's walk north-east is its back view; the Dragoon's idle and death north-east are its east; the Horse's graze south-east is its south. Fix: draw the missing views (prompt G for the gun and wagon, the Cuirassier in prompt D).
6. **The Dragoon's horse trots in place.** In the east, south-east and north-east walk the hooves hardly move (the foot spread changes only 27 to 33 px), yet it rides at 112 px/s. Its south walk is a three-quarter right view. Its idle rider is drawn bigger than its walking rider (idle 51 to 56 px tall, walk 46 to 48), so he shrinks each time he moves. Fix: prompt D.
7. **The Missionary shrinks when he walks.** His idle is about 3 px taller than his walk in every view (36 against 33), and his east idle is a single frame. Fix: redraw his idle at the walk's size (prompt F).
8. **The Mounted Missionary's gallop.** It played at 8 fps, one stride in 1.1 s at 124 px/s: the horse slid six times its stride. Fixed (it now gallops like the Messenger). Its south walk is still a three-quarter right view, and its east walk frame 6 has a loose piece and frame 7 is a different rider. Fix: prompt E.
9. **Field Cannon and Mortar crews jump about.** The cannon's loader jumps from behind the gun to the muzzle when the reload starts. A horse appears in the death of a deployed gun, which had no horse. Turning to deploy, the gun spins through its front view. The Mortar's idle swapped the gunners from side to side twice a second (fixed). Fix: prompt G, and the ideas in the cannon section.
10. **The Musketeer's front walk is a shuffle.** Its walk has 3 frames in the south, 4 south-east, 6 east, 5 north-east and 7 north. At 12 fps the south stride lasts 0.25 s, and turning jumps the phase. The Musketeer's death east frame 3 has a loose lower leg lying apart from the body. Fix: prompt A.

### Fixed on this branch (`fix_crown.py` and `scripts/unit.gd`)

- **Officer and Armoured Officer walk hopped.** In the south and north walks whole frames were lifted 1 to 4 px, so the man hopped and jumped up when he started walking. Every frame now stands on the ground row, 33, like his idle. `fix_officer_walk_x3.gif`, `fix_armoured_officer_walk_x3.gif`.
- **Armoured Officer aim and fire floated.** They stood 1 to 2 px above his idle (south, east, north-east). Lowered. `fix_armoured_officer_fire_x3.gif`.
- **Horseman idle south-east floated.** The horse stood 3 to 4 px above every other south-east strip, so it bobbed up each time it stopped. Lowered by 3. `fix_horseman_idle_se_x3.gif`.
- **Messenger walk east had two or three riders in frames 4 and 5.** The sheet's figures touched, and the cut kept parts of the neighbours. Frames 4 and 5 are now the two whole riders of that cell, placed where frames 1 to 3 stand. The coat mask follows. `fix_messenger_walk_e_x3.gif`.
- **Mortar idle crew teleported.** Frame 2 drew both gunners on one side. At 2 fps the crew jumped from side to side twice a second. Frame 2 is now frame 1, the pose the deploy ends on. `fix_mortar_idle_x3.gif`.
- **A stray dash under the Musketeer's muzzle** in the fire-up east strip (3 px, both frames). Cleared. `fix_musketeer_fireup_speck_x3.gif`.
- **The Mounted Missionary galloped in slow motion.** Added to `Unit.GALLOPERS`, so its 9-frame gallop plays at 15.75 fps, one stride in 0.57 s, like the Messenger's. The animation viewer follows. `fix_mounted_missionary_gallop_speed_x3.gif` (the ground scrolls at its speed: watch the hooves).

The masks beside the strips (horse coat, veterancy trim) were moved with them. Tests run: `test_unit_walk_audit`, `test_west_views`, `test_anim_viewer`, `test_building_anim`, `test_mount_anim`, `test_horses`, `test_pistol`, `test_horse_care`. All pass.

What was not changed, and why: per-frame bobs of a gallop (horses do leave the ground), small 1 px islands that sit next to a barrel or a leg (gaps in the drawing, not dirt), explosion and soil debris, and anything that needs new drawing.

## Numbers that apply everywhere

- Walk speeds at full speed: the men on foot at 12 fps, the gallopers scaled so one stride takes 0.57 s, everything else at 8 fps. Idle at 2 fps. Attacks at 9 fps, deaths at 7 fps, once.
- The team colour: every Crown soldier has the key reds and they swap cleanly. The horse team has none, as it should. Near-misses (reds that look like team colour but stay red) are only in the Powder Wagon's flag and fire (up to 25 px in its death) and a few pixels in the horse team's harness. These are fine: they are fire and leather.
- No empty frames, and no frame counts that disagree with `art_data.gd`. Taller strips (aim up, fire north, melee) keep their extra room on top, and the game lines their feet up correctly.
- The west views are mirrors. That swaps hands: muskets, pistols and sabres are in the left hand facing west, and every belt, pouch and plume swaps side. Nothing has writing on it, so no text is reversed. Only the Clockwork's Clock Soldier has its own west views today. For the Crown it is not worth drawing west views until the attack views (finding 1) are right.

## Labourer

Good. This is the best-finished Crown unit after the earlier audits. Walk, carry and keg walks plant their feet on one row, every frame. The death is lively: the hat flies off and he falls flat. The hammering and the hoe read well.

Problems:

- The idle's 2 frames are nearly the same. It reads as a still picture.
- Switching from idle to hammering, the body drops 3 to 5 px. He crouches with no in-between.
- The keg death throws 15 to 26 small debris islands per view. That is the explosion, and it is meant.
- Mirrored west views put the hoe and hammer in his left hand.

To make better:

- (c) An idle fidget: wiping his brow or leaning on the hoe, 4 frames, played now and then. A "job done" stretch after a building finishes.

Picture: `sheet_labourer_idles_death_build.png`.

## Musketeer and Guardsman (musketeer, musketeer_armoured)

Good: the idle stands well. The reload in the east view (8 frames) is clear. The fire flash and smoke read at game size. The death starts from a standing pose, so the hand-over is clean. Aim up and fire up (at flyers) have room above and line up.

Problems:

- Finding 1: aim, fire and melee face east in the south, south-east and north-east views. Only north differs: the musket points straight up to fire north, and the north melee hides the musket behind his back, so no thrust can be seen.
- Finding 10: walk frame counts are 3, 4, 6, 5 and 7 by view. The south walk is a 0.25 s shuffle.
- Reload frame counts are 5, 5, 8, 6 and 3 by view. The game stretches each to 2 s, so the north reload holds each frame for 0.7 s.
- Idle to fire: the figure jumps 2 to 4 px (fire is drawn leaning in). Idle to aim jumps 2 to 4 px too.
- The death east frame 3 has a loose lower leg 5 px from the body (68 px island). Same for the Guardsman.
- The Guardsman's east idle holds the musket low across his body; every other view holds it upright.

(b) Redraw: prompt A.

(c) New life: a flinch when hit (2 frames, the body knocked back 1 px). A "present arms" when a volley ends.

Pictures: `sheet_musketeer_idle_aim_fire_melee.png`, `sheet_musketeer_reload_death.png`, `sheet_musketeer_aimup_fireup.png`, `sheet_guardsman_idle_aim_fire_melee.png`, `musketeer_game_fire_x3.gif`, `musketeer_game_melee_x3.gif`.

## Officer and Armoured Officer (dismounted, dismounted_armoured)

Good: the new walk (8 frames) and the new melee (4 frames, a bright sabre arc) are the best-drawn Crown soldier strips. After the fix, the walk stands on the ground.

Problems:

- Finding 3: two different men. Idle, aim, fire and death are the old man.
- Aim and fire: the same east picture in all five views (finding 1). Aim is 1 frame.
- The Officer's death: the same east picture in all five views. It is 5 frames and falls well.
- The Armoured Officer's death: 2 frames, 0.29 s, already on the ground in frame 1 (18 px tall, his idle 34).
- Idle to melee and back: the body jumps 8 px (the melee man is the bigger, new man).
- Even at 12 fps the walk slides about 1.8 times its stride (43 px a cycle, a step of 12 px).

(b) Redraw: prompt B.

(c) New life: the Officer points his sabre forward when he gives an order (2 frames), and raises it when his group wins a fight.

Pictures: `sheet_officer_idle_aim_fire_death.png`, `sheet_armoured_officer_idle_aim_fire_death.png`, `sheet_officer_walk_after.png`, `dismounted_game_fire_x3.gif`, `dismounted_game_death_x3.gif`.

## Horseman and Cuirassier

Good: the gallop is a real gallop in every view (8 to 10 frames). The sabre attack has a clear wind-up, a bright arc and a follow-through. The pistol has a flash and smoke. The mount strips are readable: the man walks to the horse, swings a leg over and settles. The deaths fall well, horse and rider together.

Problems:

- Horseman idle south-east floated 3 to 4 px (fixed). His north idle still stands 2 to 3 px high (62 to 63 against 65), but moving it would make the mount strip's last frame jump, so it was left.
- The Cuirassier's walk north-east is a copy of its north back view.
- The Cuirassier's east idle is a different, older drawing: a rider in a red coat on a dark horse with a red saddle cloth, not the steel rider of the other views.
- The pistol strips give both riders a red plume that their other strips lack.
- Idle to attack: 4 to 8 px jumps (the rider rises in his stirrups for the wind-up). That is fine.

(b) Redraw: the Cuirassier's north-east walk and east idle (prompt D).

(c) New life: the horse tosses its head and stamps in the idle (4 frames instead of 2). A rear on the charge.

Pictures: `sheet_cuirassier_idle_attack_pistol_death.png`, `sheet_horseman_idle_attack_pistol_death_before_fix.png`, `sheet_cuirassier_walk_horse_team.png`, `cuirassier_game_walk_x3.gif`, `sheet_mount_horseman_cuirassier.png`.

## Dragoon and Armoured Dragoon

Good: the light Dragoon's north and north-east walks are real back views. The deaths (5 frames) fall well. The mount strips are clean.

Problems:

- Finding 2: the Armoured Dragoon has one view.
- Finding 6: the light Dragoon's horse barely moves its legs. Its south walk is a three-quarter right view. Its idle rider is bigger than its walking rider.
- The light Dragoon's idle and death north-east are copies of east.
- Both walks: in most frames no hoof touches the ground row (median 2 to 6 px up), so the walking unit rides a little higher than it stands. The contact frames do reach the ground, so this was left.
- The Armoured Dragoon's idle in south-east, east and north-east lifts the whole horse 3 px every second frame.

(b) Redraw: prompt D.

Pictures: `sheet_dragoon_idle_walk_death.png`, `sheet_armoured_dragoon_idle_walk_death.png`, `dragoon_game_walk_x3.gif`, `dragoon_armoured_game_walk_x3.gif`.

## Messenger

Good: a light, quick rider. The death falls well.

Problems:

- Walk east frames 4 and 5 held two or three riders (fixed). The east gallop is now 5 frames, the other views 8 or 9.
- The south and north-east walks are drawn a little high in some frames (60 to 64 against 65).
- His idle is a different size per view: 52 px tall east, 55 south-east and north-east, 57 north, 60 south.

(b) Redraw: a full 8-frame east gallop (prompt D covers it).

Picture: `sheet_messenger_idle_walk_death_before_fix.png`, `fix_messenger_walk_e_x3.gif`.

## Horse (riderless)

Good: the walk is a real walk in every view. The graze reads.

Problems:

- Finding 4: the death starts already lying down. It is 3 frames, 0.43 s.
- The walk is played at 8 fps while the horse moves at 96 px/s. A 4-frame walk covers 48 px a cycle, about 1.8 times its stride. The horse walks while its speed is a canter.
- Graze south-east is a copy of graze south.
- The idle is a different height per view: 45 px south, 54 north-east.

(b) Redraw: prompt C (a canter and a fall).

Pictures: `sheet_horse_idle_walk_graze_death.png`, `horse_game_death_x3.gif`.

## Horse team (the gun and wagon horse)

Good: a heavy draught walk in every view. The harness and traces read.

Problems: one 1 px gap separates a hind leg in walk east frame 4 (invisible at game size). The east idle is a single frame. Nothing to fix.

(c) New life: a head toss in the idle.

## Field Cannon

Good: the crew of two in every view. The fire has a flash, recoil and smoke that thins out. The reload shows the loader ramming at the muzzle. The death is a wreck with smoke.

Problems:

- Walk: the same side-on limber picture for south-east, east and north-east (copies). The south walk has the horse under the gun.
- Deploy: the gun turns through its front view (frames 3 and 4) whatever way it faces, then snaps to its idle. The horse fades out as a checker dither.
- Fire to reload: the loader jumps from behind the gun to the muzzle in one frame. Reload south frames 1 and 2 are the same.
- The death of a deployed gun shows a dead horse that was not there.
- The idle is one frame: nothing moves while the gun waits.

(b) Redraw: prompt G.

(c) New life: the gunners shade their eyes and look out while idle (2 frames, now and then). A "fire!" arm signal by the gun captain before the shot.

Pictures: `sheet_cannon_idle_walk_fire.png`, `sheet_cannon_deploy_death.png`, `sheet_cannon_reload.png`, `cannon_game_deploy_x3.gif`, `cannon_game_reload_x3.gif`.

## Mortar

Good: the fire is a big, satisfying column of flame and smoke. The reload (13 frames) is clear: swab, powder, shell, ready. The towed walk is a real side-on team.

Problems:

- The idle crew swapped sides twice a second (fixed).
- Idle to fire: the crew stand in different places, so they jump 6 to 8 px.
- Reload frames 1 and 2 are the same in north-east and north; 11 and 12 in south-east.
- The walk south and south-east reach 9 to 10 px lower than the idle. That is the towing horse in front, not a jump.

(b) Redraw: prompt G.

Pictures: `sheet_mortar_idle_packed_fire_death_before_fix.png`, `sheet_mortar_walk_deploy.png`, `fix_mortar_idle_x3.gif`.

## Observation Balloon

Good: the envelope sways in the idle and drifts while it moves. The death has rips, falling debris and smoke on the ground.

Problems:

- The death hangs whole in the air for four frames, then the last frame lies on the ground. There is no fall.
- The idle north view changes height by 13 px over its 4 frames (132 to 145). It pulses rather than sways.
- The death smoke in north-east is cut by the top of the cell.

(b) Redraw: prompt C (the balloon part).

Pictures: `sheet_balloon_idle_drift_death.png`, `balloon_game_death_x3.gif`.

## Powder Wagon

Good: the horse walks, the wheels turn. The death is a fine explosion: fire, blast, burnt wreck.

Problems:

- North-east is a copy of east in every strip. Going up and right, the wagon faces down and right.
- Unload is a single frame per view.
- The wagon's feet are on row 76 in every strip, 7 px under its anchor (69). It is the same in every strip, so nothing jumps.

(b) Redraw: prompt G.

Picture: `sheet_powder_wagon.png`.

## Missionary (on foot, bandaging, mounted)

Good: the bandaging strips beside a fallen Horseman or Cuirassier read well: he kneels and works. The walk is steady.

Problems:

- Finding 7: the idle is about 3 px taller than the walk. The east idle is a single frame.
- Finding 4: the death has no fall, no north view, and the south-east frames are in a strange order.
- His own bandage strips are single frames; the north-east view is missing.
- Mounted: see finding 8. The mounted idle and death have the cross and hat.

(b) Redraw: prompts E and F.

Pictures: `sheet_missionary_idle_walk_bandage_death.png`, `sheet_missionary_bandage_dismounted.png`, `sheet_mounted_missionary_walk.png`, `missionary_game_death_x3.gif`.

## Crown buildings

### Construction states

Every Crown building has four stills: construction, built, damaged, destroyed. They read well and match each other. The scaffold picture fades from 55% to full while it is built, then pops to the finished building.

To make better: show the building rise. A cheap code idea: draw the built picture over the scaffold, revealed from the bottom up as the progress grows, so the walls climb inside the scaffold. A better art idea: a second scaffold stage (frame and roof beams, no tiles) for 50 to 100%.

Picture: `sheet_building_states.png`.

### Town Hall and Church: the bell

The bell swings in the belfry while the hall trains, 4 frames at 0.25 s. It reads. The Church's windows glow while a Missionary heals nearby, and a wisp of smoke rises. Both pass `test_building_anim`.

Pictures: `game_town_hall.png`, `game_church.png`.

### Barracks: the drills

The man being trained drills on the yard: the Musketeer aims, fires and reloads at the straw dummy; riders mount the wooden horse and swing; Dragoons climb on and off. The drills follow each unit's own strips, so they inherit the unit problems above: the Officers' drill uses the old Officer.

Problem: at the normal zoom the drilling man is about 10 px tall. The drill can only be read zoomed in.

Pictures: `game_drill_musketeer.png`, `game_drill_officer.png`, `game_barracks.png`.

### Horse Breeder: the paddock

Horses walk, stand and graze in the paddock in the coats being trained. It works, and the coats change with the queue.

Problem: the paddock horses use the riderless horse's walk at a slow pace, so its feet slide a little, as in the Horse section, but slowly enough not to show.

Pictures: `game_horse_breeder.png`, `game_coats_spotted_white.png`.

### Armoury: the experiments

Nine six-frame comic experiments on the roof, one per research. They are charming when zoomed in.

Problems:

- The patch of roof under the inventor is redrawn differently in every frame. Between two frames 100 to 300 of its pixels change, so the ground "boils" (this is the "patch wobble" on the owner's list). `armoury_bayonet_patch_boil_x4.gif`.
- The frames are tiny: 50 to 64 px wide, 41 to 73 px tall, and the inventor is about 12 px tall at game zoom. The gags (a hole in the breastplate, the burst pouch) cannot be read without zooming in.
- Frame heights differ by experiment (41 to 73 px tall), because each sheet was cut on its own. They all stand on the same roof spot, so it does not show.

To make better: one fixed ground patch pasted under every frame (cut once from the cleanest frame) would end the boil. It needs a small importer change in `tools/import_armoury_anims.py`, so it was left for the owner. Bigger smoke and flash effects in code would make each gag's beat read at game zoom.

Picture: `game_armoury_charge.png`.

### Farm, Powder Mill, smoke and fire

- The Farm's sails turn in 6 frames at 0.3 s. The loop is even: every frame overlaps the next by the same amount (0.39), so there is no hitch. They slow down and speed up with use.
- The Powder Mill's horse walks round its track, one lap in 7 s, walk frames at 7 fps, and eases in and out over 1.5 s. The runner stone turns with it. It reads well.
- Chimney smoke and the Foundry's fire are effects from `Building.IDLE_FX`, only while in use. Fire on a damaged building uses the shared fire effect. Nothing to fix.

## (b) Prompts for ChatGPT redraws

Each prompt stands alone. Attach the listed images (at most three). The layout matches the earlier redraw sheets in `art/redraws/` (look at `art/redraws/officer_melee.png`): one PNG, a flat dark navy background (#011430), a title band at the top and direction names down the left, then one row per direction, top to bottom south, south-east, east, north-east, north, frames left to right. Figures must not touch each other. No grid lines, hard pixel edges. The importer (written per sheet, like `tools/import_redraw_officers.py`) cuts the figures by the empty space between them, keys out the navy and shrinks them to the cell.

Style line in every prompt: "Pixel art, 17th to 18th century European soldiers, painted soft shading, dark outline, the same pixel scale and palette as the references, three-quarter top-down view like a classic RTS. Hard pixel edges, no anti-aliasing."

### Prompt A: Musketeer and Guardsman, firing and thrusting in every direction, and a 6-frame walk

Attach: `docs/shots/anim_audit_crown/sheet_musketeer_idle_aim_fire_melee.png`, `docs/shots/anim_audit_crown/sheet_guardsman_idle_aim_fire_melee.png`, `art/redraws/officer_melee.png` (for the sheet layout only).

"The first image shows a red-coated musketeer with a black tricorn hat, from five directions (rows: south, south-east, east, north-east, north). His aim, fire and bayonet poses face east in every row, so when he shoots toward the viewer he points sideways. Redraw them so he faces the row's direction: in the south row he points the musket at the viewer, in south-east down and to the right, in north-east up and to the right, in north away from the viewer with the musket visible past his shoulder. Make one sheet with these rows of frames for each direction: AIM 2 frames (musket rising, musket level at the shoulder), FIRE 2 frames (bright muzzle flash with a puff of grey smoke, then the smoke drifting off), BAYONET 3 frames (ready, thrust with the arms straight, recover), WALK 6 frames (contact, down, passing, contact with the other foot, down, passing), same man, same size in every frame, feet on one ground line, the musket on the shoulder in the walk. Then a second sheet, the same, for the Guardsman in the second image (steel helmet and breastplate over the red coat). Pixel art, 17th to 18th century European soldiers, painted soft shading, dark outline, the same pixel scale and palette as the references, three-quarter top-down view like a classic RTS. Hard pixel edges, no anti-aliasing. Flat dark navy background, direction names down the left, figures apart."

### Prompt B: Officer and Armoured Officer, idle, aim, fire and death on the new man

Attach: `docs/shots/anim_audit_crown/sheet_officer_walk_after.png`, `docs/shots/anim_audit_crown/sheet_officer_idle_aim_fire_death.png`, `art/redraws/armoured_officer_melee.png`.

"The first image is an officer on foot walking in five directions (rows: south, south-east, east, north-east, north): a broad man in a red coat and a brown tricorn. The second image shows his idle, aim, fire and death, but they are an older, narrower man with a white plume, and the aim, fire and death are the same east-facing picture in every row. Redraw them on the man of the first image, facing each row's direction: IDLE 2 frames (standing, a slight breath), AIM 2 frames (pistol raised toward the row's direction), FIRE 2 frames (flash and smoke, then the smoke drifting), DEATH 5 frames (hit, staggering, knees buckling, falling, lying flat). Same size as the walk in every frame, feet on one ground line. Then a second sheet, the same, for the armoured officer in the third image (steel helmet with a red crest, breastplate): his death must start standing and fall over 5 frames. Pixel art, 17th to 18th century European soldiers, painted soft shading, dark outline, the same pixel scale and palette as the references, three-quarter top-down view like a classic RTS. Hard pixel edges, no anti-aliasing. Flat dark navy background, direction names down the left, figures apart."

### Prompt C: the riderless horse's canter and fall, and the balloon's fall

Attach: `docs/shots/anim_audit_crown/sheet_horse_idle_walk_graze_death.png`, `docs/shots/anim_audit_crown/sheet_balloon_idle_drift_death.png`.

"The first image is a saddled dark horse with a red saddle cloth, from five directions (rows: south, south-east, east, north-east, north). Its death starts with the horse already lying down. Draw for each direction: CANTER 6 frames (a three-beat canter, the legs clearly reaching), DEATH 5 frames (hit and rearing back, legs buckling, falling on its side, lying, a last kick). Also a GRAZE row for the south-east, different from the south. Same horse, same size, hooves on one ground line. Second sheet: the red and cream striped observation balloon of the second image, with its basket and crew: DEATH 6 frames in each direction that FALL: the envelope rips and sags, the basket drops, the balloon sinks lower frame by frame, crashes and lies on the ground smoking (the last frame like the second image's last frame). Leave room above for the smoke. Pixel art, painted soft shading, dark outline, the same pixel scale and palette as the references, three-quarter top-down view like a classic RTS. Hard pixel edges, no anti-aliasing. Flat dark navy background, direction names down the left, figures apart."

### Prompt D: cavalry views (Armoured Dragoon, Dragoon, Cuirassier, Messenger)

Attach: `docs/shots/anim_audit_crown/sheet_armoured_dragoon_idle_walk_death.png`, `docs/shots/anim_audit_crown/sheet_dragoon_idle_walk_death.png`, `art/redraws/mounted_walk_C.png`.

"The first image is an armoured dragoon (steel helmet, red coat, musket) on a dark horse. Its gallop is the same three-quarter front view in every row, even going north. Draw a real gallop for each direction (rows: south toward the viewer, south-east, east side-on, north-east from behind and to the right, north from behind), 8 frames each: the legs reaching far forward and back, a moment with all hooves off the ground, the rider rising and falling with the horse. Same rider and horse size in every frame and every row, hooves on one ground line. Then a second sheet, the same, for the light dragoon of the second image (red coat, tricorn), whose horse barely moves its legs now, with also an IDLE row of 2 frames for each direction at the same size as its gallop (its idle rider is drawn bigger today). Then, if possible, a third sheet: a north-east gallop and an east idle for a cuirassier (steel helmet and cuirass over a red coat, dark horse), and an 8-frame east gallop for a messenger (brown hat, red coat, saddlebags). Pixel art, painted soft shading, dark outline, the same pixel scale and palette as the references, three-quarter top-down view like a classic RTS. Hard pixel edges, no anti-aliasing. Flat dark navy background, direction names down the left, figures apart."

### Prompt E: the Mounted Missionary's gallop

Attach: `docs/shots/anim_audit_crown/sheet_mounted_missionary_walk.png`, `docs/shots/anim_audit_crown/sheet_messenger_idle_walk_death_before_fix.png`.

"The first image is a missionary in a black coat and hat, holding a wooden cross, riding a grey horse with a red saddle cloth, in five directions (rows: south, south-east, east, north-east, north). The south row is a three-quarter right view instead of coming toward the viewer, and the east row has a loose piece in frame 6 and a different rider in frame 7. Redraw the gallop, 8 frames for each direction, like the messenger's gallop in the second image: south toward the viewer, south-east, east side-on, north-east from behind and to the right, north from behind. Same man, cross and horse in every frame, same size, hooves on one ground line. Pixel art, painted soft shading, dark outline, the same pixel scale and palette as the references, three-quarter top-down view like a classic RTS. Hard pixel edges, no anti-aliasing. Flat dark navy background, direction names down the left, figures apart."

### Prompt F: the Missionary on foot, idle and death

Attach: `docs/shots/anim_audit_crown/sheet_missionary_idle_walk_bandage_death.png`.

"The image shows a missionary in a long black coat, black hat, red stole and a satchel, in five directions (rows: south, south-east, east, north-east, north). His idle is drawn bigger than his walk, the east idle is one frame, and his death starts lying down. Redraw for each direction: IDLE 2 frames at exactly the size of the walk (a breath, the hand on the satchel), DEATH 4 frames (hit, sinking to his knees, falling forward, lying flat with the hat beside him), and a BANDAGE row for the north-east (kneeling, working on a bandage, 3 frames). Pixel art, painted soft shading, dark outline, the same pixel scale and palette as the reference, three-quarter top-down view like a classic RTS. Hard pixel edges, no anti-aliasing. Flat dark navy background, direction names down the left, figures apart."

### Prompt G: guns and the wagon, the missing diagonal views

Attach: `docs/shots/anim_audit_crown/sheet_cannon_idle_walk_fire.png`, `docs/shots/anim_audit_crown/sheet_powder_wagon.png`, `docs/shots/anim_audit_crown/sheet_cannon_deploy_death.png`.

"The first image is a bronze field cannon on a wooden carriage, towed by a dark horse with two gunners in red coats and steel helmets. Its towed walk is the same side-on picture for south-east, east and north-east. Draw the towed WALK, 4 frames, for south-east (coming down and to the right) and north-east (going up and to the right), same horse, gun and men, same size as the east row. Also a DEATH of the gun without its horse (it is unhitched when firing), 3 frames for each direction: a shot hits, the carriage breaks, the wreck smokes, the two gunners lying. Second, the covered powder wagon of the second image: its north-east row is a copy of east. Draw the wagon going up and to the right (seen from behind and to the right), WALK 6 frames and IDLE 2 frames, same horse and size. Pixel art, painted soft shading, dark outline, the same pixel scale and palette as the references, three-quarter top-down view like a classic RTS. Hard pixel edges, no anti-aliasing. Flat dark navy background, direction names down the left, figures apart."

## (c) New animations that would add the most life

1. **A hit flinch for the men on foot** (Musketeer, Guardsman, Officers, Labourer): 2 frames per view, the body knocked back and the head turned. The game would play it for 0.15 s when a unit takes a hit and is not attacking. Needs: the strips, an `_anim_name` case on a short timer after damage. Biggest readability gain in a fight: you would see who is being hit.
2. **Idle fidgets**: a Musketeer checks his musket's lock, an Officer adjusts his hat, a horse tosses its head, the cannon crew looks out. 4 frames, played once every 6 to 12 s at random instead of the 2-frame breath. Needs: the strips, and a random "fidget" phase in the idle.
3. **A victory pose** for the end of a fight: muskets raised, the Officer's sabre up, riders' horses rearing. 3 frames, played when no enemy is in sight after a kill. Needs: the strips and a short timer after the last kill.
4. **A real construction rise** (see Construction states): the built picture revealed bottom-up over the scaffold. Needs only code.
5. **A fire command for guns**: the gun captain raises an arm before the shot. 2 frames inserted before `fire`. Makes the cannon's wind-up readable.
