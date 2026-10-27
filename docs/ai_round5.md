# AI round 5: the Crown against the new Clockwork, the Clockwork against Horsemen

Version 0.14.88, branch `ai-round5`. Written to be read aloud.

## Status: BLOCKED, not yet played

This run had no Godot. The task said Godot is at /home/claude/godot. It was not there.
Downloading Godot 4.7 from GitHub was refused by the session's safety check, and the Nix mirror is blocked by the proxy.
So no game, no test and no screenshot was run.
The code is written and checked for syntax only (gdtoolkit's gdparse on both scripts).
Do not merge it before the checks at the end of this page are run.

## Where the code is

All the new rules are in one file, `scripts/ai_round5.gd` (class AIRound5, one per AI, `ai.r5`).
`scripts/ai.gd` only calls it, at about twenty marked hooks (search for `r5.`).
Each hook is a no-op unless round 5 applies: the Crown parts only when the Crown faces a Clockwork enemy, the Clockwork parts only for the Clockwork.
The Crown against the Brood is untouched, so the Brood games should not change.
`ai.r5.on = false` switches all of it off, for "before" numbers in tests.
No unit, building or cost number changed. No new random numbers are drawn, so runs stay as repeatable as before.

## The evidence

The owner, as the Crown, beat the Hard Clockwork easily: 32 to 47 Musketeers, 2 or 3 Field Cannons and a Powder Wagon by 10 to 13 minutes, his ramp walled, 36 to 45 Labourers.
The Crown computer lost 6 of 8 games to the same Clockwork computer.
At 8:00 it had 40 workers but only 12 Musketeers. Its money went on idle horses, a Missionary and Officers.
Its army stood outside its walls and died. Its low-ground expansion fell at 9:34.
Its first attack went out at 7:37 with 16 supply, just before the Clockwork's 40-supply wave.
Before the Clockwork rewrite it won about 6 of 8.

## Part A: the Crown computer against the Clockwork

1. Labourers. From 4:00, with 24 or more, no new Labourer while the army's supply is under 80% of the Labourers. Never more than 42. (`hold_labourers`)
2. Horsemen. Two at most, for scouting and picking off Winders. The rest of the Barracks' time goes on Musketeers. A Horseman rush keeps its own rule. (`horsemen_cap`)
3. Horses. A Foundry keeps one horse standing by, and only while a gun or the wagon is wanted or queued. No spare horse at the breeders. Riders still get their horse when they are trained. (`foundry_horses`, `spare_horses`)
4. Missionaries. One at most. (`missionary_ok`)
5. Behind the wall. When enemies come to the outside of the ramp wall and they are worth 85% of our army or more, the whole army holds on the high ground behind the wall. Musketeers stand three tiles in and shoot over it. Cannons and Mortars stand six tiles in. Units that walked out are called back. It holds until the wave is worth under 70% of the army. An enemy inside the wall is fought as before. A smaller wave is met as before. (`hold_behind_wall`)
6. No attack into a bigger army. A wave only goes out when it is worth 1.2 times the biggest enemy army seen in the last four minutes, or at 60 supply. (`attack_ok`)
7. Pulling back. A wave that trades badly comes home, with the Clockwork's own rule (lost 2.2 times what it killed, and at least 300, over 30 seconds). (`retreat_rule`)
8. Expansions. The next Town Hall waits for 14 army supply worth 90% of the biggest enemy army seen. If the main's soil is under 30%, it expands anyway. (`hold_hall`)
9. The Horseman rush. Against the Clockwork the Breeder opening comes 1 game in 10 instead of 3 in 10 (the Rush plan still always rushes). The rush gives up as soon as the defenders seen are worth 80% of the riders, so the riders ride home alive. After that the usual failed-rush switch to the Musketeer game applies, and the two-rider cap stops more Horsemen. (`breeder_chance`, `rush_beaten`)

## Part B: the Clockwork computer against Horsemen

The owner said: bunch the workers up and attack the Horseman, to give the Clock Soldiers time to arrive. Do not feed them one worker at a time. Hold a few soldiers at the ramp.

1. The Winders group up. When only riders (fast ground units) raid a Cog Press, a Mainspring or a Clocktower, every Winder within about 10 tiles of the raid joins one group. All of them hit the same rider, the one nearest the group. They fight if the group has half the riders' strength while soldiers are coming, or 90% of it when none are. They never chase a rider more than about 13 tiles from their press; then they go back to work. (`worker_raid`)
2. The soldiers come as a group. The nearest Clock Soldiers walk to the Winders' press, not to the rider. Three per rider, between 3 and 8, never one alone. A soldier led more than 10 tiles away walks back. They go home 8 seconds after the last rider leaves. (`guard_workers`, `tick`)
3. The ramp post. Once riders have been seen in the last four minutes, with 10 or more Clock Soldiers at home, 3 of them stand on HOLD across the top of the main's ramp. From 16 soldiers, 4. A guard running down is swapped for a fresh one. When a real army comes up the ramp, the post joins the fight. (`_ramp_tick`)
4. Still running. Against Balloons, and against slow armies the Winders cannot beat, the old rule stays: the Winders run.
5. Raptors are fast too, so a Brood Raptor raid now meets a group of Winders. Winders beat Raptors one for one, so this should help.

## Decisions made without the owner

The Breeder opening against the Clockwork is now rare, 1 in 10. The rush lost every game, and the Musketeer game is what won his games.
The Crown's changes only apply against the Clockwork. They may suit the Brood games too, but the task said those must not get worse, so they are left alone.
The ramp post uses the same ramp finder the Crown's wall uses.
The wall hold thresholds (85% in, 70% out) and the hall gate (14 supply) are first guesses.

## What is left: the checks to run

Put Godot 4.7 at /home/claude/godot, then:

1. The raid test, new: `godot --headless --fixed-fps 30 --script res://tools/test_ai_cw_horse_raid.gd -- map:greenhold seed:5 riders:3 at:200`. It plays the same game with round 5 off and on, and counts the Winders lost. Run riders:2 and riders:4, and other seeds.
2. The AI tests, compared with main: test_ai_* , test_gear_ai, test_ai_rush_followup, test_ai_wall_vs_rush, test_ai_worker_safety, test_determinism.
3. Crown computer against Clockwork computer, both sides, 8 or more games, the usual four (greenhold 11 0, frostmere 12 1, hollowfen 13 0, kestrel_rise 14 1), twice, with `tools/study/study_game_v2.gd`. Compare with `ai.r5.on = false`.
4. Crown against Brood, the four maps. These should not change at all.
5. Films with `tools/shot_ai_match.gd`: the wall hold (the "holds behind its wall" line in log.txt), the Winders grouping ("groups its Winders up"), the ramp post ("posts ... on HOLD").

Things to look for: the army standing behind the wall must still reach the gate with its shots; the ramp post must not block the Clockwork's own Winders and waves; the Crown's halls must not stall for good when the Clockwork army is always bigger.
