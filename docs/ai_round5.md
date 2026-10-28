# AI round 5: the Crown against the new Clockwork, the Clockwork against Horsemen

Version 0.14.100 (branch `ai-round5-merge`, merged into main). Written to be read aloud.

## Status: DONE. The Clockwork part is on in the game; the Crown part is off

The owner asked for the Clockwork part: the Winders bunch up and fight Horsemen, the soldiers come as a group, a few stand on HOLD at the ramp.
Since 0.14.96 (riders fight on the move, scripts/ride_by.gd) four Horsemen kill a whole crew of Winders, so this defence matters now.
Part B (the Clockwork) is ON. Part A (the Crown against the Clockwork) is OFF: it did not win the Crown more games (the tables below).
Part A stays in the code: `-- r5:crown` on the command line turns it on (`r5:crownonly` for part A alone, `r5:off` for neither).

### The Clockwork part only, as shipped (0.14.99 with ride-by)

Crown computer against Clockwork computer, Hard, the four maps, each side of the map once:

| map | Crown on the usual side | Crown on the other side |
|---|---|---|
| greenhold (seed 11) | won (22:21) | won (28:39) |
| frostmere (seed 12) | won (23:19) | won (18:45) |
| hollowfen (seed 13) | won (26:58) | lost (17:27) |
| kestrel_rise (seed 14) | lost (11:50) | lost (10:47) |

The Crown won 5 of 8, the same as main (5 of 8 earlier, plus 1 win, 1 even and 2 losses on the other sides). So the Clockwork is not made too strong.
In every one of the 8 games the Winders banded together against Horsemen, soldiers came as a group, and the ramp post went up.

The raid test on 0.14.99 (ride-by riders):

| map, riders | before: Winders lost, riders killed | after |
|---|---|---|
| greenhold, 3 riders | 12 of 17 lost, 0 killed | 0 lost, 3 killed, ramp post 3 |
| greenhold, 4 riders | 16 of 17 lost, 3 killed | 4 lost, 4 killed, ramp post 4 |
| kestrel_rise, 3 riders | 2 lost, 3 killed | 2 lost, 3 killed, ramp post 4 |
| frostmere, 3 riders | 10 of 19 lost, 1 killed | 2 lost, 3 killed, ramp post 3 |
| hollowfen, 4 riders | 11 of 22 lost, 4 killed | 4 lost, 4 killed, ramp post 3 |
The AI tests pass. test_ai_rush_followup fails its two [mop] checks with round 5 on and off alike (main); its [few] check failed once and passed twice on a re-run (it does not touch round 5).

## The first round of games (both parts on)

### The raid test (tools/test_ai_cw_horse_raid.gd, Winders lost to Horsemen, round 5 off then on)

| map, riders, when | before: Winders lost, riders killed | after: Winders lost, riders killed | ramp post after |
|---|---|---|---|
| greenhold, 2 riders, 3:20 | 4 lost, 2 killed | 0 lost, 2 killed | 1 |
| greenhold, 3 riders, 3:20 | 11 lost, 0 or 1 killed | 2 lost, 3 killed | 0 (8 soldiers home) |
| greenhold, 4 riders, 3:20 | 14 lost, 1 killed | 6 lost, 4 killed | 0 |
| frostmere, 3 riders, 3:40 | 10 lost, 3 killed | 2 lost, 3 killed | 1 |
| hollowfen, 4 riders, 4:20 | 7 to 16 lost, 1 to 4 killed | 3 or 4 lost, 4 killed | 3 |
| kestrel_rise, 3 riders, 4:00 | 10 lost, 2 killed | 2 lost, 3 killed | 4 |

Every run passes. The Winders group up (they stand about 50 px apart instead of scattering), the Clock Soldiers come as one group, and the ramp post stands once 12 or so soldiers are at home.
One seed (greenhold 21 at 7:00) never got a raid going in either run: the riders the test drops did not reach the Winders.

### The AI tests

test_ai_rush, test_ai_rush_followup, test_ai_wall_vs_rush, test_ai_army_response, test_ai_scout, test_ai_scout_defence, test_gear_ai, test_ai_worker_safety: all pass.
test_determinism (Crown against Clockwork) varies run to run with round 5 on and with it off, as it does on main.
New: tools/test_ai_r5_hold_spots.gd checks that the Crown finds its spots behind the wall and the Clockwork its ramp post on all four maps.

### The games (Hard against Hard, study_game_v2, the four maps, Crown against Clockwork)

A win by a lead at 30:00 counts as a win.

| version | greenhold | frostmere | hollowfen | kestrel_rise | Crown wins |
|---|---|---|---|---|---|
| before (main, `r5:off`) | won, won | won, even | won, won | lost, lost | 5 of 8, 1 even |
| round 5 first run (v1) | won, lost | won, won | won | lost | 4 of 6 |
| round 5 as on this branch (v2) | won, lost | won, won | won, lost | lost, lost | 4 of 8 |
| v3, Barracks before tech (taken out again) | lost, lost | won | | lost | 1 of 4 |
| part A only (`r5:crown`, the Clockwork as before) | lost | won | even | lost | 1 of 4, 1 even |

The old number to beat, 1 or 2 Crown wins in 8, is out of date: on 0.14.94 the Crown computer already wins 5 of 8.
Both "before" losses on kestrel_rise came from the Horse Breeder rush opening, which round 5 makes rare. Round 5 lost kestrel_rise with the Musketeer opening too.

Crown against Brood, round 5 on, once on each map: the Crown won all four (12:49, 12:43, 12:02, 9:58), the same as main.

### Why the Crown did not get better

The films and logs show the same story in the lost games.
The Crown expands at about 6:00. The Clockwork's first wave, 20 to 30 supply, comes at 7:30 to 8:30.
The Crown has 14 to 17 Musketeers then. Its army dies at the expansion, the expansion falls, the main's soil runs out around 10:00, and the income stops (about 9,000 gold earned by 12:00 against the Clockwork's 12,000 cogs).
In v1 the army held behind the wall against any bigger wave, so it left the expansion to fall. v2 holds only for a wave at the ramp; the expansion is defended as before. Neither saved the expansion.
v3 copied the owner's build (Barracks before the Armoury and Church). The Crown then attacked early with 21 supply and lost the army. It was taken out.
Part B helps the Clockwork against the Crown's two Horsemen too, so "after" games face a slightly stronger Clockwork. But part A alone was no better either.

Pictures (greenhold, seed 11, filmed with tools/shot_ai_match.gd):
`docs/shots/ai_round5/crown_expansion_0840.png`: 8:40, the Clockwork's 41-supply wave walks into the Crown's low-ground expansion, held by a handful of men while the army holds behind the ramp wall.
`docs/shots/ai_round5/clockwork_ramp_post_1000.png`: 10:00, the Clockwork's ramp post: Clock Soldiers on HOLD at the top of its ramp.

### What changed in this merge

- The ramps are found at the start (the wall covers the band later, and the ramp finder skips built cells: the hold behind the wall never found its spots).
- A narrow ramp top with one spot still takes the whole post (the extra guards stand beside it).
- The hold behind the wall is only for a wave within 12 tiles of the ramp.
- The Labourer hold is softer: from 30 Labourers, while the army's supply is under 60% of them (24 and 80% starved the economy).
- Study switches, on the command line after `--`: `r5:off` (all off, the same as 0.14.99), `r5:crown` (part A on as well), `r5:crownonly` (part A alone). The first round of games used an older meaning: part A was on by default then.

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

1. Labourers. From 4:00, with 30 or more, no new Labourer while the army's supply is under 60% of the Labourers. Never more than 42. (`hold_labourers`)
2. Horsemen. Two at most, for scouting and picking off Winders. The rest of the Barracks' time goes on Musketeers. A Horseman rush keeps its own rule. (`horsemen_cap`)
3. Horses. A Foundry keeps one horse standing by, and only while a gun or the wagon is wanted or queued. No spare horse at the breeders. Riders still get their horse when they are trained. (`foundry_horses`, `spare_horses`)
4. Missionaries. One at most. (`missionary_ok`)
5. Behind the wall. When enemies come to the outside of the ramp wall (within 12 tiles of the ramp) and they are worth 85% of our army or more, the whole army holds on the high ground behind the wall. Musketeers stand three tiles in and shoot over it. Cannons and Mortars stand six tiles in. Units that walked out are called back. It holds until the wave is worth under 70% of the army. An enemy inside the wall is fought as before. A smaller wave is met as before. (`hold_behind_wall`)
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

## What is left

- Part A needs a different idea. The Crown loses its expansion to the first Clockwork wave and then runs out of soil. Things to try: a later expansion against the Clockwork (with the army at home and the wall), more Labourers on the main's soil first, or Cannons at the expansion.
- The raid test's greenhold seed 21 at 7:00 never starts a raid.
