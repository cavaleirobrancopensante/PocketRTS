# Black powder smoke (0.14.99, branch powder-smoke; THICK added on merge)

The owner asked, on 2026-10-27: "Can we have more smoke in the game? Black powder smoke: a bit more from every shot,
and it stays on the battlefield a bit, vanishing slowly. No mechanical consequences, but aesthetically pleasing."

## What it looks like

Every black powder shot leaves smoke on the field.
The muzzle flash and its quick puff are still there, as before.
On top of them, the shot now leaves a few grey-white puffs that stay.
They drift slowly on a light wind.
They grow, thin out, and fade away over ten to twenty-four seconds.
A cannon's cloud is bigger and lasts longest.
So a long firefight builds a haze over the firing lines.
When the shooting stops, the haze clears slowly.

Pictures are in docs/shots/powder_smoke/.
Two lines of fourteen Musketeers and a Field Cannon fire for twenty seconds, then the enemy line is gone.
0_before, 2_fire_10s and 3_fire_20s show the haze building up.
5_fire_20s_hud is the same moment with the interface, the men selected and their health bars showing.
6_after_5s, 7_after_10s and 8_after_20s show it clearing.
powder_smoke.gif is all of it, at four times the speed.

## What makes smoke

- A Musketeer's or Guardsman's musket. A Dragoon fires on foot, so his shots count as a Musketeer's.
- Musketeers firing from a balloon.
- A Horseman's pistol.
- A shot that flies wide into a Mist Toad's fog, from any of these.
- A Field Cannon: round shot and canister.
- A Mortar firing, and its shell bursting where it lands.
- A powder keg or a Powder Wagon going up. A Powder Wagon makes the biggest cloud.

The Clockwork and the Brood fire no powder, so they make no smoke.
Their rifles are electric, their springers fire bolts, the Brood spits acid.
The Clockwork's Heavy Locomotive gun keeps only its old small puff.
It is a steam engine's gun, so I left it alone.

## How it stays fair and readable

It is only for the look. It changes nothing in a fight.
It does not block sight, fog or shots.
It never touches the game's random numbers. It has its own.
A whole computer match plays out exactly the same with the smoke off and on.
The test checks this every ten seconds of a seven-minute Crown against Crown match.

The smoke is drawn in two layers.
The thick layer lies under the units and buildings, like haze on the ground.
A thin veil, a third of the puffs at half strength, lies over them.
Units stay clearly visible through it.
Health bars, selection rings and the orders stay readable.
The veil does sit over the health bars too, very faintly. You can see it in 5_fire_20s_hud: the bars read fine.
Effects, the overlay with the orders, the fog of war and the interface are all drawn over the smoke.

You only see smoke where your side sees the ground right now.
A shot fired out of your sight makes no smoke for you.
A puff that drifts out of your sight fades out.
Watching the computers, it follows whoever's eyes you watch through.

## The numbers

- Puffs per shot, on FULL: a musket 3, a cannon 7, canister 8, a Mortar 5, its shell 3, a keg 8, a Powder Wagon 16.
- On LIGHT: a musket 1, a cannon 3, canister 3, a Mortar 2, a shell 1, a keg 3, a Powder Wagon 6.
- Lives: a musket's puffs 10 to 16 seconds, a cannon's 16 to 24, a Powder Wagon's 17 to 24. On LIGHT, about two thirds of that.
- Size: a musket's puff starts about 16 pixels wide and grows to about 80. A cannon's grows to about 120.
- How solid: at most about half see-through where one puff lies. It stays thick for a while, then fades slowly.
- The wind: about 4 to 8 pixels a second, one wind for the whole field. It turns slowly over the match, about half a turn in several minutes.
- A shot's puffs are first pushed forward along the shot, then hang and drift.
- The cap: 720 puffs alive on FULL, 260 on LIGHT, 960 on THICK.
  Past 80 percent of the cap, the oldest puffs age three times faster (twelve before 0.24.2).
  If the cap is still hit, a new puff is not made: a live puff is never overwritten (before 0.24.2 the oldest vanished).
- Dense clouds (0.24.2): see "Clippy, blinky and too long" at the end.
- The puffs move and are redrawn 20 times a second on FULL, 12 on LIGHT. They move only a few pixels a second, so this is smooth.

## The setting

Settings has a new row: POWDER SMOKE, with OFF, LIGHT, FULL and THICK (experiment).
It starts on THICK on every platform for now (see THICK below).
Before THICK, it started on FULL on a computer and on LIGHT on a phone and in the browser.
Once you press it, your choice is saved.
It applies from the next match.
It is translated: FUMAÇA DE PÓLVORA in Portuguese, HUMO DE PÓLVORA in Spanish.

## Online and replays

The host sends each shot's smoke to the guests as an effect named "powder:" and the kind.
The replay records it the same way.
Each player then draws it with their own setting and their own fog.
An older version that does not know it simply drops it.
A replay jump clears the smoke from the time before.
Smoke takes only the room left over in each network update, after shots and blows.

## What it costs

All puffs are drawn in two MultiMesh nodes: two draw calls, whatever the number of puffs.
Nothing is made per puff, and nothing is allocated each frame.
Puffs out of the camera's view are not drawn.

I measured a big Crown against Crown battle: 32 Musketeers and 3 Field Cannons a side, all firing for a minute, all in view.
Tool: tools/bench_powder_smoke.gd. That is about 2,250 puffs made and up to 660 alive at once.

- The game's side, without drawing (headless): 3.02 milliseconds a frame without smoke, 3.18 with it.
  The smoke's own work is about 0.25 milliseconds a frame on FULL, and 0.06 on LIGHT.
- With drawing: this cloud machine has no graphics card, so it draws in software, which is very slow at see-through pictures.
  There a frame took 55 milliseconds without smoke, 62 on LIGHT, and 74 on FULL.
  On a real graphics card that drawing is a tiny job. On a phone it is a small one, and phones start on LIGHT.
- The match log's performance line now says how many smoke puffs are alive.
  Its "busy with" list shows the smoke's time as "powder smoke".
  So a playtest log will show if it ever costs too much.

## Tests

- tools/test_powder_smoke.gd: shots make puffs, they drift, they fade and are removed, the cap holds and the oldest fade early,
  no smoke where your side does not see, a puff drifting out of sight fades out, the game's random numbers are untouched,
  OFF makes none, LIGHT makes fewer, the Clockwork and Brood make none, and a guest gets the host's smoke.
  Then it plays a seven-minute computer match twice, with the smoke OFF and FULL, and checks the state hash is the same every ten seconds.
  It mutes the sounds and lifts the path time limit, as tools/perf_bench.gd does. Without that, two runs differ anyway.
- tools/test_replay.gd and tools/test_files.gd pass.
- tools/test_determinism.gd: on this machine two runs of it already differ on main, before any smoke.
  The sounds draw from the game's random numbers by the wall clock.
  That is not the smoke, so the smoke test uses the muted way instead.

## Tools

- tools/shot_powder_smoke.gd films the two lines firing and the haze clearing.
- tools/powder_smoke_gif.py makes the GIF from its frames.
- tools/bench_powder_smoke.gd measures the cost.

## What is left

- The puffs are the painted muzzle smoke, scaled up and softened in code. Painted soft smoke puffs would look better.
  This is noted in docs/art_style_inconsistency.md.
- The veil over the units also lies faintly over the health bars.
  Moving every unit's health bar to its own layer would fix that, but it touches every unit's drawing, so I left it.
- The wind is the same for every match on a map. It could follow a map's own weather one day.
- It has not been tried on a real phone. If LIGHT is still slow there, its cap can go lower.

## THICK (experiment, 0.14.99)

The owner, on 2026-10-27, after the job started:
"Let's try drawing over everything; it could be interesting to make the smoke a bit annoying, as an experiment."

So there is a fourth value, THICK (experiment). In Portuguese ESPESSA (experimento), in Spanish ESPESA (experimento).

- It is drawn over everything on the field: the units, the buildings, the health bars, the selection rings, the order lines, the effects and the fog.
  It is still under the interface, the minimap and the menus, because those are drawn on their own layers above the world.
- It is one layer only, at z 60. The fog is at 40 and the overlay with the rings and orders at 50.
  There is no haze under the units and no veil: the one layer covers both jobs.
- It is a third denser: a musket 4 puffs, a cannon 9, canister 11, a Mortar 7, its shell 4, a keg 11, a Powder Wagon 21.
- The puffs live a quarter longer: a musket's about 12 to 20 seconds, a cannon's 20 to 30.
- They are 15 percent more solid.
- The cap is 960 puffs alive, and they move 20 times a second, as on FULL.
- It is the default for now, on a computer, a phone and in the browser.
  A player who never pressed the setting gets THICK. A choice someone saved stays as saved.
- To go back: Settings, POWDER SMOKE, press until it says FULL.

It is still only for the look.
It never changes what your side sees: fog, vision, shots and the game's random numbers are untouched.
The smoke test plays the seven-minute match with the smoke OFF, FULL and THICK and checks the state hash is the same every ten seconds.

Because it lies over the fog too, a puff right at the edge of your sight can lie a little over the dark.
It only ever shows where your side saw the ground, and it fades out as it drifts out of sight, so it tells nothing new.

Pictures: docs/shots/powder_smoke/thick/, the same scene as FULL: the two lines of fourteen Musketeers and a cannon.
- full_vs_thick_20s.jpg and full_vs_thick_20s_selected.jpg: FULL on the left, THICK on the right, after twenty seconds of fire, freshly filmed the same way.
  On THICK the enemy line and its health bars are almost hidden, and the smoke lies over your own selection rings where it drifts.
- 2_fire_10s, 3_fire_20s, 4_fire_20s_selected, 5_fire_20s_hud (with the interface over the smoke), 6_after_5s, 7_after_10s, 8_after_20s.
- powder_smoke_thick.gif: all of it at four times the speed. The FULL GIF is ../powder_smoke.gif.

What THICK costs, with tools/bench_powder_smoke.gd (32 Musketeers and 3 Field Cannons a side, a minute of fire, all in view):

- The smoke's own work: 0.22 milliseconds a frame on THICK, 0.19 on FULL. Up to 909 puffs alive on THICK, 660 on FULL.
- Without drawing (headless): 2.37 milliseconds a frame on THICK, 2.25 on FULL.
- With drawing, on this machine's slow software renderer: 81 milliseconds a frame on THICK, 82 on FULL, 60 with no smoke.
  THICK draws about as much as FULL: it has more puffs, but one layer instead of the haze and the veil.
- On a phone this is more than LIGHT was. If a phone playtest shows it slow, THICK's cap (960) can go lower, or the default can go back to LIGHT on phones.

## Clippy, blinky and too long (0.24.2, branch powder-smoke)

The owner played 0.24.1 (Crown against Clockwork, THICK) and said:
"currently the gunpowder fog is too buggy, its clippy and blinky, and it takes too long to dissipate maybe its because a lot was fired at once with multiple volleys, and yes, it should linger longer, but something is off with that animation".
His match log had up to 326 puffs at once, with 30+ Musketeers and 4 Field Cannons firing volleys.

### What was wrong

1. Clippy: square edges. The puffs are the painted muzzle smoke frames (27 by 25 pixels), grown four to five times.
   The painted smoke touches the edges of its frames (frame 1 on three sides).
   So a grown puff showed straight, cut-off edges, and the next frame of the atlas could bleed in as a thin line.
2. Clippy: popping at the screen's edge. A puff was drawn only while its centre was inside the view (plus 120 px).
   A THICK puff grows to about 140 px wide, so at the edges it could still pop in and out while scrolling. The margin is now bigger.
3. Blinky: sudden vanishing. Past 80 percent of the cap the oldest puffs aged twelve times faster, gone in about a second,
   and the set of "oldest" changed tick to tick, so the old haze collapsed in jerks. At the cap a new puff simply overwrote the oldest one: it vanished in one frame.
4. Blinky: new puffs popping in. A puff faded in over a sixth of a second. A volley of 120 puffs landing on a cloud flashed in.
5. Too long, and a wall: every puff kept its full strength however many others lay on it.
   Volley after volley stacked into a solid white wall (up to 15 puffs' worth of alpha on one 64 px square).
   All puffs of a volley also age together, so the wall stayed solid for most of its life, then thinned all at once.

### What changed

- The shader fades each puff to nothing in a soft circle (from 28 to 50 percent of its width) and keeps its texture lookups inside the frame. No square edges, no lines.
- Puffs are culled with a 230 px margin (the view's 120 plus 110), more than a grown puff's reach.
- A puff fades in over 0.6 s (smoothstep).
- No puff ever vanishes while it shows: near the cap the oldest age 3 times faster (still smooth), and when the ring's oldest slot is still alive, a new puff is not made.
- Dense clouds merge. The field is cut into 96 px squares and the puffs in each are counted every tick.
  - Past 8 puffs in a square, each puff there is drawn thinner: 8 / count, never under 30 percent, smoothed at 0.7 a second so it never jumps.
  - Past 8 puffs it also ages faster: 30 percent faster per 8 puffs more, at most 2.2 times. A heavy cloud thins steadily, and the last thin wisps linger at the normal pace.
  - Past 22 puffs in a square, a new shot's puffs merge into the cloud: only 22 / count of them are made. The cloud is fed while the line fires, but not piled higher.
- The cost is the same or a little lower: fewer puffs, a little more work each.

### The numbers

The 30-Musketeer volley: tools/shot_powder_volley.gd, 30 Musketeers and 4 Field Cannons fire at a line of dummies for 12 s, then stop (THICK, the default).
"Peak" is the most smoke over one 64 px square, as the drawn puffs' alpha summed. About 1 reads as a light haze, 3 to 5 as thick smoke, 15 as a solid wall.

| | before (0.24.1) | after (0.24.2) |
|---|---|---|
| puffs made | 595 | 496 |
| most alive | 566 | 338 |
| peak while firing | 15.6 | 4.8 |
| peak at 17 s (they have just stopped) | 12.1 | 4.5 |
| peak at 25 s | 6.1 | 3.1 |
| peak under 1 | at 38 s | at 35 s |
| puffs left at 42 s | 9 | 2 |

(The men fire on until about 17 s: their last shots were already loaded.)
So the smoke still lingers about as long (he wants it to linger), but as a haze you can see the men through, thinning steadily, not a white wall.

Pictures: docs/shots/powder_smoke/volley_before/ and volley_after/: v1 to v4 are 0.5 s apart from the first volley, v5 and v6 at 6 and 12 s of fire, v7 to v11 at 5, 10, 15, 20 and 30 s after.
volley_before_after.jpg puts them side by side: before on the left, after on the right.

The test (tools/test_powder_smoke.gd, its "volley" part, ticked by hand at 20 Hz on THICK): six volleys of 30 muskets and 4 cannons, 2.5 s apart.
- No puff's alpha changes by more than 0.10 between two ticks (measured 0.092: a puff fading in).
- No puff is removed while it still shows more than 0.01 (measured 0.002).
- The most smoke on one 64 px square while firing stays under 8 (measured 5.7).
- 5 s after the last volley it still lingers (2.6).
- It is under 1 within 16 s of the last volley (12.2 s) and gone within 30 s (22.7 s).
- A hundred Powder Wagons at one spot make 501 puffs, not 1,600; the cap holds without overwriting; the match still plays out the same with the smoke off, FULL and THICK.
- `-- quick` skips the three seven-minute matches.

What it costs (tools/bench_powder_smoke.gd, THICK, headless, on a busy cloud machine): the smoke's own work 0.84 ms a frame after, 0.87 before;
peak 660 puffs alive after, 932 before. (The machine was shared, so the totals per frame are noisy; the smoke's share is what to compare.)

### Still open

- Only THICK was filmed; FULL and LIGHT use the same rules (LIGHT rarely gets dense).
- The puffs are still the painted muzzle smoke, softened; a painted soft puff would be better (docs/art_style_inconsistency.md).
