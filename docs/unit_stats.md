# The stats row on the unit card

The owner asked, on 28 October 2026, for more about each unit's attack on the unit card, with icons, for every faction. That includes the new Brood's structure-units when they walk as units.

## What it shows

Under the unit's lines on the selection card there is now one row of small chips. Each chip is an icon and a number. From left to right:

- The attack: the damage of one hit. The icon says the kind of attack: melee (a sword), ranged (a ball), or area (a burst).
- Attack speed: the time from one attack to the next, in seconds. That is aim, plus the blow, plus the reload.
- DPS: damage a second, on one target with no armour.
- Range, in tiles.
- Bonuses: against armoured units, against buildings, against light units, against flyers, or against named units.
- Hits flyers: shown when the unit can hit air.
- Armour, health, speed in tiles a second, sight, and supply.
- At the end, in gold letters, the names of its special attacks and abilities, such as BAYONET, PISTOL, CHARGE, CANISTER, SWEEP, ROOT or WIND.

A unit with no weapon shows a red barred sign instead of the attack chips.

## Numbers as they are now

Every number is what the unit has right now, not just what the book says. Veterancy, the musket locks, the Armour refit, Prepared Charges, the Gunner's Quadrant, a run-down Clockwork unit, overload, Shield Forward, acid, and rooting all count. A number that changed from the trained value is light blue when it is better and orange when it is worse. The trained value and the reason are in the tooltip.

## Tooltips

On a computer, hold the mouse over a chip. On a phone, tap it. The tooltip gives the full numbers and a line on what they mean. The gold special names open one tooltip with a line for each special attack.

## The new Brood's structure-units

The Rootmaw, the Mound Turtle, the Tyrannosaur and the Brood Mother show their bite when they are uprooted. Rooted, the attack chips become one red chip that says ROOTED, meaning it cannot attack. Its tooltip says what the attack will be once uprooted. The armour chip shows the rooted bonus of 3 in light blue, and speed shows 0.

## Groups

For a group, the row shows the first unit's stats. On a computer, hovering over a portrait in the group shows that unit's stats instead.

## The icons

The icons are the owner's ChatGPT sheet, with the melee icon taken from his redo. His second sheet, `art/redraws/stat_icons_light_dps_chatgpt.png`, adds two: bonus against light units (a sword striking a cloth tunic) and damage a second (an hourglass with a blood drop). The damage-a-second chip now shows that icon and the number, without the letters DPS. The tool `tools/import_stat_icons.py` cuts both sheets into `assets/ui/stats`. It cuts away the brass frames, because at 18 pixels a frame leaves the picture too small. Named bonuses still have no icon of their own and borrow the bonus-against-armoured icon.

## Checks and pictures

The test is `tools/test_unit_stats.gd`. It builds the stats for every unit of every faction, armoured ones too, and checks that damage a second, range and attack time are sane. It checks the effective values and the rooted Brood. It checks that the row fits at 200 and 1100 pixels, and that the Portuguese and Spanish texts are there.

The pictures are in `docs/shots/unit_stats`. They are made by `tools/shot_unit_stats.gd`, on the computer at 1600 by 900 and on a phone at 915 by 412.
