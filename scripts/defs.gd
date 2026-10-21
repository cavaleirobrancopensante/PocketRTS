class_name Defs
## Game rules: factions, every unit and building, and economy constants.
## Ranges and radii are in pixels; one map tile is 32 px.

const TILE := 32
const START_GOLD := 250
const EGGS_MAX := 5
const EGG_TIME := 6.0
const WIND_DECAY := 0.012         # Clockwork: charge lost per second outside a field (empty in ~80 s)
const WIND_MIN := 0.55
const AUTO_REPAIR := 8           # REPAIR autocast: how far (tiles) an idle worker looks for something to fix
const REPAIR_RATE := 20.0         # slowest repair speed (hp/s per worker); faster when the thing builds quickly

# ---- Economy: every faction makes its own resources from structures.
# Each town hall allows a fixed number of each economy structure (FACTIONS[f]["econ"]);
# Crown and Clockwork ones must stand near one of their halls.
const ECON_RANGE := 14            # tiles from a hall
const HALL_SPACING := 18          # a new hall needs its own ground: tiles from your other halls
## Deposits: every base site (each main and every expansion spot) has a line of rock outcrops
## (2x2 tiles) along its back, saltpetre and ore alternating, like a mineral line. A Powder
## Mill must stand next to saltpetre and an Ore Crusher next to ore (a gap of at most
## `adjacent` tiles); each draws on every outcrop of its kind within `reach` tiles (edge to
## edge), nearest first, and once those are spent works at `spent` of its rate. Amounts are in
## what they pay: powder for saltpetre, ore for ore. A site's 3 saltpetre outcrops last a fully
## worked Mill (~120 powder a minute) about 11 minutes; its 3 ore outcrops last a saturated
## Clockwork base (~1,150-1,200 ore a minute) about 11 minutes. The Brood ignores them.
const DEPOSIT := {"saltpetre": 440.0, "ore": 3800.0, "per_site": 6, "adjacent": 2, "reach": 6.0, "spent": 0.25}
const DEPOSIT_FOR := {"powder_mill": "saltpetre", "ore_crusher": "ore"}
# Crown: farms grow (faster with labourers working them) and pay out a whole harvest.
# Each Town Hall allows 2 Farms (crew 8) and 1 Powder Mill (crew 6): a full base is 16
# farmers + 6 millers, ~1,140 gold and ~120 powder a minute.
const FARM_GROW := 40.0           # seconds to ripen with a full crew
const FARM_BASE := 0.15           # share of that speed with nobody working it
const FARM_YIELD := 380           # gold a harvest (fresh soil)
## Soil fatigue: each Town Hall's farmland holds a fixed reserve of gold, shared by the farms
## that belong to it (a farm belongs to the nearest hall). Every harvest draws its yield from
## the reserve; once it's spent those farms pay a third. A new hall brings fresh soil (one
## built where a hall fell takes over what was left there). Powder Mills don't tire.
const SOIL_RESERVE := 9000
const SOIL_TIRED := 1.0 / 3.0     # share of a harvest that tired soil still pays
const SOIL_LOW := 0.25            # warn the player below this share of the reserve (Hive ground too)
const MILL_RATE := 0.33           # powder per second per labourer at a Powder Mill (6 per hall: ~2/s, ~120/min) while its saltpetre lasts
const START_POWDER := 80
## Personal powder: Musketeers, Cannons and Mortars carry their own, in shots (one per shot:
## round shot, canister or shell alike). A dry Musketeer fights with the bayonet until it has
## `rearm` shots again. They refill by themselves (`refill` shots a second) within `range` tiles of
## one of their side's finished `from` buildings, paid from the powder bank at `cost` powder
## a shot (a full musketeer: 6 powder; with the bank empty the refill waits), or of a Powder
## Wagon with powder left (drawn from the wagon's store, already paid for: a cannon shot takes
## 3 of the wagon's musket shots). Shots themselves don't touch the bank any more (the
## Balloon's gunners still burn 1 a shot).
const POWDER := {"musketeer": 12, "cannon": 8, "mortar": 6, "refill": 2.0, "range": 3.0, "rearm": 4,
	"cost": {"musketeer": 0.5, "cannon": 1.5, "mortar": 1.5}, "from": ["powder_mill", "barracks", "town_hall"]}
## Powder Wagon: holds `store` musket shots. Parked within POWDER.range tiles of a Powder Mill,
## Barracks or Town Hall it fills `fill` shots a second, paid from the powder bank at
## 1 powder per `per_powder` shots (the musket rate). SUPPLY: up to `runners` labourers carry
## kegs from the nearest Powder Mill to it (`keg` shots a keg, loaded in `keg_load` s, paid the
## same way: 30 shots = 15 powder). Destroyed, it blows up: up to `blast` damage (scaled by the
## powder left, never under `blast_min`) within `radius` px, friends included.
const WAGON := {"store": 120, "fill": 8.0, "per_powder": 2.0, "keg": 30, "keg_load": 1.5, "runners": 2,
	"blast": 120.0, "blast_min": 20.0, "radius": 96.0}
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
## Winders carry them to an Ore Crusher, which turns the charge into ore drawn from the ore
## outcrops beside it (a quarter once they're spent). A carried battery keeps its charge
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
const BRACE := {"armor": 7, "reach": 120.0, "cone": 0.45, "front": 0.2, "switch": 0.6}
## Wind-up Soldiers run on a spring, not a battery: `run` s away from a field and they run
## down; a Winder cranks one back up at `crank` a second (or a field does).
const SPRING := {"run": 50.0, "crank": 0.6}
## Winders wind themselves: `run` s away from a field, then they stop for `stop` s to crank.
const WINDER_SELF := {"run": 90.0, "stop": 3.0, "low": 0.04}


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
		"build": ["town_hall", "cottage", "farm", "powder_mill", "wall", "gate", "barracks", "foundry", "church"],
		"start_workers": 4, "start_gold": 300, "ready": true, "max_supply": 100,
		"res": ["Gold", "Powder"], "econ": {"farm": 2, "powder_mill": 1},
		"start": ["farm"],
		"about": "Musketeers, cannons and mortars. Farms ripen into big harvests; Powder Mills grind saltpetre into powder for muskets and cannons. Slow and strong when dug in.",
	},
	"brood": {
		"name": "The Brood", "hall": "hive", "worker": "grub", "supply": "clutch_mound",
		"build": ["hive", "clutch_mound", "feeding_pit", "brood_pen", "spore_vent", "warren", "gorge_pit", "roost"],
		"start_workers": 5, "ready": true, "max_supply": 160,
		"res": ["Biomass", "Essence"], "econ": {"feeding_pit": 3, "brood_pen": 1},
		"start": ["feeding_pit"],
		"about": "A swarm of cheap lizards. Grubs haul food from pits to the Hive: the longer the haul, the richer the food, and each Hive's ground runs out in time. Essence comes from the fallen and from offerings at the Brood Pen. Army cap 160.",
	},
	"clockwork": {
		"name": "The Clockwork", "hall": "clocktower", "worker": "winder", "supply": "spring_tower",
		"build": ["clocktower", "spring_tower", "boiler", "ore_crusher", "charging_pylon", "assembly_works", "engine_hall", "capacitor_works"],
		"start_workers": 4, "ready": true, "max_supply": 100,
		"res": ["Ore", "Energy"], "econ": {"boiler": 2, "ore_crusher": 2},
		"start": ["ore_crusher"],
		"about": "Constructs that run on wind and batteries. The Clocktower and Boilers fill batteries; Winders carry them to Ore Crushers beside the ore outcrops (a battery fades on the road), and the batteries left waiting are your Energy. Each base's ore and coal run out in time. Army cap 100.",
	},
}

const UNITS := {
	"labourer": {
		"tags": ["light"],
		"name": "Labourer", "hp": 45, "armor": 0, "speed": 74, "cost": 50, "time": 12.0, "supply": 1,
		"sight": 7, "range": 20, "damage": 5, "cooldown": 1.3, "radius": 9, "from": "town_hall",
		"faction": "crown", "worker": true, "about": "Mines gold and builds. Weak in a fight.",
	},
	"musketeer": {
		"tags": ["light"],
		"name": "Musketeer", "hp": 70, "armor": 0, "speed": 62, "cost": 60, "cost2": 10, "time": 15.0, "supply": 2,
		"sight": 8, "range": 190, "damage": 20, "cooldown": 2.8, "aim": 0.4, "radius": 10, "from": "barracks", "requires": "powder_mill",
		"anti_air": true, "faction": "crown", "about": "Line infantry: fires at range and, by itself, stabs with the bayonet when the enemy closes in (or when its 12 shots run dry; it refills near a Mill, Barracks, Town Hall or Powder Wagon). Long reload. Needs a Powder Mill. The Barracks researches Armour and better locks for it.",
	},
	"cannon": {
		"tags": ["armored"],
		"name": "Field Cannon", "hp": 140, "armor": 1, "speed": 38, "cost": 200, "time": 32.0, "supply": 4,
		"sight": 8, "range": 430, "min_range": 80, "damage": 32, "splash": 46, "cooldown": 4.5, "aim": 0.6,
		"radius": 22, "from": "foundry", "building_bonus": 2.5, "faction": "crown",
		"about": "Artillery. Limbered, the horse tows it; unlimber (2.5 s) to fire. Round shot reaches further than it can see: other units must spot for it. Canister also hits flyers. Carries 8 shots; refills near a Mill, Barracks, Town Hall or Powder Wagon.",
	},
	"mortar": {
		"tags": ["armored"],
		"name": "Mortar", "hp": 120, "armor": 1, "speed": 38, "cost": 175, "cost2": 20, "time": 30.0, "supply": 3,
		"sight": 8, "range": 352, "min_range": 160, "damage": 30, "splash": 48, "cooldown": 5.0, "aim": 0.6,
		"radius": 18, "from": "foundry", "building_bonus": 1.5, "ground_only": true, "faction": "crown",
		"about": "Siege mortar. Packed it rolls; DEPLOY it (3 s) to fire. It lobs a shell high over men and walls (5 to 11 tiles away) that bursts where it lands: 30 damage over a wide area, friends too. Can't hit flyers. Carries 6 shells; refills near a Mill, Barracks, Town Hall or Powder Wagon.",
	},
	"powder_wagon": {
		"tags": ["armored"],
		"name": "Powder Wagon", "hp": 220, "armor": 1, "speed": 38, "cost": 100, "cost2": 30, "time": 25.0, "supply": 2,
		"sight": 7, "range": 0, "damage": 0, "cooldown": 1.0, "radius": 16, "from": "foundry",
		"no_attack": true, "faction": "crown",
		"about": "Carries 120 shots of powder for the army: musketeers and cannons within 3 tiles refill from it. Fills up near a Mill, Barracks or Town Hall (1 powder per 2 shots); SUPPLY sends 2 labourers with kegs from the Powder Mill. No weapon, and when it's destroyed it blows up (more powder, bigger blast; friends too): guard it.",
	},
	"cuirassier": {
		"tags": ["armored"],
		"name": "Cuirassier", "hp": 170, "armor": 2, "speed": 108, "cost": 175, "time": 24.0, "supply": 3,
		"sight": 8, "range": 26, "damage": 15, "cooldown": 1.3, "aim": 0.15, "radius": 15, "from": "barracks",
		"requires": "foundry", "bonus": {"cannon": 1.6, "spitter": 1.3, "arc_thrower": 1.3}, "charge": true, "faction": "crown",
		"about": "Fast armoured horseman with a sabre. After a gallop his first blow hits double and throws the enemy back. Bayonets hurt him.",
	},
	"balloon": {
		"tags": ["light"],
		"name": "Observation Balloon", "hp": 180, "armor": 0, "speed": 46, "cost": 175, "cost2": 30, "time": 30.0, "supply": 4,
		"sight": 12, "range": 220, "damage": 16, "cooldown": 3.0, "aim": 0.35, "radius": 19, "from": "foundry", "art_scale": 1.2,
		"air": true, "anti_air": true, "gunners": 2, "faction": "crown",
		"about": "A snipers' nest in the sky: two musketeers who each shoot at the ground or at flyers, and a long view for your cannons. LOAD up to 4 Musketeers or Labourers (carried Musketeers fire from the basket) and UNLOAD them anywhere, even over cliffs. Slow and fragile. Each shot burns powder.",
	},
	"grub": {
		"tags": ["light"],
		"name": "Grub", "hp": 40, "armor": 0, "speed": 68, "cost": 50, "time": 12.0, "supply": 1,
		"sight": 6, "range": 18, "damage": 4, "cooldown": 1.2, "radius": 8, "from": "hive",
		"faction": "brood", "worker": true,
		"about": "Hauls food from Feeding Pits to a Hive (longer hauls pay more). Turns into buildings.",
	},
	"raptor": {
		"tags": ["light"],
		"name": "Raptors", "hp": 36, "armor": 0, "speed": 108, "cost": 75, "time": 11.0, "supply": 1, "spawn": 3,
		"sight": 7, "range": 22, "damage": 6, "cooldown": 0.9, "aim": 0.1, "radius": 7, "from": "hive",
		"requires": "warren", "faction": "brood", "about": "Fast, flimsy claws. Three hatch from each egg.",
	},
	"spitter": {
		"tags": ["light"],
		"name": "Spitters", "hp": 45, "armor": 0, "speed": 68, "cost": 90, "time": 13.0, "supply": 1, "spawn": 2,
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
		"sight": 7, "range": 20, "damage": 5, "cooldown": 1.2, "radius": 12, "from": "clocktower",
		"faction": "clockwork", "worker": true, "repairs": true,
		"about": "Cranks Boilers for energy, starts buildings and repairs constructs and buildings.",
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
		"about": "A tower shield on legs, with a weak piston lance. BRACE plants the shield: it can't move, and musket balls, spit, arc balls and spines aimed at your units behind it hit the shield instead.",
	},
	"arc_thrower": {
		"tags": ["armored"],
		"name": "Arc Thrower", "hp": 160, "armor": 1, "speed": 54, "cost": 150, "time": 22.0, "supply": 3,
		"sight": 9, "range": 210, "damage": 28, "cooldown": 2.6, "aim": 0.4, "radius": 14, "from": "assembly_works",
		"requires": "boiler", "anti_air": true, "faction": "clockwork",
		"about": "Throws balls of lightning at one enemy, ground or air. Every throw takes a good bite of its own wind: it runs down fast in a long fight away from a field.",
	},
	"steam_walker": {
		"tags": ["armored"],
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
		"about": "Bandages wounded soldiers back to full health, and by himself raises fallen Crown soldiers from their bodies (6 s): back at half health under the cross for 30 s. One who falls again under the cross is gone for good. Can't be hurt unless near enemy buildings. One per Church.",
	},
	"skywing": {
		"tags": ["light"],
		"name": "Skywing", "hp": 75, "armor": 0, "speed": 118, "cost": 100, "cost2": 40, "time": 16.0, "supply": 2,
		"sight": 9, "range": 130, "damage": 11, "cooldown": 1.1, "aim": 0.15, "radius": 13, "from": "hive",
		"air": true, "anti_air": true, "air_only": true, "requires": "roost", "faction": "brood",
		"about": "Flying, it hunts other flyers with volleys of spines (it can't touch the ground). LAND it (1.2 s) to fight on the ground with its bite: then it walks, can't cross cliffs, and anything can hit it. Costs essence.",
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
		"supply": 10, "sight": 9, "trains": ["labourer"], "faction": "crown", "about": "Trains labourers. Each Town Hall allows 2 Farms and 1 Powder Mill nearby (the mill goes next to saltpetre), and its farmland holds a reserve of gold: once the farms have drawn it out they pay a third. Expand to fresh land.",
	},
	"cottage": {
		"name": "Cottage", "hp": 400, "armor": 1, "cost": 100, "time": 20.0, "size": Vector2i(2, 2),
		"supply": 8, "sight": 5, "trains": [], "faction": "crown", "about": "Houses 8 more supply.",
	},
	# Crown fortifications: one tile each, laid in a line (pick the start, then the end).
	"wall": {
		"name": "Stone Wall", "hp": 450, "armor": 4, "cost": 10, "time": 4.0, "size": Vector2i(1, 1),
		"supply": 0, "sight": 3, "trains": [], "line": true, "faction": "crown",
		"about": "Blocks the way. Lay it in a line: pick where it starts, then where it ends. Wall off your ramp and keep a gate.",
	},
	"gate": {
		"name": "Gate", "hp": 600, "armor": 4, "cost": 25, "time": 6.0, "size": Vector2i(1, 1),
		"supply": 0, "sight": 4, "trains": [], "line": true, "gate": true, "faction": "crown",
		"about": "A piece of wall that opens for your own side and your allies, and stays shut to the enemy. Lay it straight onto your own wall to swap a piece for a gate. It faces the way the wall runs; ROTATE turns it by hand.",
	},
	"barracks": {
		"name": "Barracks", "hp": 1000, "armor": 2, "cost": 150, "time": 40.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": ["musketeer", "cuirassier"], "faction": "crown", "about": "Trains musketeers and (with a Foundry) cuirassiers. Researches Armour and better musket locks.",
	},
	"foundry": {
		"name": "Foundry", "hp": 900, "armor": 2, "cost": 200, "time": 45.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": ["cannon", "mortar", "balloon", "powder_wagon"], "requires": "barracks", "faction": "crown", "about": "Casts field cannons and mortars, rigs observation balloons and builds powder wagons. Lets the Barracks train cuirassiers. Needs a Barracks.",
	},
	"hive": {
		"name": "Hive", "hp": 1500, "armor": 1, "cost": 350, "time": 55.0, "size": Vector2i(5, 4),
		"supply": 16, "sight": 9, "trains": ["grub", "raptor", "spitter", "brute", "skywing", "spore_mother", "bloater"], "eggs": true, "swamp": 9,
		"faction": "brood", "about": "Lays eggs; every Brood unit hatches here. Grubs bring food here. Allows 3 Feeding Pits and 1 Brood Pen nearby. Its ground holds a reserve of biomass: once the pits have drawn it out they yield a third. Expand to fresh ground.",
	},
	"clutch_mound": {
		"name": "Clutch Mound", "hp": 350, "armor": 0, "cost": 75, "time": 18.0, "size": Vector2i(2, 2),
		"supply": 12, "sight": 5, "trains": [], "swamp": 7, "faction": "brood", "about": "12 more supply. Spreads swamp. Each one makes your Hives lay eggs 10% faster (up to 3).",
	},
	"warren": {
		"name": "Warren", "hp": 800, "armor": 1, "cost": 150, "time": 35.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": [], "swamp": 5, "faction": "brood", "about": "Lets the Hive hatch Raptors and Spitters.",
	},
	"gorge_pit": {
		"name": "Gorge Pit", "hp": 800, "armor": 1, "cost": 200, "time": 45.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": [], "swamp": 5, "requires": "warren", "faction": "brood",
		"about": "Lets the Hive hatch Brutes and Spore Mothers. Needs a Warren.",
	},
	"clocktower": {
		"name": "Clocktower", "hp": 2000, "armor": 3, "cost": 400, "time": 60.0, "size": Vector2i(5, 4),
		"supply": 10, "sight": 9, "trains": ["winder"], "field": 9, "battery": [2.0, 6], "crew": 4, "faction": "clockwork",
		"about": "Builds Winders and fills a battery every 2 s. Allows 2 Boilers and 2 Ore Crushers nearby (crushers go next to ore). Its Boilers share its coal: once that's burnt they fill batteries at a third. Expand to fresh coal and ore.",
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
		"name": "Farm", "hp": 500, "armor": 1, "cost": 100, "time": 25.0, "size": Vector2i(5, 4),
		"supply": 0, "sight": 5, "trains": [], "crew": 8, "faction": "crown",
		"about": "Ripens into a 380-gold harvest about every 40 s with a full crew. Up to 8 labourers make it grow faster, each as much as the next. Harvests draw on its Town Hall's soil: tired soil pays a third.",
	},
	"powder_mill": {
		"name": "Powder Mill", "hp": 600, "armor": 1, "cost": 100, "time": 30.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 5, "trains": [], "crew": 6, "faction": "crown",
		"about": "Build it next to saltpetre (the rock outcrops at the back of a base). Up to 6 labourers grind the saltpetre within 6 tiles into black powder for the bank: it buys musketeers and wagons and pays for refilling soldiers' powder. Once that saltpetre is spent it grinds at a quarter. Soldiers and wagons nearby refill here.",
	},
	"church": {
		"name": "Church", "hp": 900, "armor": 2, "cost": 150, "time": 35.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 7, "trains": ["missionary"], "requires": "barracks", "faction": "crown",
		"about": "Sends out one Missionary. Needs a Barracks.",
	},
	"feeding_pit": {
		"name": "Feeding Pit", "hp": 450, "armor": 0, "cost": 75, "time": 18.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 6, "trains": [], "crew": 5, "swamp": 4, "faction": "brood",
		"about": "Up to 5 grubs haul food from here to the nearest Hive. Farther from the Hive pays more per grub (best from about 18 to 22 tiles). Loads draw on that Hive's ground: spent ground yields a third.",
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
		"about": "Lets the Hive hatch Skywings. Needs a Warren.",
	},
	"boiler": {
		"name": "Boiler", "hp": 900, "armor": 2, "cost": 150, "time": 30.0, "size": Vector2i(4, 4),
		"supply": 0, "sight": 6, "trains": [], "battery": [1.0, 8], "crew": 7, "faction": "clockwork",
		"about": "Fills a battery every second by itself, burning its Clocktower's coal (spent coal: a third as fast). Up to 7 Winders carry them to Ore Crushers. Constructs that stand by it a while get overcharged. Unlocks Bulwarks, Arc Throwers and the Engine Hall.",
	},
	"ore_crusher": {
		"name": "Ore Crusher", "hp": 800, "armor": 2, "cost": 125, "time": 30.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 6, "trains": [], "faction": "clockwork",
		"about": "Build it next to ore (the rock outcrops at the back of a base). Winders bring batteries here and the charge becomes ore, drawn from the ore within 6 tiles; once that's spent it pays a quarter. The farther a battery travelled, the more it holds.",
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
## and the second (`cost2`), taking `time` seconds; `requires` another research first.
## (`icon`: assets/icons/<icon>.png.)
## Crown, at the Barracks: Armour (+`armor` and +`hp` for every Musketeer, those in the
## field too, and the armoured look) and the musket locks, one after the other: each sets
## the Musketeers' reload to `reload` of the base (the totals, not on top of each other).
const RESEARCH := {
	"armour": {"name": "Armour", "at": "barracks", "faction": "crown", "cost": 150, "cost2": 50, "time": 45.0,
		"icon": "research_armour", "armor": 1, "hp": 20,
		"about": "Breastplates and helmets for every Musketeer, those already in the field too: +1 armour, +20 health."},
	"matchlock": {"name": "Matchlock", "at": "barracks", "faction": "crown", "cost": 100, "cost2": 25, "time": 35.0,
		"icon": "research_matchlock", "reload": 0.9,
		"about": "Better matchlocks: Musketeers reload 10% faster (and burn their powder faster)."},
	"flintlock": {"name": "Flintlock", "at": "barracks", "faction": "crown", "cost": 150, "cost2": 50, "time": 45.0,
		"icon": "research_flintlock", "reload": 0.8, "requires": "matchlock",
		"about": "Flintlocks: Musketeers reload 20% faster than at the start (and burn their powder faster)."},
	"caplock": {"name": "Caplock", "at": "barracks", "faction": "crown", "cost": 200, "cost2": 75, "time": 55.0,
		"icon": "research_caplock", "reload": 0.7, "requires": "flintlock",
		"about": "Percussion caps: Musketeers reload 30% faster than at the start (and burn their powder faster)."},
}
## The musket locks, in order.
const LOCKS := ["matchlock", "flintlock", "caplock"]


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
## Missionary raising the fallen: a Crown soldier's body can be raised for `window` s after
## he falls; it takes `time` s and he comes back with `hp` of his health and the cross for
## `cross` s (no bandaging or raising meanwhile). Falling again under the cross, he's gone
## for good. Idle Missionaries look for bodies within `scan` tiles. Soldiers (`kinds`) only:
## not labourers, guns, wagons or balloons.
const REVIVE := {"time": 6.0, "hp": 0.5, "cross": 30.0, "window": 60.0, "scan": 10,
	"kinds": ["musketeer", "cuirassier"]}
## Clockwork towers zap flyers with chain lightning; while they do, their field is off.
const TOWER_ZAP := {"range": 8.0, "damage": 10.0, "cooldown": 1.6, "chain": 3, "jump": 110.0, "falloff": 0.7, "off": 3.0}
## Cuirassier: after galloping this long, his next blow is a charge.
const CHARGE := {"run": 2.0, "mult": 2.0, "force": 300.0, "stun": 0.6}
## Stormcaller: a storm of lightning that stuns everything inside (friends too).
## A control spell, not a killer (the rework: was radius 96, 3 s, 8 damage a second to
## enemies, charge only): it stuns, hurts almost nothing, and burns `cost2` stored batteries.
const STORM := {"cost": 70.0, "cost2": 2, "max": 100.0, "fill": 7.0, "range": 260.0, "radius": 80.0, "time": 2.5, "dps": 0.0, "cast": 0.7}
## Spore Mother: rooting takes a while; rooted she spreads swamp. Miasma heals the Brood
## inside it, up to a share of each unit's health per cloud; clouds don't stack.
## Bloater: its acid cloud
## (a full sac: burst damage and cloud at their biggest; each spit empties some of it)
const BLOAT := {"radius": 80.0, "time": 9.0, "dps": 4.0, "slow": 0.6, "burst": 60.0, "spit_cost": 15.0, "reach": 22.0}
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
## Brood: a little for its size, more for every kill it made.
const VET := {"per_kill": 0.01, "max": 0.5}
const HARVEST := {"time": 120.0, "range": 10, "take": 1.2, "per_supply": 1}
const ROOT_SWITCH := 2.5
const ROOT_SWAMP := 4.0          # tiles
const MIASMA := {"cost2": 30, "cooldown": 18.0, "range": 220.0, "radius": 96.0, "time": 8.0, "hps": 7.0, "cap": 0.3, "cast": 0.7}
const CANISTER := {"range": 150.0, "damage": 18.0, "cooldown": 3.6, "cone": 0.82, "vs_light": 1.5}
## Round shot: the ball tears through a line of men past where it lands (bonus against
## armour); only a little splash where it hits.
const ROUND_SHOT := {"line": 90.0, "width": 9.0, "vs_armored": 1.75, "splash": 24.0, "splash_dmg": 0.35}


static func has_tag(kind: String, tag: String) -> bool:
	return UNITS.has(kind) and (UNITS[kind].get("tags", []) as Array).has(tag)

const ADVANCED := ["barracks", "foundry", "church", "warren", "gorge_pit", "roost", "assembly_works", "engine_hall", "charging_pylon", "capacitor_works"]


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
]
