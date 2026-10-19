class_name Defs
## Game rules: every unit and building of the Crown, and economy constants.
## Ranges and radii are in pixels; one map tile is 32 px.

const TILE := 32
const START_GOLD := 250
const MAX_SUPPLY := 100
const MINE_GOLD := 5000
const CARRY := 8                 # gold per trip
const MINE_TIME := 2.4           # seconds swinging the pick per trip

const UNITS := {
	"labourer": {
		"name": "Labourer", "hp": 45, "armor": 0, "speed": 74, "cost": 50, "time": 12.0, "supply": 1,
		"sight": 7, "range": 20, "damage": 5, "cooldown": 1.3, "radius": 9, "from": "town_hall",
		"about": "Mines gold and builds. Weak in a fight.",
	},
	"musketeer": {
		"name": "Musketeer", "hp": 70, "armor": 0, "speed": 62, "cost": 100, "time": 20.0, "supply": 2,
		"sight": 8, "range": 190, "damage": 20, "cooldown": 2.8, "aim": 0.4, "radius": 10, "from": "barracks",
		"about": "Ranged line infantry. Long reload.",
	},
	"pikeman": {
		"name": "Pikeman", "hp": 120, "armor": 2, "speed": 60, "cost": 75, "time": 16.0, "supply": 2,
		"sight": 7, "range": 30, "damage": 13, "cooldown": 1.1, "radius": 10, "from": "barracks",
		"bonus": {"cannon": 2.5}, "about": "Tough melee. Wrecks cannons up close.",
	},
	"cannon": {
		"name": "Field Cannon", "hp": 140, "armor": 1, "speed": 40, "cost": 200, "time": 32.0, "supply": 4,
		"sight": 9, "range": 300, "min_range": 70, "damage": 32, "splash": 46, "cooldown": 4.5, "aim": 0.6,
		"radius": 15, "from": "foundry", "building_bonus": 2.5,
		"about": "Long-range splash. Smashes buildings. Can't hit what's too close.",
	},
}

const BUILDINGS := {
	"town_hall": {
		"name": "Town Hall", "hp": 1600, "armor": 2, "cost": 400, "time": 60.0, "size": Vector2i(5, 4),
		"supply": 10, "sight": 9, "trains": ["labourer"], "about": "Trains labourers. Gold is brought here.",
	},
	"cottage": {
		"name": "Cottage", "hp": 400, "armor": 1, "cost": 100, "time": 20.0, "size": Vector2i(2, 2),
		"supply": 8, "sight": 5, "trains": [], "about": "Houses 8 more supply.",
	},
	"barracks": {
		"name": "Barracks", "hp": 1000, "armor": 2, "cost": 150, "time": 40.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": ["musketeer", "pikeman"], "about": "Trains musketeers and pikemen.",
	},
	"foundry": {
		"name": "Foundry", "hp": 900, "armor": 2, "cost": 200, "time": 45.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": ["cannon"], "requires": "barracks", "about": "Casts field cannons. Needs a Barracks.",
	},
}

const BUILD_ORDER := ["town_hall", "cottage", "barracks", "foundry"]

const TEAM_COLOURS := [Color("#3a78e8"), Color("#e03a32")]
const TEAM_NAMES := ["Blue", "Red"]
