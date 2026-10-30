# The Mother's egg tooltip and the card's worker chips (0.22.7)

The owner, 2026-10-30 09:06. Branch `egg-tooltips`.

## 1. The egg tooltip (scripts/egg_tip.gd)

Over the Brood Mother the game draws her egg line, `4/10  4.8s · 00:35`: eggs she holds / her clutch's size, the
next egg (tenths of a second under 10 s, else mm:ss) and the time until her clutch is full (BroodNew.next_egg_in,
full_in, clock_text). `EggTip.label_text` is that text (BroodNew.draw draws it), `EggTip.label_rect` is where it is
(the whole line, a few px of slack), `EggTip.at` finds it under the mouse.

Resting the mouse on it for 0.5 s (TIP_LABEL_DELAY, the same as the worker labels: Hud._hover_at / _tip_of) opens
`EggTip.tip`:

- **head**: `6 eggs of 15 · next egg in 1.4s · clutch full in 00:27`, then `Laying x1.91: 19.1 eggs a minute, one
  every 3.1 s.`
- **body**: what the numbers over her mean; her clutch's size at her stage and at each stage (10 / 15 / 20: GROW
  raises it); the base (one egg every 6 s at stage 1); each lever with its value (BroodNew.lay_rate):
  her stage (x1.0 / x1.3 / x1.7), the Sires within 7 tiles named (+20% each, their pheromones), the Mound Turtles on
  new ground (15 tiles or more from her and each other: +15% each, up to 3; the ones rooted nearer are counted as
  giving nothing), her harvest veterancy (+1% each, up to 50); and the sum (`x1.3 x (1 + 0.47) = x1.91`).
- **hint**: what stops her laying, the present case first (`NOW: she is growing`, `NOW: her clutch is full`, `NOW: the
  Tyrant Sire is researching`), then the rule: growing and a full clutch stop her; a Sire who researches fathers no
  eggs of his line; she keeps laying while she researches.

The same text is on her card's LAYING button (Hud._nb_buttons: `_tip_fn`, a live tooltip) and on the EGGS chip of
her card (below): one text, three places. Only for her own side (and spectators, the demo): `EggTip.shown_to`, the
rule her egg line is drawn by. The map hover is mouse only (as asked).

Her fastest: stage 3 x1.7 x (1 + 0.6 three Sires + 0.45 three far turtles + 0.5 full veterancy) = x4.3, about one egg
every 1.4 s.

## 2. The card's chips (scripts/card_tips.gd)

The unit card had no icon for its workers, its resource or the Mother's eggs (the counts were only on the map labels
and in the info line). Now the stats row (UnitStats.draw_row) starts with `CardTips.chips`, each opening the same
tooltip as its map label (a mouse resting on it after 0.35 s; a tap on a phone, as every stat chip):

| card | chips | tooltip |
| --- | --- | --- |
| Brood Mother | egg `7/15`, grub `5` (grubs bringing her food) | EggTip.tip; CardTips.mother_food_tip |
| Rootmaw (rooted), food pile | grub `5/6`, food dot `129` | WorkerLabels.tip (its GRUBS label) |
| Town Hall | Labourer `0/2` (haulers assigned / needed) | WorkerLabels.tip (HAULERS) |
| Farm | Labourer `3/8`, soil dot `78%` | WorkerLabels.tip (FARMERS) |
| Powder Mill | Labourer `2/6`, saltpetre dot `100%` | WorkerLabels.tip (POWDER MAKERS) |
| Cog Press | Winder `2/4`, brass dot `90%` | WorkerLabels.tip (WINDERS) |
| Mainspring | Winder `2/4` | WorkerLabels.tip (WINDERS) |
| Horse Breeder | Labourer: its Town Hall's haulers | that hall's WorkerLabels.tip |

The egg is the first frame of the egg's own sprite; the workers are their portraits; the resources are a dot in their
top-bar colour (code-drawn; listed in docs/art_style_inconsistency.md). Own side only (spectators and the demo see
all).

## Tests and pictures

- `tools/test_egg_tooltips.gd`: a stage-2 Mother with the Tyrant Sire near, a turtle 18 tiles out, 12 veterancy:
  every number of the tooltip against lay_rate, translated in pt and es, a full clutch says so; the map hover (centre
  and end of the line) gives the tooltip after the labels' delay; her EGGS chip, its hover and her LAYING button give
  the same text; nothing for the enemy; the Rootmaw's, Town Hall's, Farm's, Mill's and Horse Breeder's chips carry
  their label's count and tooltip.
- `tools/shot_egg_tooltips.gd` -> docs/shots/egg_tooltips/: map_hover.png, card_egg_chip.png,
  card_rootmaw_grubs.png, card_hall_haulers.png, card_farm_soil.png.
