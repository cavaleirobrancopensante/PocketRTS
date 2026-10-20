class_name Defs
## Game rules: factions, every unit and building, and economy constants.
## Ranges and radii are in pixels; one map tile is 32 px.

const TILE := 32
const START_GOLD := 250
const MINE_GOLD := 5000
const CARRY := 8                 # gold per trip
const MINE_IDEAL := 12           # labourers a Crown mine can keep busy (the X/Y label)
const MINE_TIME := 2.4           # seconds swinging the pick per trip
const FEED_TIME := 0.65          # Brood: a feeding grub turns out 1 gold this often
const FEEDERS_PER_MINE := 8
const EGGS_MAX := 5
const EGG_TIME := 6.0
const RIG_RATE := 8.0             # Clockwork: gold per second from a Drill Rig
const WIND_DECAY := 0.04          # Clockwork: wind lost per second outside a field
const WIND_MIN := 0.55
const REPAIR_RATE := 14.0         # hp per second a Winder restores

# ---- Economy: no resources on the map; every faction makes its own from structures.
# Each town hall allows a fixed number of each economy structure (FACTIONS[f]["econ"]);
# Crown and Clockwork ones must stand near one of their halls.
const ECON_RANGE := 14            # tiles from a hall
const HALL_SPACING := 18          # a new hall needs its own ground: tiles from your other halls
# Crown: farms grow (faster with labourers working them) and pay out a whole harvest.
const FARM_GROW := 40.0           # seconds to ripen with a full crew
const FARM_BASE := 0.15           # share of that speed with nobody working it
const FARM_YIELD := 280
const MILL_RATE := 0.5            # powder per second per labourer at a Powder Mill
const START_POWDER := 80
const POWDER_SHOT := {"musketeer": 1, "cannon": 3}
# Brood: grubs haul food from Feeding Pits to a Hive; the longer the haul, the richer it is.
const PIT_TIME := 2.0             # seconds a grub feeds at the pit before hauling
const FOOD_BASE := 6.5
const FOOD_PER_TILE2 := 0.06      # value grows with the square of the distance (in tiles)
const FOOD_MAX := 40                # a load is worth most from about 23 tiles out; farther only takes longer
const ESSENCE_PER_SUPPLY := 3     # a body falling near a Bone Midden
const MIDDEN_RANGE := 12          # tiles
const MIDDEN_TRICKLE := 0.15      # essence per second per midden
# Clockwork: Winders crank Boilers for energy, split between ore, assembly and wind.
## Clockwork economy: every energy building fills batteries by itself; Winders carry them to
## an Ore Crusher. A battery gains charge the longer it's on the road (so far crushers pay
## more), but past its limit, or if its carrier is hit, it blows up. Yellow batteries at
## first; a Capacitor Works makes every source fill blue ones (more charge, more time).
const BATTERY := {
	"yellow": {"base": 10.0, "gain": 1.0, "overload": 22.0},
	"blue": {"base": 14.0, "gain": 1.6, "overload": 30.0},
	"load": 1.0, "blast": 10.0, "splash": 8.0,
}
const REPAIR_COST := 0.2          # ore per hit point a Winder repairs
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

const FACTIONS := {
	"crown": {
		"name": "The Crown", "hall": "town_hall", "worker": "labourer", "supply": "cottage",
		"build": ["town_hall", "cottage", "farm", "powder_mill", "wall", "gate", "barracks", "foundry", "church"],
		"start_workers": 5, "ready": true, "max_supply": 100,
		"res": ["Gold", "Powder"], "econ": {"farm": 4, "powder_mill": 1},
		"start": ["farm", "farm"],
		"about": "Musketeers and cannons. Farms ripen into big harvests; muskets and cannons burn powder. Slow and strong when dug in.",
	},
	"brood": {
		"name": "The Brood", "hall": "hive", "worker": "grub", "supply": "clutch_mound",
		"build": ["hive", "clutch_mound", "feeding_pit", "bone_midden", "spore_vent", "warren", "gorge_pit", "roost"],
		"start_workers": 5, "ready": true, "max_supply": 160,
		"res": ["Biomass", "Essence"], "econ": {"feeding_pit": 3, "bone_midden": 1},
		"start": ["feeding_pit"],
		"about": "A swarm of cheap lizards. Grubs haul food from pits to the Hive: the longer the haul, the richer the food. Essence comes from the fallen. Army cap 160.",
	},
	"clockwork": {
		"name": "The Clockwork", "hall": "clocktower", "worker": "winder", "supply": "spring_tower",
		"build": ["clocktower", "spring_tower", "boiler", "ore_crusher", "charging_pylon", "assembly_works", "capacitor_works"],
		"start_workers": 3, "ready": true, "max_supply": 80,
		"res": ["Ore", "Energy"], "econ": {"boiler": 2, "ore_crusher": 2},
		"start": ["ore_crusher"],
		"about": "Few, very tough constructs. Energy buildings fill batteries; Winders carry them to Ore Crushers (farther = more charge, but they can blow up). Army cap 80.",
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
		"anti_air": true, "faction": "crown", "about": "Ranged line infantry. Long reload. Needs a Powder Mill; each shot burns powder.",
	},
	"pikeman": {
		"tags": ["armored"],
		"name": "Pikeman", "hp": 120, "armor": 2, "speed": 60, "cost": 50, "time": 13.0, "supply": 2,
		"sight": 7, "range": 30, "damage": 13, "cooldown": 1.1, "radius": 11, "from": "barracks",
		"bonus": {"cannon": 2.5, "brute": 1.6, "cuirassier": 2.0}, "faction": "crown", "about": "Tough melee. Wrecks cannons, brutes and cavalry up close.",
	},
	"cannon": {
		"tags": ["armored"],
		"name": "Field Cannon", "hp": 140, "armor": 1, "speed": 38, "cost": 200, "time": 32.0, "supply": 4,
		"sight": 8, "range": 430, "min_range": 80, "damage": 32, "splash": 46, "cooldown": 4.5, "aim": 0.6,
		"radius": 19, "from": "foundry", "building_bonus": 2.5, "faction": "crown",
		"about": "Artillery. Limbered, the horse tows it; unlimber (2.5 s) to fire. Round shot reaches further than it can see: other units must spot for it. Canister also hits flyers.",
	},
	"cuirassier": {
		"tags": ["armored"],
		"name": "Cuirassier", "hp": 170, "armor": 2, "speed": 108, "cost": 175, "time": 24.0, "supply": 3,
		"sight": 8, "range": 26, "damage": 15, "cooldown": 1.3, "aim": 0.15, "radius": 15, "from": "barracks",
		"requires": "foundry", "bonus": {"cannon": 1.6, "spitter": 1.3, "bolt": 1.3}, "charge": true, "faction": "crown",
		"about": "Fast armoured horseman with a sabre. After a gallop his first blow hits double and throws the enemy back. Pikes beat him.",
	},
	"balloon": {
		"tags": ["light"],
		"name": "Observation Balloon", "hp": 180, "armor": 0, "speed": 46, "cost": 175, "cost2": 30, "time": 30.0, "supply": 4,
		"sight": 12, "range": 220, "damage": 16, "cooldown": 3.0, "aim": 0.35, "radius": 16, "from": "foundry",
		"air": true, "anti_air": true, "gunners": 2, "faction": "crown",
		"about": "A snipers' nest in the sky: two musketeers who each shoot at the ground or at flyers, and a long view for your cannons. Slow and fragile. Each shot burns powder.",
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
		"acid": 3.0, "requires": ["warren", "bone_midden"], "cost2": 5, "anti_air": true, "faction": "brood",
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
		"sight": 7, "range": 18, "damage": 20, "cooldown": 1.0, "aim": 0.7, "radius": 12, "from": "hive",
		"air": true, "ground_only": true, "requires": "roost", "faction": "brood",
		"about": "A floating gas sac. It drifts over walls to the enemy and bursts: an acid cloud for 8 s that strips armour and slows everyone inside. Used up when it bursts.",
	},
	"winder": {
		"tags": ["light"],
		"name": "Winder", "hp": 70, "armor": 1, "speed": 64, "cost": 60, "time": 14.0, "supply": 1,
		"sight": 7, "range": 20, "damage": 5, "cooldown": 1.2, "radius": 12, "from": "clocktower",
		"faction": "clockwork", "worker": true, "repairs": true,
		"about": "Cranks Boilers for energy, starts buildings and repairs constructs and buildings.",
	},
	"gearknight": {
		"tags": ["armored"],
		"name": "Gearknight", "hp": 300, "armor": 3, "speed": 52, "cost": 170, "time": 24.0, "supply": 3,
		"sight": 7, "range": 26, "damage": 20, "cooldown": 1.4, "aim": 0.3, "radius": 19, "from": "assembly_works",
		"regen": 1.5, "faction": "clockwork", "about": "Iron knight. Very hard to kill; slowly repairs itself.",
	},
	"bolt": {
		"tags": ["armored"],
		"name": "Bolt Automaton", "hp": 150, "armor": 1, "speed": 52, "cost": 160, "time": 22.0, "supply": 3,
		"sight": 9, "range": 230, "damage": 30, "cooldown": 3.0, "aim": 0.5, "radius": 15, "from": "assembly_works",
		"pierce": true, "requires": "boiler", "anti_air": true, "faction": "clockwork", "about": "Crossbow bolts pierce up to three enemies in a line.",
	},
	"steam_walker": {
		"tags": ["armored"],
		"name": "Steam Walker", "hp": 380, "armor": 2, "speed": 44, "cost": 260, "time": 34.0, "supply": 5,
		"sight": 8, "range": 72, "damage": 15, "cooldown": 1.6, "aim": 0.3, "radius": 28, "from": "assembly_works",
		"cone": true, "building_bonus": 2.0, "requires": "spring_tower", "faction": "clockwork",
		"about": "Scalding steam hits everything in front of it. Melts swarms and buildings.",
	},
	"stormcaller": {
		"tags": ["light"],
		"name": "Stormcaller", "hp": 90, "armor": 0, "speed": 56, "cost": 150, "time": 24.0, "supply": 2,
		"sight": 9, "range": 120, "damage": 7, "cooldown": 1.3, "aim": 0.25, "radius": 12, "from": "assembly_works",
		"requires": "charging_pylon", "anti_air": true, "faction": "clockwork",
		"about": "Fragile lightning caster. STORM stuns everything inside it, friends too. Its charge only fills inside a Clockwork field.",
	},
	"missionary": {
		"tags": ["light"],
		"name": "Missionary", "hp": 60, "armor": 0, "speed": 62, "cost": 125, "time": 20.0, "supply": 1,
		"sight": 8, "range": 0, "damage": 0, "cooldown": 1.0, "radius": 10, "from": "church",
		"medic": true, "per": "church", "faction": "crown",
		"about": "Bandages wounded soldiers back to full health. Can't be hurt unless near enemy buildings. One per Church.",
	},
	"skywing": {
		"tags": ["light"],
		"name": "Skywing", "hp": 75, "armor": 0, "speed": 118, "cost": 100, "cost2": 40, "time": 16.0, "supply": 2,
		"sight": 9, "range": 24, "damage": 9, "cooldown": 1.0, "aim": 0.15, "radius": 13, "from": "hive",
		"air": true, "anti_air": true, "requires": "roost", "faction": "brood",
		"about": "Flies over cliffs and walls. Only ranged units can hit it. Costs essence.",
	},
	"ornithopter": {
		"tags": ["light"],
		"name": "Ornithopter", "hp": 110, "armor": 1, "speed": 112, "cost": 150, "time": 22.0, "supply": 2,
		"sight": 9, "range": 140, "damage": 12, "cooldown": 1.4, "aim": 0.2, "radius": 13, "from": "assembly_works",
		"air": true, "anti_air": true, "vs_air": 1.75, "requires": "charging_pylon", "faction": "clockwork",
		"about": "Fast clockwork flyer with a lightning gun, deadliest against other flyers. Like every construct it winds down away from a field.",
	},
	"tesla_cart": {
		"tags": ["armored"],
		"name": "Tesla Cart", "hp": 240, "armor": 2, "speed": 50, "cost": 190, "time": 28.0, "supply": 3,
		"sight": 9, "range": 170, "damage": 14, "cooldown": 1.6, "aim": 0.2, "radius": 18, "from": "assembly_works",
		"tesla": true, "anti_air": true, "requires": "charging_pylon", "faction": "clockwork",
		"about": "Rolls packed; deploy it (3 s) to power nearby constructs and zap enemies in chains.",
	},
}

const BUILDINGS := {
	"town_hall": {
		"name": "Town Hall", "hp": 1600, "armor": 2, "cost": 400, "time": 60.0, "size": Vector2i(5, 4),
		"supply": 10, "sight": 9, "trains": ["labourer"], "faction": "crown", "about": "Trains labourers. Each Town Hall allows 4 Farms and a Powder Mill nearby.",
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
		"about": "A piece of wall that opens for your own side and your allies, and stays shut to the enemy.",
	},
	"barracks": {
		"name": "Barracks", "hp": 1000, "armor": 2, "cost": 150, "time": 40.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": ["musketeer", "pikeman", "cuirassier"], "faction": "crown", "about": "Trains musketeers, pikemen and (with a Foundry) cuirassiers.",
	},
	"foundry": {
		"name": "Foundry", "hp": 900, "armor": 2, "cost": 200, "time": 45.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": ["cannon", "balloon"], "requires": "barracks", "faction": "crown", "about": "Casts field cannons and rigs observation balloons. Lets the Barracks train cuirassiers. Needs a Barracks.",
	},
	"hive": {
		"name": "Hive", "hp": 1500, "armor": 1, "cost": 350, "time": 55.0, "size": Vector2i(5, 4),
		"supply": 16, "sight": 9, "trains": ["grub", "raptor", "spitter", "brute", "skywing", "spore_mother", "bloater"], "eggs": true, "swamp": 9,
		"faction": "brood", "about": "Lays eggs; every Brood unit hatches here. Grubs bring food here. Allows 3 Feeding Pits.",
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
		"about": "Builds Winders and fills a battery every 2 s. Allows 2 Boilers and 2 Ore Crushers nearby.",
	},
	"spring_tower": {
		"name": "Spring Tower", "hp": 500, "armor": 2, "cost": 100, "time": 20.0, "size": Vector2i(2, 2),
		"supply": 10, "sight": 6, "trains": [], "field": 7, "battery": [6.0, 3], "crew": 1, "faction": "clockwork",
		"about": "10 more supply. Keeps nearby constructs wound up, and slowly fills batteries.",
	},
	"drill_rig": {
		"name": "Drill Rig", "hp": 700, "armor": 2, "cost": 175, "time": 30.0, "size": Vector2i(2, 2),
		"supply": 0, "sight": 6, "trains": [], "rig": true, "faction": "clockwork",
		"about": "Build it next to a gold mine: it drills gold by itself. One per mine.",
	},
	"assembly_works": {
		"name": "Assembly Works", "hp": 1300, "armor": 3, "cost": 200, "time": 45.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": ["gearknight", "bolt", "steam_walker", "tesla_cart", "stormcaller", "ornithopter"], "faction": "clockwork",
		"about": "Assembles every combat construct. Faster with more energy on assembly.",
	},
	"farm": {
		"name": "Farm", "hp": 500, "armor": 1, "cost": 100, "time": 25.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 5, "trains": [], "crew": 3, "faction": "crown",
		"about": "Ripens into a 350-gold harvest. Up to 3 labourers make it grow faster.",
	},
	"powder_mill": {
		"name": "Powder Mill", "hp": 600, "armor": 1, "cost": 125, "time": 30.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 5, "trains": [], "crew": 2, "faction": "crown",
		"about": "Labourers grind black powder. Muskets and cannons can't fire without it.",
	},
	"church": {
		"name": "Church", "hp": 900, "armor": 2, "cost": 150, "time": 35.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 7, "trains": ["missionary"], "requires": "barracks", "faction": "crown",
		"about": "Sends out one Missionary. Needs a Barracks.",
	},
	"feeding_pit": {
		"name": "Feeding Pit", "hp": 450, "armor": 0, "cost": 75, "time": 18.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 6, "trains": [], "crew": 5, "swamp": 4, "faction": "brood",
		"about": "Up to 5 grubs haul food from here to the nearest Hive. Far from a Hive = richer food.",
	},
	"bone_midden": {
		"name": "Bone Midden", "hp": 500, "armor": 0, "cost": 100, "time": 22.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 6, "trains": [], "swamp": 4, "faction": "brood",
		"about": "Gathers essence from every body that falls nearby (and a little on its own).",
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
		"name": "Boiler", "hp": 800, "armor": 2, "cost": 150, "time": 30.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 6, "trains": [], "battery": [1.0, 8], "crew": 7, "faction": "clockwork",
		"about": "Fills a battery every second by itself. Up to 7 Winders carry them to Ore Crushers. Unlocks Bolt Automatons.",
	},
	"ore_crusher": {
		"name": "Ore Crusher", "hp": 800, "armor": 2, "cost": 125, "time": 30.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 6, "trains": [], "faction": "clockwork",
		"about": "Winders bring batteries here and the charge becomes ore. The farther a battery travelled, the more it holds.",
	},
	"capacitor_works": {
		"name": "Capacitor Works", "hp": 900, "armor": 2, "cost": 250, "time": 50.0, "size": Vector2i(2, 2),
		"supply": 0, "sight": 7, "trains": [], "requires": "assembly_works", "faction": "clockwork",
		"about": "Blue energy: every source fills blue batteries, with more charge and more time before they overload. Needs an Assembly Works.",
	},
	"charging_pylon": {
		"name": "Charging Pylon", "hp": 600, "armor": 2, "cost": 150, "time": 30.0, "size": Vector2i(2, 2),
		"supply": 0, "sight": 7, "trains": [], "field": 7, "mends": 3.0, "battery": [3.0, 4], "crew": 3, "faction": "clockwork",
		"about": "Winds up and slowly mends constructs nearby. Unlocks the Tesla Cart and the Stormcaller.",
	},
}



## Tech step: each faction's first ranged unit needs one piece of research at the building
## that makes its first fighters, so the opening is melee and the ranged unit comes a little later.
const RESEARCH := {}   # (the tech step is now the second economy building: see "requires")


## Units whose art is still being finished: they can't be trained yet.
const PENDING := ["balloon", "ornithopter", "bloater"]


static func is_worker(kind: String) -> bool:
	return Defs.UNITS.has(kind) and Defs.UNITS[kind].get("worker", false)


## Basic structures (halls, supply, economy) go on the BUILD page; production and tech
## buildings on ADVANCED.
## Crown abilities.
const PIKE_PUSH := {"cooldown": 7.0, "force": 260.0, "stun": 0.7, "damage": 4.0}
const BAYONET := {"range": 26.0, "damage": 11.0, "cooldown": 1.2, "aim": 0.2, "bonus": {"cannon": 2.0, "spitter": 1.3}}
const CANNON_SWITCH := 2.5       # limber / unlimber
## Clockwork towers zap flyers with chain lightning; while they do, their field is off.
const TOWER_ZAP := {"range": 8.0, "damage": 10.0, "cooldown": 1.6, "chain": 3, "jump": 110.0, "falloff": 0.7, "off": 3.0}
## Cuirassier: after galloping this long, his next blow is a charge.
const CHARGE := {"run": 2.0, "mult": 2.0, "force": 300.0, "stun": 0.6}
## Stormcaller: a storm of lightning that stuns everything inside (friends too).
const STORM := {"cost": 70.0, "max": 100.0, "fill": 7.0, "range": 260.0, "radius": 96.0, "time": 3.0, "dps": 8.0, "cast": 0.7}
## Spore Mother: rooting takes a while; rooted she spreads swamp. Miasma heals the Brood
## inside it, up to a share of each unit's health per cloud; clouds don't stack.
## Bloater: its acid cloud
const BLOAT := {"radius": 72.0, "time": 8.0, "dps": 3.0, "slow": 0.6}
const ROOT_SWITCH := 2.5
const ROOT_SWAMP := 4.0          # tiles
const MIASMA := {"cost2": 30, "cooldown": 18.0, "range": 220.0, "radius": 96.0, "time": 8.0, "hps": 7.0, "cap": 0.3, "cast": 0.7}
const CANISTER := {"range": 150.0, "damage": 18.0, "cooldown": 3.6, "powder": 2, "cone": 0.82, "vs_light": 1.5}
## Round shot: the ball tears through a line of men past where it lands (bonus against
## armour); only a little splash where it hits.
const ROUND_SHOT := {"line": 90.0, "width": 9.0, "vs_armored": 1.75, "splash": 24.0, "splash_dmg": 0.35}


static func has_tag(kind: String, tag: String) -> bool:
	return UNITS.has(kind) and (UNITS[kind].get("tags", []) as Array).has(tag)

const ADVANCED := ["barracks", "foundry", "church", "warren", "gorge_pit", "roost", "assembly_works", "charging_pylon", "capacitor_works"]


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
