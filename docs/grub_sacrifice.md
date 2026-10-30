# Grub sacrifice, sacrifice values, harvest spoils and the Mother's veterancy (0.22.4)

The owner, 2026-10-30:
- 08:19: grubs can be sacrificed, for less than a Raptor.
- 08:28: a grub gives an egg back like every other unit; the Venom Sire costs 25 spoils.
- 08:34: final numbers: a Raptor 15, a grub 10.
- 08:39: harvested bodies give twice the spoils; the Mother gains veterancy from harvests.

## What changed

- **Grubs can be offered up.** SACRIFICE (C) is on the grub's card. A grub gives **10 spoils** and **a whole egg back**.
- **A grub at work** (carrying food from a Rootmaw, on HARVEST, carrying a body's cocoon) can be sent. It hands over what
  it carries when it reaches the Mother (`Game.sacrifice`: its food, `load_f`, and its cocoon's spoils), so nothing
  carried is lost.
- **A grub on its way to morph** (order `nb_morph`: walking to become a Rootmaw, a Mound Turtle or a Sire's lure) can't
  be offered up (`Unit.can_sacrifice`), and SACRIFICE is not on its card. Once it arrives it is gone (the cocoon or
  lure is a different creature, which has no sacrifice value).
- **Set values.** `Defs.NB["sac"] = {"raptor": 15, "grub": 10}` overrides `Game.sacrifice_value`'s formula for those two
  kinds. A Raptor was 9. Every other creature stays on the formula: 35% (`Defs.SACRIFICE`) of its share of its egg's
  food price.
- **The Venom Sire costs 25 spoils** on top of his 200 food (`Defs.UNITS["dilophosaurus"]["cost2"]`). As the owner puts
  it, "sac 3 grubs to get a Venom Sire" (or two Raptors, or a few harvested bodies). The grub's BUILD card shows his lure
  at "200 food + 25 spoils" in the tooltip. With fewer spoils it is greyed out with "Not enough spoils.", and a grub
  that arrives at the spot without them is refused with the same words. The Tyrant Sire still costs no spoils, so every
  opening starts without them.

## What each creature gives when offered up

| Creature | Spoils | Eggs back | Source of the value |
| --- | --- | --- | --- |
| Grub | 10 | 1 (hatches alone) | set by hand |
| Raptor | 15 (30 an egg of two, 45 a Bigger Clutch egg of three) | 1/2 (1/3 with Bigger Clutch) | set by hand (was 9) |
| Spitter | 16 | 1/2 (1/3) | formula |
| Hatchlings | 14 | 1/2 (1/3) | formula |
| Tyrant Challenger | 35 | as the young it was | formula |
| Mist Toad | 35 | 1 | formula |
| Brute | 53 | 1 | formula |
| Venom Challenger | 53 | as the young it was | formula |
| Storm Challenger | 53 | as the young it was | formula |
| (Skywing, retired) | 35 | 1 | formula |

The Mother, the Sires, Rootmaws, Mound Turtles, eggs and food piles can't be offered up.

## The egg-back choice (the owner decided, 08:28): a grub gives a whole egg back

This is the 0.22.3 rule: the young of one egg together give one egg back. A grub hatches alone, so it is all of its
egg's young, like a Brute (`BroodNew.egg_share` already gives it 12/12). There is no exception to learn.

The worry was a loop: lay a grub (50 food, 1 egg), offer it up (1 egg back, 10 spoils), so food turns into spoils for
no eggs. That loop exists, but the Raptor loop beats it, so the grub loop is never the one to use:

| Loop (one egg) | Food in | Spoils out | Food per spoil | Needs |
| --- | --- | --- | --- | --- |
| Grub | 50 | 10 | 5.0 | nothing |
| Raptors, plain egg | 50 | 30 | 1.7 | a Tyrant Sire rooted beside her |
| Raptors, Bigger Clutch | 75 | 45 | 1.7 | the Sire and the research |

So the grub loop buys spoils three times dearer than Raptors do. It also costs hatch time (12 s), the walk, and supply
while the grub lives. Its real use is the one the owner wanted. Late, when the Rootmaws run dry (resources run out, by
the owner's design), spare grubs are turned back into eggs for warriors and a few spoils. They no longer stand idle. A
lost economy recovers part of its value (design principles, section 2: refunds let the loser recover).

## Harvested bodies: twice the spoils (08:39)

A body a grub wraps and carries to the Mother gives 4 spoils for each point of its supply (was 2). It also gives 2 for
each kill the unit made (was 1), with the kills part capped at 100 (was 50). The values are `Defs.HARVEST` "per_supply",
"per_kill" and "kill_cap", used by `Game.corpse_value`. Examples: a Raptor 4, a Musketeer 4, a Brute 12, a Horseman
with his horse 16, a veteran with 20 kills +40.

## The Brood Mother's veterancy from harvest (08:39)

- Every harvest a grub DELIVERS to her gives her 1 veterancy. That is a body wrapped and carried home, of either side.
  A grub offered up while carrying a cocoon counts too, because it hands the body over. Each veterancy point is +1%
  laying, up to 50 (+50%). The values are `Defs.NB` "hvet_rate" and "hvet_max".
- It stacks with her other levers the way they already stack: `BroodNew.lay_rate` is stage rate x (1 + 20% a father near
  + 15% a turtle on new ground + 1% a veterancy point). `lay_rate` also returns the veterancy as its 5th value, and her
  "Laying +X%" line names it ("veterancy 23").
- It is kept on her as `nb["hvet"]`, a whole number. It is saved (`unit_save` / `unit_load`), sent online with the rest
  of `nb` (net_snapshot), and replay-safe: it changes only in the simulation, at a delivery.
- Shown: once she has some, her card has an info button "VETERANCY 23 · EGGS +23%" with a tooltip, and her laying
  tooltip lists it as the fourth lever. The game's veteran look (VetLook: amber, then obsidian skin) needs a skin mask
  per sprite strip, and the Mother has none. It also counts kills, not harvests. So she gets no recolour. A small mark
  over her could be added later; it would be drawn in code, so it would go in docs/art_style_inconsistency.md.
- Her kills still give her the normal kills veterancy (damage), as before. The two are separate.

### Is it a snowball? (the owner's view, 08:44)

It is not a flat snowball. Faster laying still needs food to turn eggs into units; the veterancy only lifts the
laying-time limit. That limit, one Mother laying every egg, is part of the Brood's income gap that the coaching found,
so this also eases it.

Its brakes (design principles, section 2):
- the cap: +50% at most;
- bodies come from both sides: the side that lost a fight harvests too, often more, because its dead lie at home;
- bodies rot (Defs.ROT) and area shots tear them up (Defs.BODY_BLAST), so the enemy can deny the harvest.

The owner may want a slow decay later (a quiet brake), for example 1 point lost per minute without a harvest.

## The computer (scripts/ai_brood_new.gd was not edited: the brood-eco job owns it)

- `_nb_essence` offers up spare home **Raptors** while spoils are short of what it wants now. Each one now gives 15, not
  9, so it reaches its spoils target with fewer Raptors (about 3 instead of 5 for the 45 its stage-2 floor wants). Its
  home guard rule is unchanged.
- **The Venom Sire now needs 25 spoils. This can stall the computer.** `_nb_morphs` checks `morph_problem` before it
  sends a grub. With too few spoils it gets "Not enough spoils.", sets `_morph_keep` to his FOOD price (200) and
  returns. So it holds back food (the eggs wait) and makes no Rootmaw or far turtle meanwhile: `_nb_next_father` comes
  before them in its chain. `_nb_spoils_want` does not count the Venom Sire, so nothing offers up Raptors for those 25
  spoils. Only harvested bodies bring them in. Fix for the brood-eco job: add the Venom Sire's `cost2` to
  `_nb_spoils_want` while he is the next father, and keep food only when the shortfall is food.
- Harvest pays twice as much now, and the computer already sends two grubs to harvest bodies near home
  (`_nb_essence`). So it reaches its spoils targets sooner, and its Mother gains veterancy (faster laying) from those
  harvests with no change to the computer.
- The computer never offers up grubs. If wanted, spare grubs (more than its Rootmaws can crew, at the supply cap or with
  dry Rootmaws) are a cheap late source of eggs and spoils. Its morph picker (`_nb_morphs`, the grub it chooses) should
  then skip grubs on `order == "sacrifice"`.

## Tests

tools/test_brood_new.gd section 11b (`_grub_sacrifice`):
- the set values: a grub 10, a Raptor 15, a Brute on the formula (53);
- SACRIFICE (C) is on a grub's card;
- an offered grub gives +10 spoils and a whole egg (2 to 3 eggs);
- a grub carrying 7 food and one carrying a 6-spoil cocoon hand them over (+26 spoils, +7 food);
- a grub walking to morph can't be offered up and has no SACRIFICE button;
- the Venom Sire's price shows as "200 food + 25 spoils"; he is refused with 20 spoils and allowed with 25;
- a delivered harvest gives the doubled spoils (a Musketeer with 3 kills: 4 + 6 = 10) and +1 veterancy;
- 60 harvests cap her at 50 (+50%), and her laying rate rises by exactly that share;
- the veterancy button is on her card.
