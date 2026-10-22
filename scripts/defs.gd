class_name Defs
## Game rules: factions, every unit and building, and economy constants.
## Ranges and radii are in pixels; one map tile is 32 px.

const TILE := 32
const START_GOLD := 250
const EGGS_MAX := 5               # a Burrow's eggs (an upgraded hall holds more: HALL_LEVELS)
const EGG_TIME := 6.0
## The Brood's main hall grows in three levels (its kind stays "hive" at every level; the
## level is kept on the building and saved): name, health, armour and how many eggs it holds.
## Levels 2 and 3 are upgrades on the hall's card (`label`), paid in biomass (`cost`) and
## essence (`cost2`), taking `time` s, `needs` a finished building of that kind; the hall
## keeps laying, hatching and taking food meanwhile, and CANCEL pays it back. `art`: its
## sprite sheet (assets/buildings/<art>_<state>.png, tools/import_brood_halls.py); until it
## exists the Burrow's is drawn `scale` times bigger (anchored at the bottom).
const HALL_LEVELS := [
	{"name": "Burrow", "hp": 1500, "armor": 1, "eggs": 5, "art": "hive", "scale": 1.0},
	{"name": "Warren", "hp": 2000, "armor": 1, "eggs": 10, "art": "warren_hall", "scale": 1.15,
		"label": "WARREN", "cost": 150, "cost2": 0, "time": 40.0,
		"about": "Upgrade to Warren: up to 10 eggs, more health (2000). The hall keeps laying eggs and hatching meanwhile."},
	{"name": "Broodmound", "hp": 2600, "armor": 2, "eggs": 15, "art": "broodmound", "scale": 1.3,
		"label": "BROODMOUND", "cost": 250, "cost2": 50, "time": 60.0, "needs": "gorge_pit",
		"about": "Upgrade to Broodmound: up to 15 eggs, more health (2600) and armour 2. The hall keeps laying eggs and hatching meanwhile."},
]
const WIND_DECAY := 0.012         # Clockwork: charge lost per second outside a field (empty in ~80 s)
const WIND_MIN := 0.55
const AUTO_REPAIR := 8           # REPAIR autocast: how far (tiles) an idle worker looks for something to fix
const REPAIR_RATE := 20.0         # slowest repair speed (hp/s per worker); faster when the thing builds quickly

# ---- Economy: every faction makes its own resources from structures.
# Each town hall allows a fixed number of each economy structure (FACTIONS[f]["econ"]);
# Crown and Clockwork ones must stand near one of their halls.
const ECON_RANGE := 14            # tiles from a hall
const HALL_SPACING := 18          # a new hall needs its own ground: tiles from your other halls
## Lodes: every Town Hall's ground holds a reserve of saltpetre for its Powder Mill, every
## Clocktower's a reserve of ore for its Ore Crushers (a Mill / Crusher draws on the nearest
## hall of its own). Amounts are in what they pay: powder for saltpetre, ore for ore. A hall's
## saltpetre lasts a fully worked Mill (~120 powder a minute) about 11 minutes; a Clocktower's
## ore lasts a saturated Clockwork base (~1,150-1,200 ore a minute) about 10 minutes. Once
## spent, its Mill / Crushers work at LODE_SPENT. Like soil, a hall raised where one fell takes
## over what was left there. The Brood has no lode (its Hive ground is GROUND_RESERVE).
const LODE := {"town_hall": 1320.0, "clocktower": 11400.0}     # 3 x 440 powder, 3 x 3,800 ore
const LODE_NAME := {"town_hall": "saltpetre", "clocktower": "ore"}
const LODE_FOR := {"powder_mill": "town_hall", "ore_crusher": "clocktower", "boiler": "clocktower"}
const LODE_SPENT := 0.25
## Efficiency bars (economy buildings): staffing (crew at work / full crew) x the state of the
## base's reserve, from 100% fresh down to its trickle share once spent (Building.efficiency).
const EFF_GOOD := 0.8             # green from here, through yellow, to red at EFF_POOR and below
const EFF_POOR := 0.4
# Crown: farms grow (faster with labourers working them) and pay out a whole harvest.
# Each Town Hall allows 2 Farms (crew 8) and 1 Powder Mill (crew 6): a full base is 16
# farmers + 6 millers, ~1,140 gold and ~120 powder a minute. (Horse Breeders are production
# buildings: they sell horses for gold, as many breeders as you like.)
const FARM_GROW := 40.0           # seconds to ripen with a full crew
const FARM_BASE := 0.15           # share of that speed with nobody working it
const FARM_YIELD := 380           # gold a harvest (fresh soil; was 450 while a hall allowed one farm)
## Soil fatigue: each Town Hall's farmland holds a fixed reserve of gold, shared by the farms
## that belong to it (a farm belongs to the nearest hall). Every harvest draws its yield from
## the reserve; once it's spent those farms pay a third. A new hall brings fresh soil (one
## built where a hall fell takes over what was left there). Powder Mills draw on its saltpetre (LODE).
const SOIL_RESERVE := 9000
const SOIL_TIRED := 1.0 / 3.0     # share of a harvest that tired soil still pays
const SOIL_LOW := 0.25            # warn the player below this share of the reserve (Hive ground too)
const MILL_RATE := 0.33           # powder per second per labourer at a Powder Mill (6 per hall: ~2/s, ~120/min) while its saltpetre lasts
## The Crown starts with no powder: a Powder Mill comes before Musketeers (or a Horse Breeder
## before Horsemen: the two openings).
const START_POWDER := 0
## Personal powder: Musketeers, Cannons and Mortars carry their own, in shots (one per shot:
## round shot, canister or shell alike). A dry Musketeer fights with the bayonet until it has
## `rearm` shots again. They refill by themselves (`refill` shots a second) within `range` tiles of
## one of their side's finished `from` buildings, paid from the powder bank at `cost` powder
## a shot (a full musketeer: 6 powder; with the bank empty the refill waits), or of a Powder
## Wagon with powder left (drawn from the wagon's store, already paid for: a cannon shot takes
## 3 of the wagon's musket shots). Shots themselves don't touch the bank any more.
## A soldier refitted with the Shot Pouch (RESEARCH "pouch") carries `pouch` musket shots.
const POWDER := {"musketeer": 10, "pouch": 20, "cannon": 8, "mortar": 6, "refill": 2.0, "range": 3.0, "rearm": 3,
	"cuirassier": 4, "dismounted": 4,       # the pistol's charges (Defs.PISTOL): mounted and on foot alike
	"cost": {"musketeer": 0.5, "cannon": 1.5, "mortar": 1.5, "cuirassier": 0.5, "dismounted": 0.5}, "from": ["powder_mill", "barracks", "town_hall"]}
## The Horseman's flintlock pistol (Horseman, Cuirassier, Officer, Armoured Officer: `kinds`):
## one loaded shot of `damage` at up to `range` px (a single ranged blow, like a musket ball;
## ground targets only, never at buildings), aimed in `aim` s; `after` s later his sabre is
## out and he fights with it as before. He fires it mounted or on foot, but reloads only on
## foot (an Officer): `reload` s, by himself, spending `powder` of the charges he carries
## (POWDER: refilled like a Musketeer's); with none left he can't reload. The reload waits
## while he's in a sabre fight (an enemy within `busy` px). Trained loaded; mounting and
## dismounting keep the pistol as it is. HOLD FIRE: he never fires it by himself.
const PISTOL := {"damage": 30.0, "range": 110.0, "aim": 0.35, "after": 0.4, "reload": 4.0, "powder": 1.0,
	"busy": 40.0, "kinds": ["cuirassier", "dismounted"]}
## Powder Wagon: holds `store` musket shots. Parked within POWDER.range tiles of a Powder Mill,
## Barracks or Town Hall it fills `fill` shots a second, paid from the powder bank at
## 1 powder per `per_powder` shots (the musket rate). SUPPLY: up to `runners` labourers carry
## kegs from the nearest Powder Mill to it (`keg` shots a keg, loaded in `keg_load` s, paid the
## same way: 30 shots = 15 powder). Destroyed, it blows up: up to `blast` damage (scaled by the
## powder left, never under `blast_min`) within `radius` px, friends included.
const WAGON := {"store": 120, "fill": 8.0, "per_powder": 2.0, "keg": 30, "keg_load": 1.5, "runners": 2,
	"blast": 170.0, "blast_min": 70.0, "radius": 110.0}
## Observation Balloon's powder store: `store` musket shots (full when it's rigged). The
## Musketeers in its basket top up from it (POWDER.refill shots a second). Hovering still within
## `reach` tiles of a Powder Wagon with powder left, or of a finished POWDER.from building, with
## room in the store, the pilot lowers a rope and hauls up a keg of `keg` shots in `haul` s
## (from a building: paid from the bank at WAGON.per_powder shots a powder; from a wagon:
## taken from its store). Moving off reels the rope in (the keg goes back).
const BALLOON := {"store": 40, "keg": 10, "haul": 3.0, "reach": 2.0}
## A labourer killed with a keg on his back: a small blast (friends included).
## (Step 3, keg mines, will reuse the keg carry and Game.powder_blast.)
const KEG := {"blast": 40.0, "radius": 48.0}
# Brood: grubs haul food from Feeding Pits to a Hive; the longer the haul, the richer it is.
## A load pays for the time its round trip takes, at a rate that rises with the pit's
## distance from its Hive (centre to centre, in tiles): FOOD_RATE biomass per grub-second
## from FOOD_NEAR tiles in, up to FOOD_BONUS more (+30%) at FOOD_FAR tiles, flat to
## FOOD_PEAK, then a little less per tile beyond (FOOD_FADE). The trip is estimated as
## PIT_TIME + FOOD_TRIP seconds a tile of open ground between the two buildings (less the
## FOOD_REACH a grub needn't walk: it unloads beside each one). So a grub earns ~60-70 biomass
## a minute within 9 tiles of the Hive and ~88 from 15-24 tiles out (tools/econ_bench.gd pits).
const PIT_TIME := 2.0             # seconds a grub feeds at the pit before hauling
const FOOD_RATE := 1.2            # biomass per grub-second of round trip (near pits)
const FOOD_NEAR := 6.0
const FOOD_FAR := 18.0
const FOOD_PEAK := 22.0
const FOOD_BONUS := 0.3
const FOOD_FADE := 0.015          # share of the rate lost per tile beyond FOOD_PEAK
const FOOD_TRIP := 0.8            # seconds of round trip per tile walked (mostly on swamp)
const FOOD_REACH := 1.5           # tiles of the gap a grub doesn't walk
const FOOD_MAX_D := 32.0          # a load is worth no more from farther out than this
## Hive ground: the Feeding Pits around a Hive (a pit belongs to the nearest Hive) share one
## reserve of biomass; every load hauled draws its value from it, and once it's spent those
## pits yield a third. A new Hive has fresh ground (one grown where a Hive fell takes over
## what was left there).
const GROUND_RESERVE := 10500     # (a fully worked Hive draws ~1,000-1,150 a minute: ~10 minutes)
const ESSENCE_PER_SUPPLY := 3     # a body falling near a Brood Pen
const PEN_RANGE := 12             # tiles
## Brood Pen SACRIFICE: a Brood creature offered up at a Pen gives this share of its biomass
## cost as essence (a Raptor, 25 biomass, gives 3).
const SACRIFICE := 0.12
# Clockwork: Winders carry batteries from the energy buildings to the Ore Crushers.
## Clockwork economy: only the Clocktower and Boilers (2 per Clocktower) fill batteries;
## Winders carry them to an Ore Crusher, which turns the charge into ore drawn from its
## Clocktower's ore (LODE; a quarter once it's spent). A carried battery keeps its charge
## for `fresh` s, then slowly loses it on the road (`decay`: share of its charge a second,
## never below `floor`), so long hauls pay less; if its carrier is hit, it bursts. Yellow batteries at first; a Capacitor Works
## makes every source fill blue ones (more charge, slower to fade).
const BATTERY := {
	"yellow": {"base": 11.5, "decay": 0.03},
	"blue": {"base": 15.5, "decay": 0.02},
	"fresh": 6.0, "floor": 0.4, "load": 1.0, "blast": 10.0, "splash": 8.0,
	"ore": 0.7,     # ore per point of charge at the crusher
}
## ENERGY: the full batteries waiting at the Clocktowers and Boilers are the Clockwork's
## energy. Winders leave the last `keep` of them for it; top constructs (cost2), storms
## and the like spend them.
const ENERGY_KEEP := 6
## Coal: each Clocktower's Boilers (a Boiler belongs to the nearest Clocktower) share a
## reserve of coal, one unit a battery; once it's spent they fill batteries at a third.
## (A saturated base's 2 Boilers burn ~110 a minute: ~11 minutes.)
const COAL_RESERVE := 1200
const COAL_SPENT := 1.0 / 3.0
## Overcharged: a construct that stays inside a Boiler's glow (`boiler` tiles), a Charging
## Pylon's or a deployed Tesla Cart's field for `time` s hits `damage` harder while it
## stays. (The Ornithopter's OVERLOAD is the strong version.)
const OVERCHARGE := {"time": 10.0, "damage": 1.15, "boiler": 5.0}
## Thresher: its saws spin up while it keeps attacking: damage from `low` to `high` times
## over `time` s; `reset` s without a blow and they spin down. Spinning drains its wind
## (`drain` a second at full spin). Every blow also bites up to `cleave` more enemies
## within `reach` px of its target (`cleave_dmg` of the blow).
const THRESHER := {"low": 0.4, "high": 1.6, "time": 3.0, "reset": 1.0, "drain": 0.02, "cleave": 2, "reach": 30.0, "cleave_dmg": 0.6}
## Arc Thrower: each lightning ball takes `drain` of its own wind.
const ARC := {"drain": 0.05, "speed": 420.0}
## Bulwark: BRACE plants the tower shield (`switch` s): it can't move, its armour is `armor`,
## and shots (musket balls, spit, arc balls, spines) at friendly units up to `reach` px
## behind it, inside the `cone` (cosine) away from the shooter, hit the shield instead
## (the shooter must be in front of it: `front`).
const BRACE := {"armor": 7, "reach": 120.0, "cone": 0.45, "front": 0.2, "switch": 0.6, "drain": 2.5}   # drain: battery use while braced (x normal)
## Wind-up Soldiers run on a spring, not a battery: `run` s away from a field and they run
## down; a Winder cranks one back up at `crank` a second (or a field does).
const SPRING := {"run": 50.0, "crank": 0.6}
## Winders wind themselves: `run` s away from a field, then they stop for `stop` s to crank.
const WINDER_SELF := {"run": 90.0, "stop": 3.0, "low": 0.04}
## The Winder's self-building crate: a new Clockwork building's Winder fetches it from the
## nearest Clocktower (`pickup` s to shoulder it), carries it to the site and drops it; the
## build time starts when it lands. Dropped on the way (he died or got another job), it lies
## there with `hp` until a Winder carries it on (`lift` s to pick it up; idle Winders within
## `auto` tiles do so by themselves); destroyed, the building is cancelled (Game.abandon's
## refund). No Clocktower: the Winder starts the building as before. The unfold plays frames
## 0-4 for `unfold` s each, holds frame 5 for `hold` s and cross-fades into the construction
## sprite over `fade` s (a low building, the Assembly Works, holds frame 4 instead: ArtData.CRATE).
const CRATE := {"hp": 40.0, "pickup": 0.8, "lift": 0.5, "auto": 10, "unfold": 0.4, "hold": 0.3, "fade": 0.5}


## A carried battery's charge after `t` seconds on the road.
static func battery_charge(blue: bool, t: float) -> float:
	var info: Dictionary = BATTERY["blue" if blue else "yellow"]
	return float(info["base"]) * maxf(float(BATTERY["floor"]), 1.0 - float(info["decay"]) * maxf(0.0, t - float(BATTERY["fresh"])))
## Crown machines: Labourers repair them like buildings; Missionaries don't bandage them.
const CROWN_MACHINES := ["cannon", "mortar", "powder_wagon", "balloon"]
const REPAIR_COST := 0.25        # a full repair costs this share of the price (StarCraft: 25%)
const ENERGY_PER_WINDER := 3.5
const ENERGY_HALL := 3.0
const ORE_PER_ENERGY := 1.8
const CRUSHER_CAP := 12.0         # ore per second one Ore Crusher can handle
const SPLITS := {
	"ECONOMY": [0.7, 0.15, 0.15], "BALANCED": [0.45, 0.3, 0.25],
	"WAR": [0.15, 0.5, 0.35], "HOLD": [0.2, 0.2, 0.6],
}
# Missionary
const BANDAGE_TIME := 4.0
const CROSS_TIME := 5.0           # after bandaging, that soldier can't be bandaged again yet
const MISSIONARY_DANGER := 8      # tiles from an enemy building where he can be hurt
# Tesla Cart
const TESLA_SWITCH := 3.0         # seconds to deploy or pack
const TESLA_FIELD := 6            # tiles
## Tesla Cart lightning: the bolt, then `jumps` more enemies within `reach` px at `falloff`
## of it (the rework leans the cart toward powering constructs: was 2 jumps at 60%, 80 px).
const TESLA_CHAIN := {"jumps": 1, "falloff": 0.4, "reach": 70.0}

const FACTIONS := {
	"crown": {
		"name": "The Crown", "hall": "town_hall", "worker": "labourer", "supply": "cottage",
		"build": ["town_hall", "cottage", "farm", "horse_breeder", "powder_mill", "wall", "gate", "barracks", "armoury", "foundry", "church"],
		"start_workers": 4, "start_gold": 300, "ready": true, "max_supply": 100,
		"res": ["Gold", "Powder"], "econ": {"farm": 2, "powder_mill": 1},
		"start": ["farm"],
		"about": "Musketeers, cannons and mortars, and horses for them. Farms ripen into big harvests; Horse Breeders sell the horses that cavalry and guns need; Powder Mills grind each Town Hall's saltpetre into powder for muskets and cannons. Slow and strong when dug in.",
	},
	"brood": {
		"name": "The Brood", "hall": "hive", "worker": "grub", "supply": "clutch_mound",
		"build": ["hive", "clutch_mound", "feeding_pit", "brood_pen", "spore_vent", "warren", "gorge_pit", "roost"],
		"start_workers": 5, "ready": true, "max_supply": 160,
		"res": ["Biomass", "Essence"], "econ": {"feeding_pit": 3, "brood_pen": 1},
		"start": ["feeding_pit"],
		"about": "A swarm of cheap lizards. Grubs haul food from pits to the Burrow: the longer the haul, the richer the food, and each Burrow's ground runs out in time. Upgrade it to a Warren, then a Broodmound, for more eggs. Essence comes from the fallen and from offerings at the Brood Pen. Army cap 160.",
	},
	"clockwork": {
		"name": "The Clockwork", "hall": "clocktower", "worker": "winder", "supply": "spring_tower",
		"build": ["clocktower", "spring_tower", "boiler", "ore_crusher", "charging_pylon", "assembly_works", "engine_hall", "capacitor_works"],
		"start_workers": 4, "ready": true, "max_supply": 100,
		"res": ["Ore", "Energy"], "econ": {"boiler": 2, "ore_crusher": 2},
		"start": ["ore_crusher"],
		"about": "Constructs that run on wind and batteries. The Clocktower and Boilers fill batteries; Winders carry them to Ore Crushers (a battery fades on the road), and the batteries left waiting are your Energy. Each Clocktower's ore and coal run out in time. Army cap 100.",
	},
}

const UNITS := {
	"labourer": {
		"tags": ["light"],
		"name": "Labourer", "hp": 46, "armor": 0, "speed": 74, "cost": 50, "time": 12.0, "supply": 1,
		"sight": 7, "range": 20, "damage": 7, "cooldown": 1.0, "radius": 9, "from": "town_hall",
		"faction": "crown", "worker": true, "about": "Mines gold and builds. Weak in a fight.",
	},
	"musketeer": {
		"tags": ["light"],
		"name": "Musketeer", "hp": 70, "armor": 0, "speed": 62, "cost": 60, "cost2": 10, "time": 15.0, "supply": 1,
		"sight": 8, "range": 190, "damage": 20, "cooldown": 2.8, "aim": 0.4, "radius": 10, "from": "barracks", "requires": "powder_mill",
		"anti_air": true, "faction": "crown", "about": "Light line infantry: fires at range and, by itself, stabs with the bayonet when the enemy closes in (or when its 10 shots run dry, 20 with the Shot Pouch; it refills near a Mill, Barracks, Town Hall or Powder Wagon). Long reload. Costs 10 powder: the Powder Mill grinds more. The Armoury researches Armour (he becomes a Guardsman), better locks, the socket bayonet and the shot pouch for him. MOUNT a horse and he rides as a Dragoon.",
	},
	"cannon": {
		"tags": ["armored"],
		"name": "Field Cannon", "hp": 140, "armor": 1, "speed": 38, "cost": 170, "time": 32.0, "supply": 4,
		"sight": 8, "range": 430, "min_range": 80, "damage": 32, "splash": 46, "cooldown": 4.5, "aim": 0.6,
		"radius": 22, "from": "foundry", "building_bonus": 2.5, "faction": "crown", "needs_horse": true,
		"about": "Artillery. Limbered, the horse tows it; unlimber (2.5 s) to fire. Round shot reaches further than it can see: other units must spot for it. Canister also hits flyers. Carries 8 shots; refills near a Mill, Barracks, Town Hall or Powder Wagon.",
	},
	"mortar": {
		"tags": ["armored"],
		"name": "Mortar", "hp": 120, "armor": 1, "speed": 38, "cost": 145, "cost2": 20, "time": 30.0, "supply": 3,
		"sight": 8, "range": 352, "min_range": 160, "damage": 30, "splash": 48, "cooldown": 5.0, "aim": 0.6,
		"radius": 18, "from": "foundry", "building_bonus": 1.5, "ground_only": true, "faction": "crown", "needs_horse": true,
		"about": "Siege mortar. Packed it rolls; DEPLOY it (3 s) to fire. It lobs a shell high over men and walls (5 to 11 tiles away) that bursts where it lands: 30 damage over a wide area, friends too. Can't hit flyers. Carries 6 shells; refills near a Mill, Barracks, Town Hall or Powder Wagon.",
	},
	"powder_wagon": {
		"tags": ["armored"],
		"name": "Powder Wagon", "hp": 220, "armor": 1, "speed": 38, "cost": 70, "cost2": 30, "time": 25.0, "supply": 2,
		"sight": 7, "range": 0, "damage": 0, "cooldown": 1.0, "radius": 16, "from": "foundry",
		"no_attack": true, "faction": "crown", "needs_horse": true,
		"about": "Carries 120 shots of powder for the army: musketeers and cannons within 3 tiles refill from it. Fills up near a Mill, Barracks or Town Hall (1 powder per 2 shots); SUPPLY (on from the start; G turns it off) sends 2 labourers with kegs from the Powder Mill when it's out in the field: idle ones first, else men taken off the farms or the mills, whichever your side can best spare. No weapon, and when it's destroyed it blows up (more powder, bigger blast; friends too): guard it.",
	},
	# (the kind stays "cuirassier" for saves, the AI and hotkeys: unarmoured he is the
	# Horseman, with Armour the Cuirassier: see ARMOURED)
	"cuirassier": {
		"tags": ["light"],
		"name": "Horseman", "hp": 140, "armor": 1, "speed": 112, "cost": 115, "time": 22.0, "supply": 3,
		"sight": 8, "range": 26, "damage": 18, "cooldown": 1.1, "aim": 0.15, "radius": 15, "from": "barracks",
		"requires": "horse_breeder", "bonus": {"cannon": 1.6, "spitter": 1.3, "arc_thrower": 1.3}, "charge": true, "faction": "crown", "needs_horse": true,
		"about": "Fast light horseman with a pistol and a sabre. Trained with his horse in one click (a free one at a breeder, else the breeder trains one: 40 more); he comes out on foot and rides off on it. He opens with his one loaded pistol shot (30 damage, a little over half a musket's reach), then fights with the sabre; he can only reload on foot (DISMOUNT: he's an Officer then). Once the Armoury has drilled the Cavalry Charge, his first sabre blow after a gallop hits double and throws the enemy back. With Armour he becomes a Cuirassier. Bayonets hurt him.",
	},
	# ---- horses (Defs.HORSES) and the men who ride them. Horses are bought at a Horse Breeder
	# (trained like soldiers); the rest are a man on a horse (MOUNT) or off it (DISMOUNT): Defs.MOUNTS.
	"horse": {
		"tags": ["light"],
		"name": "Horse", "hp": 60, "armor": 0, "speed": 96, "cost": 40, "time": 15.0, "supply": 0,
		"sight": 4, "range": 0, "damage": 0, "cooldown": 1.0, "radius": 11, "from": "horse_breeder",
		"no_attack": true, "horse": true, "faction": "crown",
		"about": "Bought at a Horse Breeder (40 gold). Lead it by the reins (LEAD), ride it (MOUNT), harness it to a gun or wagon, or bring it to a Barracks or Foundry for cavalry and guns. Left alone with an enemy man beside it, it's stolen.",
	},
	"messenger": {
		"tags": ["light"],
		"name": "Messenger", "hp": 60, "armor": 0, "speed": 124, "cost": 50, "time": 1.0, "supply": 1,
		"sight": 9, "range": 0, "damage": 0, "cooldown": 1.0, "radius": 13, "from": "",
		"no_attack": true, "mounted": true, "faction": "crown",
		"about": "A Labourer on a horse: the fastest thing on the ground, unarmed, a scout. He can still lead horses. DISMOUNT to work again.",
	},
	# (light he is the Dragoon, with Armour the Armoured Dragoon: see ARMOURED)
	"dragoon": {
		"tags": ["light"],
		"name": "Dragoon", "hp": 90, "armor": 0, "speed": 112, "cost": 60, "cost2": 10, "time": 15.0, "supply": 1,
		"sight": 8, "range": 190, "damage": 0, "cooldown": 2.8, "radius": 14, "from": "barracks",
		"requires": ["powder_mill", "horse_breeder"], "needs_horse": true,
		"no_attack": true, "mounted": true, "anti_air": true, "faction": "crown",
		"about": "A Musketeer on a horse: rides fast but can't fight in the saddle. Trained at the Barracks with his horse in one click, for the Musketeer's price (a free horse at a breeder, else the breeder trains one: 40 more); he comes out on foot and rides off on it. Told to attack, he dismounts (0.8 s), fires as a Musketeer (reloading a third slower), and remounts by himself to move on. His reload waits while he rides.",
	},
	# the Officer: a Horseman off his horse (with Armour: the Armoured Officer). The Barracks
	# trains him on foot too, for the Horseman's price less the horse's.
	"dismounted": {
		"tags": ["light"],
		"name": "Officer", "hp": 80, "armor": 1, "speed": 64, "cost": 75, "time": 18.0, "supply": 3,
		"sight": 8, "range": 110, "damage": 30, "cooldown": 1.1, "aim": 0.35, "radius": 10, "from": "barracks",
		"requires": "horse_breeder", "sabre": {"damage": 18.0, "cooldown": 1.1}, "faction": "crown",
		"about": "A Horseman on foot: his flintlock pistol (one shot, 30 damage, a little over half a musket's reach) and the same sabre as in the saddle up close (about a plain bayonet's match). On foot he reloads the pistol by himself (4 s, a little powder: his charges refill like a Musketeer's). MOUNT a horse and he rides as a Horseman.",
	},
	"balloon": {
		"tags": ["light"],
		"name": "Observation Balloon", "hp": 180, "armor": 0, "speed": 46, "cost": 125, "cost2": 20, "time": 25.0, "supply": 2,
		"sight": 14, "range": 0, "damage": 0, "cooldown": 1.0, "radius": 22, "from": "foundry",
		"air": true, "no_attack": true, "faction": "crown",
		"about": "A pilot and a basket for 4 Musketeers or Labourers: LOAD them and UNLOAD them anywhere, even over cliffs. Musketeers aboard shoot from the basket (at the ground or at flyers) and reach 35% further from up there, and refill from its 48-shot powder store; hover it within 2 tiles of a Powder Wagon, Mill, Barracks or Town Hall and the pilot hauls up kegs (RESTOCK). Sees 14 tiles. Slow and fragile; the pilot doesn't fight.",
	},
	"grub": {
		"tags": ["light"],
		"name": "Grub", "hp": 46, "armor": 0, "speed": 68, "cost": 50, "time": 12.0, "supply": 1,
		"sight": 6, "range": 18, "damage": 6, "cooldown": 1.0, "radius": 8, "from": "hive",
		"faction": "brood", "worker": true,
		"about": "Hauls food from Feeding Pits to a Burrow (longer hauls pay more). Turns into buildings.",
	},
	"raptor": {
		"tags": ["light"],
		"name": "Raptors", "hp": 36, "armor": 0, "speed": 108, "cost": 75, "time": 11.0, "supply": 1, "spawn": 3,
		"sight": 7, "range": 22, "damage": 6, "cooldown": 0.9, "aim": 0.1, "radius": 7, "from": "hive",
		"requires": "warren", "faction": "brood", "about": "Fast, flimsy claws. Three hatch from each egg.",
	},
	"spitter": {
		"tags": ["light"],
		"name": "Spitters", "hp": 70, "armor": 0, "speed": 68, "cost": 90, "time": 13.0, "supply": 1, "spawn": 2,
		"sight": 8, "range": 150, "damage": 8, "cooldown": 2.0, "aim": 0.35, "radius": 12, "from": "hive",
		"acid": 3.0, "requires": ["warren", "brood_pen"], "cost2": 5, "anti_air": true, "faction": "brood",
		"about": "Spit acid that burns and strips armour. Two hatch from each egg.",
	},
	"brute": {
		"tags": ["armored"],
		"name": "Brute", "hp": 240, "armor": 2, "speed": 56, "cost": 150, "time": 22.0, "supply": 3,
		"sight": 7, "range": 28, "damage": 26, "cooldown": 1.8, "aim": 0.25, "radius": 20, "from": "hive",
		"building_bonus": 1.6, "requires": "gorge_pit", "cost2": 20, "faction": "brood",
		"about": "Huge horned tank. Charges in and knocks enemies back.",
	},
	"spore_mother": {
		"tags": ["armored"],
		"name": "Spore Mother", "hp": 260, "armor": 1, "speed": 40, "cost": 175, "cost2": 40, "time": 26.0, "supply": 4,
		"sight": 10, "range": 300, "min_range": 70, "damage": 26, "splash": 50, "cooldown": 4.0, "aim": 0.6,
		"radius": 20, "from": "hive", "requires": "gorge_pit", "faction": "brood",
		"about": "Walking, she can't attack. ROOT her (2.5 s): she lobs big spit blobs that splash a whole area, and spreads swamp. Casts MIASMA, a cloud that heals the Brood.",
	},
	"bloater": {
		"tags": ["light"],
		"name": "Bloater", "hp": 60, "armor": 0, "speed": 44, "cost": 50, "cost2": 25, "time": 14.0, "supply": 1,
		"sight": 8, "range": 160, "damage": 7, "cooldown": 2.2, "aim": 0.5, "radius": 12, "from": "hive",
		"air": true, "ground_only": true, "requires": "roost", "faction": "brood",
		"about": "A floating gas sac full of acid. It spits acid from afar, but every glob uses up gas; out of gas it deflates (slower, harmless) and slowly fills up again, faster on swamp. On HOLD GAS it keeps it all and drifts in to burst as a huge acid bomb. Used up when it bursts.",
	},
	"winder": {
		"tags": ["light"],
		"name": "Winder", "hp": 70, "armor": 1, "speed": 64, "cost": 60, "time": 14.0, "supply": 1,
		"sight": 7, "range": 20, "damage": 7, "cooldown": 1.0, "radius": 12, "from": "clocktower",
		"faction": "clockwork", "worker": true, "repairs": true,
		"about": "Cranks Boilers for energy and repairs constructs and buildings. To start a building he fetches a crate from the nearest Clocktower and carries it to the site, where it unfolds and builds itself; killed or sent elsewhere on the way, he drops it for another Winder to carry on.",
	},
	"windup_soldier": {
		"tags": ["light"],
		"name": "Wind-up Soldiers", "hp": 55, "armor": 1, "speed": 66, "cost": 75, "time": 13.0, "supply": 1, "spawn": 3,
		"sight": 7, "range": 24, "damage": 7, "cooldown": 1.1, "aim": 0.15, "radius": 8, "from": "assembly_works",
		"spring": true, "faction": "clockwork",
		"about": "Cheap tin spearmen, three to an order. They run on a spring, not a battery: about 50 s away from a field and they run down and freeze until a Winder cranks them up again (or a field reaches them).",
	},
	"thresher": {
		"tags": ["armored"],
		"name": "Thresher", "hp": 280, "armor": 3, "speed": 54, "cost": 165, "time": 21.0, "supply": 3,
		"sight": 7, "range": 26, "damage": 20, "cooldown": 1.0, "aim": 0.2, "radius": 18, "from": "assembly_works",
		"wind_drain": 2.0, "faction": "clockwork",
		"about": "Saw-armed brute. Its saws SPIN UP while it keeps cutting: from 40% to 160% damage over 3 s, and every blow bites the enemies round its target too. Strong against swarms that stand and fight, weak against anything that runs. A battery junkie: it runs down fast, faster still while spinning.",
	},
	"bulwark": {
		"tags": ["armored"],
		"name": "Bulwark", "hp": 340, "armor": 4, "speed": 46, "cost": 175, "time": 26.0, "supply": 3,
		"sight": 7, "range": 34, "damage": 9, "cooldown": 1.6, "aim": 0.3, "radius": 16, "from": "assembly_works",
		"requires": "boiler", "faction": "clockwork",
		"about": "A tower shield on legs, with a weak piston lance. BRACE plants the shield (holding it up burns its battery 2.5x as fast): it can't move, and musket balls, spit, arc balls and spines aimed at your units behind it hit the shield instead.",
	},
	"arc_thrower": {
		"tags": ["armored"],
		"name": "Arc Thrower", "hp": 160, "armor": 1, "speed": 54, "cost": 150, "time": 22.0, "supply": 3,
		"sight": 9, "range": 210, "damage": 28, "cooldown": 2.6, "aim": 0.4, "radius": 14, "from": "assembly_works",
		"requires": "boiler", "anti_air": true, "faction": "clockwork",
		"about": "Throws balls of lightning at one enemy, ground or air. Every throw takes a good bite of its own wind: it runs down fast in a long fight away from a field.",
	},
	"steam_walker": {
		"tags": ["armored", "massive"],
		"name": "Steam Walker", "hp": 380, "armor": 2, "speed": 44, "cost": 240, "cost2": 3, "time": 34.0, "supply": 5,
		"sight": 8, "range": 72, "damage": 15, "cooldown": 1.6, "aim": 0.3, "radius": 28, "from": "engine_hall",
		"cone": true, "building_bonus": 2.0, "wind_drain": 2.0, "faction": "clockwork",
		"about": "Scalding steam hits everything in front of it. Melts swarms and buildings. A battery junkie: it runs down fast away from a field.",
	},
	"stormcaller": {
		"tags": ["light"],
		"name": "Stormcaller", "hp": 90, "armor": 0, "speed": 56, "cost": 150, "cost2": 2, "time": 24.0, "supply": 2,
		"sight": 9, "range": 120, "damage": 7, "cooldown": 1.3, "aim": 0.25, "radius": 12, "from": "engine_hall",
		"requires": "charging_pylon", "anti_air": true, "faction": "clockwork",
		"about": "Fragile lightning caster. STORM stuns everything inside it for 2.5 s, friends too, but does no damage; it burns 2 stored batteries. Its charge only fills inside a Clockwork field.",
	},
	"missionary": {
		"tags": ["light"],
		"name": "Missionary", "hp": 60, "armor": 0, "speed": 62, "cost": 125, "time": 20.0, "supply": 1,
		"sight": 8, "range": 0, "damage": 0, "cooldown": 1.0, "radius": 10, "from": "church",
		"medic": true, "per": "church", "faction": "crown",
		"about": "Bandages wounded soldiers back to full health, and by himself raises fallen Crown soldiers from their bodies (6 s): back at half health under the cross for 30 s. One who falls again under the cross is gone for good. Can't be hurt unless near enemy buildings. One per Church. MOUNT a horse to ride as a Mounted Missionary.",
	},
	# the Missionary on a horse (MOUNT / DISMOUNT: Defs.MOUNTS)
	"mounted_missionary": {
		"tags": ["light"],
		"name": "Mounted Missionary", "hp": 60, "armor": 0, "speed": 124, "cost": 125, "time": 1.0, "supply": 1,
		"sight": 9, "range": 0, "damage": 0, "cooldown": 1.0, "radius": 13, "from": "",
		"medic": true, "mounted": true, "faction": "crown",
		"about": "A Missionary on a horse: as fast as a Messenger, unarmed. He gets off to bandage the wounded (and back on after); to raise the fallen he gets off by himself (and stays on foot). Can't be hurt unless near enemy buildings.",
	},
	"skywing": {
		"tags": ["light"],
		"name": "Skywing", "hp": 75, "armor": 0, "speed": 118, "cost": 100, "cost2": 40, "time": 16.0, "supply": 2,
		"sight": 9, "range": 130, "damage": 11, "cooldown": 1.1, "aim": 0.15, "radius": 13, "from": "hive",
		"air": true, "anti_air": true, "air_only": true, "requires": "roost", "faction": "brood",
		"about": "Flying, it hunts other flyers with volleys of spines (it can't touch the ground). LAND it (1.2 s) to fight on the ground with its bite: then it walks, can't cross cliffs, and anything can hit it. Costs essence.",
	},
	"mist_toad": {
		"tags": ["light"],
		"name": "Mist Toad", "hp": 90, "armor": 0, "speed": 42, "cost": 100, "cost2": 25, "time": 22.0, "supply": 3,
		"sight": 9, "range": 24, "damage": 4, "cooldown": 1.6, "aim": 0.3, "radius": 14, "from": "hive",
		"requires": "gorge_pit", "faction": "brood",
		"about": "Slow, fragile swamp caster with only a weak lick. Its energy (fills over time, faster on swamp) pays for two spells. FOG lays a swamp fog bank: shots fired from or into it miss half the time, and units inside see only 2 tiles. TONGUE marks one enemy for 3 s (they see the crosshair), then drags it to the Toad's feet; heavy engines are only staggered.",
	},
	"ornithopter": {
		"tags": ["light"],
		"name": "Ornithopter", "hp": 110, "armor": 1, "speed": 112, "cost": 150, "time": 22.0, "supply": 2,
		"sight": 9, "range": 140, "damage": 12, "cooldown": 1.4, "aim": 0.2, "radius": 13, "from": "engine_hall",
		"air": true, "anti_air": true, "vs_air": 1.75, "requires": "charging_pylon", "faction": "clockwork",
		"about": "Fast clockwork flyer with a lightning gun, deadliest against other flyers. On COURIER it fetches charged batteries and winds up stranded constructs; OVERLOAD dumps its battery into one construct (faster, harder hitting for 12 s). Like every construct it winds down away from a field.",
	},
	"tesla_cart": {
		"tags": ["armored"],
		"name": "Tesla Cart", "hp": 240, "armor": 2, "speed": 50, "cost": 180, "cost2": 2, "time": 28.0, "supply": 3,
		"sight": 9, "range": 170, "damage": 14, "cooldown": 1.6, "aim": 0.2, "radius": 18, "from": "engine_hall",
		"tesla": true, "anti_air": true, "requires": "charging_pylon", "faction": "clockwork",
		"about": "Mobile power: rolls packed; deploy it (3 s) to wind up (and overcharge) the constructs around it. Its lightning hits flyers too and jumps to one more enemy. Costs 2 energy.",
	},
}

const BUILDINGS := {
	"town_hall": {
		"name": "Town Hall", "hp": 1600, "armor": 2, "cost": 400, "time": 60.0, "size": Vector2i(5, 4),
		"supply": 10, "sight": 9, "trains": ["labourer"], "faction": "crown", "about": "Trains labourers. Each Town Hall allows 2 Farms and 1 Powder Mill nearby. Its farmland holds a reserve of gold (once the farms have drawn it out they pay a third) and its ground a reserve of saltpetre for the Mill (spent, the Mill grinds at a quarter). Expand to fresh land.",
	},
	"cottage": {
		"name": "Cottage", "hp": 400, "armor": 1, "cost": 100, "time": 20.0, "size": Vector2i(2, 2),
		"supply": 8, "sight": 5, "trains": [], "faction": "crown", "about": "Houses 8 more supply. The first one unlocks the Barracks and the palisade and gates.",
	},
	# Crown fortifications: one tile each, laid in a line (pick the start, then the end).
	"wall": {
		"name": "Palisade", "hp": 300, "armor": 2, "cost": 25, "time": 8.0, "size": Vector2i(1, 1),
		"supply": 0, "sight": 3, "trains": [], "line": true, "requires": "cottage", "faction": "crown",
		"about": "A wooden palisade: blocks the way. Lay it in a line: pick where it starts, then where it ends; the stakes join up with your other palisade and gates. Wall off your ramp and keep a gate.",
	},
	"gate": {
		"name": "Gate", "hp": 300, "armor": 2, "cost": 50, "time": 12.0, "size": Vector2i(1, 1),
		"supply": 0, "sight": 4, "trains": [], "line": true, "gate": true, "requires": "cottage", "faction": "crown",
		"about": "A piece of palisade that opens for your own side and your allies, and stays shut to the enemy. Lay it straight onto your own palisade to swap a piece for a gate. Gates turn to match the palisade they're placed in; R (ROTATE) turns one by hand: while placing, for where the palisade doesn't say; once built, for good.",
	},
	"barracks": {
		"name": "Barracks", "hp": 1000, "armor": 2, "cost": 150, "time": 40.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": ["musketeer", "cuirassier", "dragoon", "dismounted"], "requires": "cottage", "faction": "crown", "about": "Trains Musketeers (with a Powder Mill), Horsemen and Officers (with a Horse Breeder; a Horseman's horse comes in the same click) and Dragoons (both: a Musketeer and his horse); with Armour, the armoured ones too. Refits soldiers. Needs a Cottage. Two openings: Powder Mill first for Musketeers, or Horse Breeder first for a Horseman rush.",
	},
	"armoury": {
		"name": "Armoury", "hp": 1000, "armor": 2, "cost": 150, "time": 40.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": [], "requires": "barracks", "faction": "crown",
		"about": "All the Crown's research: Armour, the musket locks, the bayonet, the guns' drills and the Cavalry Charge. Refits soldiers. Needs a Barracks.",
	},
	"foundry": {
		"name": "Foundry", "hp": 900, "armor": 2, "cost": 200, "time": 45.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": ["cannon", "mortar", "balloon", "powder_wagon"], "requires": "barracks", "faction": "crown", "about": "Casts field cannons and mortars, rigs observation balloons and builds powder wagons (each cannon, mortar and wagon needs a horse: one at the Foundry, else a free one at a breeder walks over, else a breeder trains one; the gun waits for it). Needs a Barracks.",
	},
	"hive": {
		"name": "Burrow", "hp": 1500, "armor": 1, "cost": 350, "time": 55.0, "size": Vector2i(5, 4),
		"supply": 16, "sight": 9, "trains": ["grub", "raptor", "spitter", "brute", "skywing", "spore_mother", "bloater", "mist_toad"], "eggs": true, "swamp": 9,
		"faction": "brood", "about": "Lays eggs (up to 5); every Brood unit hatches here. Grubs bring food here. Allows 3 Feeding Pits and 1 Brood Pen nearby. Its ground holds a reserve of biomass: once the pits have drawn it out they yield a third. Expand to fresh ground. Upgrades to a Warren (10 eggs), then a Broodmound (15 eggs).",
	},
	"clutch_mound": {
		"name": "Clutch Mound", "hp": 350, "armor": 0, "cost": 75, "time": 18.0, "size": Vector2i(2, 2),
		"supply": 12, "sight": 5, "trains": [], "swamp": 7, "faction": "brood", "about": "12 more supply. Spreads swamp. Each one makes your Burrows lay eggs 10% faster (up to 3).",
	},
	"warren": {
		"name": "Spawning Den", "hp": 800, "armor": 1, "cost": 150, "time": 35.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": [], "swamp": 5, "faction": "brood", "about": "Lets your Burrows hatch Raptors and Spitters.",
	},
	"gorge_pit": {
		"name": "Gorge Pit", "hp": 800, "armor": 1, "cost": 200, "time": 45.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": [], "swamp": 5, "requires": "warren", "faction": "brood",
		"about": "Lets your Burrows hatch Brutes, Spore Mothers and Mist Toads, and a Warren grow into a Broodmound. Needs a Spawning Den.",
	},
	"clocktower": {
		"name": "Clocktower", "hp": 2000, "armor": 3, "cost": 400, "time": 60.0, "size": Vector2i(5, 4),
		"supply": 10, "sight": 9, "trains": ["winder"], "field": 9, "battery": [2.0, 6], "crew": 4, "faction": "clockwork",
		"about": "Builds Winders and fills a battery every 2 s. Allows 2 Boilers and 2 Ore Crushers nearby. Its ground holds a reserve of ore for its crushers (spent, they pay a quarter), and its Boilers share its coal (once that's burnt they fill batteries at a third). Expand to fresh coal and ore.",
	},
	"spring_tower": {
		"name": "Spring Tower", "hp": 500, "armor": 2, "cost": 100, "time": 20.0, "size": Vector2i(2, 2),
		"supply": 10, "sight": 6, "trains": [], "field": 7, "faction": "clockwork",
		"about": "10 more supply. Keeps nearby constructs wound up.",
	},
	"assembly_works": {
		"name": "Assembly Works", "hp": 1400, "armor": 3, "cost": 200, "time": 45.0, "size": Vector2i(5, 4),
		"supply": 0, "sight": 7, "trains": ["windup_soldier", "thresher", "bulwark", "arc_thrower"], "faction": "clockwork",
		"about": "Assembles the line: Wind-up Soldiers, Threshers, and (with a Boiler) Bulwarks and Arc Throwers. Faster with blue energy.",
	},
	"engine_hall": {
		"name": "Engine Hall", "hp": 1500, "armor": 3, "cost": 250, "time": 50.0, "size": Vector2i(4, 4),
		"supply": 0, "sight": 7, "trains": ["steam_walker", "tesla_cart", "stormcaller", "ornithopter"],
		"requires": ["assembly_works", "boiler"], "faction": "clockwork",
		"about": "Builds the big engines: Steam Walkers, and (with a Charging Pylon) Tesla Carts, Stormcallers and Ornithopters. They cost energy (stored batteries) too. Needs an Assembly Works and a Boiler.",
	},
	"farm": {
		"name": "Farm", "hp": 500, "armor": 1, "cost": 100, "time": 25.0, "size": Vector2i(6, 5),
		"supply": 0, "sight": 5, "trains": [], "crew": 8, "faction": "crown",
		"about": "Ripens into a 380-gold harvest about every 40 s with a full crew. Up to 8 labourers make it grow faster, each as much as the next. Harvests draw on its Town Hall's soil: tired soil pays a third.",
	},
	"powder_mill": {
		"name": "Powder Mill", "hp": 600, "armor": 1, "cost": 100, "time": 30.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 5, "trains": [], "crew": 6, "faction": "crown",
		"about": "Up to 6 labourers grind its Town Hall's saltpetre into black powder for the bank: it buys musketeers and wagons and pays for refilling soldiers' powder. Once that saltpetre is spent it grinds at a quarter. Soldiers and wagons nearby refill here.",
	},
	"horse_breeder": {
		"name": "Horse Breeder", "hp": 500, "armor": 1, "cost": 100, "time": 25.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 6, "trains": ["horse"], "faction": "crown",
		"about": "Sells horses: HORSE trains one (40 gold, 15 s; no supply). Horses are what cavalry, guns and wagons need. RALLY sends new horses somewhere (a Barracks or Foundry). Unlocks Horsemen. Build as many as you like, anywhere.",
	},
	"church": {
		"name": "Church", "hp": 900, "armor": 2, "cost": 150, "time": 35.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 7, "trains": ["missionary"], "requires": "barracks", "faction": "crown",
		"about": "Sends out one Missionary. Needs a Barracks.",
	},
	"feeding_pit": {
		"name": "Feeding Pit", "hp": 450, "armor": 0, "cost": 75, "time": 18.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 6, "trains": [], "crew": 5, "swamp": 4, "faction": "brood",
		"about": "Up to 5 grubs haul food from here to the nearest Burrow. Farther from the Burrow pays more per grub (best from about 18 to 22 tiles). Loads draw on that Burrow's ground: spent ground yields a third.",
	},
	"brood_pen": {
		"name": "Brood Pen", "hp": 600, "armor": 0, "cost": 100, "time": 22.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 6, "trains": [], "swamp": 4, "faction": "brood",
		"about": "Turns every body that falls nearby (friend or foe) into essence. SACRIFICE: Brood creatures brought here are offered up for essence (12% of their biomass cost: 3 a Raptor).",
	},
	"spore_vent": {
		"name": "Spore Vent", "hp": 300, "armor": 0, "cost": 90, "time": 16.0, "size": Vector2i(2, 2),
		"supply": 0, "sight": 7, "trains": [], "swamp": 12, "faction": "brood",
		"about": "Spreads swamp far around it.",
	},
	"roost": {
		"name": "Roost", "hp": 700, "armor": 1, "cost": 175, "time": 35.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 8, "trains": [], "swamp": 4, "requires": "warren", "faction": "brood",
		"about": "Lets your Burrows hatch Skywings. Needs a Spawning Den.",
	},
	"boiler": {
		"name": "Boiler", "hp": 900, "armor": 2, "cost": 150, "time": 30.0, "size": Vector2i(4, 4),
		"supply": 0, "sight": 6, "trains": [], "battery": [1.0, 8], "crew": 7, "faction": "clockwork",
		"about": "Fills a battery every second by itself, burning its Clocktower's coal (spent coal: a third as fast). Up to 7 Winders carry them to Ore Crushers. Constructs that stand by it a while get overcharged. Unlocks Bulwarks, Arc Throwers and the Engine Hall.",
	},
	"ore_crusher": {
		"name": "Ore Crusher", "hp": 800, "armor": 2, "cost": 125, "time": 30.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 6, "trains": [], "faction": "clockwork",
		"about": "Winders bring batteries here and the charge becomes ore, drawn from its Clocktower's ore; once that's spent it pays a quarter. The farther a battery travelled, the more it holds.",
	},
	"capacitor_works": {
		"name": "Capacitor Works", "hp": 900, "armor": 2, "cost": 250, "time": 50.0, "size": Vector2i(2, 2),
		"supply": 0, "sight": 7, "trains": [], "requires": "assembly_works", "faction": "clockwork",
		"about": "Blue energy: every source fills blue batteries, with more charge and more time before they overload. Needs an Assembly Works.",
	},
	"charging_pylon": {
		"name": "Charging Pylon", "hp": 600, "armor": 2, "cost": 150, "time": 30.0, "size": Vector2i(2, 2),
		"supply": 0, "sight": 7, "trains": [], "field": 7, "mends": 3.0, "faction": "clockwork",
		"about": "Winds up and slowly mends constructs nearby (they get overcharged after a while in its field). Unlocks the Tesla Cart, the Stormcaller and the Ornithopter.",
	},
}



## Research: done once per player at a building (`at`), paid in the first resource (`cost`)
## and the second (`cost2`), taking `time` seconds; `requires` another research first,
## `needs` a finished building of that kind. (`icon`: assets/icons/<icon>.png; `label`: its
## button's, when the name is too long for one.)
## Crown, all at the Armoury. EQUIPMENT (Armour, the musket locks, the socket bayonet) only
## UNLOCKS the upgrade: each soldier is then refitted one by one (REFIT): he walks to a
## Barracks, an Armoury or a Powder Wagon and pays `fee` gold (+ `fee2` powder) there
## (Armour: `fees` per kind, [gold, powder]). New Musketeers come out with the locks and the
## bayonet researched, their fees added to their price; Armour adds a second, armoured
## recruit at the Barracks for each soldier (Guardsman, Cuirassier: ARMOURED), priced with
## its fee. A lock sets his reload to `reload` of the base (the totals, not on top of each
## other); a soldier refitted to a later lock skips the ones between and pays only its fee.
## DRILLS (`drill`: Prepared Charges, the Gunner's Quadrant, the Cavalry Charge) are a
## technique, not equipment: every unit of their `kinds` has them at once, for nothing.
const RESEARCH := {
	"armour": {"name": "Armour", "at": "armoury", "faction": "crown", "cost": 125, "cost2": 50, "time": 45.0,
		"icon": "research_armour", "needs": "foundry", "fees": {"musketeer": [12, 4], "cuirassier": [30, 0], "dragoon": [12, 4], "dismounted": [30, 0]},
		"about": "Breastplates, morions and cuirasses: unlocks the ARMOUR refit for Musketeers (they become Guardsmen: +1 armour, +20 health; 12 gold + 4 powder a man) and Horsemen (they become Cuirassiers: +1 armour, +30 health, a little slower; 30 gold). The Barracks can then train both armoured."},
	"matchlock": {"name": "Matchlock", "at": "armoury", "faction": "crown", "cost": 50, "cost2": 10, "time": 30.0,
		"icon": "research_matchlock", "reload": 0.9, "fee": 8,
		"about": "Better matchlocks: unlocks the refit (reload 10% faster, powder burns faster), 8 gold a man. New Musketeers come out with it."},
	"flintlock": {"name": "Flintlock", "at": "armoury", "faction": "crown", "cost": 75, "cost2": 25, "time": 40.0,
		"icon": "research_flintlock", "reload": 0.8, "requires": "matchlock", "needs": "foundry", "fee": 12,
		"about": "Flintlocks: unlocks the refit (reload 20% faster than at the start), 12 gold a man. New Musketeers come out with it."},
	"caplock": {"name": "Caplock", "at": "armoury", "faction": "crown", "cost": 100, "cost2": 40, "time": 50.0,
		"icon": "research_caplock", "reload": 0.7, "requires": "flintlock", "fee": 16,
		"about": "Percussion caps: unlocks the refit (reload 30% faster than at the start), 16 gold a man. New Musketeers come out with it."},
	"bayonet": {"name": "Socket Bayonet", "label": "BAYONET", "at": "armoury", "faction": "crown", "cost": 40, "cost2": 0, "time": 20.0,
		"icon": "research_bayonet", "damage": 6.0, "cooldown": 0.85, "fee": 3,
		"about": "A socket bayonet that leaves the muzzle free: unlocks the refit (bayonet +6 damage, thrusts 15% faster), 3 gold a man. New Musketeers come out with it."},
	"pouch": {"name": "Shot Pouch", "label": "POUCH", "at": "armoury", "faction": "crown", "cost": 60, "cost2": 20, "time": 25.0,
		"icon": "research_pouch", "fee": 5,
		"about": "A bigger shot pouch: unlocks the refit (he carries 20 shots instead of 10), 5 gold a man. Every musket soldier: Musketeers, Guardsmen and Dragoons. Recruits don't come with it."},
	"charges": {"name": "Prepared Charges", "label": "CHARGES", "at": "armoury", "faction": "crown", "cost": 100, "cost2": 40, "time": 40.0,
		"icon": "research_charges", "needs": "foundry", "drill": true, "kinds": ["cannon", "mortar"], "reload": 0.8,
		"about": "Powder in ready-made bags: every Field Cannon and Mortar reloads 20% faster."},
	"quadrant": {"name": "Gunner's Quadrant", "label": "QUADRANT", "at": "armoury", "faction": "crown", "cost": 125, "cost2": 30, "time": 45.0,
		"icon": "research_quadrant", "requires": "charges", "drill": true, "kinds": ["cannon", "mortar"], "range": 32,
		"about": "Laying the guns by the quadrant: every Field Cannon and Mortar reaches 1 tile further."},
	"charge": {"name": "Cavalry Charge", "label": "CHARGE", "at": "armoury", "faction": "crown", "cost": 60, "cost2": 0, "time": 25.0,
		"icon": "research_charge", "drill": true, "kinds": ["cuirassier"],
		"about": "Drilled to charge: after about 2 s at the gallop a Horseman's or Cuirassier's next sabre blow hits double and throws the enemy back."},
}
## The musket locks, in order.
const LOCKS := ["matchlock", "flintlock", "caplock"]
## Light and armoured: a soldier of these kinds refitted with Armour (or trained armoured)
## is the armoured version: his name, tag ("armored"), portrait and sprites (`art`) follow,
## and his armour, health and speed change by these. Unarmoured (tag "light") he wears
## LIGHT_ART (or his own kind's sprites).
const ARMOURED := {
	"musketeer": {"name": "Guardsman", "key": "guardsman", "art": "musketeer_armoured", "armor": 1, "hp": 20, "speed": 0,
		"about": "Armoured line infantry: a Musketeer in morion and breastplate (+1 armour, +20 health). Fires at range and stabs with the bayonet up close."},
	"cuirassier": {"name": "Cuirassier", "key": "cuirassier", "art": "cuirassier", "armor": 1, "hp": 30, "speed": -4,
		"about": "Fast armoured horseman with a pistol and a sabre: a Horseman in helmet and cuirass (+1 armour, +30 health, a little slower). Bayonets hurt him."},
	"dragoon": {"name": "Armoured Dragoon", "key": "armoured_dragoon", "art": "cuirassier", "armor": 1, "hp": 20, "speed": -4,
		"about": "A Guardsman on a horse: rides fast, dismounts to fire as a Guardsman and remounts to move on."},
	"dismounted": {"name": "Armoured Officer", "key": "dismounted_cuirassier", "art": "musketeer_armoured", "armor": 1, "hp": 30, "speed": -2,
		"about": "A Cuirassier on foot: pistol and sabre, in his cuirass; he reloads the pistol by himself on foot. MOUNT a horse and he rides as a Cuirassier."},
}
const LIGHT_ART := {"cuirassier": "horseman"}

## ---- Horses (the Crown). A Horse Breeder trains them for gold (UNITS.horse: cost, time);
## nothing comes free and it pays no income. Horses graze within `wander` px of
## where they were left. Training a unit with "needs_horse" takes a horse of ours standing
## within `at_building` tiles of the building (led ones too). A man leads up to `lead_max`.
## A horse with nobody of its side leading it, coming to mount or harness it, and no unit of
## its side within `guard` tiles, is stolen by an enemy man within `steal` px (Crown men on
## foot or riding, Clockwork Winders; never the Brood). MOUNT takes `mount` s, DISMOUNT
## `dismount` s, a Dragoon's own dismount-to-fire and remount `quick` s; on foot after that
## dismount he reloads at `dragoon_reload` x a Musketeer's time. LEAD / MOUNT / HARNESS look
## for free horses within `fetch` tiles.
## A gun or wagon draws a team of up to `team_max` horses: each beyond the first adds
## `team_speed` of its speed (4 horses: +36%, a cannon 38 -> 52, still far slower than cavalry);
## while it has extra horses they take `team_hit` of every blow it takes, front one first
## (a horse's 60 health), and one killed drops the speed again.
## One click trains the rider and his horse: a unit that needs a horse takes one standing at
## its building, else a free one within `near_breeder` tiles of a Horse Breeder of ours
## (reserved for it), else the nearest breeder queues one for it (paying for it).
## Loose horses: when a rider is killed his horse may live and bolt, belonging to nobody
## (team -1), by the blow that killed him (Entity.last_blow): `bolt_ranged` for a single
## shot at range (muskets, carbines, acid globs, single zaps), `bolt_melee` for a sabre,
## bayonet or Clockwork blow; never for the Brood's jaws, splash or area (round shot,
## canister, shells, blasts, chain lightning, clouds, spells), nor for a horse with no more
## than `bolt_hp` of its health. It gallops (`bolt_speed` x its pace) `bolt_tiles` tiles
## away from the killer, then grazes there; any man who can lead horses takes it by walking
## up to it. A gun destroyed by a shot or a blow (not a blast) gives each horse of its team
## the same chance. A raised rider walks back to his own loose horse within `bolt_back` tiles.
## (Tests override the two chances with Unit.bolt_force: Defs are read-only.)
const HORSES := {"wander": 34.0,
	"at_building": 2.0, "lead_max": 3, "guard": 2.0, "steal": 26.0, "mount": 1.5, "dismount": 1.0,
	"quick": 0.8, "dragoon_reload": 1.3, "scan": 0.5, "fetch": 8,
	"team_max": 4, "team_speed": 0.12, "team_hit": 0.3, "near_breeder": 4.0,
	"bolt_ranged": 0.4, "bolt_melee": 0.25, "bolt_hp": 0.2, "bolt_tiles": [5.0, 7.0], "bolt_speed": 1.4,
	"bolt_back": 8.0}
## The saddle cloth of a loose horse (nobody's): a faded greyish white.
const NEUTRAL_CLOTH := Color(0.86, 0.85, 0.80)
## Who rides what: the man on foot -> the mounted unit (and back with FOOT). Armour, his locks,
## bayonet, pouch, kills, powder, hp share and reload go across both ways.
const MOUNTS := {"labourer": "messenger", "musketeer": "dragoon", "dismounted": "cuirassier", "missionary": "mounted_missionary"}
const FOOT := {"messenger": "labourer", "dragoon": "musketeer", "cuirassier": "dismounted", "mounted_missionary": "missionary"}
## Men who can lead horses by the reins (and the Clockwork's Winders).
const LEADERS := ["labourer", "musketeer", "dismounted", "messenger", "winder"]
## Units drawn by a horse: without one (RELEASE HORSE) they stand where they are.
const HARNESSED := ["cannon", "mortar", "powder_wagon"]
## Soldiers who carry a musket (locks, the shot pouch, the musket's powder). (The Officer
## carries a pistol now: Defs.PISTOL.)
const MUSKETS := ["musketeer", "dragoon"]
## Riders the Barracks trains with their horse in one click: with a horse at the Barracks he
## comes out mounted; with one kept for him at a breeder he comes out as the man on foot
## (this kind) and walks to it.
const RIDERS := {"cuirassier": "dismounted", "dragoon": "musketeer"}

## The horse system's art table: every sprite choice in one place, so new sheets drop in by
## changing this table only. "art": the ArtData.UNITS sprite set a unit kind wears
## ("armoured": with Armour); "portrait" / "portrait_armoured": its icon
## (assets/icons/<name>.png) while it has none of its own; "feather" / "feather_armoured": a
## plume drawn on his hat (a stand-in sprite, to tell him from a Musketeer); "building": the
## sprite name of a building (assets/buildings/<name>_<state>.png). The designer's sheets:
## tools/import_horse_units.py (horse, messenger, dragoon, dragoon_armoured, dismounted,
## dismounted_armoured, missionary_mounted) and tools/import_horse_breeder.py. Still TEMPORARY: the portraits of
## the new units and the Shot Pouch's and horse commands' icons.
const TEMP_ART := {
	"horse": {"art": "horse", "portrait": "horse"},
	"messenger": {"art": "messenger", "portrait": "messenger"},
	"dragoon": {"art": "dragoon", "armoured": "dragoon_armoured", "portrait": "dragoon", "portrait_armoured": "dragoon_armoured"},
	"dismounted": {"art": "dismounted", "armoured": "dismounted_armoured", "portrait": "dismounted", "portrait_armoured": "dismounted_armoured"},
	"mounted_missionary": {"art": "missionary_mounted", "portrait": "mounted_missionary"},
	"horse_breeder": {"building": "horse_breeder", "portrait": "horse_breeder"},
	# the horse commands' card icons (tools/import_horse_icons.py)
	"horse_lead": {"portrait": "horse_lead"},
	"horse_release": {"portrait": "horse_release"},
	"horse_mount": {"portrait": "horse_mount"},
	"horse_dismount": {"portrait": "horse_dismount"},
	"horse_harness": {"portrait": "horse_harness"},
	"horse_unhitch": {"portrait": "horse_unhitch"},
}


## The sprite set (ArtData.UNITS key) for a unit kind, light or armoured, through TEMP_ART.
static func art_for(kind: String, armoured: bool) -> String:
	if TEMP_ART.has(kind) and TEMP_ART[kind].has("art"):
		return String(TEMP_ART[kind].get("armoured", TEMP_ART[kind]["art"])) if armoured else String(TEMP_ART[kind]["art"])
	if armoured and ARMOURED.has(kind):
		return String(ARMOURED[kind]["art"])
	return String(LIGHT_ART.get(kind, kind))


## The icon standing in for one not drawn yet (TEMP_ART "portrait"), or the name itself.
static func icon_for(name: String) -> String:
	for k in TEMP_ART:
		var akey := String(ARMOURED[k]["key"]) if ARMOURED.has(k) else "-"
		if name == k or name == akey:
			var info: Dictionary = TEMP_ART[k]
			return String(info.get("portrait_armoured", info.get("portrait", name))) if name == akey else String(info.get("portrait", name))
	return name
## The Barracks' train buttons: key -> [unit kind, armoured]. The kinds stay "musketeer",
## "cuirassier", "dragoon" and "dismounted" (saves, the AI, hotkeys); the armoured ones need
## Armour researched and cost its fee on top. (The key "cuirassier" is the armoured horseman,
## "dismounted" the Officer, "dismounted_cuirassier" the Armoured Officer.)
const TRAIN_AS := {"musketeer": ["musketeer", false], "guardsman": ["musketeer", true],
	"horseman": ["cuirassier", false], "cuirassier": ["cuirassier", true],
	"dragoon": ["dragoon", false], "armoured_dragoon": ["dragoon", true],
	"dismounted": ["dismounted", false], "dismounted_cuirassier": ["dismounted", true]}


## A research's button label.
static func research_label(key: String) -> String:
	return String(RESEARCH[key].get("label", String(RESEARCH[key]["name"]).to_upper()))


static func train_kind(key: String) -> String:
	return String(TRAIN_AS[key][0]) if TRAIN_AS.has(key) else key


static func train_armoured(key: String) -> bool:
	return TRAIN_AS.has(key) and bool(TRAIN_AS[key][1])


## The train button for a soldier of this kind, light or armoured.
static func train_key(kind: String, armoured: bool) -> String:
	if ARMOURED.has(kind):
		if armoured:
			return String(ARMOURED[kind]["key"])
		return "horseman" if kind == "cuirassier" else kind
	return kind


static func train_name(key: String) -> String:
	var k := train_kind(key)
	if train_armoured(key):
		return String(ARMOURED[k]["name"])
	return String(UNITS[k]["name"]) if UNITS.has(k) else key


## The train buttons for a building's kinds: a light and an armoured one for each soldier
## that has both (`armour`: Armour researched; without it only the light one).
static func train_keys(kinds: Array, armour: bool) -> Array:
	var out: Array = []
	for k in kinds:
		if ARMOURED.has(k):
			out.append(train_key(k, false))
			if armour:
				out.append(train_key(k, true))
		else:
			out.append(k)
	return out


## Refitting a soldier: `time` s at a Barracks, an Armoury or a Powder Wagon (within `reach`
## px of it). AUTO REFIT (a toggle on each of them) sends idle soldiers within `auto` tiles
## of it, every `scan` s.
const REFIT := {"time": 2.0, "reach": 20.0, "auto": 3, "scan": 1.0, "give_up": 40.0}
## The buildings soldiers are refitted at (and every Powder Wagon).
const REFIT_AT := ["barracks", "armoury"]


## Units whose art is still being finished: they can't be trained yet.
const PENDING := []


static func is_worker(kind: String) -> bool:
	return Defs.UNITS.has(kind) and Defs.UNITS[kind].get("worker", false)


## Basic structures (halls, supply, economy) go on the BUILD page; production and tech
## buildings on ADVANCED.
## Crown abilities.
## Musketeer bayonet: used by itself on an enemy on the ground within `close` px (edge to
## edge), and on anything once the powder has run dry. It can't reach flyers.
const BAYONET := {"range": 26.0, "close": 30.0, "damage": 18.0, "cooldown": 1.0, "aim": 0.2,
	"bonus": {"cannon": 2.0, "spitter": 1.3, "cuirassier": 1.5}}
const CANNON_SWITCH := 2.5       # limber / unlimber
const MORTAR_SWITCH := 3.0       # deploy / pack
## Mortar shell: lobbed high (`arc`: the top of its flight as a share of the distance, at
## `speed` px a second along the ground) and bursting where it lands: every ground unit
## within the Mortar's splash is hurt, friends too, `edge` of the blow at the rim.
const MORTAR := {"arc": 0.55, "speed": 240.0, "edge": 0.5}
## Missionary priorities (on foot or mounted, ordered or on his own): bodies first, scored
## worth x urgency / distance (Game.body_score: worth = price + `per_kill` a kill; a body he
## couldn't reach and raise before its window closes is skipped), then the wounded missing at
## least `hurt` of their health, scored worth x health missing / (1 + distance / `near_patient`)
## (Game.patient_score). Idle or walking to a patient, he looks again every `rescan` s; a raise
## once begun is only given up if the body can't be raised any more. A target another
## Missionary of his side has claimed is left to him.
const CARE := {"per_kill": 20.0, "near_body": 300.0, "near_patient": 600.0, "hurt": 0.25, "rescan": 1.0}
## Missionary raising the fallen: a Crown soldier's body can be raised for `window` s after
## he falls; it takes `time` s and he comes back with `hp` of his health and the cross for
## `cross` s (no bandaging or raising meanwhile). Falling again under the cross, he's gone
## for good. Idle Missionaries look for bodies within `scan` tiles. Soldiers (`kinds`) only:
## not labourers, guns, wagons or balloons.
const REVIVE := {"time": 6.0, "hp": 0.5, "cross": 30.0, "window": 60.0, "scan": 10,
	"kinds": ["musketeer", "cuirassier", "dismounted", "dragoon"]}
## Clockwork towers zap flyers with chain lightning; while they do, their field is off.
const TOWER_ZAP := {"range": 8.0, "damage": 10.0, "cooldown": 1.6, "chain": 3, "jump": 110.0, "falloff": 0.7, "off": 3.0}
## Horseman / Cuirassier, once the Cavalry Charge is researched: after galloping this long,
## his next blow is a charge.
const CHARGE := {"run": 2.0, "mult": 2.0, "force": 300.0, "stun": 0.6}
## Stormcaller: a storm of lightning that stuns everything inside (friends too).
## A control spell, not a killer (the rework: was radius 96, 3 s, 8 damage a second to
## enemies, charge only): it stuns, hurts almost nothing, and burns `cost2` stored batteries.
const STORM := {"cost": 70.0, "cost2": 2, "max": 100.0, "fill": 7.0, "range": 260.0, "radius": 80.0, "time": 2.5, "dps": 0.0, "cast": 0.7}
## Spore Mother: rooting takes a while; rooted she spreads swamp. Miasma heals the Brood
## inside it, up to a share of each unit's health per cloud; clouds don't stack.
## Bloater: its acid cloud
## (a full sac: burst damage and cloud at their biggest; each spit empties some of it).
## `buildings`: the cloud eats enemy buildings inside it at this share of `dps`.
const BLOAT := {"radius": 80.0, "time": 9.0, "dps": 4.0, "slow": 0.6, "burst": 60.0, "spit_cost": 15.0, "reach": 22.0, "buildings": 0.5}
## Bloater out of gas: it deflates (no spitting, no bursting, slower) and fills up again.
const DEFLATE := {"refill": 4.0, "swamp": 2.0, "slow": 0.8, "anim": 0.8}
## Observation Balloon as a dropship: who can ride in the basket and what a fall costs.
const DROPSHIP := {"capacity": 4, "kinds": ["musketeer", "labourer"], "fall": 0.5, "board": 26.0, "give_up": 30.0}
## Skywing landed: a ground unit that bites (these replace its flying stats).
const SKYWING_LANDED := {"air": false, "air_only": false, "ground_only": true, "anti_air": false,
	"speed": 70, "range": 24, "damage": 14, "cooldown": 1.0, "aim": 0.15}
const SKYWING_SWITCH := 1.2       # landing / taking off
## Ornithopter: winding a construct from a carried battery, and overloading one with it.
const TOPTER := {"load": 0.8, "wind": 0.8, "low": 0.5, "reach": 22.0}
const OVERLOAD := {"time": 12.0, "damage": 1.5, "speed": 1.3, "cooldown": 0.75, "after": 0.25, "reach": 30.0}
## Veterancy: every kill adds damage (to a cap); a fallen unit's body holds essence for the
## Brood: a little for its size, more for every kill it made. It shows on the sprite
## (VetLook): a Crown soldier's trim is black, silver from `silver` kills, gold from `gold`;
## a Brood creature's skin as painted, amber-ochre, then obsidian.
const VET := {"per_kill": 0.01, "max": 0.5, "silver": 25, "gold": 50}
## A horse's own veterancy: every `tiles` it travels under a rider or in harness (a gun's,
## mortar's or wagon's team) it's a rank more seasoned, up to `max`: each rank +`hp` health
## (its share of a rider's too) and +`body` supply's worth of essence in its carcass.
const HORSE_VET := {"tiles": 100.0, "max": 3, "hp": 0.15, "body": 1}
const HORSE_REGEN := 0.5          # hp a second: horses heal by themselves (they're never raised)
const HARVEST := {"time": 120.0, "range": 10, "take": 1.2, "per_supply": 1}
const ROOT_SWITCH := 2.5
const ROOT_SWAMP := 4.0          # tiles
const MIASMA := {"cost2": 30, "cooldown": 18.0, "range": 220.0, "radius": 96.0, "time": 8.0, "hps": 7.0, "cap": 0.3, "cast": 0.7}
## Mist Toad: its energy (`charge`) fills `fill` a second (x `swamp` on Brood swamp) up to
## `max`; a new Toad hatches with `start`. Its two spells spend it.
const TOAD := {"max": 150.0, "fill": 1.5, "swamp": 2.0, "start": 75.0}
## FOG: a swamp fog bank (`radius` px) laid on a spot within `range` for `time` s. Ranged
## attacks (range 100+) fired from inside it or into it miss `miss` of the time, and units
## inside see only `sight` tiles. It hides everyone, friend or foe.
const FOG := {"cost": 50.0, "range": 224.0, "radius": 96.0, "time": 12.0, "miss": 0.5, "sight": 2, "cast": 0.6}
## TONGUE: one enemy ground unit within `range` px is marked for `windup` s (its owner sees
## the crosshair); the windup breaks if the Toad is stunned, killed or moved more than
## `moved` px, or the target gets beyond `break` x the range. Then the tongue lashes out
## (`lash` s) and drags it to the Toad's feet over `pull` s, stunned meanwhile (and `after` s
## more). Heavy units (supply `heavy`+ or tagged massive, like the Steam Walker) can't be
## pulled: they're staggered (stunned `stagger` s). The energy is spent when the windup starts.
const TONGUE := {"cost": 75.0, "range": 224.0, "windup": 3.0, "break": 1.5, "moved": 12.0, "lash": 0.15,
	"pull": 0.6, "after": 0.3, "stagger": 1.0, "heavy": 5}
const CANISTER := {"range": 150.0, "damage": 18.0, "cooldown": 3.6, "cone": 0.82, "vs_light": 1.5}
## Round shot: the ball tears through a line of men past where it lands (bonus against
## armour); only a little splash where it hits.
const ROUND_SHOT := {"line": 90.0, "width": 9.0, "vs_armored": 1.75, "splash": 24.0, "splash_dmg": 0.35}


static func has_tag(kind: String, tag: String) -> bool:
	return UNITS.has(kind) and (UNITS[kind].get("tags", []) as Array).has(tag)

const ADVANCED := ["barracks", "horse_breeder", "armoury", "foundry", "church", "warren", "gorge_pit", "roost", "assembly_works", "engine_hall", "charging_pylon", "capacitor_works"]


static func is_basic(kind: String) -> bool:
	return not ADVANCED.has(kind)


static func is_econ(kind: String) -> bool:
	if not BUILDINGS.has(kind):
		return false
	return FACTIONS[BUILDINGS[kind]["faction"]]["econ"].has(kind)

const TEAM_COLOURS := [Color("#3a78e8"), Color("#e03a32")]
const TEAM_NAMES := ["Blue", "Red"]
## Player colours to choose from (the art's pure-red parts are recoloured to these).
## Lobby colour choices besides the palette: any colour at random, or a random colour that
## stands out on the map's ground (no green armies on a green map).
const COLOUR_RANDOM := -1
const COLOUR_FITS_MAP := -2
## Palette colours that blend into each biome's ground.
const BIOME_AVOID := {
	"grass": ["Green"], "marsh": ["Green"], "autumn": ["Orange", "Yellow"], "desert": ["Yellow", "Orange"],
	"snow": ["Blue"], "volcanic": ["Red", "Orange"],
	"heath": ["Green", "Purple", "Pink"], "jungle": ["Green", "Teal"], "canyon": ["Orange", "Red"],
	"tundra": ["Blue", "Teal"], "ashland": ["Red", "Orange"], "pinewood": ["Green", "Orange"],
	"steppe": ["Yellow", "Orange"], "coast": ["Teal", "Yellow"], "oldkingdom": ["Green"], "bog": ["Green"],
	"glowwood": ["Teal", "Blue"], "fall": ["Orange", "Yellow", "Red"], "badlands": ["Yellow"],
}


static func colour_name(c: int) -> String:
	if c == COLOUR_RANDOM:
		return "Random"
	if c == COLOUR_FITS_MAP:
		return "Fits map"
	return PALETTE[c][0]


static func colour_of(c: int) -> Color:
	if c < 0:
		return Color(0.45, 0.42, 0.38)
	return PALETTE[c][1]


const PALETTE := [
	["Blue", Color("#3a78e8")], ["Red", Color("#e03a32")], ["Green", Color("#3fae4a")],
	["Yellow", Color("#e8c53a")], ["Purple", Color("#9a4fd6")], ["Orange", Color("#ec8a2c")],
	["Teal", Color("#22c4b4")], ["Pink", Color("#f07ac0")],
]


## Short texts for the hover / "?" tooltips (Crown and Brood; the Clockwork's come later).
## Where a kind has none, the tooltip falls back to its "about" text.
const TIPS := {
	# Crown units
	"labourer": "Works Farms and Powder Mills, builds and repairs. Weak in a fight.",
	"musketeer": "Light line infantry (needs a Powder Mill): 10 shots, a long reload, the bayonet up close. Hits flyers. Refills powder near a Mill, Barracks, Hall or Wagon. MOUNT a horse: a Dragoon.",
	# horse commands (the command card's tooltips)
	"LEAD": "Each man takes up to 3 of your free horses nearby by the reins; they follow at his side. (Right-click a horse with Labourers: they lead it.)",
	"RELEASE": "Let go of the reins: the horses stay where they stand and graze. Unattended, an enemy man can steal them.",
	"MOUNT": "Each man walks to the nearest free horse and gets on (1.5 s): Labourer to Messenger, Musketeer to Dragoon, Guardsman to Armoured Dragoon, Missionary to Mounted Missionary, Officer to Horseman (his pistol as it is). (Right-click a horse with soldiers: they mount it.)",
	"DISMOUNT": "Get off (1 s): the horse stands beside him, unled. He can lead it or remount it; left alone, it can be stolen.",
	"RELEASE HORSE": "Unhitch one horse (the front one of a team first): it stands free. With none left the gun or wagon can't move, but a gun still fires and a wagon still supplies.",
	"HARNESS": "Your nearest free horse walks over and is hitched: one more each time, up to 4 in a team, each beyond the first +12% speed. (Or right-click the gun with a horse selected or led.)",
	"guardsman": "Armoured line infantry (+1 armour, +20 health): a Musketeer in morion and breastplate. Needs Armour.",
	"horseman": "Fast light horseman: one pistol shot (30 damage, 110 reach), then the sabre. Needs a Horse Breeder; one click trains him and his horse (40 more without a spare). He reloads only on foot. With the Cavalry Charge his first sabre blow after a gallop hits double. Bayonets hurt him.",
	"cannon": "Long-range artillery (it needs a horse: one click finds or buys it). HARNESS up to 4 horses: +12% speed each. UNLIMBER to fire: round shot ploughs through lines, canister shreds light units and flyers. Needs spotters.",
	"mortar": "Siege mortar: DEPLOY, then it lobs shells over walls 5 to 11 tiles away. The splash hurts friends too. Can't hit flyers.",
	"powder_wagon": "Carries 120 shots of powder for the soldiers near it. No weapon, and it blows up when destroyed.",
	"cuirassier": "Fast armoured horseman (+1 armour, +30 health): a Horseman in helmet and cuirass, pistol and sabre. Needs Armour; his horse comes with him (one click). Bayonets hurt him.",
	"horse": "Bought at a Horse Breeder (40 gold, 15 s). LEAD it, MOUNT it, harness it to a gun or wagon, or bring it to a Barracks or Foundry: cavalry and guns need one each. Left alone near an enemy man, it's stolen.",
	"messenger": "A Labourer on a horse: very fast, unarmed, sees far. A scout. He can lead horses too.",
	"mounted_missionary": "A Missionary on a horse: fast and unarmed. Gets off to bandage (and back on after) and to raise the fallen.",
	"dragoon": "A Musketeer on a horse: rides fast, dismounts to fire (0.8 s), remounts to move. His reload waits while he rides. Needs a Powder Mill and a Horse Breeder; one click trains him and his horse (40 more without a spare).",
	"armoured_dragoon": "A Guardsman on a horse: rides fast, dismounts to fire, remounts to move. Needs Armour; his horse comes with him (one click).",
	"dismounted": "Officer: a Horseman on foot. One pistol shot (30 damage, 110 reach), then the sabre; he reloads the pistol by himself on foot (4 s, a little powder). Needs a Horse Breeder. MOUNT a horse: a Horseman.",
	"dismounted_cuirassier": "Armoured Officer: a Cuirassier on foot, pistol and sabre, in his cuirass; reloads on foot. Needs Armour. MOUNT a horse: a Cuirassier.",
	"balloon": "Carries 4 Musketeers or Labourers anywhere, over cliffs too. Musketeers aboard shoot 35% further. Slow and fragile.",
	"missionary": "Bandages the wounded and raises fallen Crown soldiers. Can't be hurt away from enemy buildings. One per Church.",
	# Brood units
	"grub": "Hauls food from Feeding Pits to a Burrow (longer hauls pay more) and turns into buildings.",
	"raptor": "Fast, flimsy claws. Three hatch from each egg.",
	"spitter": "Spits acid that burns and strips armour. Two hatch from each egg.",
	"brute": "Huge horned tank: charges in and knocks enemies back.",
	"spore_mother": "ROOT her to lob splashing spit blobs and spread swamp; MIASMA heals the Brood. Can't attack while walking.",
	"bloater": "Floating acid sac: spits from afar until its gas runs out. On HOLD GAS it drifts in to burst as a huge acid bomb.",
	"skywing": "Flying, it hunts flyers with spines. LAND it to bite ground units (then anything can hit it).",
	"mist_toad": "Swamp caster. FOG makes shots miss half the time; TONGUE drags an enemy to its feet. Weak in a fight.",
	# Crown buildings
	"town_hall": "Trains Labourers. Allows 2 Farms and 1 Powder Mill nearby; its soil and saltpetre run out in time.",
	"horse_breeder": "Trains horses: 40 gold and 15 s each, no supply; RALLY sends them on. Unlocks Horsemen; cavalry, guns and wagons need its horses. Build as many as you like, anywhere. Two openings: Powder Mill first for Musketeers, or Horse Breeder first for a Horseman rush.",
	"cottage": "Houses 8 more supply. The first one unlocks the Barracks and the palisade.",
	"wall": "Palisade: blocks the way. Lay it in a line: pick the start, then the end. Needs a Cottage.",
	"gate": "A palisade piece that opens for your side only. Lay it onto your own palisade to swap a piece. Needs a Cottage.",
	"barracks": "Trains Musketeers (needs a Powder Mill), Horsemen and Officers (need a Horse Breeder), Dragoons (both), and with Armour the armoured ones. Refits soldiers. Needs a Cottage. Two openings: Powder Mill first for Musketeers, or Horse Breeder first for a Horseman rush.",
	"armoury": "Researches Armour, the musket locks, the socket bayonet, the guns' drills and the Cavalry Charge. Refits soldiers too.",
	"foundry": "Casts cannons and mortars, rigs balloons, builds powder wagons (each needs a horse: one standing here, else one from a breeder walks over by itself).",
	"farm": "Ripens into a 380-gold harvest about every 40 s with a full crew (up to 8 Labourers).",
	"powder_mill": "Up to 6 Labourers grind the Hall's saltpetre into powder (you start with none). Unlocks Musketeers. Soldiers and wagons nearby refill here.",
	"church": "Sends out one Missionary.",
	# Brood buildings
	"hive": "Lays eggs (up to 5): every Brood unit hatches here. Grubs bring food here. Allows 3 Feeding Pits and 1 Brood Pen nearby. Upgrades to a Warren (10 eggs), then a Broodmound (15).",
	"clutch_mound": "12 more supply. Spreads swamp; each makes Burrows lay eggs 10% faster (up to 3).",
	"warren": "Lets your Burrows hatch Raptors and Spitters.",
	"gorge_pit": "Lets your Burrows hatch Brutes, Spore Mothers and Mist Toads; a Warren can grow into a Broodmound.",
	"feeding_pit": "Up to 5 grubs haul food from here to the Burrow. Farther from the Burrow pays more (best 18 to 22 tiles).",
	"brood_pen": "Bodies falling nearby give essence. SACRIFICE Brood creatures here for essence.",
	"spore_vent": "Spreads swamp far around it.",
	"roost": "Lets your Burrows hatch Skywings and Bloaters.",
	# Crown research
	"armour": "Unlocks the ARMOUR refit (Guardsman: +1 armour, +20 health; Cuirassier: +1 armour, +30 health) and the armoured recruits.",
	"matchlock": "Unlocks the Matchlock refit: reload 10% faster. New Musketeers come out with it.",
	"flintlock": "Unlocks the Flintlock refit: reload 20% faster than at the start.",
	"caplock": "Unlocks the Caplock refit: reload 30% faster than at the start.",
	"bayonet": "Unlocks the Socket Bayonet refit: bayonet +6 damage, thrusts 15% faster. New Musketeers come out with it.",
	"pouch": "Unlocks the Shot Pouch refit: a musket soldier carries 20 shots instead of 10. Recruits don't come with it.",
	"charges": "Every Field Cannon and Mortar reloads 20% faster.",
	"quadrant": "Every Field Cannon and Mortar reaches 1 tile further.",
	"charge": "Horsemen and Cuirassiers charge: after a gallop the first blow hits double and throws the enemy back.",
}


## The short tooltip text for a unit, building or research ("about" when it has none).
static func tip(kind: String) -> String:
	if TIPS.has(kind):
		return TIPS[kind]
	if train_armoured(kind):
		return String(ARMOURED[train_kind(kind)]["about"])
	for d in [UNITS, BUILDINGS, RESEARCH]:
		if (d as Dictionary).has(kind):
			return String(d[kind].get("about", ""))
	return ""
