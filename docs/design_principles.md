# Design principles

Adapted from Callum McCole's RTS design essays (callummccole.wordpress.com: "Is Balance Overrated?",
"Anti-Snowball Design in RTS", "What Makes RTS Games Fun: Meaningful Base Building", "Why We Play RTS").
The owner rates this advice highly: read it before any balance, economy, AI or building change, and
cite the rule you are following in the commit message.

## 1. Fairness before perfect balance
- Aim for **fairness and counterplay**, not symmetry. A mirror match is balanced and the least loved.
  Asymmetric factions stay fair when every strong thing has a way to be answered.
- Prefer **soft counters** (spread out, close the range, use terrain) to hard counters; keep hard
  counters few and clear.
- Niche units are fine if they shine in a defined context. Do not pile up situational options.
- **Telegraph** powerful effects (cast time, flare, sound, a visible carrier) and give the player time
  to react. Reaction time matters more than cost or raw power for how fair something feels.
- A punishment should match the mistake. No random swings the player could not prevent.
- Keep damage modifiers few and intuitive; justify targeting restrictions by the fiction.
- Keep mechanics consistent with the art style and fiction.
- Separate modes (vs AI, 1v1, teams) if a change would help one and break another.

## 2. Anti-snowball (small leads must not decide the game)
- **Army scaling is non-linear**: attention cost, clumping and choke penalties, counters, ranges small
  relative to unit size, mass-of-one-kind penalties.
- **Economy forces expansion and is depletable**: saturation limits, soil/ground that runs down, income
  that is exposed (workers, buildings, captured points). No permanent safe global bonuses.
- **Supply caps, cheap rebuilding and refunds** let the loser recover; a big bank must not be a win button.
- **Retreat** must be possible so a lost battle is a lost territory, not a lost game.
- Pro-snowball mechanics (veterancy, upgrades) each need an offsetting brake.
- Brakes work **quietly** (a slow upkeep, not a sharp threshold that punishes the leader consciously).
- **Defender's advantage** early (walls, gates, high ground) that fades mid-game so a winner can finish.
- Alternative win conditions keep comebacks alive.

## 3. Meaningful base building
- Design the economy first: placement matters only when drop-offs, depletion and travel make it matter.
- Walls and chokes matter only if clumping costs damage; unit range vs size must support it.
- Buildings need **utility, vulnerability and interactions** (garrison, capture, sabotage, repair).
- Builders must have an **opportunity cost** and be fragile or slow enough to be worth harassing.
- Buildings should **reveal strategy** fairly (scouting and counter-scouting); let players hide key tech.
- Prefer mutually exclusive placement trade-offs over pure adjacency maths.

## 4. Why we play (what to protect)
- Mastery across economy, production, tech and tactics; every choice has an opportunity cost.
- The player is the strategist: several ways to win (counter, out-earn, out-micro).
- Visible growth from almost nothing, with constructions that have a real purpose.
- Epic scale; battles that carry the weight of the whole match.
- Gentle onboarding: complexity is the main cost.

## Where this already shows in PocketRTS, and open questions
- Soil and ground depletion, saltpetre and the Burrow/Town Hall expansion pressure follow section 2.
  Playtest v0.12.4 (Frostmere, Crown vs Hard Brood): soil hit 0% at about 10 minutes and the Crown sat on
  1,000-2,100 unspent gold at the 100/100 supply cap. Depletion should force expansion, not strangle it,
  and a big bank plus a hard cap is the "bank as win button" problem.
- Gates, walls, high ground: defender's advantage; check it fades mid-game.
- Brood sacrifice and essence, Crown powder logistics: both are exposed income, which is good.
- Open: upkeep-style quiet brake for very large armies; retreat tools; an alternative victory condition.
