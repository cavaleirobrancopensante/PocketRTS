# Clock charge on the card and over units; the Netter's net (0.24.4)

The owner's playtest of 2026-10-30 (Clockwork): the Springer's card did not show its charge; the charge is important,
so show it on the card and as a bar over units (hideable); the Springer's screw was too small in flight; the Netter
shut a unit down completely, too strong.

## Charge

- Which units: `Unit.has_charge()`: every Clockwork non-worker except the Great Winder (it never runs down). The
  charge is `Unit.wind` (0..1).
- Winding: `Unit.charge_winding()`: on its side's gear field (`_in_field`), cranked by a Winder (`cranked_t`),
  overloaded, or inside a Great Winder's ring (`wound_until`, set by `GreatWinder.wind_area`).
- Card (scripts/ui/hud.gd): an amber bar (5 px) under the health bar, pale gold while winding, red under 20%; the
  text line starts with `Unit.charge_text()`: "Charge 63%", "Winding up: 63%", "Fully wound", "RUN DOWN". Own,
  allied and demo/spectator views only. The old "Charge N%: it runs down..." line is now "It runs down away from the
  gear field..." (off the field only), so the number is not said twice.
- Group panel: a 2 px charge line under each portrait's health, only when not full.
- Over units (Unit._draw_charge_bar, from `_draw_unit` under the health and reload bars): 2 px, own/allied units
  only, hidden when full (on or off the field), so a wound army shows nothing. It rides the existing `_draw_key`
  redraw path (wind in 1/40 steps, plus a winding flag and the setting), so no extra per-frame cost in big battles.
- Setting: SHOW CHARGE BARS (`Settings.charge_bars`, `ui/charge_bars`, default on).

## Springer screw

`Defs.SPRINGER_SHOT["fly_scale"]` 0.75 (was drawn at `shot_scale` 0.42: ~1.8x) in flight only; sparks on impact stay
at `shot_scale`; the damage lands at once as before (looks only).

## Netter

A caught unit (Unit.net_t > 0) cannot move (`Unit._move` zeroes its velocity), cannot cast (`Game.spell_problem`,
`Unit._cast` waits), cannot start a TONGUE (a windup breaks), JUMP or MORPH (their own checks), but it attacks
whatever is in its reach (the net no longer calls `Unit.stun`; a blow or shot under way goes on, a spell being cast is
lost). A flyer still comes down (`Unit.is_air`). No stun stars. Saves: `net_t` alone holds it after a load.

Tests: tools/test_clock_charge.gd (card text, bar show/hide, the setting, the screw size, a netted Musketeer fires
but does not move), tools/test_cw_tier3.gd (a netted Springer fires at a target in reach), tools/test_stun_mark.gd.
Pictures: docs/shots/clock_charge/ (1: bars off the field and the Springer card "Charge 44%"; 2: a group's portraits; 4: the bigger screw in flight), from tools/shot_clock_charge.gd.
