# Turning gears (an experiment)

The owner's idea, 2026-10-28: "What about real movement? If a unit steps on a gear it starts the round-about. If it stays on the gear ring it keeps going round and round. Workers step inside the ring to the building so they don't go round and round. This would make some fun interactions in micro."

It is built as an experiment. It is on by default for now, so the owner can play it.

The owner was away while it was built. He left corrections on the branch after the job started (OWNER_NOTE_gear_turn.md, now folded in here and deleted). Every other choice below is Claude's, and says so.

## What it does

Every Clockwork building has a gear ring on the ground. The ring has two parts. The middle is a flat iron or brass plate. Around it is the toothed band.

Only the toothed band turns. The plate in the middle stays still.

A unit standing on a turning band is carried round with it. It moves with the teeth, at the teeth's own speed.

If it stays on the band, it keeps going round and round.

Rings that mesh turn opposite ways, like real gears. Where two rings meet, both carry the same way, because their teeth move together there.

A unit walking across a band drifts too. It drifts by the full, correct amount for the time it spends on the band. This was the owner's correction: no softening for walkers. Its path finding steers it back, so it still gets where it was sent.

Idle units stay where they are. They keep riding round until the player moves them off. This was the owner's correction too: no automatic step off.

Units on HOLD stay and are carried. That is the micro.

Units fighting while they stand on a band keep fighting, and drift.

## Who is not carried

Workers at work are not carried. Winders going to a Cog Press, a Mainspring, a building site, a repair, or home, walk straight in across the band, as the owner asked. A worker that is idle, on HOLD, or simply moved by the player, is carried like anyone else.

Flyers are not carried.

The big machines are not carried. Claude's choice: anything with a body radius of 22 or more. That is the Field Cannon, the Spring Ballista and the Great Winder. Wheels and big frames spinning on a ring looked silly.

A limbered gun or wagon is not carried. A man in a balloon, a man crewing a Ballista, and a Springer in the air are not carried.

## Which rings turn

A ring turns only when the art shows it turning. That means a finished building that is connected to the gear field.

A building being built, an unlinked building, and a dead building have still rings. A building swapping its gear has a still ring while it swaps, and so has everything hanging on it.

## The speeds

The teeth pass at 1.4 teeth a second, 25 pixels apart. So the band moves at 35 pixels a second at the middle of the teeth. That is about one tile a second. A little less up and down the screen, because the ring lies flat at the camera's angle.

For comparison, a Musketeer walks 62 pixels a second, a Clock Soldier 68, a Winder 74.

A unit on a band goes round once in about:

- 27 seconds on a Clocktower's ring.
- 15 seconds on a small 3 by 3 ring.
- 21 seconds on a big 3 by 3 ring.

The band is about two tiles wide on a Clocktower, a bit over one tile on a small ring.

Small gears turn faster than big ones. But the teeth move at the same speed on every ring. So a unit rides at the same speed on any band. On a small ring it simply goes round sooner.

All of these are in Defs.GEAR_TURN. The carry share is 1. The walker's share is 1, the owner's call.

## The setting

Settings, TURNING GEARS (experiment). In Portuguese, ENGRENAGENS GIRANDO (experimento). In Spanish, ENGRANAJES QUE GIRAN (experimento).

It is on by default.

It applies from the next match. A match keeps the rule it started with. The rule is saved in the match's setup. So a continued match keeps it, an online guest gets the host's rule, and a replay shows what was played.

To switch it off: Settings, TURNING GEARS, OFF.

## The computer

The computer does not mean to ride a ring. So it walks its own idle units and its own units on HOLD off a band after one second, to just outside the ring. Their orders stay the same. This is the computer's choice, not a rule for the player. The owner allowed it: its AI may move them off deliberately.

So no computer unit circles forever.

Its workers cross like the player's. Its fighters fighting on a band drift like anyone.

## How it looks

The teeth already turn. On top of that:

- A unit being carried kicks up a little dust at its feet, trailing behind it.
- Point the mouse at a band, and gold chevrons run round it the way it turns.
- In the GEAR VIEW (the ` key), every turning band shows its chevrons.

These are drawn from positions only, so an online guest and a replay show them too.

## The micro it creates

An enemy holding on a ring is shifted out of position. A gun line parked on your Clocktower's band slides round it, maybe out of range, maybe into the open.

A defender can be shifted too. Clock Soldiers holding a ring face round as the ring turns. Park them on the plate or beside the ring if you want them still.

A raid that crosses a band is pushed sideways a little, the way the ring turns. Rings that turn toward a gap can carry attackers into it, or away from it.

Melee units chasing a man on a band have to follow him round.

Where to build matters a little more. A ring next to your ramp moves whoever stands on it.

## How it is made

scripts/gear_turn.gd does the carrying. It is called once a tick for each unit, before it moves. It moves the unit through resolve_terrain, so a unit is never pushed into a cliff, a wall or a building. Pressed against one, it just stops there.

scripts/gear.gd keeps the bands: the inner and outer radius of each connected ring, its turn rate, and a coarse grid to find them fast. The turn rate is worked out from the gear tree: the Clocktower turns on its own, each ring meshing with it the other way at the same rim speed, and through an idler cog the same way.

Everything runs in the simulation, with no randomness. So it is deterministic.

## Tests

- tools/test_gear_turn.gd: a unit on HOLD rides round, the right way, at the teeth's speed; the plate and the ground off the band carry nothing; Winders going to a press or a repair are never carried and get there; the player's idle unit stays and rides; a walker drifts and still arrives; the computer walks its units off; big machines and flyers stay put; meshed rings turn opposite ways at the same rim speed; the setting off stops it; the same scene twice gives the same hash.
- tools/test_gear_turn_match.gd: a Hard Clockwork computer against a Hard Crown computer, nine minutes. No computer unit rides round for long unless it is fighting. A HASH line every minute: run it twice and compare.
- tools/test_gear_rules.gd: its turret volley switches the experiment off, because the target on HOLD would ride out of the turret's reach.

## Pictures

docs/shots/gear_turn/, made by tools/shot_gear_turn.gd and tools/gear_turn_gif.py:

- hold.gif: six enemy Musketeers on HOLD on a Clocktower's band, carried round while they shoot.
- winder.gif: a Winder walks in across the band to repair the Clocktower, not carried. A Clock Soldier left idle on the band rides round beside him. The gear view's chevrons show the way each band turns.
- raid.gif: a Crown raid on a Clockwork base whose Clock Soldiers hold on the ring.

## Open questions for the owner

1. Speed. One tile a second, the teeth's own speed. Faster would be wilder, slower would be calmer. Should the carry be its own number, apart from how fast the art turns?
2. The big machines. Should the Field Cannon, the Ballista and the Great Winder ride too?
3. Workers. They are never carried while at work, even standing on a band to repair. Should a Winder repairing from the band ride round as he works?
4. Facing. A carried unit keeps facing where it faced. On a real turntable it would turn with the ring. Should it?
5. The computer. It walks its idle and HOLD units off after a second. Should it use the rings on purpose, for example holding beside them, or parking an enemy-side ring?
6. Enemy rings. Your units ride the enemy's rings too. Is that wanted? It makes raiding a Clockwork base harder to control.
7. Online. The host runs it and the guest sees the result, so both agree. Lockstep, if it comes, would need it to be deterministic across devices: it uses only floating point sums like the rest of the movement.
