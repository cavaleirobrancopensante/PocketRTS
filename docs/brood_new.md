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
- ROOT and UPROOT for the Mother and the Rootmaw. Rooting takes 4 seconds for her, 2.5 for the Rootmaw. They always root facing south-east.
- Rooted: 3 more armour, then a quarter less damage. The Mother heals 4 a second while rooted. Rooted creatures spread swamp: 9 tiles round the Mother, 4 round a Rootmaw.
- Rooted creatures still fight where they stand. The Mother swipes with her paws, the Rootmaw bites.
- Only the Mother lays eggs. She holds up to 10 and grows one every 6 seconds. Every rooted Rootmaw makes her 10% faster, up to 30%.
- You pick a creature on her card. She lays its egg at once, rooted or walking. The egg drops behind her. The fall is drawn in code.
- The egg hatches after the creature's normal time. It cracks for the last 0.8 seconds, then the creature stands on the open shell while it breaks apart.
- The Rootmaw roots on fresh ground: 3,000 food in a 5-tile circle. Two rooted circles may not overlap. Old ground keeps what was left, like the old pits.
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
- Essence: grubs harvest bodies to the Mother. SACRIFICE offers creatures at the Mother.
- The computer can play it. It keeps the Mother rooted at home, roots Rootmaws on fresh ground round her, keeps grubs on them, lays the Tyrannosaur and keeps him by her, lays Raptors and some Brutes, and attacks in waves. Anything near the Mother is fought by everything.

## The numbers

- Brood Mother: 2,400 health, armour 1, speed 24, paw 40 damage every 2.4 s. Gives 40 supply.
- Rootmaw: 450 health, armour 0, speed 80 (40 hauling), bite 14. Costs 75, 18 s. Gives 20 supply while rooted.
- Tyrannosaur: 1,000 health, armour 2, speed 64, bite 42 every 1.9 s. Costs 200, 35 s, 4 supply.
- Egg: 80 health, armour 1. Food pile: nobody's, cannot be attacked.
- The starting Rootmaw holds 120 food, so the grubs start at once.
- All numbers are in Defs.NB and the three entries of Defs.UNITS. They are a first guess.

## Claude's choices, for the owner to confirm

- Supply: the Mother gives 40, each rooted Rootmaw 20, up to 200. No supply creature. Moving a Rootmaw costs its supply while it walks.
- Essence and sacrifice: kept. Bodies and offerings go to the Mother.
- The old buildings' roles. Clutch Mound: supply and swamp now come from rooted Rootmaws. Spawning Den and Gorge Pit: the Tyrannosaur. Brood Pen: the Mother takes offerings. Roost: the Pterodactyl, later. Burrow upgrades: none; the Mother holds 10 eggs.
- Swamp: kept, but only round rooted creatures. It still makes the Brood faster and heals it. Nothing needs swamp to be placed, since nothing is built.
- Not in the new Brood yet: Spitters (their father comes later), Bloaters and Skywings (the Pterodactyl comes later). The Mother's card does not offer them.
- Research: none yet. The old Brood's upgrades lived in buildings.
- Unfertilised warriors' eggs: they wait 25 seconds for the father, then hatch as grubs.
- The Mother can be uprooted and walked. The computer never does.

## What is missing

- Online play: the faction is not in the online lobby yet. The game already sends the new state, so it should be a small step.
- The other fathers: the Pterodactyl and the Spitter father.
- Research and upgrades for the new Brood.
- The computer is simple. It does not move the Mother, does not haul food, does not use essence for much, and does not scout.
- Done in code for now: the breath mist, the egg's red tint once fertilised, the egg's fall. Listed in docs/art_style_inconsistency.md. The egg and the food pile are the owner's sheets; the pile shows the frame that matches what is left and what has rotted.
- Sounds reuse the old Brood's.
- The Mother's attack shows her standing pose even when rooted.
- Determinism: a match with the new Brood repeats exactly for about as long as an old one does (tools/test_determinism.gd, with budget: 60 seconds against the old game's 30 to 40). Neither is fully repeatable yet.

## Tests and pictures

- tools/test_brood_new.gd: rooting buffs, laying while walking, fertilising only near the Mother, unfertilised eggs hatch as grubs, one Tyrannosaur, a Rootmaw drinking its ground, UPROOT spills, HAUL carries and bursts, grubs carry food to the Mother, killing the Mother loses, a saved game continues.
- tools/test_files.gd checks the new creatures' art and icons. tools/test_replay.gd passes with b:brood_new.
- tools/sim_brood_new.gd plays a computer match and prints the sides every 30 seconds.
- Pictures: docs/shots/brood_new/ (tools/shot_brood_new.gd, then python3 -I tools/brood_new_gif.py docs/shots/brood_new).
