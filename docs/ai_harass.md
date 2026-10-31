# The computer's harass (0.24.24, branch ai-harass)

## What the owner saw

Hard Clockwork (Balanced) v Hard Brood (Air rush), Highmoor, 0.24.21. At about 2:31-2:50 the Clockwork's first Clock
Soldier went out alone, met a ROOTED Mound Turtle on the Brood's new ground and stood hitting it. The owner:
"clockwork ai sent 1 clock soldier to harass and stopped to attack a turtle, instead of stopping he should have pushed
and scouted and tried to harass the worker line of brood, forcing brood to uproot the tyrant to deal with it".

## Why it happened

Replaying that match up (tools test, seed 1) showed the soldier was not sent on purpose: it was a DETACHMENT
(AI._defend) sent after the Brood's scouting grub at the Clockwork base. When the detachment was let go it was given an
attack-move home, but an attack-move keeps chasing the target it already has, so it followed the grub right across the
map; the grub got away and the next thing in reach was the rooted turtle. Nothing in the computer steered it after that.

## What changed (scripts/ai_harass.gd, AIHarass; AI.hz())

- **Strays become harassers.** An army unit (any faction run by AI._army: Crown, Clockwork) that is out alone far from
  home (900 px from our nearest building, not in a wave, a detachment, a guard post, the Crown's raid, the scout or an
  errand) is taken by the harass, at most 3 at a time.
- **Structures are walked past.** Buildings, walls, turrets and ROOTED Brood creatures (Mound Turtles, Rootmaws, a
  rooted Sire or Mother, cocoons, eggs, food piles) are never chosen. A harasser that its attack-move locked onto one
  gets a plain move past it. Only when it is stuck (3 s without moving) does it attack-move to break through.
- **Workers first.** Its prey is grubs, Labourers and Winders (and units that can't fight back) within 12 tiles. A worker
  inside an armed defender's reach counts as farther away, and so does one walking away as fast as the harasser (it
  would never be caught). A grub loading at its Rootmaw stands still and no rooted creature attacks, so those come
  first. The worker it is already after is kept unless another is clearly better. With no prey in
  sight it walks to the worker line: workers it can see, else economy buildings, else (against the Brood) the Rootmaws
  or the Mother it has seen, else the enemy's base; there, with nothing to hunt, it loops round the base.
- **Real defenders.** A Sire (any father) or the Mother on her feet, or armed units worth more than the party: it pulls
  back for 6 s, then comes again. A weaker armed unit that reaches it is fought. Pulled back 3 times, hurt below 35%, run
  down (a construct out of wind) or out 150 s: it goes home and is let go (not taken again for 60 s).
- Orders are given every army think (about once a second): attack orders on chosen workers, plain moves past the rest.
- **The Crown's raid** (AI._raid, AI._hunt) goes to the same worker line, rides past rooted creatures as it rode past
  buildings, and rides home from a Sire or the Mother on her feet, or from armed units worth more than the party.
  With every grub in sight killed it waits beside the Rootmaw for the next one (plain move; attack-move only with an
  armed enemy near), never hitting the Rootmaw or turtle (0.24.28: on main it stood 31% of the time on the turtle).
- **The scouts.** The scout no longer counts a rooted creature as a threat, so it no longer stops to fight one or backs
  off from one. A soldier scout (AIScout) or the Brood's Raptor scout bites a worker within 6 tiles on its loop and walks
  past rooted creatures.
- A big army push keeps its own targeting (it may hit structures).

## Test

`tools/test_ai_harass.gd`: a Brood base with its computer off, a rooted Mound Turtle in the way and grubs working a
rooted Rootmaw behind it.
- [clock] One Clock Soldier on attack-move into the turtle, taken by the harass: within 40 s the grubs are hurt and it
  spent under 25% of its time on the turtle; a Tyrant Sire comes at it: it pulls back and lives; the Sire gone, it comes
  again.
- [horse] The same with one Crown Horseman.
- [raid] The Crown's raiding party (two Horsemen in AI._raid): grubs hurt, the turtle left alone, a Sire rides them home.

Since 0.24.24 (brood-fix3) the swamp spreads 1 tile a second from a rooted turtle, so the test waits for it to reach
the Rootmaw's spot before rooting the Rootmaw; the Sire comes over open ground (a clear straight walk to the harasser).

## Open

- The Brood's own computer (ai_brood_new.gd) has its own army logic; only its Raptor scout uses the harass rules.
- The computer does not yet send a harass on purpose (a planned early poke). It harasses with what is already out
  (strays, the Crown's raid and the scouts).
