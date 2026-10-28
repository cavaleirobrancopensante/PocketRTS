# Ride-by: the Horseman and the Cuirassier attack on the move (0.14.96)

The owner asked for this on 2026-10-27.
A harassment unit with no splash that must stop to swing is useless.
So the sabre riders now fight like the Cyclone in StarCraft 2, but with a sabre.
This is the Horseman and the Cuirassier (Defs.UNITS "cuirassier", light and armoured).
It is not the Dragoon, and not the Officers on foot.

## What changed

- On any order, a rider in the saddle strikes as he rides past.
  The orders are move, attack-move, attack, patrol and follow.
  The computer's hunts and raids give these orders too.
- He strikes any enemy within sabre reach, on his normal cooldown.
  He never slows down and never stops to swing.
- On a plain move he still goes where you sent him.
  He cuts down what he passes on the way.
- On an attack-move he picks targets on his way, as before.
- On an attack order he rides AT the target.
  He strikes in passing, rides on a little past it, and swings round its far end.
  The next pass comes back along its other side.
  So he loops round the target, like a racetrack, instead of standing beside it.
- On an attack order he only strikes that target.
  On a move or an attack-move he strikes whoever is in reach.
- A man on the run is ridden down.
  The rider aims where the man will be, catches him, strikes, and loops back.
- A building gets the same loops, along its sides and round its corners.
- His one pistol shot is fired from the gallop too.
  He takes aim a little before he is in reach, so it goes off near full reach.
  He fires it on an attack or an attack-move. A plain move keeps it.
- On HOLD POSITION he stands and fights as before. No loops.
- Stopped, standing idle on guard, he also stands and fights as before.
  Told to stop, he stops.
- A wall or a gate is still hacked at standing. A horse can't ride through a wall.
- The Dragoon is unchanged. He still dismounts to fire.

## The Cavalry Charge

- The charge bonus stays on the first blow after a run. It is not on every pass.
- A run only counts after five seconds with no blow (Defs.RIDE_BY "calm").
- Then two seconds at the gallop make the charge (Defs.CHARGE "run", as before).
- In the test: the first blow hit 36, every pass after it hit 18.
- After a lull and a new run, the next first blow hit 36 again.

## The numbers (Defs.RIDE_BY)

- hit: 1.0. The move-hit's damage multiplier. Full damage, as the Cyclone fires at full damage.
  This is the knob to turn if riding by is too strong or too weak.
- side: 8 px. He passes this far beside the target's edge. His sabre reaches 26.
- commit: 56 px. From this close he rides straight through the pass.
- over: 45 px, out_max: 0.7 s. He rides on this far past before he turns.
- turn: 4.4 radians a second. His turning circle is about 25 px.
- near: 260 px. Farther than this, the pathing brings him in, as before.
- calm: 5 s. The charge rule above.
- slash: 0.24 s. How long the drawn sabre arc lasts.
- Against one target, a pass comes about every 1.5 to 2 seconds.
  Standing, he struck every 1.1 seconds. So one target takes a little longer to kill.
  In exchange he never stands still, and a crowd gets cut from every side.

## The raid test, before and after

tools/test_ride_by_raid.gd plays each case twice on the same open ground.
First with the old standing fight, then on the move.
Four Horsemen attack-move onto the defenders. Thirty or forty seconds.
The numbers move a little from run to run.

| case | before (standing) | after (on the move) |
|---|---|---|
| 8 Labourers at work | all 8 dead, half by 5.5 s | all 8 dead, half by 5.1 s |
| 8 grubs at work | all 8, half by 5.7 s | all 8, half by 5.9 s |
| 8 Winders at work | only 2 dead in 30 s | all 8, half by 7.8 s |
| 8 Labourers who run away | all 8, half by 10.5 s | 6 to 8, half by 8.6 to 9.2 s |
| 8 Labourers who fight back | all 8, riders keep 84% health | all 8, riders keep 87% |
| 8 grubs who fight back | all 8, riders keep 88% | all 8, riders keep 88% |
| 8 Winders who fight back | all 8, riders keep 87% | all 8, riders keep 91% |
| 5 Musketeers on HOLD | all 5 dead, riders keep 74% | all 5 dead, riders keep 66% |
| 6 Raptors | all 6, riders keep 96% | all 6, riders keep 96% |
| 5 Clock Soldiers | all 5, riders keep 96% | all 5, riders keep 96% |
| 6 Labourers in a palisade ring | half dead at 21.1 s | half dead at 20.4 s |

What it means:
- Against a worker line, the raid is about as deadly as before.
- Workers who run away are caught a little sooner.
- Workers who fight back still cost the riders about as much.
- Musketeers cost the riders a bit more than before. Riding round them takes fire from every side.
- A palisade ring holds them off as long as before. They still hack at the wall standing.
- The big change is the Clockwork's Winders.
  Before, four standing Horsemen killed only two of eight Winders in thirty seconds.
  The other Winders kept repairing the one being hit.
  Riding by spreads the blows over many Winders, and all eight die.
  Please look at this one. It may want a fix on the repair side.
- Four Horsemen beat five Musketeers on HOLD in the open, before and after.
  That was already so. A wall plus Musketeers is the answer, as in the design principles.

## The computer

- Its Horseman rush, raids and attack waves use the new fight by themselves.
  They give move, attack-move and attack orders, and those ride by.
- One small hook in scripts/ai.gd: AI._party_prey.
  Riders hunting together now ride down the same worker.
  Each going for his own nearest worker split the party apart in loops.
- tools/test_ai_rush_followup.gd: the same results as main.
  Its two "mop" checks fail on main too.

## Online, replays, saves

- Everything runs on the game clock and the units' own state. Nothing random.
- tools/test_ride_by.gd runs the same fight in two separate game processes.
  The two rides match to the frame.
- The host simulates. A new field, ride_n, counts the blows struck in passing.
  It is streamed like the other unit fields, so a guest and a replay draw the sabre arc.
- Old replays still play: the replay player fills a missing field with its default.
- Saves keep the rider's side, heading and charge clock. Saves keep no attack order, as before.
- tools/test_determinism.gd still differs between two runs, on main too.
  On main it split at 40 s, on this branch at 30 s, both before any Horseman is out.
  That is the old match determinism problem in docs/pathfinding_audit.md, not this change.

## The pictures (docs/shots/ride_by/)

- sheet_worker_line.png: three Horsemen ride through a line of Labourers on a plain move, slashing as they pass.
- worker_02.png and worker_04.png: two of those frames, full size.
- sheet_cannon_loops.png: a Cuirassier told to attack a Cannon, pass after pass.
  His track is drawn in yellow, a red mark where each blow landed.
- cannon_04.png: one pass, full size, with the sabre arc.
- cannon_track.png: the whole track after twelve seconds. Nine passes round the gun.
- Made by tools/shot_ride_by.gd. Run it again to film new ones.

## The art

- The painted attack strip stands the horse still. So on the move it isn't used.
- He keeps galloping, and a sabre arc is drawn in code across his front.
  Forehand and backhand in turn.
- The pistol from the gallop shows the usual flash and smoke.
- This is logged in docs/art_style_inconsistency.md.
  Wanted: a painted slash at the gallop, and a pistol at the gallop.

## Tests

- tools/test_ride_by.gd: a move past enemies hits them without slowing.
  An attack makes passes all round the target, never standing.
  A fleeing man is ridden down. A building gets passes.
  The pistol is fired at the gallop. The charge is only on the first blow after a run.
  HOLD and standing on guard fight as before. The Dragoon is unchanged.
  Save and load keep the ride's state. Two processes ride the same fight.
- tools/test_ride_by_raid.gd: the raid table above.
- tools/test_pistol.gd: now checks the shot is fired from the gallop, not the old pistol strip.
- tools/test_ai_army_response.gd: the computer of slot 0 is switched off.
  It kept sending the test's parked raider on attack-moves into the defenders.
  Riding loops through them, he pulled more defenders than a parked horseman should.
- Also run, same results as main: test_hold_fire, test_horses, test_ai_rush, test_ai_wall_vs_rush,
  test_ai_worker_safety, test_ai_brood_horse (3 fails on main too), test_mount_anim, test_files, test_horse_care,
  test_horse_deliver, test_horse_vanish, test_loose_horses, test_attack_ground, test_ground_attack, test_pathing,
  test_replay, test_i18n, tools/test_online.sh (host and guest ALL OK) and tools/bench_net_snapshot.gd (the
  streamed field lists match).

## What is left

- The Winders and the repair. See the raid table.
- A painted "slash at the gallop" strip, and a "pistol at the gallop" one, to replace the drawn arc.
- Standing idle on guard he still fights standing. If the owner wants him to ride loops on guard too,
  add "idle" to RideBy.ORDERS. It pulled more defenders after him in the army-response test.
- The damage knob, Defs.RIDE_BY "hit", is 1.0. Turn it down if riding by turns out too strong in play.
