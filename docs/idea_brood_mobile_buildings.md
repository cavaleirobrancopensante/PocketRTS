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
- (13:34) DECIDED (owner): the MOUND TURTLE is the Brood's expansion creature: Rootmaws may root only on swamp (CORRECTED 13:40: any swamp, it need NOT be joined to the Queen's); a turtle walks to fresh ground, roots and spreads swamp there (killing it shrinks the swamp and cuts off the Rootmaws on it). Also, in a pinch, a TANK: lots of health and armour (more when rooted), slow, a weak bite at most; it can soak damage or body-block a ramp (rooted, it closes the ramp like the Crown's wall). Its cost: a turtle out of place gives no supply and no swamp.
- (13:40) CORRECTION (owner): the swamp does NOT have to be joined to the Queen's, it only has to exist. A lone turtle sent far away makes a hidden "ninja" base with Rootmaws; the farther from the Queen, the more each grub trip pays (the old distance rule), so it is a real reward for the risk.
- (13:34) DECIDED (owner): the MOUND TURTLE is the Brood's expansion creature: Rootmaws may root only on swamp joined to the Queen's; a turtle walks to fresh ground, roots and spreads swamp there (killing it shrinks the swamp and cuts off the Rootmaws on it). Also, in a pinch, a TANK: lots of health and armour (more when rooted), slow, a weak bite at most; it can soak damage or body-block a ramp (rooted, it closes the ramp like the Crown's wall). Its cost: a turtle out of place gives no supply and no swamp.
- (2026-10-28, Claude) BUILT AS AN EXPERIMENT the player picks: "The Brood (new, experiment)" in the skirmish setup (0.15.9). The Brood Mother, the Rootmaw (UPROOT and HAUL), the Mound Turtle (supply, swamp, a ramp blocker; stand-in art) and the Tyrannosaur, with eggs, fertilising, grubs and SACRIFICE at the Mother. What works, the numbers and Claude's choices for the owner to confirm: docs/brood_new.md.
- (14:18) FOR THE FUTURE (owner, an idea, not decided): STAGES. The Brood Mother could grow in stages 1, 2 and 3: bigger at each stage, and each stage unlocks more of the tech creatures/units (like the old Hive -> Warren -> Broodmound). The same for the Tyrannosaur: size 1, then size 3, as it grows from the Raptor father into the Brute father.
- (14:18) Mound Turtle art in: mound_turtle_concept2_chatgpt.png (chosen, swamp chimneys), mound_turtle_se_chatgpt.png (south-east: walk, rooting, rooted loop, uprooting, death), mound_turtle_e_sheet_chatgpt.png (the same sheet drawn nearer east: its walk row is the EAST walk), mound_turtle_s_walk_chatgpt.png (south walk). North-east and north walks still to come.
- (14:45) Father concepts in (owner, both liked; the creatures themselves WAIT, owner: "let's wait a little to introduce the actual creatures"): art/redraws/pterodactyl_concept_chatgpt.png (flying, landed, fertilising; its small direction row drew a dinosaur, not the pterosaur: ignore it) and the Dilophosaurus: art/redraws/dilophosaurus_concept_chatgpt.png, the fertilising pose's tail was hidden, so art/redraws/dilophosaurus_concept_composed.png (tools/art/compose_dilophosaurus.py: walking, spitting with the frill spread, fertilising with the walker's tail grafted on).
- (15:58) DECIDED (owner): the Brood Mother CANNOT ATTACK WHILE ROOTED (in her nest). To fight she must uproot. (The rooted-swipe sheet asked for by mistake is kept as art/redraws/brood_mother_rooted_attack_se_REJECTED.png, unused; it also grew an extra arm out of her back.)
- (15:58) Tyrannosaur nest sheet in (art/redraws/tyrannosaur_nest_se_chatgpt.png: rooting 5, fertilising loop 6, uprooting 5) and the Rootmaw rooted breathing (art/redraws/rootmaw_rooted_breath_se_chatgpt.png: 6 fill stages x 3).
- (17:14) DECIDED (owner): NO ROOTED CREATURE ATTACKS. Rooted means building: the Mother, the Rootmaw, the Mound Turtle and the Tyrannosaur cannot attack while rooted; to fight they must uproot.
- (17:20) DECIDED (owner): each SACRIFICE at the Mother gives her 1 egg at once (as well as the essence), with no age or type rule for now; the grub cycle (lay, feed back, lay) is to be judged in playtests, not guarded in advance. If her clutch is full, no extra egg.
- (17:16) PROPOSED (Claude, not yet confirmed): the Mother's growth stages raise her egg rate: stage 1 10 eggs held / 1 per 6 s; stage 2 about 15% bigger, 15 eggs, about 50% faster; stage 3 about 30% bigger, 20 eggs, about twice as fast; growing costs food and time while rooted (no laying meanwhile); bigger = a bigger, slower target with a wider swamp.
- (17:55) DECIDED (owner): the Mother is the ONLY producer, so her egg laying may be raised by SEVERAL levers that STACK (the other factions scale by building more production buildings; the Brood scales only through her): (1) growth stages (bigger, more eggs held, faster laying, unlock fathers); (2) FATHERS near her: their pheromones make her lay faster, each father within reach adds to the rate (lore: as in some real lizards, the males' presence and courtship speed the female's egg development); (3) Mound Turtles rooted on NEW GROUND (an expansion: about 15+ tiles from her and from other counted turtles; turtles at home give supply and swamp only): lore: their chimneys pump scent into the swamp water, she tastes new territory and lays more. All three stack; the totals are set by the math in docs/brood_new_stages.md so each phase of the game matches the other factions' production.
- (19:19) OWNER PLAYTEST of 0.15.13 (decisions and fixes):
  1. The Tyrannosaur needs a clear indicator of where to nest: a radius round the Mother (the father range) shown while placing/selecting him.
  2. Rooted creatures are drawn on the top layer and hide units (grubs vanish under the Queen): rooted ones go in the BUILDING layer so units draw over them.
  3. A rooted creature is a building: its command card is a building's (no move, attack, stop, hold), only its own commands.
  4. DECIDED: the STRUCTURE-UNITS (Rootmaw, Mound Turtle, Tyrannosaur and later fathers) come from GRUBS: select a grub and turn it into one (like the old Brood's grub building). The Mother lays only units (grubs and warriors), not structure-units.
  5. Grubs still show the old Brood buildings on their card: they must not.
  6. A laid egg can be selected but doesn't show what it will hatch; eggs need a rally point.
  7. Right-clicking with a rooted creature selected sets a RALLY POINT (it must not uproot); UPROOT is only the button.
  8. ROOT works like BUILD: a placement ghost on the grid to plan where it roots; it walks there and roots.
  9. Rooted, the colliders are much bigger (a building's footprint).
  10. Rooted creatures don't pulsate when idle: they animate only while producing (laying, fertilising) or being harvested.
- (20:07) KEPT (owner): 1 egg per SACRIFICE stays. The Raptor cycle (round 2, test 6) is not a real exploit: it turns food into essence at about a third (75 food -> 27 essence), wastes time hatching and walking, and essence buys nothing without more food; once she grows, food is the limit, not eggs. Owner: "an exploit is only dangerous if you can capitalize on it". Revisit only if real games show essence or eggs piling up with nothing to stop them.
- (Claude, 0.15.14) BUILT, all ten points of the 19:19 playtest (docs/brood_new.md "Rooted = a building"; scripts/brood_root.gd): the father ring, the building layer, the building card, the structure-units from grubs (a cocoon, the old grub-building look as a stand-in), the grub card without the old buildings, the egg's card and rally, right-click = rally (never uproots), ROOT like BUILD (a ghost on the grid with reasons), building footprints (the Rootmaw 3x2, the turtle 3x3, the Tyrannosaur 4x3, the Mother 9x4 growing with her stages; the own side's pass over a rooted turtle DROPPED: the footprint is solid for all), idle stillness. Also the computer's Mother no longer flip-flops (round 2's bug).
- (21:28) OWNER PLAYTEST of 0.15.14: (1) the grub keeps B (BUILD) and then the structure-units in that menu; (2) the Mother's laying animation is too fast: make it last longer; (3) Rootmaws need the worker count number on top (like the old pits); (4) no expansion spots shown for the new Brood: show them (turtle spots); (5) asked to justify the costs (a grub is lost when it morphs); (6) the Tyrannosaur keeps his fertilising animation until all the warrior eggs hatch; (7) the grub's card says hauling to the Burrow: it must say the Brood Mother; check all old text and logic like that; (8) the Brood Mother is hard to select: a click anywhere on her sprite selects her.
- (21:32) DECIDED (owner): EGG PLACEMENT: an egg always looks for the nearest empty spot round the Mother (a Tyrannosaur or other rooted creature right under her must not hide the eggs); if no empty spot is within a reasonable distance (she is boxed in by rooted creatures), it is laid ON the structure; eggs are drawn on the top layer so they are always seen; and hatchlings may walk through their own side's rooted creatures until they are clear, so nothing is ever stuck.
- (21:34) DECIDED (owner): the Mound Turtle costs 100 (was 150): with the grub it uses up, 150 for 12 supply, the Crown Cottage's 12.5 a supply point. The Rootmaw stays 75 (the old Feeding Pit) and the Tyrannosaur 200 (the old Gorge Pit).
- (21:45) DECIDED (owner): FLIERS REWORK: the Skywing is redrawn as a small olive pterosaur (the Pterodactyl father's young), same role (hunts flyers, LANDS to bite). The BLOATER IS REMOVED from the new Brood and replaced by another unit (to be designed). FATHERS UNLOCK BY THE MOTHER'S STAGE: the Tyrannosaur from the start, stage 2 unlocks the Dilophosaurus, stage 3 the Pterodactyl. The new fathers can be made now. Lines (Claude's proposal, to confirm): Tyrannosaur: Raptor, Brute; Dilophosaurus: Spitter, Spore Mother, Mist Toad; Pterodactyl: Skywing and the Bloater's replacement.
- (21:36) OWNER: the unit card must show each unit's attacks (and more stats) for all factions, with icons (job: branch unit-stats; ChatGPT stat icon sheet art/redraws/stat_icons_chatgpt.png).
- (22:09) OWNER: the expansion spots must read "OPTIMAL EXPANSION SPOT" (or similar) on the ground/while placing, for every faction; the new Brood sees them too, to send its turtles.
- (Claude, 0.15.16) BUILT, the 21:28 playtest and the decisions of 21:32, 21:34 and 22:09 (docs/brood_new.md "The owner's playtest of 0.15.14"): the grub's BUILD menu, the laying show 2.76 s (rate unchanged), the worker count over Rootmaws and piles, the turtle expansion spots with labels for every faction, the Tyrannosaur's loop till his eggs hatch, the old-word audit (pt/es), a click on the drawn body, eggs on the nearest empty spot / on a creature when boxed in, hatchlings walking through their own creatures, progress bars (growing with STOP GROWING, morphing, rooting, hatching), the Mound Turtle at 100.
- (2026-10-29 10:28) OWNER: the SPORE MOTHER and the STORMCALLER are RETIRED (not used any more). The Toad's TONGUE can't pull the Tyrannosaur (fathers and the Mother are only staggered); TONGUE can now target FLYING units. Whether TONGUE pulls the Crown's Field Cannon or only staggers it is UNDECIDED: a study first (SC2's Viper Abduct on Siege Tanks as the reference: it breaks Terran turtles, but Terran has the Ghost as a counter; the Crown has no counter to the Toad), plus filmed coached games of Clockwork and Brood against an entrenched Crown.
- (2026-10-29 11:03-11:05) OWNER: SPITTERS are in the new Brood (the Tyrannosaur fathers them until the Spitter father exists). Their role with the Toad: focus fire on any Horseman charging the Toad (the charge stun is the Crown's answer to a tongue windup; Spitters are the Brood's answer to that answer).
- (2026-10-29 11:10) DECIDED (owner): FATHER LINES: Tyrannosaur (from the start): Raptor, Brute. Dilophosaurus (unlocked by the Mother's stage 2): Spitter, Mist Toad. Pterodactyl (stage 3): Skywing (and the Bloater's replacement, later). One of each father; each near the Mother adds its pheromone bonus. Build the two new fathers now, with the art there is and stand-ins until the rest arrives.
- (2026-10-29 12:06) DECIDED (owner): the fathers are named TYRANT SIRE (was Tyrannosaur: Raptor, Brute), VENOM SIRE (was Dilophosaurus: Spitter, Mist Toad) and STORM SIRE (was Pterodactyl: Skywing). The internal ids may stay; every name the player sees changes (pt/es too).
- (Claude, 0.16.0) BUILT: the three fathers with their lines, stages, nests and art (docs/brood_new.md "The three fathers").
