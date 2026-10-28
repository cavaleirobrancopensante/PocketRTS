# The new Brood (experiment)

The owner's redesign of the Brood, built as an experiment you can pick. The old Brood stays as it is and stays the default.

Where the decisions come from: docs/idea_brood_mobile_buildings.md (the owner's lines, in order). Code: scripts/brood_new.gd (the rules), scripts/ai_brood_new.gd (the computer). Art: tools/import_brood_new.py. Test: tools/test_brood_new.gd.

## How to play it

- In the skirmish setup, pick "The Brood (new, experiment)" in a slot's faction list. It is the last one.
- It plays as the Brood: same grubs, warriors, essence, sounds and music.
- Not in the online lobby yet. Replays and saved games work.

## What works

- No buildings. You start with the Brood Mother, one Rootmaw and five grubs.
- At the start, the Mother and the Rootmaw play the end of their rooting. Then they are rooted.
- Kill the Brood Mother and that side is out. Nothing else counts.
- ROOT and UPROOT for the Mother, the Rootmaw and the Mound Turtle. Rooting takes 4 seconds for her, 2.5 for the others. They always root facing south-east.
- Rooted: 3 more armour, then a quarter less damage. The Mother heals 4 a second while rooted. Rooted, the Mother spreads swamp 12 tiles round her (her main base, as the old capital), a Mound Turtle 10 tiles. A Rootmaw spreads none.
- Rooted creatures still fight where they stand. The Mother swipes with her paws, the Rootmaw bites.
- Only the Mother lays eggs. She holds up to 10 and grows one every 6 seconds. Every rooted Mound Turtle makes her 10% faster, up to 30%.
- THE MOUND TURTLE (the owner, 13:25, 13:34, 13:40) is the old Clutch Mound, the Brood's expansion and its tank: a huge swamp turtle hatched from one of her eggs. Rooted, it sinks into the mud, gives 12 supply, makes her lay faster and turns the ground round it to swamp. Uprooted, it walks slowly and gives no supply and no swamp. It has a weak bite.
- Expansion: a Rootmaw roots only on its side's swamp, ANY swamp: the Mother's, or a lone turtle's far away (a hidden base). It need not be joined to hers. The farther from her, the more each grub trip pays, as before. Kill the turtle and its swamp shrinks back; a Rootmaw left off the swamp says "dry" and stops feeding.
- Body-block: a rooted turtle's body is 120 px across (a 3-tile ramp is 96). Nothing of another side walks through it, so a rooted turtle on a ramp closes it like the Crown's wall. Its own side's creatures climb over the shell, as friends pass a gate. Flyers pass over. tools/test_brood_new.gd checks it on a real ramp: 8 Raptors, none past in 25 seconds; uprooted and moved off, all 8 go through.
- Its art isn't drawn yet: rooted it shows the old Clutch Mound's picture, walking a smaller, brown-tinted Rootmaw (a stand-in).
- You pick a creature on her card. She lays its egg at once, rooted or walking. The egg drops behind her. The fall is drawn in code.
- The egg hatches after the creature's normal time. It cracks for the last 0.8 seconds, then the creature stands on the open shell while it breaks apart.
- The Rootmaw roots on fresh ground on its side's swamp: 3,000 food in a 5-tile circle. Two rooted circles may not overlap. Old ground keeps what was left, like the old pits.
- A rooted Rootmaw drinks 4 food a second from its ground into its body. It holds 300. Its 6 filling frames show how full it is.
- Grubs take the food at its flank and carry it to the Mother. The farther, the more a trip pays, as with the old pits. Each Rootmaw takes 6 grubs, one more every 4 tiles beyond 6, up to 12.
- The grubs have their new harvesting animation at the flank.
- UPROOT spills the Rootmaw's food as a pile on the ground. Grubs can still collect it. It rots, 0.6 a second. The Rootmaw walks off thin and quick.
- HAUL uproots it full. It walks at half speed with its food. Rooted again, it keeps it. Killed while hauling, all its food bursts out as a pile. A move order to a rooted Rootmaw also hauls, so food is never lost by accident.
- The Tyrannosaur is the father of the ground warriors: Raptors, Brutes, Spore Mothers and Mist Toads.
- A warrior's egg can only be laid while the Tyrannosaur stands within 7 tiles of the Mother.
- The Tyrannosaur fertilises the eggs near him: his head-lowered breath, a red-gold mist drawn in code, and the egg turns red. 1.5 seconds an egg. He only does it standing still, not fighting.
- An egg he does not reach in 25 seconds hatches as a grub. The price difference is paid back.
- Only one Tyrannosaur at a time. An egg for one counts. If he dies, lay another.
- Essence: grubs harvest bodies to the Mother. SACRIFICE happens at the Mother (the owner, 13:25): the creature walks to her and she devours it with a swipe. There is no Brood Pen creature.
- THE MOTHER IS THE DEFENCE (the owner, 13:20): no tower, no guard creature. Rooted at home with only her grubs, she beats an early all-in by herself. tools/test_brood_new_defence.gd checks it: 9 Raptors, 3 Horsemen, 5 Musketeers, 12 Clock Soldiers, 2 Brutes with 6 Raptors. She lives through every one with 1,700 to 2,400 of her 2,400 health left. Her numbers were not changed for it.
- The computer can play it. It keeps the Mother rooted at home, roots Rootmaws on fresh swamp round her, roots Mound Turtles round her for supply ahead of need, keeps grubs on them, lays the Tyrannosaur and keeps him by her, lays Raptors and some Brutes, and attacks in waves. Anything near the Mother is fought by everything.

## The numbers

- Brood Mother: 2,400 health, armour 1, speed 24, paw 40 damage every 2.4 s. Gives 16 supply, as the old Burrow.
- Rootmaw: 450 health, armour 0, speed 80 (40 hauling), bite 14. Costs 75, 18 s.
- Mound Turtle: 600 health, armour 2, speed 26, bite 6 every 1.6 s. Costs 150 biomass, 25 s. Rooted: 3 more armour and a quarter less damage, 12 supply, eggs 10% faster (up to 3), swamp 10 tiles, a body 120 px across.
- Fairness of the turtle (docs/design_principles.md): the Crown closes a ramp with a Cottage and a Gate: 150 gold, 400 + 300 health, armour 1 and 2, and 8 supply. One rooted turtle closes it for the same 150, with 12 supply. Its supply costs 12.5 biomass a point, as the Cottage's 12.5 gold. It is harder to break than one Cottage (a Musketeer's ball does about 11 to it, 19 to a Cottage), but it is a single piece: the Crown's Gate falls in 17 balls, the turtle in about 55. It is slow (26) and gives nothing uprooted, so walling with it costs the Brood its swamp and supply elsewhere. Against small claws it is very hard (a Raptor does about 1 a bite): that is the rooted armour rule, the same for the Mother.
- Tyrannosaur: 1,000 health, armour 2, speed 64, bite 42 every 1.9 s. Costs 200, 35 s, 4 supply.
- Egg: 80 health, armour 1. Food pile: nobody's, cannot be attacked.
- The starting Rootmaw holds 120 food, so the grubs start at once.
- All numbers are in Defs.NB and the creatures' entries of Defs.UNITS. They are a first guess.

## Claude's choices, for the owner to confirm

- Supply: decided by the owner: the Mound Turtle. The Mother gives 16 (the old Burrow's), each rooted Mound Turtle 12, up to 200. Moving a turtle costs its supply while it walks.
- Essence and sacrifice: kept. Bodies and offerings go to the Mother.
- The old buildings' roles (the owner's, 13:20 and 13:25): the Burrow is the Mother, the Feeding Pit the Rootmaw, the Clutch Mound the Mound Turtle, the Spawning Den and Gorge Pit the Tyrannosaur, the Roost the Pterodactyl (later). The Brood Pen has no creature: SACRIFICE is at the Mother. Burrow upgrades: none; the Mother holds 10 eggs.
- Swamp (the owner's rules, 13:34 and 13:40): only round the rooted Mother and Mound Turtles. A Rootmaw needs it to root and feed. It still makes the Brood faster and heals it.
- Not in the new Brood yet: Spitters (their father comes later), Bloaters and Skywings (the Pterodactyl comes later). The Mother's card does not offer them.
- Research: none yet. The old Brood's upgrades lived in buildings.
- Unfertilised warriors' eggs: they wait 25 seconds for the father, then hatch as grubs.
- The Mother can be uprooted and walked. The computer never does.

## What is missing

- Online play: the faction is not in the online lobby yet. The game already sends the new state, so it should be a small step.
- The other fathers: the Pterodactyl and the Spitter father.
- Research and upgrades for the new Brood.
- The computer is simple. It does not move the Mother, does not haul food, does not close its ramp with a turtle, does not make hidden bases, does not use essence for much, and does not scout. Its economy is slow in the first five minutes.
- Done in code for now: the breath mist, the egg's red tint once fertilised, the egg's fall. Listed in docs/art_style_inconsistency.md. The egg and the food pile are the owner's sheets; the pile shows the frame that matches what is left and what has rotted.
- Sounds reuse the old Brood's.
- The Mother's attack shows her standing pose even when rooted.
- Determinism: a match with the new Brood repeats exactly for about as long as an old one does (tools/test_determinism.gd, with budget: 60 seconds against the old game's 30 to 40). Neither is fully repeatable yet.

## Tests and pictures

- tools/test_brood_new.gd: rooting buffs, laying while walking, fertilising only near the Mother, unfertilised eggs hatch as grubs, one Tyrannosaur, a Rootmaw drinking its ground, UPROOT spills, HAUL carries and bursts, grubs carry food to the Mother, killing the Mother loses, a saved game continues, the Mound Turtle's supply and faster eggs, SACRIFICE at the Mother, a Rootmaw only on swamp (a far turtle's too) and dry when its turtle dies, a rooted turtle closing a real ramp.
- tools/test_files.gd checks the new creatures' art and icons. tools/test_replay.gd passes with b:brood_new.
- tools/test_brood_new_defence.gd: the rooted Mother alone against five early all-ins.
- tools/sim_brood_new.gd plays a computer match and prints the sides every 30 seconds.
- Pictures: docs/shots/brood_new/ (tools/shot_brood_new.gd, then python3 -I tools/brood_new_gif.py docs/shots/brood_new).
