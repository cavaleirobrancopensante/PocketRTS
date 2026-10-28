# Black powder smoke (0.14.94, branch powder-smoke)

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
- The cap: 720 puffs alive on FULL, 260 on LIGHT.
  Past 80 percent of the cap, the oldest puffs age twelve times faster, so they fade out in a second or two instead of vanishing at once.
  If the cap is still hit, the newest puff takes the oldest one's place.
- The puffs move and are redrawn 20 times a second on FULL, 12 on LIGHT. They move only a few pixels a second, so this is smooth.

## The setting

Settings has a new row: POWDER SMOKE, with OFF, LIGHT and FULL.
It starts on FULL on a computer.
It starts on LIGHT on a phone and in the browser, because the web build draws with the slower renderer.
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
