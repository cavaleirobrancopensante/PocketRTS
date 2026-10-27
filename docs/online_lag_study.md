# Online lag study

Written for Holdfast 0.14.37 to 0.14.40 (branch wt-online). It is meant to be read aloud: plain sentences, a few small
tables, numbers rounded.

## Summary

What changed. The friend who joins (the guest) no longer waits a round trip to see their units move: a move or an
attack-move starts walking at the click, then blends into the host's game without a jump. The host's own orders now
wait as long as the guest's take to arrive (the room's "Same delay for both players", on by default), so both players
have the same delay. The host sends an even beat of fifteen pictures a second, each with the same amount of game time,
and the guest shows them from a small buffer sized to how unevenly they arrive, so units walk smoothly. The pictures
cost the host a third of what they did and are half the size. There is a ping counter left of the clock, a network
line in the match log every minute, a "Waiting for the host..." line, and a hidden host tab pauses the match for both.
MENU and PAUSE are separate (SURRENDER is always in the MENU, online too, which runs on behind it), the MENU has a
music player, the chat works both ways, click rings show only on your own screen, a refused order says why, and a
guest's room no longer sits empty.

Before and after, on a normal internet connection (ping about 180 ms):

| | before | now |
|---|---|---|
| guest: move order to walking on screen | 330 ms | 31 ms |
| guest: other orders (attack, build, train) | 190 ms | 186 ms |
| host: move order to walking | 25 ms | 117 ms (the same delay, on purpose) |
| guest: walking speed, change tick to tick | 8% to 16% | 7% |
| host: one picture, 68 units | 2.5 ms, 3.5 KB | 0.8 ms, 1.6 KB |

At home the guest's walk went from 180 ms to 33 ms, on a poor connection (ping 340 ms) from 470 ms to 21 ms.

What to re-test online, on the two devices:

- Same delay on and off: does it feel the same for both players? (On: the host feels about half the ping.)
- The guest: move and attack-move answer at once; units never jump back; attacks, building and training take one ping.
- Watching the other player's units walk: smooth, no stop and go.
- The ping counter, and the match logs from both devices (the minute lines say ping, this device's leg to the relay,
  pictures, orders and stalls: please send both).
- MENU: PAUSE from either player (3 each), RESUME and the 3, 2, 1; SURRENDER from the guest and from the host; QUIT.
- The music player: NEXT, picking a song, paging the list.
- Chat both ways; the click ring only on your own screen.
- Joining: the room should fill in within two seconds; a wrong code says "No answer from the host yet" after 8 s.
- Hiding the host's browser tab: both games pause and come back with a 3, 2, 1.

For the merge: wt-online is merged with main up to 0.14.36 and its entries are 0.14.37 to 0.14.40. The automatic
test (tools/test_online.sh, about two minutes) passes for Crown, Brood and Clockwork guests, co-op and a host
surrender, at 0, 60 and 120 ms each way. Main's Jack "arm" value needed a line in the snapshot's direct readers
(0.14.40): any value added to NetSnapshot.UNIT_PROPS or BLD_PROPS must be added to unit_vals / bld_vals and their
writers too, and the test now fails if it is not.

## 1. How an online match works, in short

The host's game is the real one. It runs the whole match: every unit, the economy and the computer players. Fifteen
times a second it takes a picture of the match, a "snapshot", and sends it to the friend. The friend's game, the
guest, does not simulate anything. It puts every unit where the pictures say and draws them, and it sends every order
the friend gives to the host, who checks it and runs it.

Both games talk through the relay, a small program on Cloudflare (tools/relay/worker.js). The relay pairs the two
players by the room code and passes the bytes on. It knows nothing about the game.

So the host sees its own orders at once, and the guest sees its orders only after a trip to the host and back. That
difference is the lag the owner reported: "the host has basically no lag, but the invited player has too much lag".

## 2. What was measured, and how

Everything was measured on one computer (a 2-core cloud machine, so a phone will be slower; the minute lines of the
match log now carry the same numbers from real devices).

- tools/bench_net_snapshot.gd plays two Hard computers on Hollowfen and, every 0.1 s of game time, builds a snapshot,
  packs it, unpacks it and puts it on a puppet game, timing each step. It does this the new way and, given the 0.14.32
  file, the old way, and checks that the puppet ends up identical to the host. With spawn:N it adds N Musketeers and N
  Raptors that march across the map, for a big battle.
- tools/test_online.sh starts the local relay, a host and a guest, plays a short match and prints LAG lines. The
  relay can hold every message back to imitate the internet: LAG_MS is the delay each way, JITTER_MS a random extra
  on top. Three connections were used: a home network (no delay), a normal internet connection (60 ms each way plus
  up to 30 ms), and a poor one (120 ms each way plus up to 60 ms). The round trip, the ping, is then about 15, 180 and
  340 ms.
- The test also runs the old behaviour, by switches: nolead (the guest's units wait for the host), nosame (no equal
  delay), rate10 (ten snapshots a second), clocksnap (snapshots by the clock) and noterp (the old glide instead of the
  buffer). "Before" in the tables below is all five together, which is how 0.14.32 played.

## 3. The host: making the pictures

A snapshot lists every unit and building with its place, health and state. Since the work on this branch, only what
changed since the last picture is sent, enemy units the guest cannot see are left out, and the values are read
directly instead of by name.

Time to build and pack one snapshot on this computer, and its size:

| units in the match | before: build + pack | now: build + pack | before: size | now: size |
|---|---|---|---|---|
| 26 | 1.1 ms | 0.4 ms | 2.0 KB | 1.1 KB |
| 68 | 2.5 ms | 0.8 ms | 3.5 KB | 1.6 KB |
| 175 | 6.3 ms | 2.4 ms | 5.1 KB | 3.3 KB |
| 326 | 8.8 ms | 3.3 ms | 8.1 KB | 4.8 KB |
| 625 | 18.2 ms | 7.1 ms | 13.6 KB | 8.5 KB |

So the host's cost is now about a third of what it was, and the pictures are a third to a half smaller. The cost grows
in a straight line with the units, about 11 microseconds each on this computer. A phone is perhaps three to five times
slower: in a 600-unit battle a phone host would spend 20 to 35 ms on each picture. That is why the host sends fewer
pictures when they get expensive: it keeps their cost under 5% of its time, and their size under 40 KB a second, and
never goes below ten a second.

## 4. Packing the messages

Every message is turned into bytes with Godot's var_to_bytes and, above 160 bytes, compressed with zstd. Packing a
snapshot takes 0.1 to 0.6 ms and unpacking 0.1 to 0.9 ms, from the smallest match to the biggest. The old deflate
compression took four to seven times longer for the same size. Packing is not a cause of lag any more.

## 5. The relay

Each room is one Cloudflare Durable Object. Cloudflare places it near whoever opened the room first, so near the
host. The guest's messages therefore travel from the guest to the nearest Cloudflare edge, on to the room, and from
there to the host; the host's go the other way. The relay itself adds well under a millisecond per message. What
costs is the distance: the ping between the players is the guest's leg to the room plus the host's leg to the room.
It cannot be measured from this machine (the cloud machine cannot reach the real relay), so the match log now
measures it on the devices: every minute line says how long this device's own leg to the relay takes ("to the relay
85 ms avg"). If one player's leg is much longer than the other's, that player's connection is the slow part. A relay
nearer to both players would only help if they live far apart; there is nothing to fix in the relay code.

## 6. The guest: putting the pictures on screen

Applying a snapshot on the guest takes 0.3 ms in a small match and 5 ms with 600 units (it was 0.6 and 13 ms). A
picture that brings new units costs more for that frame: up to 25 ms when 150 units appear at once, 75 ms with 300.
Several pictures that arrive in the same frame are merged and only the newest is applied, so a slow frame never
causes a pile-up.

Then the units must move smoothly between pictures. Before, each unit glided toward the newest picture over about the
time between pictures. When the next picture came late, which happens all the time on the internet, the unit reached
its spot, stopped, and started again when the picture came. Now the guest keeps each unit's last few places, each with
the host's clock, and shows the match a little behind the newest picture. The unit's place is worked out between the
two pictures around that moment, so it walks at an even speed as long as the next picture comes within the buffer.
The buffer is the time between pictures plus twice how unevenly they arrive, measured all the time: about 80 ms at
home, 110 ms on a normal connection, 150 ms on a poor one.

How even a walking unit looks on the guest's screen, as the change of its speed from one game tick to the next (0%
would be perfectly even):

| connection | before | now |
|---|---|---|
| normal (60 ± 30 ms) | 8% to 16% | 7% |
| poor (120 ± 60 ms) | 8% to 19% | 7% |

The "before" numbers depend on the rate: at ten pictures a second the steps were bigger but stopped less often.

Two smaller faults were found on the way. The host meant to send twenty pictures a second, but checked the clock in a
way that, at sixty frames a second, sent one every fourth frame: fifteen a second, alternating one and two game ticks
of movement each, a stutter. It now sends one every two game ticks, exactly. And the clock that steers the buffer
followed every picture's arrival, which made the walk pulse faster and slower by up to a third; it now follows the
average.

## 7. Input delay: from a click to seeing it happen

Move order, from the click to the unit walking on the player's own screen:

| connection | guest before | guest now | host before | host now |
|---|---|---|---|---|
| home (ping 15 ms) | 180 ms | 33 ms | 30 ms | 42 ms |
| normal (ping 180 ms) | 330 ms | 31 ms | 25 ms | 117 ms |
| poor (ping 340 ms) | 470 ms | 21 ms | 27 ms | 190 ms |

The guest's units now start walking at the click, before the order has even reached the host (the "lead"). When a
picture shows the host's own unit on its way, the guest's unit is taken back to the host's place gently: it walks at
about nine tenths of its speed for a moment, or faster when the host's path turns another way, never with a jump.
Only plain walks are led this way: move, attack-move (when no enemy is near), and a right click on open ground. A
click on an enemy, a building order, training and the rest still wait for the host, about one ping:

| connection | guest's other orders, click to seen | before |
|---|---|---|
| home | 41 ms | 40 ms |
| normal | 186 ms | 190 ms |
| poor | 330 ms | 340 ms |

The host's own orders now wait too, when "Same delay for both players" is on (the default, a switch in the room):
they run after half the ping, the time a guest's order takes to reach the host. So an order from either player runs
in the host's game the same time after the click, and neither side reacts faster. The ring on the ground and the
unit's voice still answer at once on both sides. The wait is the middle of the last seven pings since the start (the
pings during loading took seconds and made it 170 ms on a home network at first), and at most 250 ms. The match log
says how long it is.

## 8. A hidden or stalled host

When a browser tab is hidden, the browser stops drawing it, and Godot's game stops with it. A hidden host tab used to
freeze the guest's game without a word. Now the host's page hears that it was hidden and pauses the match for both
players; the guest's screen says "The host's game is in the background: the match waits", and the match comes back
with a 3, 2, 1. If the host stops without warning (a phone busy or asleep), the guest says "Waiting for the host..."
after one second without a picture, and the ping counter turns red and climbs. Both are written in the match log
with their length. Measured: with the host frozen for 3 s, the guest showed the waiting line after 1 s and went on as
soon as the host came back; with the host hidden for 5 s, both games paused and went on together.

## 9. The causes, ranked, and what was done

1. The guest waited a round trip for every order, the host for none. This was most of what the owner felt: 180 to
   470 ms against 30 ms. Fixed by the lead (the guest's walks start at once) and the same delay for both (the host's
   orders wait half the ping). The remaining gap is the orders that cannot be guessed: attacks on a unit, building,
   training. They take about one ping on the guest and half a ping on the host.
2. Units on the guest stopped and started when a picture came late, and the glide added up to 150 ms on top of the
   ping. Fixed by the buffer and the even beat of pictures.
3. The host's cost of making pictures, which on a phone in a big battle takes time from the host's own game: now a
   third of what it was, and the rate drops when it gets expensive.
4. A hidden host tab froze the match: now it pauses it for both, with a message.
5. The distance between the players and the relay: not fixable in code, but now visible in the match log.
6. The size of the pictures on a mobile uplink: halved, capped at 40 KB a second.

## 10. What is left

- Orders other than walking could be shown at once too (a unit turning toward the enemy it was told to attack, a
  worker heading to a building site). Each needs its own guess and its own way back if the host says no.
- The host's own walks could be shown at once, like the guest's, while they wait for the same delay. That would make
  the host's screen feel instant too; it needs the same lead, drawn on the host's real units, which are not puppets.
- On a phone, the top bar is crowded online: when there is no room left of the clock, the ping counter goes under it.
- Real devices: the owner's next online test will show the phone numbers in the minute lines.

## 11. How to repeat the measurements

    godot --headless --fixed-fps 30 --script res://tools/bench_net_snapshot.gd -- at:180,420 window:10 old:/abs/old_net_snapshot.gd spawn:150
    LAG_MS=60 JITTER_MS=30 tools/test_online.sh
    LAG_MS=60 JITTER_MS=30 tools/test_online.sh nolead nosame rate10 clocksnap noterp

(For the old snapshot code, save `git show c699e4f:scripts/net/net_snapshot.gd` (0.14.32 on main) without its class_name line.) The
test also checks the chat both ways, the words of a refused order, sixteen kinds of guest orders, a pause and its
resume, and a surrender; `quick` skips those. `hide_host:5`, `freeze_host:3` and `freeze_guest:3` test the hidden and
stalled windows; `shots:<dir>` (with a window, for example under xvfb-run) saves screenshots.

## 12. Instant feedback (0.14.55, branch net-instant)

What changed. Until now only a move and an attack-move answered the friend (the guest) at the click; every other
order showed nothing until the host's answer came back, one ping later. Now every order the guest's screen can give
reacts on the click, and the host's own orders, which wait on purpose when "Same delay for both players" is on, show
the same reactions at once on the host's screen. The host still decides everything: what the click shows is laid over
the guest's copy of the match, and the host's next picture replaces it.

How it works. A click makes an "entry" of small changes on the guest's copy (scripts/net/net_predict.gd): the item
added to a queue (drawn faint, with a breathing frame, until the host confirms it), the resources and supply spent,
the progress bar started, the rally flag moved, a setting flipped, a gun or a Spore Mother starting to set up, a
building faded (cancelled or pulled down), and a building site drawn where it was placed, faint and outlined in
dashes, which is only a picture: the real site comes from the host. Before each picture from the host is applied,
every entry is taken off, so the picture lands on the host's truth; after it, the entries the host has not answered
yet are laid on again. The host's answer arrives in the same picture as its result (the picture carries the number of
the last order it has run), so the moment an entry goes, the real queue item, site or cost is already there: nothing
flickers. Two small exceptions keep it that way: a unit's slower values come in every other picture, so a setting or a
timer stays one picture longer; and a building told to go stays faded until the host's picture takes it away.

The units' side is the lead from section 7, widened: units told to attack a unit or a building turn to it and walk
until it is in their weapon's range; a worker told to gather, build or board walks to it (a Winder first to the
Clocktower for its crate, one grub for a Brood site, which turns into the building only when the host says so); a
caster walks into range of its spot; stop and hold stand the units still at once; a deploy stops the unit and starts
the animation; units that only turn (a toad's tongue, a cast within range) turn at once. When the host's picture
shows the unit doing the same, the lead is taken back gently, as before.

When the host refuses (not enough gold, a blocked spot), its refusal now names the order, so the guest takes that
entry off at once: the site disappears, the queue item and the money go back, the units' leads are taken back, and the
reason shows as before. A building the host would not place for want of money used to be dropped without a word; the
host now says why ("Not enough gold."), so the guest's site never lingers.

The host's own held orders. They still run half a ping after the click. Meanwhile the host's top bar shows the cost
and supply spent, the queue shows the item (faint), the site is drawn, and the units turn at once. Nothing of the
real game is changed for this: the HUD reads the real values with the waiting orders on top (NetPredict.shown_player,
shown_queue), so the computers and the match itself never see it. The units do not walk ahead on the host: that would
need a drawing offset on real units, and the wait is only half a ping (about 50 to 110 ms on these links).

Measured with tools/test_online.sh, every order type in turn, for a Crown, a Brood and a Clockwork guest, on the
local relay at 40 ms each way plus up to 10 (US East, a ping of about 100 ms) and 90 ms plus up to 20 (Brazil, about
200 ms). "Seen" is the time from the click to the first frame that shows the reaction on the guest's screen (a frame
is 16 ms; 33 ms means the next game tick); "before" is the same build with the prediction switched off (nopredict),
which is how 0.14.47 played. Where the factions differ the range is given.

| order | seen before, 40 ms | seen now, 40 ms | seen before, 90 ms | seen now, 90 ms |
|---|---|---|---|---|
| move, attack-move, smart move, line move | 15 to 34 ms | 16 to 34 ms | 15 to 34 ms | 17 to 19 ms |
| stop, hold, stop after an attack | 450 to 530 ms | 15 to 18 ms | 550 to 700 ms | 15 to 18 ms |
| attack a unit | 280 to 400 ms | 18 to 33 ms | 380 to 470 ms | 17 to 33 ms |
| attack a building | 17 to 33 ms (a fogged building: a walk) | 18 to 34 ms | 17 to 34 ms | 14 to 33 ms |
| gather | over 1.3 s | 16 to 33 ms | 0.4 s, or none in 2.5 s | 18 to 33 ms |
| hold fire on, off (Crown) | 150 to 200 ms | 15 to 17 ms | 250 ms | 15 to 18 ms |
| train, cancel, cancel one of two | 116 to 150 ms | 15 to 18 ms | 250 to 285 ms | 15 to 19 ms |
| auto-train on, off | 17 ms (it flickered back once) | 15 to 18 ms | 15 to 18 ms (flickered) | 15 to 18 ms |
| rally, worker rally (Brood) | 116 to 150 ms | 15 to 17 ms | 250 to 280 ms | 16 to 18 ms |
| place a building | 117 to 146 ms | 13 to 17 ms | 233 to 266 ms | 13 to 17 ms |
| cancel a site, pull a building down | 133 to 152 ms | 15 to 17 ms | 249 to 268 ms | 15 to 20 ms |
| deploy, pack (Cannon, Spore Mother, Tesla Cart) | 116 to 215 ms | 15 to 18 ms | 253 to 285 ms | 15 to 18 ms |
| cast FOG (Mist Toad) | 199 ms | 17 ms | 317 ms | 17 ms |
| BOMBARD (the ring) | at once | at once | at once | at once |
| a placement or training the host refuses | nothing shown | 15 to 18 ms | nothing shown | 15 to 18 ms |
| host: its own TRAIN, held (shown in its queue) | 82 ms | 15 ms | 134 ms | 15 ms |

(The low "before" numbers are units that already did what was asked: a soldier without a gun "holds fire" already, a
unit already walking that way, a click on a fogged building, which is a walk.) Every reaction is within 50 ms of the
click now, in all three factions and at 0, 40 and 90 ms each way.

Jumps. The test watches each order's units, queue and money for 2.5 seconds after the click. Units moved further in
one game tick than they can walk: none, in any run. A queue going up and then down, or a setting flipping back: none,
except one rally flag in nine runs, which the prediction-off runs show too (the flag set on a spot a unit was walking
through goes with that unit, on the host as here). Before, auto-train flickered back once at every link: the old click
set it here, and a picture that came before the host's answer set it back.
Money given back while an order waits: none. A refused placement or training is taken back once, which is the point.
After a stop, a unit closes up to where the host stopped it, at a walk: 5 to 12 px for the Crown and the Clockwork, 15
to 30 px for the faster Raptors at 90 ms. That distance is the time the order took to reach the host, walked; it cannot
be guessed away without letting the unit walk on after the click, which is what a stop must not do.

What still waits for the host, and why. Everything that decides the match: shots and damage, a unit actually firing,
a building actually starting, a trained unit coming out, research done, a morph's result (a grub becoming a building,
a Swift becoming an Owl), a crate carried, the gold income. The guest shows the start, never the result. Some starts
are left to the host too, because the guest's copy cannot guess them well: a Cannon or Mortar told to BOMBARD turns
only once it is set up (it shows the ring and answers); a Mist Toad's tongue and a cast already in range only turn;
mount, lead, harness, ride, load and unload only answer and show the ring; a cancelled unit gives back its own price
but not a soldier's kit fee, which the guest does not know (the host's next picture puts it right, within one ping);
the Clockwork's batteries are not shown spent. On the host, units do not start walking before their held order runs.

Tests. tools/test_online.gd now plays 26 to 30 kinds of guest orders (move, attack-move, smart move, line move, hold,
stop, a unit's stop, attack a building and a unit, hold fire on and off, bombard, a gun's stop, deploy and pack, rally
and the Brood's worker rally, train, cancel, train two and cancel one of them, auto-train on and off, the hall upgrade,
gather, place a building and cancel it, a placement and a training the host refuses, demolish, and with the Brood and
the Clockwork their own deployers and the Mist Toad's FOG), times each one's reaction (the LAG GUEST REACT lines),
counts the jumps, and checks that nothing predicted is left once the host has answered. For the refusals the host holds
the guest's gold at 0 while the guest's screen is told it has plenty, so the click shows the site or the queue item and
the host refuses it. The host's own held TRAIN is timed too (LAG HOST own train). `nopredict` switches the prediction
off, for the "before" numbers. It passes for Crown, Brood and Clockwork guests at 0, 40 and 90 ms each way, in co-op
and with a host surrender (after main's 0.14.54 was merged in, with the replays). The local relay now keeps every frame in order: two timers due in the same millisecond
could swap, and an order then reached the host after the one sent after it.

## Screenshots

Taken by `tools/test_online.gd shots:<dir>` on the local relay at 60 ± 30 ms (docs/shots/wt-online/):
the guest's room with its ping line (guest_lobby.png), the chat both ways with the ping left of the clock
(guest_chat.png), the MENU over the running match with PAUSE, SURRENDER and the music player (guest_menu.png), and a
pause asked for by the guest, on both screens (guest_paused.png, host_paused_by_guest.png).
