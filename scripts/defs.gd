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

const FACTIONS := {
	"crown": {
		"name": "The Crown", "hall": "town_hall", "worker": "labourer", "supply": "cottage",
		"build": ["town_hall", "cottage", "barracks", "foundry"], "start_workers": 5, "ready": true, "max_supply": 100,
		"about": "Musketeers and cannons. Labourers carry gold home. Strong at range and in sieges.",
	},
	"brood": {
		"name": "The Brood", "hall": "hive", "worker": "grub", "supply": "clutch_mound",
		"build": ["hive", "clutch_mound", "warren", "gorge_pit"], "start_workers": 4, "ready": true, "max_supply": 160,
		"about": "A swarm of cheap, fragile lizards that hatch several to an egg. Grubs feed on gold where they sit and become buildings. Swamp heals and speeds them. Army cap 160.",
	},
	"clockwork": {
		"name": "The Clockwork", "hall": "clocktower", "worker": "winder", "supply": "spring_tower",
		"build": ["clocktower", "spring_tower", "drill_rig", "assembly_works"], "start_workers": 2, "ready": true,
		"max_supply": 80,
		"about": "Few, very tough constructs. Drill Rigs mine by themselves. Winders build and repair. Constructs run down outside a wind-up field. Army cap 80.",
	},
}

const UNITS := {
	"labourer": {
		"name": "Labourer", "hp": 45, "armor": 0, "speed": 74, "cost": 50, "time": 12.0, "supply": 1,
		"sight": 7, "range": 20, "damage": 5, "cooldown": 1.3, "radius": 9, "from": "town_hall",
		"faction": "crown", "worker": true, "about": "Mines gold and builds. Weak in a fight.",
	},
	"musketeer": {
		"name": "Musketeer", "hp": 70, "armor": 0, "speed": 62, "cost": 100, "time": 20.0, "supply": 2,
		"sight": 8, "range": 190, "damage": 20, "cooldown": 2.8, "aim": 0.4, "radius": 10, "from": "barracks",
		"faction": "crown", "about": "Ranged line infantry. Long reload.",
	},
	"pikeman": {
		"name": "Pikeman", "hp": 120, "armor": 2, "speed": 60, "cost": 75, "time": 16.0, "supply": 2,
		"sight": 7, "range": 30, "damage": 13, "cooldown": 1.1, "radius": 10, "from": "barracks",
		"bonus": {"cannon": 2.5, "brute": 1.6}, "faction": "crown", "about": "Tough melee. Wrecks cannons and brutes up close.",
	},
	"cannon": {
		"name": "Field Cannon", "hp": 140, "armor": 1, "speed": 40, "cost": 200, "time": 32.0, "supply": 4,
		"sight": 9, "range": 300, "min_range": 70, "damage": 32, "splash": 46, "cooldown": 4.5, "aim": 0.6,
		"radius": 15, "from": "foundry", "building_bonus": 2.5, "faction": "crown",
		"about": "Long-range splash. Smashes buildings. Can't hit what's too close.",
	},
	"grub": {
		"name": "Grub", "hp": 40, "armor": 0, "speed": 68, "cost": 50, "time": 12.0, "supply": 1,
		"sight": 6, "range": 18, "damage": 4, "cooldown": 1.2, "radius": 8, "from": "hive",
		"faction": "brood", "worker": true,
		"about": "Burrows into a mine on swamp and feeds. Turns into buildings.",
	},
	"raptor": {
		"name": "Raptors", "hp": 30, "armor": 0, "speed": 100, "cost": 75, "time": 11.0, "supply": 1, "spawn": 3,
		"sight": 7, "range": 22, "damage": 5, "cooldown": 0.9, "aim": 0.1, "radius": 9, "from": "hive",
		"requires": "warren", "faction": "brood", "about": "Fast, flimsy claws. Three hatch from each egg.",
	},
	"spitter": {
		"name": "Spitters", "hp": 45, "armor": 0, "speed": 68, "cost": 90, "time": 13.0, "supply": 1, "spawn": 2,
		"sight": 8, "range": 150, "damage": 8, "cooldown": 2.0, "aim": 0.35, "radius": 10, "from": "hive",
		"acid": 3.0, "requires": "warren", "faction": "brood",
		"about": "Spit acid that burns and strips armour. Two hatch from each egg.",
	},
	"brute": {
		"name": "Brute", "hp": 240, "armor": 2, "speed": 56, "cost": 150, "time": 22.0, "supply": 3,
		"sight": 7, "range": 28, "damage": 26, "cooldown": 1.8, "aim": 0.25, "radius": 16, "from": "hive",
		"building_bonus": 1.6, "requires": "gorge_pit", "faction": "brood",
		"about": "Huge horned tank. Charges in and knocks enemies back.",
	},
	"winder": {
		"name": "Winder", "hp": 70, "armor": 1, "speed": 64, "cost": 60, "time": 14.0, "supply": 1,
		"sight": 7, "range": 20, "damage": 5, "cooldown": 1.2, "radius": 9, "from": "clocktower",
		"faction": "clockwork", "worker": true, "repairs": true,
		"about": "Starts buildings and repairs constructs and buildings. Never mines.",
	},
	"gearknight": {
		"name": "Gearknight", "hp": 300, "armor": 4, "speed": 52, "cost": 170, "time": 24.0, "supply": 3,
		"sight": 7, "range": 26, "damage": 20, "cooldown": 1.4, "aim": 0.3, "radius": 12, "from": "assembly_works",
		"regen": 1.5, "faction": "clockwork", "about": "Iron knight. Very hard to kill; slowly repairs itself.",
	},
	"bolt": {
		"name": "Bolt Automaton", "hp": 150, "armor": 2, "speed": 52, "cost": 160, "time": 22.0, "supply": 3,
		"sight": 9, "range": 230, "damage": 30, "cooldown": 3.0, "aim": 0.5, "radius": 11, "from": "assembly_works",
		"pierce": true, "faction": "clockwork", "about": "Crossbow bolts pierce every enemy in a line.",
	},
	"steam_walker": {
		"name": "Steam Walker", "hp": 380, "armor": 3, "speed": 44, "cost": 260, "time": 34.0, "supply": 5,
		"sight": 8, "range": 72, "damage": 15, "cooldown": 1.6, "aim": 0.3, "radius": 16, "from": "assembly_works",
		"cone": true, "building_bonus": 2.0, "requires": "spring_tower", "faction": "clockwork",
		"about": "Scalding steam hits everything in front of it. Melts swarms and buildings.",
	},
}

const BUILDINGS := {
	"town_hall": {
		"name": "Town Hall", "hp": 1600, "armor": 2, "cost": 400, "time": 60.0, "size": Vector2i(5, 4),
		"supply": 10, "sight": 9, "trains": ["labourer"], "faction": "crown", "about": "Trains labourers. Gold is brought here.",
	},
	"cottage": {
		"name": "Cottage", "hp": 400, "armor": 1, "cost": 100, "time": 20.0, "size": Vector2i(2, 2),
		"supply": 8, "sight": 5, "trains": [], "faction": "crown", "about": "Houses 8 more supply.",
	},
	"barracks": {
		"name": "Barracks", "hp": 1000, "armor": 2, "cost": 150, "time": 40.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": ["musketeer", "pikeman"], "faction": "crown", "about": "Trains musketeers and pikemen.",
	},
	"foundry": {
		"name": "Foundry", "hp": 900, "armor": 2, "cost": 200, "time": 45.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": ["cannon"], "requires": "barracks", "faction": "crown", "about": "Casts field cannons. Needs a Barracks.",
	},
	"hive": {
		"name": "Hive", "hp": 1500, "armor": 1, "cost": 350, "time": 55.0, "size": Vector2i(5, 4),
		"supply": 16, "sight": 9, "trains": ["grub", "raptor", "spitter", "brute"], "eggs": true, "swamp": 9,
		"faction": "brood", "about": "Lays eggs. Every Brood unit hatches here. Can grow off swamp.",
	},
	"clutch_mound": {
		"name": "Clutch Mound", "hp": 350, "armor": 0, "cost": 75, "time": 18.0, "size": Vector2i(2, 2),
		"supply": 12, "sight": 5, "trains": [], "swamp": 7, "faction": "brood", "about": "12 more supply. Spreads swamp.",
	},
	"warren": {
		"name": "Warren", "hp": 800, "armor": 1, "cost": 150, "time": 35.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": [], "swamp": 5, "faction": "brood", "about": "Lets the Hive hatch Raptors and Spitters.",
	},
	"gorge_pit": {
		"name": "Gorge Pit", "hp": 800, "armor": 1, "cost": 200, "time": 45.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": [], "swamp": 5, "requires": "warren", "faction": "brood",
		"about": "Lets the Hive hatch Brutes. Needs a Warren.",
	},
	"clocktower": {
		"name": "Clocktower", "hp": 2000, "armor": 3, "cost": 400, "time": 60.0, "size": Vector2i(5, 4),
		"supply": 10, "sight": 9, "trains": ["winder"], "field": 9, "trickle": 1.0, "faction": "clockwork",
		"about": "Builds Winders. Winds up constructs nearby and ticks out a little gold.",
	},
	"spring_tower": {
		"name": "Spring Tower", "hp": 500, "armor": 2, "cost": 100, "time": 20.0, "size": Vector2i(2, 2),
		"supply": 10, "sight": 6, "trains": [], "field": 7, "faction": "clockwork",
		"about": "10 more supply. Keeps nearby constructs wound up.",
	},
	"drill_rig": {
		"name": "Drill Rig", "hp": 700, "armor": 2, "cost": 175, "time": 30.0, "size": Vector2i(2, 2),
		"supply": 0, "sight": 6, "trains": [], "rig": true, "faction": "clockwork",
		"about": "Build it next to a gold mine: it drills gold by itself. One per mine.",
	},
	"assembly_works": {
		"name": "Assembly Works", "hp": 1300, "armor": 3, "cost": 200, "time": 45.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": ["gearknight", "bolt", "steam_walker"], "faction": "clockwork",
		"about": "Assembles every combat construct.",
	},
}



static func is_worker(kind: String) -> bool:
	return Defs.UNITS.has(kind) and Defs.UNITS[kind].get("worker", false)

const TEAM_COLOURS := [Color("#3a78e8"), Color("#e03a32")]
const TEAM_NAMES := ["Blue", "Red"]
