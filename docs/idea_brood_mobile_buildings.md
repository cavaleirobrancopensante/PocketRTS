# Idea: Brood buildings that walk (the owner, 2026-10-27, "a crazy idea")

Not decided. Only being considered. Nothing to build yet.

## The owner's words
- He is thinking of making the Brood's buildings mobile units: a true swarm, not rooted in the ground.
- A slow Queen is the main base building.
- Each building is grown from a grub, but it is a walking unit.
- You can unroot a building and move it.
- So a building is either rooted (working as a building) or moving, and while moving it is mostly a slow fighting unit, if needed.
- He doesn't know yet how resources would be mined with an idea like that.

## Open questions (to talk through with him later)
- Mining: do rooted buildings feed from the ground under them, or do grubs still carry food to a rooted Queen or Feeding Pit?
- What a building can do while walking (train, research, supply) and what stops.
- How long rooting and unrooting take, so moving a base is a choice with a cost.
- Fairness with the Crown and the Clockwork, whose bases cannot run away (docs/design_principles.md).

## Proposal (Claude, 2026-10-28), for the owner to decide

Still not decided. This is how it could work. The owner asked for both: this proposal and the Brood economy pass (cloud job, branch brood-econ).

### Precedent
- WarCraft III's Night Elf Ancients pulled up their roots, walked, fought and rooted again. Players loved it. Their known abuse was walking production buildings to the enemy's door ("Ancient rush"). The rules below stop that.

### The two states
- ROOTED: the building works as now. It trains, researches, gives supply, spreads swamp, and a Feeding Pit feeds from its ground.
- UPROOTED: it walks, slowly. It trains nothing, researches nothing, gives no supply and spreads no swamp. Its swamp starts to shrink back. It can fight a little (a heavy, slow melee blow), with its normal armour.
- Uprooting and rooting each take several seconds (say 6 to 8). The building is vulnerable while it does it. Moving the base is a real choice with a cost.

### Where it may root
- Only on the Brood's own swamp (or right at its edge), like today's building rule. Never next to enemy buildings. This stops building rushes.
- A Feeding Pit may root only where its ground circle does not overlap another pit's circle (today's rule).

### Mining: the herd grazes
- Feeding Pits feed from the ground circle where they are rooted (today: 3,000 per pit, in a 5-tile circle).
- When the ground runs out, the player uproots the pit and walks it to fresh ground. Grazing is how the Brood mines.
- Grubs still carry the food from the pits to the capital, as now.

### The Queen and the capital
- The Queen sits in the capital Burrow and can uproot with it: the slowest walker of all.
- She is the heart of the Brood. If she dies, the Brood is badly hurt (or loses; to decide). This gives the enemy a clear target, so a Brood that can always walk away still has a way to lose.

### What each building does while walking (first idea)
- Burrow (capital, Queen): very slow, strong, no eggs while walking.
- Feeding Pit: slow, weak, the grazer.
- Clutch Mound: supply; while walking, it gives no supply (so moving them costs supply for a while).
- Spawning Den, Gorge Pit, Brood Pen, Roost: tech; while walking, their tech stays known but nothing new starts.

### How to build it, step by step
1. An EXPERIMENT setting, like THICK smoke. First only the Feeding Pits and the Queen's Burrow walk. This tests the grazing loop and whether it's fun.
2. If it feels good, the other buildings walk too, each with a small fighting role.
3. The computer learns to graze (move a spent pit to fresh ground) and to move its base away from a lost fight.

### Risks
- Fairness: walls and chokes matter less against a base that walks. For the Brood the skill moves to where it roots and when it moves.
- Readability: rooted and walking must look clearly different (legs out, roots out), and the walking time must be easy to see.
- Pathing: big walking footprints need care at ramps and between buildings.
- Art: each building needs a walking look (legs or roots). At first it can be drawn in code (logged in docs/art_style_inconsistency.md), later redrawn by ChatGPT.

### Questions for the owner
- Does the Brood lose when the Queen dies, or only get badly hurt?
- Do walking buildings fight, or only walk?
- Start with step 1 (the pits and the Queen's Burrow) as an experiment?

## THE OWNER'S DECISIONS (2026-10-28 07:16): this replaces the proposal above where they differ

- The Brood mother, the QUEEN, is the Brood's losing condition: kill her and you win.
- The Brood has NO buildings. It only has units.
- Some units ROOT DOWN into the ground. The Queen is one of them.
- Rooted: they get armour and defensive buffs.
- Uprooted: they move, and they are ordinary units.
- The Queen is the one that hoards the resources (the grubs bring the food to her).

Still to settle with him (see the chat, 2026-10-28): which units root and what each does rooted (lay eggs, give supply, spread swamp, feed from the ground, unlock tech), where the food comes from (ground circles like today's Feeding Pits, grazed by rooted feeders, or grubs foraging), whether eggs come only from the Queen, and the move-or-root timing.
- (07:19) Only the QUEEN lays eggs, and she can lay them while she MOVES ("it would be very interesting to see it moving and laying eggs").
- (07:19) Rooting units take the Feeding Pits' role: a concept for that creature is being worked out (candidates in the chat: the Mire Sow, the Gorger, the Rootmaw).
- (07:21) The feeder is the ROOTMAW, a giant tick (replaces the Feeding Pit). Rooted: it latches its head into the ground and fills up like a balloon, visibly fatter as it drinks the ground (how full it is shows how much food it holds). Uprooted: thin again, it scuttles quickly. The grubs collect the food from it and carry it to the Queen.
- (07:55) FEATURE: when a match starts, the Queen and the starting Rootmaw are shown finishing their rooting down (a visual cue only: their last rooting frames play, then they are rooted).
- (07:55) Rootmaw art: ChatGPT sheets in art/redraws/rootmaw_<dir>_chatgpt.png. South-east and east are good; the south fix is weak (owner: "not up to standards"); north-east and north failed (they drew the front or turned to south-east). Plan (Claude's proposal): the Rootmaw always turns to face SOUTH-EAST before it roots (like the buildings, which all face south-east), so rooting, filling, uprooting and death are needed only in the south-east view; the other directions need only the walk. North and north-east walks to be asked again with a back-view reference (the Raptor sheet's north frame).
- (08:05) ART DIRECTION (owner): the Brood is REPTILIAN first. A mix is fine, but not too much insect, or it becomes a StarCraft Zerg knock-off. The first Brood Mother concept (art/redraws/brood_mother_concept1_chatgpt.png: mantis forelimbs, a termite egg sac) looked epic but too insect; the next one goes reptilian (a colossal crocodilian/monitor-lizard matriarch, a frill and red spike crown, leathery egg clutches, guarding her nest mound when rooted).
- (08:14) The Brood Mother concept is CHOSEN (owner: "it is incredible"): art/redraws/brood_mother_concept2_chatgpt.png, a colossal crocodile/Komodo/frilled-dinosaur matriarch with a red spike frill, leathery glowing eggs, dropping an egg as she walks; rooted, she curls round her clutch in a nest mound.
- (08:50) The Rootmaw is now a SWAMP LIZARD (owner's choice over the tick; reptilian rule). Its ChatGPT art is complete: art/redraws/rootmaw_lizard_se_chatgpt.png (south-east: walk, rooting, filling, uprooting, death), rootmaw_lizard_{s,e,ne,n}_walk_chatgpt.png (walks); concept rootmaw_lizard_concept1_chatgpt.png; the rooted pose without the grub (erased in code; that spot is for the later grub-harvesting animation): rootmaw_lizard_rooted_nogrub.png and its south-east mirror rootmaw_lizard_rooted_se.png. The Rootmaw turns to face south-east before rooting. West views mirror in code. The tick sheets (rootmaw_*_chatgpt.png without "lizard") are superseded.
- (09:51) Brood Mother walks with real strides (frame-by-frame prompt, 4 frames, crocodile diagonal gait): art/redraws/brood_mother_{e,se,s,ne}_walk_stride_chatgpt.png; north keeps its 6-frame walk (brood_mother_n_walk_chatgpt.png, which already had a gait). West views mirror in code. The south-east sheet's rooting/breathing/uprooting and death rows are used; its small-stride walk and laying rows are replaced: the egg drop is to be done in code during the stride, in every direction.
- (10:14) BOTH FIGHT (owner): the Brood Mother attacks with her massive paws (a heavy claw swipe); the Rootmaw attacks with its terrible maw (a bite). Attack sheets: south-east first, then the other directions.
- (10:45) Attack art complete in every direction (west mirrored in code): the Brood Mother's paw swipe (brood_mother_{se_attack_fixed,s,e,ne}_attack_chatgpt.png, brood_mother_n_attack_fixed.png) and the Rootmaw's bite (rootmaw_lizard_{se,s,e,ne,n}_attack_chatgpt.png). Still open: the Brood Mother's portrait; whether a full Rootmaw spills its food or carries it when uprooted.
- (11:13) IDEA (owner, being discussed): a TYRANNOSAUR as the Brood's "barracks": it fertilises the Queen's eggs into warriors; only one at a time (if it dies, train another); a powerful fighter, but taking it to fight means no warriors are fertilised meanwhile. Claude's notes in the chat: pairs with the walking Queen (a moving war camp), soften the single point of failure (quick rebuild from an egg, fertilised eggs still hatch, unfertilised eggs hatch as grubs), fertilise within a radius. Open: does it father all warriors or only the basic ones (other creatures for advanced tiers)? Only near the Queen or any egg? A new creature or an existing one (the Brute)?
- (11:17) The Tyrannosaur is a NEW creature: a massive tyrannosaur (owner).
- (11:24) DECIDED (owner): FATHERS. The Brood's tech is a set of father creatures, each fathering one line of warriors: the Tyrannosaur (massive, new) for the ground warriors, a massive Pterodactyl for the flying units, another father for the Spitters, and so on. Every father must be CLOSE TO THE QUEEN to fertilise her eggs. Only one of each father at a time; if one dies, another can be grown. A father is a powerful fighter, but taking it away from the Queen stops its line. (Replaces the old tech buildings: Spawning Den, Gorge Pit, Roost...)
- (12:31) Tyrannosaur art complete (west mirrored in code): walks tyrannosaur_{s,e,ne,n}_walk_chatgpt.png + the south-east sheets (walk/bite, breath/death); bites tyrannosaur_{s,e,ne,n}_bite_chatgpt.png (east and north each drawn twice: the chosen ones are the plain names, the others kept as *_alt_*); portrait tyrannosaur_portrait_chatgpt.png. Fertilising = the head-lowered breath frames plus a red-gold mist and the eggs turning red, drawn in code.
- (12:34) DECIDED (owner): the Rootmaw has BOTH buttons: UPROOT (spill the food as a pile, walk off thin and quick) and HAUL (carry the food, walk slow and fat). Grub harvesting from the Rootmaw's flank needs its own animation.
- (12:34) SIZES (owner): the Rootmaw a bit bigger than a Crown Cottage (2x2); the Brood Mother as big as the Clocktower's gear ring, massive; the Tyrannosaur the size of a Crown Barracks (4x3).
- (12:34) NEXT (owner): implement the units in the game before adding more creatures (Pterodactyl and the Spitter father wait).
- (13:20) DEFENCE (owner): no extra guard creature or tower. Every old Brood building becomes a rooting creature (the Hive is the Queen, the Feeding Pit is the Rootmaw, the tech buildings are the fathers); the old Brood had no tower either, and the Brood Mother herself is strong enough to shut down an early all-in. Still to match a creature to: the Clutch Mound (supply, swamp, faster eggs) and the Brood Pen (SACRIFICE for essence).
- (13:25) DECIDED (owner): the Clutch Mound becomes the MOUND TURTLE, a huge swamp turtle: rooted, it sinks into the mud, its shell becomes a mossy mound and the ground round it turns to swamp; it gives the supply (and the faster eggs) while rooted. SACRIFICE happens at the Queen: she devours the creature (her bite/swipe art), no Brood Pen creature.
