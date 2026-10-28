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
