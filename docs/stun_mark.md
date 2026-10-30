# The stun mark (0.15.24)

The owner, 2026-10-29: "How long does the staggered effect last? We should get that common stun effect: a spinning thing
on top of the unit's head."

A stunned unit now shows a little ring of stars circling over its head: 3 stars over a small unit, 4 over a bigger one,
on an ellipse just over its health bar (Unit.bar_top: the same height the bar uses, so it sits right over a Raptor, a
Field Cannon or a Tyrannosaur), about one turn a second with a small bob. It fades in in 0.08 s and fades out over the
stun's last 0.2 s. Everyone who can see the unit sees it (the fog hides it with the unit); online guests and replays
get it too (NetSnapshot "stun_end"); a save keeps it. The unit card says `STUNNED: 0.6 s (it cannot move or fight)`.

Only REAL stuns show it: `Unit.stun(t, show := true, until := -1.0)` is the one way to stun a unit now. A stun shorter
than StunMark.MIN_SHOW (0.3 s) shows no stars (they would only flicker).

The TONGUE changed with it (owner, 2026-10-29): the Toad can tongue FLYERS (a pulled flyer is dragged through the air to
just over the Toad, Defs.TONGUE "over" px, and stays in the air; the crosshair, the windup and its break rules are the
same), and it can never pull the Brood Mother or a father (Defs.TONGUE "no_pull" plus Defs "father": true): they are only
staggered, like heavy units (5+ supply or "massive"; the Field Cannon, 4 supply, is still pulled while the owner decides).
The computer's Toads now also go for Balloons, Ornithopters and Skywings (AI.TONGUE_PRIZES).

| source | stun | stars |
| --- | --- | --- |
| Mist Toad TONGUE, a heavy target (5+ supply or "massive": Steam Walker, Pendulum, Great Winder...; the Brood Mother, the Tyrannosaur and every father) is staggered | 1.0 s (Defs.TONGUE "stagger") | yes |
| Mist Toad TONGUE, any other target is pulled (a Field Cannon too: 4 supply; a flyer through the air) | 0.9 s (pull 0.6 + after 0.3) | yes |
| Cavalry CHARGE (Cuirassier with Cavalry Charge, after a 2 s run), a light target | 0.6 s (Defs.CHARGE "stun") | yes |
| Cavalry CHARGE, a target of 3+ supply | 0.24 s (0.6 x 0.4) | no (too short) |
| Stormcaller STORM (RETIRED unit: not in the game) | 0.2 s topped up every tick while inside, up to the storm's 2.5 s + 0.2 s | yes, to the storm's end, if its code ever runs |
| Netter's net | none since 0.24.4: a ROOT (Unit.net_t holds it in Unit._move; no spells or abilities), it still fights; 4.0 s (Defs.NET "time") | no: the net shows itself; a netted unit never shows stars |
| A run-down construct (out of charge) | 0.25 s topped up while it has no charge | no: an internal hold ("RUN DOWN" on its card) |

There are no other stuns: the 0.2 s in Game._tick_zones is the storm's own top-up, and the 0.25 s in Unit's tick is the
run-down hold.

How it is drawn: scripts/stun_mark.gd, one layer over the units (Game.stun_layer, z 3: over the flyers, under the fog
clouds). It only draws while a mark lasts, only marked units on screen and seen, every star the same small texture (one
batch). The star is drawn in code (docs/art_style_inconsistency.md); an assets/ui/stun_stars.png, when there is one,
replaces it.

Test: tools/test_stun_mark.gd. Pictures: tools/shot_stun_mark.gd and tools/stun_mark_gif.py, in docs/shots/stun_mark/.
