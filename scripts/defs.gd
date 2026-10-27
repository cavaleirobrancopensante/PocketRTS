class_name Defs
## Game rules: factions, every unit and building, and economy constants.
## Ranges and radii are in pixels; one map tile is 32 px.

const TILE := 32
const CAMERA_MARGIN_TILES := 7  # the camera may scroll this many tiles past every map edge (a base by the edge can be centred); units stay on the map (owner: 25 was too much)
const START_GOLD := 250
const EGGS_MAX := 5               # a Burrow's eggs (an upgraded hall holds more: HALL_LEVELS)
## Seconds for a Burrow to lay one egg (a Clutch Mound still speeds it up). Was 6.0: +50% so each
## hatched unit is a bigger commitment; cancelling a hatching egg no longer gives the egg back.
const EGG_TIME := 9.0
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
## Brood Burrows have no ground of their own (each Feeding Pit has its own) and have no spacing rule for
## the player (since 0.12.99); this is only how far apart the COMPUTER plants its extra ones
## (centre to centre, tiles).
const BROOD_HALL_SPACING := 8
const HALL_SPACING := 18          # a new hall needs its own ground: tiles from your other halls
## Lodes: every Town Hall's ground holds a reserve of saltpetre for its Powder Mill, every
## Clocktower's a reserve of ore for its Ore Crushers (a Mill / Crusher draws on the nearest
## hall of its own). Amounts are in what they pay: powder for saltpetre, ore for ore. A hall's
## saltpetre lasts a fully worked Mill (~120 powder a minute) about 11 minutes; a Clocktower's
## ore lasts a saturated Clockwork base (~1,150-1,200 ore a minute) about 10 minutes. Once
## spent, its Mill / Crushers yield NOTHING (LODE_SPENT = 0: barren, no efficiency trickle). Like soil, a hall raised where one fell takes
## over what was left there. The Brood has no lode (its pits' ground is PIT_GROUND).
const LODE := {"town_hall": 1320.0, "clocktower": 11400.0}     # 3 x 440 powder, 3 x 3,800 ore
const LODE_NAME := {"town_hall": "saltpetre", "clocktower": "brass"}      # (the Clockwork's: ore on the old Line economy, raw brass for the cog presses)
const LODE_FOR := {"powder_mill": "town_hall", "ore_crusher": "clocktower", "ore_drill": "clocktower", "boiler": "clocktower", "cog_press": "clocktower"}
const LODE_SPENT := 0.0
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
## the reserve; once it's spent those farms pay NOTHING (total exhaustion: barren land, their crews are released). A new hall brings fresh soil (one
## built where a hall fell takes over what was left there). Powder Mills draw on its saltpetre (LODE).
const SOIL_RESERVE := 9000
const SOIL_TIRED := 0.0           # share of a harvest that spent soil still pays (none: barren; was 1/3)
const SOIL_LOW := 0.25            # warn the player below this share of the reserve (a Feeding Pit's ground too)
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
## 1 powder per `per_powder` shots (the musket rate). SUPPLY: the Town Hall's haulers (HAUL)
## carry kegs from the nearest Powder Mill to it (`keg` shots a keg, loaded in `keg_load` s, paid
## the same way: 30 shots = 15 powder). Destroyed, it blows up: up to `blast` damage (scaled by the
## powder left, never under `blast_min`) within `radius` px, friends included.
const WAGON := {"store": 120, "fill": 8.0, "per_powder": 2.0, "keg": 30, "keg_load": 1.5,
	"blast": 170.0, "blast_min": 70.0, "radius": 110.0}
## HAULERS: Labourers assigned to a Town Hall (up to its "haulers"; the same right-click as a
## Farm). They carry what the base asks for, instead of anyone being pulled off a Farm or
## Mill: a horse queued for a Barracks / Foundry entry is led (up to `horses` on leashes) from
## where the Horse Breeder spawns it to that building and hitched; a Powder Wagon on SUPPLY
## gets kegs from a Powder Mill; a gun or wagon with `team_want` horses gets spare ones.
## `scan` s between dispatches; `batch` tiles: other ready horses that close to the first one
## are led along (with no hauler free the recruit / gun fetches its horse by itself at once); `reach` px to count as arrived; `kegs` kegs on the way to one wagon at a time.
const HAUL := {"horses": 4, "scan": 0.5, "batch": 8.0, "reach": 30.0, "kegs": 2}
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
## FOOD_REACH a grub needn't walk: it unloads beside each one). So a grub earns ~30-35 biomass
## a minute within 9 tiles of the capital and ~44 from 15-24 tiles out (half of what it was; tools/econ_bench.gd pits).
const PIT_TIME := 2.0             # seconds a grub feeds at the pit before hauling
const FOOD_RATE := 0.6            # biomass per grub-second of round trip (near pits; was 1.2: halved, same distance curve)
const FOOD_NEAR := 6.0
const FOOD_FAR := 18.0
const FOOD_PEAK := 22.0
const FOOD_BONUS := 0.3
const FOOD_FADE := 0.015          # share of the rate lost per tile beyond FOOD_PEAK
## The capital's swamp reaches this many tiles farther than other Burrows', to cover a normal main base.
const CAPITAL_SWAMP_BONUS := 5
const FOOD_TRIP := 0.8            # seconds of round trip per tile walked (mostly on swamp)
const FOOD_REACH := 1.5           # tiles of the gap a grub doesn't walk
const FOOD_MAX_D := 32.0          # a load is worth no more from farther out than this
## PIT GROUND (owner's decision, 2026-10-27): every Feeding Pit has its OWN ground, PIT_GROUND biomass;
## every load hauled from it draws its value from it, and once it's spent the pit yields NOTHING
## (barren). Each pit claims a circle of ground PIT_CLAIM tiles round its centre, and two of a
## player's living pits' circles may not overlap (centres at least 2 x PIT_CLAIM apart: about 4-5
## pits on a main plateau). The ground belongs to the land: a dead pit leaves its circle behind as
## an "old ground" spot (Game.pit_spots) with what was left, and a new pit whose circle overlaps old
## spots takes over the SMALLEST amount left among them (they merge into its claim), so rebuilding
## beside a spent pit can't refresh the ground.
## THE CAPITAL: a Brood player's FIRST Burrow (the oldest one standing; if it falls the next oldest takes
## over) is the only hall grubs unload at (food and cocoons). It has no ground of its own (the pits do).
## The other Burrows only lay eggs, give supply and spread swamp. Where the Queen sits.
## A Feeding Pit's crew (its `crew` is the base) grows with its distance from the capital: +1 grub per
## PIT_CREW_STEP tiles beyond FOOD_NEAR, up to PIT_CREW_MAX, so far pits can take more hands.
const PIT_CREW_STEP := 4.0
const PIT_CREW_MAX := 12
## Brood resource buildings (Feeding Pit, Brood Pen) need swamp joined to the capital's, no farther than this.
const BROOD_RESOURCE_MAX_D := 40.0
const PIT_GROUND := 3000          # biomass in each Feeding Pit's own ground (a full crew of 6 draws ~200-250 a minute: ~12-15 minutes)
const PIT_CLAIM := 5.0            # tiles: the radius of the circle of ground a Feeding Pit claims (living pits' circles may not overlap)
## Brood Pen SACRIFICE: a Brood creature offered up at a Pen gives this share of its biomass
## cost as essence (a Raptor, 25 biomass, gives 9). Was 12% (3 a Raptor) until 0.14.40, when the Pen
## also stopped turning bodies that fell near it into essence (the fallen are harvested by grubs only).
const SACRIFICE := 0.35
# Clockwork: Winders carry batteries from the energy buildings to the Ore Crushers.
## Clockwork economy: only the Clocktower and Boilers (2 per Clocktower) fill batteries;
## Winders carry them to an Ore Crusher, which turns the charge into ore drawn from its
## Clocktower's ore (LODE; nothing once it's spent). A carried battery keeps its charge
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
## reserve of coal, one unit a battery; once it's spent they fill NO batteries (barren; was a third).
## (A saturated base's 2 Boilers burn ~110 a minute: ~11 minutes.)
const COAL_RESERVE := 1200
const COAL_SPENT := 0.0          # share of its speed a Boiler keeps on spent coal (none; was 1/3)
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
## Clock Soldier: SHIELD FORWARD (research SHIELD WALL at the Light Works; scripts/shield_wall.gd,
## docs/clock_soldier_shield.md). Switching takes `switch` s (it stands still meanwhile); raised, it walks at `speed` of
## its pace, has `armor` more armour and takes `front` less from SHOTS whose shooter stands in front of it (inside the
## `cone`, a cosine about where it faces) and `front_melee` less from blows from in front; blows from the side or behind
## and splash (shells, blasts, clouds) are not stopped. It keeps fighting, its blows `cooldown` times slower. Guesses,
## tuned with tools/measure_clock_soldier.gd (docs/clock_soldier_shield.md): a stand-up fight against shooters is won,
## the race to chase or flee is lost, and swarms of claws are not turned into a wall of it.
const SHIELD_WALL := {"speed": 0.6, "armor": 1.0, "front": 0.5, "front_melee": 0.2, "cone": 0.35, "switch": 0.5, "cooldown": 1.15}
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

## THE LINE (Clockwork, docs/clockwork_rework_plan.md, phase 1): pipe segments on the grid carry
## PRESSURE (0..1) from the Clocktower and Boilers to the buildings that touch them (scripts/line.gd).
##  pipe: one segment (a map cell; pipe and rail are laid together). `hp`/`armor`; `cost` ore to lay (also the price base of a repair, so
##   a repair is nearly free); `time` seconds a Winder needs to lay it (and the repair-speed base:
##   hp/time, so a mend is quick); units walk over pipes, enemies can shoot them.
##  supply: flow a finished source adds to the Line it touches. A Clocktower 40, a Boiler 30: a hall
##   with its two Boilers gives 100.
##  draw: flow a consumer takes. If a Line's total draw is above its total supply, EVERY point on it
##   loses the same share (supply / draw): the load is shared, so a fourth workshop on a thin Line
##   slows the other three. A building that touches two separate Lines draws from the stronger one.
##  fall: pressure lost per segment of pipe from the nearest source (0.025: a 20-segment run ends at 50%).
##  relay: a Pressure Relay that has input >= `min_in` (before its own boost) pushes out
##   min(`max_out`, input + `boost`) on every pipe it touches; the fall runs on from there (both ways).
##  speed: a building at pressure p works at 0 below `off`, then from `floor` (at `off`) up to 1.0 (at
##   `full`); linear in between. A building with no pipe beside it works at 0 ("unpowered").
##  tint: pressure colours: low (red) through mid (amber) to high (steam white-blue).
const LINE := {
	"pipe": {"name": "Line segment", "hp": 140.0, "armor": 1, "cost": 8, "time": 2.5, "faction": "clockwork"},
	"supply": {"clocktower": 40.0, "boiler": 30.0},
	"draw": {"ore_crusher": 12.0, "ore_drill": 12.0, "assembly_works": 16.0, "engine_hall": 20.0, "capacitor_works": 10.0,
		"charging_pylon": 8.0, "pressure_relay": 4.0, "rail_yard": 14.0},
	"fall": 0.025,
	"relay": {"min_in": 0.25, "boost": 0.5, "max_out": 0.9},
	"speed": {"off": 0.1, "floor": 0.25, "full": 0.8},
	"solve": 0.5,                 # seconds between pressure solves
	"max_run": 60,                # the longest run (segments) one Line order can lay
	"tint": [Color("#d8473a"), Color("#e8b43c"), Color("#bfe7f0")],
	"scale": 1.5,                 # drawn size of a pipe/rail tile and of trains against the 32 px cell (they overlap the neighbours)
}

## RAILS AND ORE TRAINS (phase 2 of the Line, docs/clockwork_rework_plan.md). The rail runs on top of every Line
## segment. An Ore Drill digs its Clocktower's ore into a stock; Ore Trains carry it along the Line to the Clocktower
## (income = what the trains deliver). A train is slow, exposed, and only as fast as the pressure under it.
##  speed: cells a second at full speed (it follows the pressure: Defs.line_speed, so a starved Line crawls).
##  cargo: ore a train carries. headway: cells of free track a train wants ahead of it on its own track (a train
##   cannot stop quickly): flow of ONE rail = speed / headway trains a second x cargo = 24 ore/s at full pressure.
##  drill: ore a second the Drill digs at full pressure; stock: the most it holds until a train takes it.
##  riders: a Troop Train carries this many soldiers (not horses or machines).
const TRAINS := {
	"ore": {"name": "Ore Train", "hp": 420.0, "armor": 2, "cost": 110, "cargo": 80.0, "speed": 2.4, "cars": 2},
	"troop": {"name": "Troop Train", "hp": 420.0, "armor": 2, "cost": 150, "riders": 8, "speed": 3.0, "cars": 1},
}
const RAIL := {
	"headway": 8, "load": 1.5, "unload": 1.2, "wait_stock": 25.0, "wait_max": 7.0, "board_max": 12.0,
	"drill": {"rate": 7.0, "stock": 160.0},
	"stranded_retry": 1.0,
	"lane": 5.0,                  # px a train keeps to the right of the track's centre line (two tracks, one per direction)
	"reverse": 1.2,               # seconds a train stands at a dead end before it backs out (the fallback when there is no loop)
	"stand_clear": 6,             # cells a train keeps behind one that stands loading / unloading (its wagons are in the way)
	"loop_kinds": ["clocktower", "ore_drill"],   # buildings trains stop at: a rail stub that ends at one gets a loop round it (Line.plan)
	"loop_min": 4,                # the smallest loop (a rectangle of rail) is this many cells on a side
	"loop_max": 9,
}
const TRAIN_MAX := 10            # trains a team may own

## ==========================================================================================================
## CLOCKWORK ROSTER PROTOTYPE (docs/clockwork_units_prototype.md). Experimental units to try and then cut: every
## number of them is in this ONE block (rough guesses, tune by play in the CLOCKWORK LAB). To drop a unit: delete
## its entry in UNITS, its name in CW_KINDS / CW_RAIL and its sub-block here; scripts/cw_units.gd ignores a
## kind it does not find. Off unless `cw_roster` is on (the LAB setting, and the tests): the build lists and
## train cards hide the new things, the computer never uses them.
## Distances are in pixels (32 = one tile) unless the key says tiles; times in seconds.
## ==========================================================================================================
static var cw_roster := false

const CW_KINDS := ["tin_militia", "scrapper", "rail_rifleman", "work_car", "plate_wagon", "heavy_loco", "carrier_car", "tesla_loco", "storm_engine"]
## Rail-bound units: they move only along the finished Line (CwRail), at the pressure's speed.
const CW_RAIL := ["work_car", "plate_wagon", "heavy_loco", "carrier_car", "tesla_loco", "storm_engine"]
## The building that builds the rail vehicles (the foot units come from the Assembly Works).
const CW_YARD := "rail_yard"

const CW := {
	# the LAB: resources a match starts with, and the buildings put up beside the Line at the start
	"lab": {"ore": 40000, "res2": 600, "buildings": ["assembly_works", "rail_yard", "engine_hall", "boiler", "charging_pylon"]},
	# SIDINGS (a side arm on a Line segment where a vehicle waits for another to pass)
	#  cost: ore to build one; gap: tiles (Chebyshev) between two sidings; reach: cells a vehicle will go to find one;
	#  meet: cells at which two vehicles head-on count as meeting; hold: seconds a vehicle waits at least / at most;
	#  offset: px the parked vehicle stands to the side of the track
	"siding": {"cost": 12, "gap": 4, "reach": 4, "meet": 3, "hold_min": 1.2, "hold_max": 9.0, "offset": 11.0},
	# WORK CAR: crew = Winders that come with it, crew_max = the most it holds; radius = how far (tiles) from the car the
	# crew leave to work; idle_back = seconds a crew member is idle before he walks back; depart_wait = how long
	# the car waits for its crew before it leaves without them; stranded = their speed share once the car is lost
	"work_car": {"crew": 3, "crew_max": 4, "radius": 6, "idle_back": 2.5, "depart_wait": 6.0, "stranded": 0.5, "board": 42.0},
	# TIN MILITIA: leash = tiles from the Line they can be ordered to / stay in. fuel = what a militia body counts as for a Scrapper
	"militia": {"leash": 7, "fuel": 2},
	# SCRAPPER: salvage stacks. reach: px around it in which a death counts; max: stacks; decay: seconds per stack lost;
	# damage / speed: bonus per stack; gain_cd: seconds between two gains (a splash that kills six counts once)
	"scrapper": {"reach": 260.0, "max": 5, "decay": 4.0, "damage": 0.10, "speed": 0.04, "gain_cd": 0.4, "heal": 6.0},
	# PLATE WAGON: its body blocks enemy ground units across the track (half = px each side of its middle; deployed
	# the side plates widen it); PLATES gives cover to your units within `radius` for `time` s: ranged hits on them
	# do `cover` of the damage; cooldown after; siege = damage taken from siege units; deploy = seconds to raise the plates
	"plate": {"half": 46.0, "half_up": 64.0, "radius": 150.0, "time": 6.0, "cooldown": 14.0, "cover": 0.4, "siege": 2.0, "deploy": 1.2},
	# HEAVY LOCOMOTIVE: on the rails full damage. Set up off the rails (within `reach` tiles of the Line) it needs
	# Tin Militia aboard: `crew` seats; power = share of damage / fire rate at full crew (scaled by the crew aboard);
	# no crew = helpless. splash: px of the shell's burst.
	"heavy": {"crew": 3, "power": 0.6, "reach": 6, "deploy": 2.5, "splash": 34.0, "splash_dmg": 0.5, "off_speed": 0.6},
	# RAIL RIFLEMAN: standing on or within `near` tiles of the Line he shoots `range` x further and `damage` x harder;
	# riding a Troop Train he fires from it at `train` x the normal rate.
	"rifle": {"near": 2, "range": 1.3, "damage": 1.3, "train": 0.8},
	# CARRIER CAR: deck seats for Ornithopters; a landed flyer heals `heal` hp a second, is wound up at `wind` a second
	# and refills its battery; `pick` px: a landed Ornithopter takes a small unit standing this close; one car per team.
	"carrier": {"deck": 2, "heal": 14.0, "wind": 0.5, "pick": 110.0, "max_team": 1, "land_time": 0.8},
	# TESLA LOCOMOTIVE: bolts hit `jumps` more enemies at `falloff`; the pipe it runs on is `pipe` px of reach for the chain
	# (enemies near the Line within it are hit too); pressure scales damage between `min_p` and 1; units it passes get
	# overcharged for `charge` s (friends); `pressure_rate` = bonus damage per point of local pressure over 0.5.
	"tesla": {"jumps": 2, "falloff": 0.55, "reach": 96.0, "min_p": 0.6, "pass": 70.0, "pressure_bonus": 0.6},
	# STORM ENGINE: THUNDER raises a storm of `radius` px for `time` s at up to `range` px: `dps` damage and the acid slow (Defs.BLOAT slow)
	# to enemies in it; cooldown after. Set up off the rails with Tin Militia: `off_*` multipliers.
	# COUPLING (scripts/cw_consist.gd): rail vehicles hook together into one train. len: [side view, end-on view] px a vehicle
	# is long on the track (a coupling joins two vehicles at half of each length less the hook overlap); reach: px from the
	# last car at which a vehicle sent to couple hooks on; bump: px ahead (same lane) at which a moving vehicle running into an
	# idle one hooks on; reverse: seconds a train stands before it swaps ends (the rear car leads: push-pull, so nothing
	# sticks out); close: px/s at which a car slides into its place on the train; guard: damage taken by the other cars while
	# a Heavy Locomotive is coupled (the locomotive shields the train); max: cars in one train; age: seconds a new vehicle
	# is left alone by "driving into it"; cool: seconds after UNCOUPLE before a bump can hook the parts again;
	# give_up: seconds a vehicle sent to couple tries before it gives up; locos: the kinds that lead a train.
	"couple": {"len": {"work_car": [68.0, 28.0], "plate_wagon": [68.0, 28.0], "heavy_loco": [68.0, 28.0], "carrier_car": [68.0, 28.0],
		"tesla_loco": [68.0, 28.0], "storm_engine": [68.0, 28.0]}, "hook": [4.0, 1.0], "reach": 78.0, "bump": 40.0, "reverse": 1.0,
		"close": 260.0, "guard": 0.85, "max": 6, "age": 4.0, "cool": 5.0, "give_up": 45.0, "locos": ["heavy_loco", "tesla_loco", "storm_engine"]},
	"storm": {"range": 330.0, "radius": 110.0, "time": 9.0, "dps": 9.0, "cooldown": 20.0, "cast": 1.2, "reach": 6, "deploy": 2.5, "off_dps": 0.6, "off_radius": 0.7, "crew": 3},
}

## ==========================================================================================================
## GEAR FIELD AND COGS (docs/clockwork_gear_prototype.md, owner's design 2026-10-26). The Clockwork's NEW economy
## and base. The Line (pipes, rails, trains, pressure) is SHELVED behind `line_mode` (default off, kept intact:
## switch it on in tests); `gear_mode` (default on) is the Clockwork's economy now. Every number of the gear
## field and the cog presses is in the ONE block GEAR below (rough guesses: tune by play). Lengths in tiles
## unless the key says px; times in seconds.
## ==========================================================================================================
static var line_mode := false
static var gear_mode := true

## The cog-making building's kind (provisional name: change it here and in the loc files only).
const GEAR_PRESS := "cog_press"
## A new worker's first job (owner, 2026-10-26), every faction: a post on the PRIMARY resource (Farms, Feeding
## Pits, Cog Presses, the old ore buildings) before any on the SECONDARY one (tier 1: Powder Mills, Mainsprings, the
## old Boilers), and hauling at the Town Hall last. Nearest first within a tier. Kinds not listed are tier 0.
const CREW_TIER := {"powder_mill": 1, "mainspring": 1, "boiler": 1}

const GEAR := {
	# THE FIELD. Every Clockwork building has a ground gear ring: radius = half its footprint + `pad` (small / big
	# connecting gear), the Clocktower's ring is the biggest (`tower`). The radius is rounded to a whole number of
	# teeth (`pitch` px apart along the rim) so that meshing gears keep the same tooth size. The rings are the painted
	# ones (scripts/gear_art.gd): a 3x3 building's small ring has 21 chunky teeth, a big one 30, the Clocktower's 38.
	"pitch": 25.0,
	"pad": {"small": 0.9, "big": 2.0, "tower": 2.2},
	# Two rings LINK when their pitch circles (mid tooth) are at most `slack` tiles apart (or overlap), and they may not
	# overlap deeper than `overlap` tiles (about half a tooth: gears cannot pass through each other). Within `mesh_tol` px
	# of touching they mesh directly; a wider gap gets an IDLER cog between them (at least `idler_min` teeth, bigger for a
	# wider gap, GearNet.idler_for).
	"slack": 2.0,
	"overlap": 0.25,
	"mesh_tol": 3.0,
	"idler_min": 8,
	"edge": 6,                      # px: the ring's thick edge under it (its silhouette drawn this many times, 1 px lower each)
	"solve": 0.5,                   # seconds between connection recomputes
	"teeth_rate": 1.4,              # teeth a second passing a mesh point: the Clocktower ring turns this slowly, small gears spin faster
	# GEAR SWAP (a building's SMALL GEAR / BIG GEAR button): cogs and seconds; the building idles meanwhile
	"swap_cost": 25,
	"swap_time": 4.0,
	"start_cogs": 300,
	# THE COG PRESS: `full` cogs a second at full crew; with nobody on it, `base` of that (like a farm with nobody on
	# it); every Winder winding it adds an equal share up to `crew`. Small gear: 8/s, crew 6. Big gear: 10.5/s, crew 12:
	# a Winder adds 1.13 (small) or 0.74 (big), about a Crown Labourer on a Farm (1.19 gold/s); six pay 8.0 vs 6.0, nine
	# 8.0 vs 8.3: the big gear only wins from 9 Winders. 2 presses per Clocktower (Defs.FACTIONS econ). (Crews were 3 and
	# 6 until 0.14.33: the Clockwork earned about twice the Crown per worker, docs/clockwork_economy_study.md.)
	"press": {"base": 0.15, "small": {"full": 8.0, "crew": 6}, "big": {"full": 10.5, "crew": 12}},
	# THE MAINSPRING (docs/clockwork_ground_up.md): winds TENSION, the second resource, at `full` a second with its whole
	# `crew`, `base` of that alone, like the press: SMALL gear 2.0/s with 3 Winders, BIG gear 2.6/s with 6 (the big one wins
	# from 5 Winders). Every finished Mainspring STORES `store` Tension: winding stops when the pool holds what the springs
	# store together (GearEcon.tension_cap; nothing unwinds). Spent on the strong things (their `tension` price).
	# (docs/clockwork_economy_study.md)
	"mainspring": {"base": 0.15, "small": {"full": 2.0, "crew": 3, "store": 200}, "big": {"full": 2.6, "crew": 6, "store": 400}},
	# DRIVE (a building's EFFICIENCY, GearEcon): the Clocktower and every Mainspring drive the field; a building meshing with
	# one works at the first share, each ring farther out at the next (the last one from there on). An idler is free.
	"drive": [1.0, 0.9, 0.8, 0.7],
	"frame_dt": 0.11,               # seconds a frame of the Cog Press's and the Mainspring's working loops
	"pop": {"cog_press": 4.0, "mainspring": 6.0},     # seconds between the "+N" shown over a working press / spring (Building.pop_income)
	"works_dt": 0.12,               # ... of the Light Works' loop (while it trains)
	"regulator_dt": 0.15,           # ... of the Regulator's pendulum (always, while built and linked)
	"escapement_dt": 0.125,         # ... of the Escapement's anchor and wheel (while it is active: linked and meshed with a Mainspring):
	"escapement_frames": 24,        #     a tick or a tock every 4 frames (0.5 s), the wheel's half-tooth jump as the anchor swings through
	"aviary_dt": 0.15,              # ... of the Clock Aviary's doors and bird (4 frames, while it makes a Swift or researches)
	"spent": 0.25,                  # share of a press's yield once its Clocktower's raw brass (Defs.LODE) is spent
	# colours of the drawn gears (code-drawn placeholder art: docs/art_style_inconsistency.md)
	"col": {"brass": Color("#e8c76a"), "edge": Color("#3b2a14"), "rim": Color(0.282, 0.18, 0.071), "dead": Color("#4a443c"), "off": Color("#8c8478"),
		"ok": Color("#8fe39a"), "clash": Color("#ff7f6a"), "far": Color("#ffc65a")},
}

## The old economy (Winders hauling batteries to Ore Crushers) stays in the game behind this switch until the
## rails are proven: false puts the Ore Crusher back in the Clockwork's build list and start.
static var rail_econ := true


## Gear mode's Clockwork barracks and supply building (the Line keeps the Assembly Works and the Spring Tower).
const CW_WORKS := "movement_works"
const CW_SUPPLY := "regulator"


## NO POWER in gear mode (owner, 2026-10-26: "steam and electricity are looks only"): the Boiler, the Charging Pylon (the
## tesla tower), the Engine Hall (it needs a Boiler and its engines cost energy) and the Capacitor Works (blue energy) are
## not built, and nothing that needs one of them or costs energy (cost2: stored batteries) is trained. The Line keeps them.
const ENERGY_KINDS := ["boiler", "charging_pylon", "engine_hall", "capacitor_works"]


## The Clockwork's units in gear mode (the rebuilt faction, docs/clockwork_ground_up.md): every other Clockwork unit is the
## old roster, retired from the live game (owner, 2026-10-26), kept in the code for the shelved Line and the tests.
const CW_NEW_UNITS := ["winder", "clock_soldier", "springer", "cuckoo", "ticking_owl", "pendulum", "netter", "ballista", "great_winder"]
## (the Spring Catapult, art only, was never in this list: the SPRING BALLISTA replaces it, owner 2026-10-27; its art
## and tools stay in art/redraws/catapult_* and tools/catapult_guide/)


## True in gear mode for an old Clockwork unit or building that the live game no longer offers (not in CW_NEW_UNITS /
## not in build_list). Always false with gear mode off.
static func retired(k: String) -> bool:
	if not gear_mode:
		return false
	if UNITS.has(k):
		return String(UNITS[k].get("faction", "")) == "clockwork" and not CW_NEW_UNITS.has(k)
	if BUILDINGS.has(k):
		return String(BUILDINGS[k].get("faction", "")) == "clockwork" and not build_list("clockwork").has(k)
	return false


## True in gear mode for a Clockwork building or unit that runs on energy (ENERGY_KINDS, a unit costing batteries, or
## anything that requires one of ENERGY_KINDS): left out of the build and train lists. Always false with gear mode off.
static func energy_only(k: String) -> bool:
	if not gear_mode:
		return false
	if ENERGY_KINDS.has(k):
		return true
	var d: Dictionary = UNITS.get(k, BUILDINGS.get(k, {}))
	if String(d.get("faction", "")) != "clockwork":
		return false
	if UNITS.has(k) and int(d.get("cost2", 0)) > 0:
		return true
	var r = d.get("requires", "")
	for x in (r if r is Array else [r]):
		if ENERGY_KINDS.has(String(x)):
			return true
	return false


## The RATCHET TURRET (gear mode; docs/clockwork_ground_up.md): the Clockwork's static defence. A squat 2x2 base on its
## gear ring with a head that turns to aim (one 45-degree step every `turn` s, back to its last facing when idle) and
## fires a big screw at the nearest enemy in `range` px, on the ground or in the air, every `cooldown` s, for `damage`.
## Like every gear building it does nothing while it is unlinked. The screw flies at `speed` px/s (the damage lands when
## it is fired, like a musket ball; the screw is the picture). `scan`: s between target searches.
## Numbers are guesses (design_principles 1 and 2): about a Musketeer and a third of damage a second (9.3 vs 7.1), a
## Musketeer's reach (190) plus a little, so Crown guns (430) and mortars out-range it and a rush of 8 Raptors (36 hp,
## 3 screws each) still kills it (about 10 s at 6 dps each) after losing 2-3. Linked only: it cannot be pushed forward.
## Head art: `head_at` (game px from the building's anchor, its footprint's bottom centre) is where the head's collar
## centre sits on the base's turntable (found by eye); `tips` the barrel tip per drawn facing, px from the collar centre
## (W/SW/NW mirror E/SE/NE); `shot_scale` the screw's size in flight (and its sparks), `muzzle_scale` the burst's.
const TURRET := {"range": 200.0, "damage": 14.0, "cooldown": 1.5, "speed": 520.0, "turn": 0.07, "scan": 0.25,
	"head_at": Vector2(0, -70), "shot_scale": 0.6, "muzzle_scale": 0.8,
	"tips": {"s": Vector2(0, -4), "se": Vector2(22, -3), "e": Vector2(40, -15), "ne": Vector2(21, -38), "n": Vector2(0, -40)}}
const CW_TURRET := "ratchet_turret"


## TIER 2 of the gear-mode Clockwork (docs/clockwork_ground_up.md): the ESCAPEMENT, the tech building (like a Cybernetics
## Core: it unlocks the Springer and holds the Tension research), and the SPRINGER, the first unit that costs Tension.
const CW_TECH := "escapement"
const SPRINGER := "springer"
## Unit ids renamed since: an old save, replay or online message that carries one gets today's id (unit_kind). The
## Springer was "jack" until 0.14.82.
const OLD_UNIT_KINDS := {"jack": "springer"}
## THE TENSION RULE (owner, 2026-10-26): a building that uses Tension works only while its gear ring meshes DIRECTLY with
## a Mainspring's ring (one hop, within the link gap: an idler cog between the two rings counts), on top of being linked
## to the field. Else it is idle (no research, unlocks nothing) and shows NEEDS MAINSPRING (GearNet.spring_for).
## The Clock Aviary too (all it makes costs Tension); a Light Works makes its Springers, Netters and Pendulums only so
## (GearEcon.spend_problem).
const TENSION_USERS := ["escapement", "cuckoo_house"]
## The Springer (Defs.UNITS "springer"): a jack-in-the-box on a coil spring that hops about and shoots screws.
## JUMP (an ability, a point): the spring presses down for `crouch` s (a visible crouch: readable and answerable), then it
## flies to the point (at most `range` px) along an arc and lands; `cooldown` s before the next. It cannot attack from the
## crouch to the landing (`land` s after touching down). The flight takes `air` s plus a px/`air_speed` s; the arc's top is
## `peak` px plus `peak_per` of the distance. Allowed onto open walkable ground only (no water, cliffs, buildings, walls);
## flat and DOWN always, UP onto higher ground only once HIGH LEAP is researched and the side sees the spot. A click past
## the range jumps the full range that way; a spot that cannot be landed on gives way to the nearest one within `search`
## tiles on the same level. `ai_low`: a computer's Springer jumps away from melee below this share of its health.
## Shot: the screw (the Ratchet Turret's projectile, Game.screw_shot) leaves the drill tip, `tips` game px from its feet per
## launcher ("r" the robot's right arm, "l" its left: the two fire in turn, scripts/springer.gd) and drawn direction (W/SW/NW
## mirror E/SE/NE; printed by tools/import_springer.py), at `shot_scale` of the turret's screw art (`muzzle_scale` for the
## burst, played at that tip), `speed` px/s.
const SPRINGER_JUMP := {"range": 160.0, "crouch": 0.35, "land": 0.2, "air": 0.3, "air_speed": 520.0, "peak": 20.0, "peak_per": 0.22,
	"cooldown": 10.0, "search": 2, "ai_low": 0.4}
const SPRINGER_SHOT := {"shot_scale": 0.42, "muzzle_scale": 0.5, "speed": 520.0,
	"tips": {"r": {"s": Vector2(-28, -13), "se": Vector2(-22, -11), "e": Vector2(24, -15), "ne": Vector2(25, -13), "n": Vector2(25, -11)},
		"l": {"s": Vector2(27, -13), "se": Vector2(24, -12), "e": Vector2(22, -21), "ne": Vector2(-24, -18), "n": Vector2(-25, -12)}}}


## The raised arm (shooting at a FLYER: the "attack_up" strip, tools/jack_guide/attack_up.py): the drill tip on the fire frame per
## drawn direction, game px from its feet (tools/import_springer.py prints them), and the raised barrel's direction (the muzzle
## burst blows along it).
const SPRINGER_SHOT_UP := {"tips": {"s": Vector2(-30, -54), "se": Vector2(-22, -52), "e": Vector2(17, -43), "ne": Vector2(24, -48), "n": Vector2(26, -48)},
	"barrel": {"s": Vector2(-0.686, -0.728), "se": Vector2(-0.442, -0.897), "e": Vector2(0.707, -0.707), "ne": Vector2(0.606, -0.795), "n": Vector2(0.656, -0.754)}}


## THE CLOCKWORK'S AIR (gear mode; docs/clockwork_ground_up.md "Air: Cuckoo and Ticking Owl"). Display names (owner,
## 2026-10-26): the building is the CLOCK AVIARY, the flyer the SWIFT; the ids stay cuckoo_house and cuckoo.
## The Aviary (CW_AIR) makes the flyers, like a Stargate: a 2x2 on its gear ring (the painted tower's plinth is narrow) that
## needs an ACTIVE Escapement to be placed (linked and meshed with a Mainspring; the Aviary itself need not mesh with one).
## The SWIFT (CUCKOO) is an air-to-air flyer that pecks (a short lunge). Once TICKING OWL is researched at an Aviary, each
## Swift can be MORPHED into a TICKING OWL (OWL) on its own (OWL_MORPH): a heavy flyer that swoops down with its talons on
## units and drops its pendulum-weight bombs on buildings (OWL_BOMB). It cannot hit flyers.
const CW_AIR := "cuckoo_house"
const CUCKOO := "cuckoo"
const OWL := "ticking_owl"
## MORPH TO OWL (a Swift's card): `cost` cogs + `tension` Tension, `time` s, each Swift on its own. It hovers where it is
## meanwhile (no moving, no fighting; it can be hit; killed, the price is lost); CANCEL MORPH pays it all back. The Owl needs
## the 2 supply more it uses than the Swift (held while it morphs).
const OWL_MORPH := {"cost": 100, "tension": 50, "time": 20.0}
## The Owl's BOMB, its attack on a BUILDING (on a unit it swoops: its UNITS numbers). The weight is let go on the 2nd frame
## of the drop (`aim` s), from where it hangs (`drop`: per drawn direction, game px from the Owl's anchor, W/SW/NW mirror
## E/SE/NE; tools/import_cuckoo.py prints them), and falls onto the building (the point of it nearest the Owl, `inside` px
## in) in `fall` s plus a little per px across; it bursts there: `damage` to every enemy building within `radius` px (edge to
## the impact) and `unit_damage` to enemy ground units within `unit_radius` px (a small area; the bonus is on buildings).
## One every `aim` + `strike` + `cooldown` s (3 s: 15 a second on buildings), from `range` px (edge distance less its radius:
## it comes right up to the building's edge, so the weight drops more than it is thrown).
## Guesses (design_principles 1): a Brute does about 17 a second to buildings for 3 supply; the Owl is slow, costs a Swift
## plus 100 cogs and 50 Tension, and a Ratchet Turret (14 every 1.5 s, at air) shoots one down before it bombs the turret.
const OWL_BOMB := {"range": 4.0, "aim": 0.11, "strike": 0.56, "cooldown": 2.33, "damage": 45.0, "radius": 32.0,
	"unit_damage": 12.0, "unit_radius": 24.0, "fall": 0.32, "fall_per": 0.003, "inside": 6.0, "scale": 1.0,
	"drop": {"s": Vector2(-3, -7), "se": Vector2(-2, -5), "e": Vector2(-4, -7), "ne": Vector2(-1, -6), "n": Vector2(-1, -7)}}
## The flyers' sprites (tools/import_cuckoo.py: every frame aligned on the body; the anchor is the bottom of the figure, the
## game lifts it `lift` px over its shadow, as every flyer) and the motion the code draws over them:
##   flap    frames a second of the fly loop (idle and walk alike)
##   strike  s the attack strip keeps playing after the blow lands (so its last frames are seen)
##   lunge   the Swift's peck: share of its REACH per frame of the attack strip (ChatGPT's painted peck: level, the brake
##           with the wings up, the STAB, held in, pulling back, level: it pulls back on the brake, darts in on the stab, the
##           blow on that 3rd frame, the beak held in on the 4th, away as the wings beat)
##   tilt    the Swift's pitch on the peck, radians per frame, turned about its body; `tilt_view` how much of it shows per
##           drawn view (side on all of it, none head-on or from behind). The painted stab already pitches the bird nose
##           down (about 15-25 degrees side on), so this is only a small snap on the blow (it was the whole pitch, about
##           20 degrees, while the peck was the flight frames re-timed)
##   dive    the Owl's swoop: the same per frame (rise, wind up, dive, strike low on the 4th, climb back)
##           REACH: from its beak (the Swift) or talons (the Owl), `strike_y` px over its anchor, to the prey's body
##           (Entity.center), less `contact` px, at most `reach` px: the bird darts all the way in and back, whatever the gap
##           the attack range leaves between the two
##   bob     the Owl after letting a bomb go: px down per frame of the bomb strip (negative: up)
##   fall    share of the flying height left per frame of the death strip (frames 5-6 lie on the ground)
##   centre  px over its ground point where shots aim (its body in the air); `bar`: where its health bar sits
const FLYER := {
	"cuckoo": {"lift": 20.0, "flap": 10.0, "strike": 0.34, "lunge": [0.0, -0.12, 1.0, 0.8, 0.3, 0.0],
		"tilt": [0.0, -0.03, 0.1, 0.07, 0.02, 0.0], "tilt_view": {"e": 1.0, "se": 0.75, "ne": 0.75},
		"strike_y": 14.0, "contact": 16.0, "reach": 64.0,
		"fall": [1.0, 0.9, 0.65, 0.3, 0.0, 0.0], "centre": 34.0, "bar": 52.0},
	"ticking_owl": {"lift": 20.0, "flap": 7.0, "strike": 0.35, "dive": [0.0, -0.15, 0.55, 1.0, 0.4, 0.0],
		"strike_y": 18.0, "contact": 6.0, "reach": 70.0,
		"bob": [0.0, 0.0, -4.0, -5.0, -1.0, 0.0], "fall": [1.0, 0.9, 0.65, 0.3, 0.0, 0.0], "centre": 52.0, "bar": 72.0},
}


## TIER 3 of the gear-mode Clockwork (docs/clockwork_ground_up.md "Tier 3"): the PENDULUM, the melee AREA DAMAGE, and the
## NETTER, the STOPPER; both from the Light Works once an Escapement works, both paid in cogs and Tension
## (scripts/pendulum.gd, scripts/netter.gd; numbers beside their UNITS entries).
const PENDULUM := "pendulum"
const NETTER := "netter"
## The Pendulum is made only while its Light Works runs on the BIG gear (UNITS "big_gear": the heavy torque;
## Game.can_train). Its arms cut in turn (right, left: scripts/pendulum.gd); each blow (on the 4th frame of its arm's
## strip) hits EVERY enemy on the ground in the ARC in front of it: within `reach` px of its feet (to the victim's edge),
## up to `arc` degrees either side of the way it faces (a third of the circle); a building it swings at takes the blow
## too. The machine's own units keep in step with the swing: it never hits its own side. `strike`: s the arm goes on after
## the blow (the strip's follow-through and settling). `vs_light`: a LIGHT unit (tag "light") takes this times the blow
## (a GUESS, design_principles 1: a cleaving blade against unarmoured men; the Crown's canister has the same 1.5).
const PENDULUM_SWING := {"reach": 62.0, "arc": 60.0, "strike": 0.29, "vs_light": 1.5}
## The Netter's NET: a weighted chain net fired from its spring cannon (its UNITS entry: reach, the long reload) at ONE enemy
## unit, leaving the muzzle (`mouth`: per drawn direction, game px from its feet, W/SW/NW mirror E/SE/NE; printed by
## tools/import_tier3.py) on the 2nd frame of the recoil; it flies `speed` px/s along a low arc (`arc` of the distance) and
## follows its target. Where it lands the target is CAUGHT for `time` s: it cannot move or fight (a blow it was winding up
## is lost) and a FLYER is brought down to the ground for that time (then anything can hit it, flyer hunters cannot). The
## weights do `damage`. A second net on a caught unit only tops its time up. `strike`: s the recoil keeps playing.
## Spread over the caught unit: assets/effects/netter_net_open(_big).png, scaled to `cover` x its radius across.
const NET := {"time": 4.0, "speed": 380.0, "arc": 0.12, "damage": 4.0, "strike": 0.5, "cover": 3.4, "drop": 0.12,
	"mouth": {"s": Vector2(0, -43), "se": Vector2(22, -34), "e": Vector2(34, -32), "ne": Vector2(19, -42), "n": Vector2(0, -41)}}


## The SPRING BALLISTA (gear mode's Clockwork tier 2, the owner's unit, 2026-10-27; scripts/ballista.gd, docs/ballista.md):
## a crewed bolt thrower on cog wheels, made at the Light Works once an Escapement works. Its screw BOLT flies in a
## straight line from the bow's `mouth` (game px from its feet per drawn view, W/SW/NW mirror E/SE/NE; printed by
## tools/import_ballista.py) at `speed` px/s and PASSES THROUGH: it goes on `line` px past the point it was aimed at and
## hits the enemies within `width` px of that line (on the ground; never its own side's), up to `hits` of them, in order:
## each takes the shot x its share (the first the whole, then 50%, then 30%); an ARMOURED unit x `vs_armored`, a building
## x the unit's building_bonus, and a building stops the bolt (it sticks in it). The damage lands when it is fired, like a
## musket ball (the bolt is the picture). NO set-up: it fires as soon as it stops, and ON THE MOVE (a MOVE order) at an
## enemy in range ahead of it (within `move_cone`, a cosine, of the way it faces). Then it RELOADS (its UNITS cooldown):
## the spring is wound only while it stands (slower than `still` px/s), by its crew.
## THE CREW: one Winder is built in (part of its picture, not a unit: it always has its own crewman); up to `crew` more
## Winders BOARD it (Balloon-style: Unit.cmd_board, room, take_aboard; UNLOAD sets them down). They stay on the field
## beside it, drawn pushing from behind while it moves and cranking at its side while it reloads, and CAN BE HIT (the
## counter: shoot the crew). Each extra Winder: +`per_crew` reload speed and +`per_crew` move speed. `board`: px from its
## feet a Winder climbs on.
const BALLISTA := {"crew": 4, "per_crew": 0.1, "board": 40.0, "line": 90.0, "width": 10.0, "hits": [1.0, 0.5, 0.3],
	"vs_armored": 1.75, "speed": 620.0, "move_cone": 0.6, "still": 8.0,
	"mouth": {"s": Vector2(0, -16), "se": Vector2(42, -28), "e": Vector2(62, -38), "ne": Vector2(56, -78), "n": Vector2(0, -87)}}
const BALLISTA_KIND := "ballista"


## The GREAT WINDER (gear mode's Clockwork tier 2, the owner's unit, 2026-10-26/27; scripts/great_winder.gd,
## docs/great_winder.md): the faction's big, slow, walking winding machine, its field workshop. No weapon. Three jobs:
## WINDING: every Clockwork construct of its side (not the Winders, who wind themselves) within `area` px of it is wound
##   `wind` a second (an army off the gear ground runs down at Defs.WIND_DECAY, 0.012 a second: inside the area it never
##   does, and a run-down statue in it wakes and fills again). Drawn as a ring on the ground while it is selected.
## MENDING (autocast MEND, on from the start; it is the unit's auto_repair): standing about, it walks to the most hurt
##   Clockwork unit of its side within `look` px and mends it with its key arm, one at a time, from `reach` px off its
##   edge: `mend` x a Winder's repair rate (Defs.REPAIR_RATE or the unit's health over its build time, the faster),
##   paid in cogs as a Winder's repair is (Defs.REPAIR_COST of the price for a full mend), and winds it `mend_wind` a
##   second too. A right-click on a hurt unit of its own sends it there.
## SWEEPING (autocast SWEEP, on from the start): with nothing to mend it walks to the nearest WRECK of its own side's
##   Clockwork units within `sweep_look` px (owner, 2026-10-27: only the Clockwork's OWN wrecks; Crown and Brood bodies
##   are never swept) and sweeps it into its hopper with its rollers for `sweep_time` s: the wreck is gone and it keeps
##   PARTS: the wreck's price / `per_part` (the less of the wreck is left, the fewer), at least 1, up to `cap` in all.
##   Parts do nothing yet: they are for REASSEMBLY, a later job (docs/great_winder.md).
## The art's walk carries it 16 game px a loop of 12 frames (docs/great_winder_legs.md): Unit.WALK_FPS_ART plays it at
## speed x 12 / 16 frames a second, so the feet do not slide.
const GREAT_WINDER := {"area": 200.0, "wind": 0.06, "look": 224.0, "reach": 30.0, "mend": 1.5, "mend_wind": 0.3,
	"sweep_look": 256.0, "sweep_reach": 34.0, "sweep_time": 2.0, "per_part": 10.0, "cap": 100, "stride": 16.0, "frames": 12}
const GREAT_WINDER_KIND := "great_winder"


## The Tension a unit, building or research costs (gear mode's Clockwork: its `tension`; 0 for anything else).
static func tension_cost(d: Dictionary) -> int:
	return int(d.get("tension", 0)) if gear_mode else 0


## A faction's two resources' names: the Clockwork's second is Tension in gear mode (no Energy), else FACTIONS "res".
static func res_names(faction: String) -> Array:
	if faction == "clockwork" and gear_mode:
		return ["Cogs", "Tension"]
	return FACTIONS[faction]["res"]


## A faction's supply building: the Clockwork's is the Regulator in gear mode, else FACTIONS "supply".
static func supply_kind(faction: String) -> String:
	if faction == "clockwork" and gear_mode:
		return CW_SUPPLY
	return String(FACTIONS[faction]["supply"])


## What a faction may build / starts with. The Clockwork: the cog press (gear mode), the Ore Drill (Line mode with rails)
## or the Ore Crusher; the Pressure Relay and the Rail Yard only while the Line is on.
static func build_list(faction: String) -> Array:
	var l: Array = FACTIONS[faction]["build"].duplicate()
	if faction == "clockwork":
		if gear_mode:
			l[l.find("ore_crusher")] = GEAR_PRESS
			l.insert(l.find(GEAR_PRESS) + 1, "mainspring")
			# the new-style army (docs/clockwork_ground_up.md): the Regulator for supply instead of the Spring Tower, and
			# the Light Works (the barracks) after the Mainspring
			l[l.find("spring_tower")] = "regulator"
			l.insert(l.find("mainspring") + 1, CW_WORKS)
			# no power (ENERGY_KINDS), and the Ratchet Turret, the static defence, after the Works
			for k in ENERGY_KINDS:
				l.erase(k)
			l.insert(l.find(CW_WORKS) + 1, CW_TURRET)
			# tier 2: the Escapement (the tech building, a Tension user) after the turret, and the Clock Aviary (the flyers)
			l.insert(l.find(CW_TURRET) + 1, CW_TECH)
			l.insert(l.find(CW_TECH) + 1, CW_AIR)
			# the old prototype army's building is retired (owner, 2026-10-26: only the new units in the live game)
			l.erase("assembly_works")
		elif rail_econ:
			l[l.find("ore_crusher")] = "ore_drill"
		if not line_mode:
			l.erase("pressure_relay")
			l.erase(CW_YARD)
		elif not cw_roster:
			l.erase(CW_YARD)
	return l


static func start_list(faction: String) -> Array:
	var l: Array = FACTIONS[faction]["start"].duplicate()
	if faction == "clockwork" and l.has("ore_crusher"):
		if gear_mode:
			l[l.find("ore_crusher")] = GEAR_PRESS
		elif rail_econ:
			l[l.find("ore_crusher")] = "ore_drill"
	return l


## Pressure -> work speed for a Clockwork building (1.0 at full; 0 with none; see LINE "speed").
static func line_speed(p: float) -> float:
	var s: Dictionary = LINE["speed"]
	if p < float(s["off"]):
		return 0.0
	var k := clampf((p - float(s["off"])) / (float(s["full"]) - float(s["off"])), 0.0, 1.0)
	return lerpf(float(s["floor"]), 1.0, k)


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
		"start_workers": 4, "start_gold": 300, "ready": true, "max_supply": 200,
		"res": ["Gold", "Powder"], "econ": {"farm": 2, "powder_mill": 1},
		"start": ["farm"],
		"about": "Musketeers, cannons and mortars, and horses for them. Farms ripen into big harvests; Horse Breeders sell the horses that cavalry and guns need; Powder Mills grind each Town Hall's saltpetre into powder for muskets and cannons. Slow and strong when dug in.",
	},
	"brood": {
		"name": "The Brood", "hall": "hive", "worker": "grub", "supply": "clutch_mound",
		"build": ["hive", "clutch_mound", "feeding_pit", "brood_pen", "warren", "gorge_pit", "roost"],
		"start_workers": 5, "ready": true, "max_supply": 200,
		"res": ["Biomass", "Essence"], "econ": {"feeding_pit": 3, "brood_pen": 1},
		"start": ["feeding_pit"],
		"about": "A swarm of cheap lizards. Grubs haul food from pits to the Burrow: the longer the haul, the richer the food, and each Burrow's ground runs out in time. Upgrade it to a Warren, then a Broodmound, for more eggs. Essence comes from the fallen and from offerings at the Brood Pen. Supply cap 200.",
	},
	"clockwork": {
		"name": "The Clockwork", "hall": "clocktower", "worker": "winder", "supply": "spring_tower",
		"build": ["clocktower", "spring_tower", "boiler", "ore_crusher", "charging_pylon", "assembly_works", "engine_hall", "capacitor_works", "pressure_relay", "rail_yard"],
		"start_workers": 4, "ready": true, "max_supply": 200,
		"res": ["Cogs", "Energy"], "econ": {"boiler": 2, "ore_crusher": 2, "ore_drill": 2, "cog_press": 2},
		"start": ["ore_crusher"], "start_gold": 300,
		"about": "A spreading machine of gears. Every building sits in a ring of ground gears that must mesh with the Clocktower's: unlinked buildings stop. Winders wind the Cog Presses for COGS, the money. Each Clocktower's brass and coal run out in time. Supply cap 200.",
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
		"about": "Carries 120 shots of powder for the army: musketeers and cannons within 3 tiles refill from it. Fills up near a Mill, Barracks or Town Hall (1 powder per 2 shots); SUPPLY (on from the start; G turns it off) has your Town Hall's haulers bring kegs from the Powder Mill when it's out in the field (assign Labourers to the Town Hall; nobody is taken off a farm or mill). No weapon, and when it's destroyed it blows up (more powder, bigger blast; friends too): guard it.",
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
		"name": "Winder", "hp": 46, "armor": 1, "speed": 74, "cost": 50, "time": 12.0, "supply": 1,
		"sight": 7, "range": 20, "damage": 7, "cooldown": 1.0, "radius": 12, "from": "clocktower",
		"faction": "clockwork", "worker": true, "repairs": true,
		"about": "The one worker: his job is WINDING. He winds a Cog Press for cogs (send him onto it: up to its crew), builds (he fetches a crate from the nearest Clocktower and carries it to the site, where it unfolds and builds itself; killed or sent elsewhere on the way, he drops it for another Winder to carry on) and repairs. He can fight a little.",
	},
	# the new-style army's tier 1 (gear mode; docs/clockwork_ground_up.md): plain melee. 0.14.49 (the owner: a bit faster, less
	# health, docs/clock_soldier_shield.md): 90 hp -> 75, speed 62 -> 68 (guesses, measured there); its SHIELD FORWARD
	# stance (Defs.SHIELD_WALL, scripts/shield_wall.gd) comes with the SHIELD WALL research. First guesses: a
	# Musketeer's price (60 + 10 powder) in cogs, sturdier than a Winder (46 hp), a short clock-hand sword whose blow lands
	# on the 4th frame of the swing (aim 0.33 s at the attack strip's 9 fps). Radius 10, a Musketeer's: the owner had it
	# drawn about 30% smaller in 0.14.32 (42 px tall, the Springer 59), so its body went from 14 to 10 with it
	"clock_soldier": {
		"tags": ["light"],
		"name": "Clock Soldier", "hp": 75, "armor": 1, "speed": 68, "cost": 70, "time": 16.0, "supply": 1,
		"sight": 7, "range": 22, "damage": 10, "cooldown": 1.2, "aim": 0.33, "radius": 10, "from": "movement_works",
		"faction": "clockwork",
		"about": "The machine's plain front-line soldier: a clock-hand sword and a pocket-watch-cover shield. Quick on its feet but light. SHIELD FORWARD (once SHIELD WALL is researched at the Light Works) raises the shield in front: slower, but tougher, and much tougher against shots from the front. Made at the Light Works.",
	},
	# TIER 2 (gear mode): the SPRINGER, the first Tension unit (the Clockwork's Stalker): ranged, hits ground and air, hops
	# (its walk), JUMPs (Defs.SPRINGER_JUMP). Guesses (design_principles 1): 100 cogs + 25 Tension, 2 supply; a shot every
	# 1.41 s (aim 0.11, the screw leaves on the 2nd frame at 9 fps, + 0.35 + cooldown 0.95): 7.1 a second, a little over a
	# Musketeer's 5.6 (20 every 3.55 s) for 1.8 of his price, at 170 px (his 190 out-ranges it: the jump is its way in);
	# 90 hp + 1 armour; a bit faster than the Clock Soldier (70 vs 62). Brass box on a spring: "armored" (round shot hurts
	# it more, canister less). An egg of Raptors (75 biomass) still beats one in the open; two Musketeers beat one.
	"springer": {
		"tags": ["armored"],
		"name": "Springer", "hp": 90, "armor": 1, "speed": 70, "cost": 100, "tension": 25, "time": 25.0, "supply": 2,
		"sight": 8, "range": 170, "damage": 10, "cooldown": 0.95, "aim": 0.11, "radius": 12, "from": "movement_works",
		"requires": "escapement", "anti_air": true, "faction": "clockwork",
		"about": "A jack-in-the-box on a coil spring: it hops about and shoots spinning screws from its drill arm, at the ground and up at flyers. JUMP: a short crouch, then a leap of up to 5 tiles (10 s to wind the spring again); flat or down any time, UP onto high ground once HIGH LEAP is researched and you can see the spot. It cannot shoot in the air. Costs Tension. Made at a Light Works whose gear ring meshes with a Mainspring's, once an Escapement works.",
	},
	# THE AIR (gear mode; Defs.CW_AIR): the SWIFT (id cuckoo), an air-to-air flyer from the Clock Aviary, and the TICKING OWL
	# each Swift can be morphed into (Defs.OWL_MORPH). Guesses (design_principles 1): the Swift is the Skywing's match in
	# the air for less (75 cogs + 15 Tension vs 100 + 40 essence) but it must close in to peck (28 px vs the Skywing's 130)
	# and cannot touch the ground: 10 every 1.27 s (aim 0.33, the hit on the stab, the 3rd or 4th frame of its painted peck
	# at 9 fps whatever the 66 ms animation tick, + 0.34 + 0.6), 7.9 a second;
	# one beats a Skywing that lets it close (about 10 s vs 14), loses to a balloon full of Musketeers. Fast (118, a
	# Skywing's). "light".
	"cuckoo": {
		"tags": ["light"],
		"name": "Swift", "hp": 90, "armor": 0, "speed": 118, "cost": 75, "tension": 15, "time": 20.0, "supply": 2,
		"sight": 9, "range": 28, "damage": 10, "cooldown": 0.6, "aim": 0.33, "radius": 13, "from": "cuckoo_house",
		"air": true, "anti_air": true, "air_only": true, "faction": "clockwork",
		"about": "A fast brass bird with a clock in its chest: it hunts other flyers and pecks them with a short lunge (it must close in, and it cannot touch the ground). MORPH TO OWL rebuilds it into a Ticking Owl once TICKING OWL is researched at a Clock Aviary. Costs Tension. Made at the Clock Aviary.",
	},
	# the TICKING OWL (morphed from a Swift: Defs.OWL_MORPH; never trained): heavy, slow, ground only. Against units the
	# TALON SWOOP: 20 every 2 s (aim 0.33, the blow on the 4th frame, + 0.35 + 1.32) from 28 px; against buildings the BOMB
	# (Defs.OWL_BOMB: 45 every 3 s, a small area). 220 hp + 1 armour, 4 supply, speed 56 (a balloon's 46, a Skywing's 118).
	# Answers: anything that shoots flyers (a Ratchet Turret, Musketeers, Spitters, Skywings, Springers, Swifts).
	"ticking_owl": {
		"tags": ["armored"],
		"name": "Ticking Owl", "hp": 220, "armor": 1, "speed": 56, "cost": 175, "tension": 65, "time": 20.0, "supply": 4,
		"sight": 9, "range": 28, "damage": 20, "cooldown": 1.32, "aim": 0.33, "radius": 18, "from": "",
		"air": true, "ground_only": true, "faction": "clockwork",
		"about": "A heavy clockwork owl with a pendulum weight under it: it SWOOPS DOWN on units with its talons and DROPS its weight as a BOMB on buildings (it bursts on impact and hurts the buildings close by). Slow; it cannot hit flyers. Made from a Swift: MORPH TO OWL, once TICKING OWL is researched at a Clock Aviary.",
	},
	# TIER 3 (gear mode; Defs.PENDULUM_SWING): the PENDULUM, the melee AREA DAMAGE: a tall, slow, tough clock tower on long
	# legs whose two bladed arms cut, in turn, through everything in the arc in front of it. Guesses (design_principles 1):
	# a Brute's job with area instead of a charge: 340 hp + 2 armour (a Brute 240 + 2), 12 a blow to EVERY enemy in a third
	# of a circle, one blow every 1.40 s, the arms taking turns (aim 0.35, the sweep's hit on the 4th frame of a 6-frame strip at
	# 9 fps, + strike 0.29 + cooldown 0.76): 8.6 a second per enemy caught, as the one-armed Pendulum's 22 every 2.59 s
	# (8.5; a Brute 10.8 on one, the old Steam Walker 6.7 in its cone), and x1.5 on LIGHT units (PENDULUM_SWING "vs_light":
	# 12.9 a second; lighter blows lose a little more to armour: 7.1 a second on 2 armour, was 7.7); slow (46, a Brute 56
	# and charging, a Musketeer 62: kiting shooters, cavalry and spreading out answer it), ground only. 200 cogs + 75
	# Tension (a Brute 150 + 20, a Cuirassier 155 with its horse), 4 supply, and only from a BIG-gear Works.
	"pendulum": {
		"tags": ["armored", "massive"],
		"name": "Pendulum", "hp": 340, "armor": 2, "speed": 46, "cost": 200, "tension": 75, "time": 35.0, "supply": 4,
		"sight": 8, "range": 32, "damage": 12, "cooldown": 0.76, "aim": 0.35, "radius": 20, "from": "movement_works",
		"building_bonus": 1.25, "requires": "escapement", "big_gear": true, "ground_only": true, "faction": "clockwork",
		"about": "A tall clock tower on long legs with two arms, each a heavy weight with a crescent blade: they sweep low in turn, like scythes at ankle height, and every blow cuts EVERY enemy on the ground in the wide arc in front of it (never your own units), light units hardest. Slow and tough; it cannot reach flyers. Made at the Light Works once an Escapement works, and only while the Works runs on its BIG gear (the heavy torque). Costs Tension.",
	},
	# TIER 3 (gear mode; Defs.NET): the NETTER, the STOPPER (the owner's "unit that stops one enemy", made of machinery: no
	# magic). Its spring cannon fires a weighted chain net at ONE enemy unit: caught, it cannot move or fight for 4 s, and a
	# flyer is brought down to the ground for that time. Guesses (design_principles 1): a long reload (a net every 14.6 s:
	# aim 0.11, the net leaves on the 2nd frame, + 0.5 + 14) and weak itself (120 hp + 1 armour, 4 damage a net, slow 54);
	# its reach (180) is a Musketeer's (190) less a little and a Spitter's (150) more. 125 cogs + 50 Tension, 2 supply (a
	# Mist Toad 100 + 25, 3 supply, a TONGUE about every 50 s). It picks the most dangerous enemy in reach that is not caught
	# already (Netter.pick); a net is visible in flight and the catch lasts a fixed time (design_principles 1: telegraphed).
	"netter": {
		"tags": ["armored"],
		"name": "Netter", "hp": 120, "armor": 1, "speed": 54, "cost": 125, "tension": 50, "time": 28.0, "supply": 2,
		"sight": 9, "range": 180, "damage": 4, "cooldown": 14.0, "aim": 0.11, "radius": 16, "from": "movement_works",
		"requires": "escapement", "anti_air": true, "faction": "clockwork",
		"about": "A low iron drum on four short legs with a spring cannon on top: it fires a weighted chain NET at one enemy, which then cannot move or fight for 4 s; a flyer it catches comes down to the ground for that time, where anything can hit it. By itself it picks the most dangerous enemy in reach that is not caught already (right-click one to choose). A long reload, and weak itself: keep it behind the line. Made at a Light Works whose gear ring meshes with a Mainspring's, once an Escapement works. Costs Tension.",
	},
	# TIER 2 (gear mode; Defs.BALLISTA, scripts/ballista.gd, docs/ballista.md): the SPRING BALLISTA, the owner's unit
	# (2026-10-27): against ARMOUR and BUILDINGS. Guesses (design_principles 1): a heavy screw bolt, 45 damage (x1.75 on an
	# armoured unit: 79; x2 on a building: 90), the bolt going on through the line behind its target (50% and 30%); a
	# shot every 7.65 s alone (aim 0.3 + strike 0.35 + a 7 s reload, wound only while it stands), 5.9 a second, 10.3 on
	# armour, 11.8 on buildings; with 4 more Winders cranking (each +10%) 5 s of winding: 8.0, 13.9 and 15.9 a second. Reach
	# 300 (a Spore Mother's; the Crown Cannon 430, the Mortar 352, a Musketeer 190), and nothing under 64 px (min_range):
	# weak up close. 210 hp + 1 armour, "armored" (iron and brass: round shot hurts it more). Slow: 34 (a towed gun 38),
	# 47.6 with four Winders pushing. 150 cogs + 50 Tension, 3 supply (a Cannon 170 gold + a horse, 4 supply).
	"ballista": {
		"tags": ["armored"],
		"name": "Spring Ballista", "hp": 210, "armor": 1, "speed": 34, "cost": 150, "tension": 50, "time": 30.0, "supply": 3,
		"sight": 9, "range": 300, "min_range": 64, "damage": 45, "cooldown": 7.0, "aim": 0.3, "radius": 24, "from": "movement_works",
		"building_bonus": 2.0, "requires": "escapement", "ground_only": true, "faction": "clockwork",
		"about": "A bolt thrower on cog wheels: its spring fires a giant screw in a straight line that goes THROUGH its target into one or two behind it. Hard on armoured units and buildings, poor against swarms of light units, and it cannot shoot anything closer than 2 tiles or in the air. No set-up: it fires as soon as it stops, and on the move at what is ahead of it, but the spring is wound again only while it stands (a slow reload). One Winder is built in; up to 4 more can BOARD it: each makes it reload and move 10% faster. They push it and crank it, and they can be shot. Made at the Light Works once an Escapement works. Costs Tension.",
	},
	# TIER 2 (gear mode; Defs.GREAT_WINDER, scripts/great_winder.gd, docs/great_winder.md): the GREAT WINDER, the owner's
	# unit (2026-10-26/27): the Clockwork's field workshop, the job its escort of ordinary Winders does, done better by one
	# machine. Guesses (design_principles 1): no weapon (a Powder Wagon's job in the Crown, a support unit to protect);
	# 420 hp + 3 armour, "armored" and "massive" (a heavy iron machine: a Pendulum 340 + 2, a Powder Wagon 220 + 1); slow:
	# 27 (its painted 4-leg walk carries it 16 px a loop: 20 frames a second at 27; a Ballista 34, a Pendulum 46); it winds
	# every construct within 200 px at 0.06 a second (5 x the run-down rate), mends one at a time at 1.5 x a Winder's rate,
	# and sweeps its own side's wrecks into parts. 175 cogs + 75 Tension, 4 supply (about the three or four escort
	# Winders it stands in for: 150-200 cogs and 3-4 supply, plus the Tension of a tier-2 machine).
	"great_winder": {
		"tags": ["armored", "massive"],
		"name": "Great Winder", "hp": 420, "armor": 3, "speed": 27, "cost": 175, "tension": 75, "time": 35.0, "supply": 4,
		"sight": 8, "range": 0, "damage": 0, "cooldown": 1.0, "radius": 26, "from": "movement_works",
		"requires": "escapement", "no_attack": true, "ground_only": true, "faction": "clockwork",
		"about": "The Clockwork's walking winding machine, big and slow, with no weapon. It keeps the army around it WOUND: every construct near it (the ring on the ground) slowly winds up, so they do not run down off the gear ground, and run-down ones wake again. MEND: with its key arm it mends hurt Clockwork units one at a time, faster than a Winder (it costs cogs, like a repair). SWEEP: it sweeps up the WRECKS of your own Clockwork units with its rollers and keeps them as PARTS (for reassembly, later). Both are automatic; press them to switch them off. Made at the Light Works once an Escapement works. Costs Tension.",
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
	# ---- CLOCKWORK ROSTER PROTOTYPE: begin (numbers beside it in CW; docs/clockwork_units_prototype.md) ----
	"tin_militia": {
		"tags": ["light"],
		"name": "Tin Militia", "hp": 45, "armor": 0, "speed": 64, "cost": 90, "time": 12.0, "supply": 1, "spawn": 4,
		"sight": 7, "range": 20, "damage": 6, "cooldown": 1.0, "aim": 0.15, "radius": 8, "from": "assembly_works",
		"line_bound": true, "faction": "clockwork",
		"about": "Cheap tin spearmen, four to an order, that fight only within 7 tiles of the Line: orders to go farther are cut short at the edge of that ground, and near the Line they never run down. They climb into a Heavy Locomotive or a Storm Engine as its crew (aboard they stay wound and safe), and when they fall they feed a nearby Scrapper.",
	},
	"scrapper": {
		"tags": ["light"],
		"name": "Scrapper", "hp": 150, "armor": 1, "speed": 58, "cost": 110, "time": 16.0, "supply": 2,
		"sight": 7, "range": 22, "damage": 11, "cooldown": 1.1, "aim": 0.2, "radius": 13, "from": "assembly_works",
		"wind_drain": 1.5, "scrap": true, "faction": "clockwork",
		"about": "A walking scrapheap with a cutting arm. Whenever anything dies near it, friend or foe, it salvages the wreck: up to 5 stacks of +10% damage and +4% speed, one stack lost every 4 s (a fallen Tin Militia counts double). It mends a little while it salvages. Strong where the dead pile up, nothing special in a quiet fight.",
	},
	"rail_rifleman": {
		"tags": ["light"],
		"name": "Rail Rifleman", "hp": 60, "armor": 0, "speed": 62, "cost": 95, "time": 14.0, "supply": 1,
		"sight": 8, "range": 130, "damage": 12, "cooldown": 1.6, "aim": 0.25, "radius": 9, "from": "assembly_works",
		"rail_rifle": true, "faction": "clockwork",
		"about": "Lightning rifle. Standing on or beside the Line (2 tiles) it reaches 30% farther and hits 30% harder, drawing on the pipe. He can ride a Troop Train (RIDE) and shoot from the carriage.",
	},
	"work_car": {
		"tags": ["armored"],
		"name": "Work Car", "hp": 320, "armor": 2, "speed": 66, "cost": 260, "time": 30.0, "supply": 2, "extra_supply": 3,
		"sight": 8, "range": 0, "damage": 0, "cooldown": 1.0, "radius": 16, "from": "rail_yard",
		"rail": true, "no_attack": true, "faction": "clockwork", "crew_car": true,
		"about": "A rail car with a crew of 3 Winders (4 at most) and the building crates: it replaces the Winder as the Line's builder. Pick it to BUILD (it runs along the Line to the site, crew go out and build), and the crew mend, wind and lay within 6 tiles of it, then walk back aboard. CREW OUT sends them all out, CREW IN calls them back. Lose the car and the crew are stranded, slow on their feet. Rail-bound.",
	},
	"plate_wagon": {
		"tags": ["armored"],
		"name": "Plate Wagon", "hp": 420, "armor": 4, "speed": 52, "cost": 180, "time": 22.0, "supply": 3,
		"sight": 7, "range": 0, "damage": 0, "cooldown": 1.0, "radius": 18, "from": "rail_yard",
		"rail": true, "no_attack": true, "gate": true, "faction": "clockwork",
		"about": "A moving gate: its body blocks the track across 3 tiles and enemy ground units cannot pass it (yours can). PLATES raises side shields for 6 s: wider block, and your units near it take only 40% of ranged hits. Weak to siege: cannons, mortars and heavy hitters do double damage to it. Rail-bound.",
	},
	"heavy_loco": {
		"tags": ["armored", "massive"],
		"name": "Heavy Locomotive", "hp": 600, "armor": 4, "speed": 38, "cost": 340, "time": 38.0, "supply": 5,
		"sight": 9, "range": 200, "damage": 34, "cooldown": 2.4, "aim": 0.4, "radius": 22, "from": "rail_yard",
		"rail": true, "heavy": true, "requires": "boiler", "building_bonus": 1.5, "faction": "clockwork",
		"about": "Slow armoured train with a cannon turret: full damage on the rails. SET UP takes it off the rails (up to 6 tiles from the Line) as a ground battery, but then it needs Tin Militia aboard to stay steamed: with a full crew of 3 it fires at 60% power, with none it is helpless. BOARD sends the Tin Militia selected with it aboard; they stay wound and safe inside. PACK drives it back to the rails.",
	},
	"carrier_car": {
		"tags": ["armored"],
		"name": "Carrier Car", "hp": 360, "armor": 2, "speed": 56, "cost": 240, "time": 28.0, "supply": 3,
		"sight": 8, "range": 0, "damage": 0, "cooldown": 1.0, "radius": 18, "from": "rail_yard",
		"rail": true, "no_attack": true, "requires": "charging_pylon", "max_team": 1, "faction": "clockwork",
		"about": "A rail wagon with a landing deck for 2 Ornithopters (DOCK them on it). Landed flyers are healed, wound up and recharged. A landed Ornithopter can CARRY one small unit (a Winder) and DROP it elsewhere. One per team. Rail-bound.",
	},
	"tesla_loco": {
		"tags": ["armored"],
		"name": "Tesla Locomotive", "hp": 380, "armor": 3, "speed": 66, "cost": 300, "time": 34.0, "supply": 4,
		"sight": 9, "range": 150, "damage": 12, "cooldown": 1.2, "aim": 0.2, "radius": 18, "from": "rail_yard",
		"rail": true, "tesla_loco": true, "anti_air": true, "requires": "charging_pylon", "faction": "clockwork",
		"about": "Zaps along the Line, flyers too. Its bolts jump to 2 more enemies and then along the pipe to enemies beside the Line; the more pressure under it, the harder it hits, and your constructs it passes are overcharged. Rail-bound.",
	},
	"storm_engine": {
		"tags": ["armored", "massive"],
		"name": "Storm Engine", "hp": 340, "armor": 2, "speed": 40, "cost": 340, "time": 40.0, "supply": 4,
		"sight": 9, "range": 0, "damage": 0, "cooldown": 1.0, "radius": 20, "from": "rail_yard",
		"rail": true, "no_attack": true, "storm_engine": true, "requires": ["charging_pylon", "boiler"], "faction": "clockwork",
		"about": "Rail-bound zoning engine. THUNDER raises a big storm for 9 s up to 330 px away: it hurts and slows everything of the enemy inside. SET UP puts it off the rails (6 tiles from the Line), but then it needs Tin Militia aboard and storms at 60% damage and 70% size.",
	},
	# ---- CLOCKWORK ROSTER PROTOTYPE: end ----
}

const BUILDINGS := {
	"town_hall": {
		"name": "Town Hall", "hp": 1600, "armor": 2, "cost": 400, "time": 60.0, "size": Vector2i(5, 4),
		"supply": 10, "sight": 9, "trains": ["labourer"], "haulers": 6, "faction": "crown", "about": "Trains labourers. Right-click Labourers onto it to make them haulers: they lead horses to the Barracks and Foundry and carry powder kegs to the Wagons. Each Town Hall allows 2 Farms and 1 Powder Mill nearby. Its farmland holds a reserve of gold (once the farms have drawn it out they pay nothing) and its ground a reserve of saltpetre for the Mill (spent, the Mill grinds nothing). Expand to fresh land.",
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
		"supply": 0, "sight": 7, "trains": ["musketeer", "dragoon", "cuirassier", "dismounted"], "requires": "cottage", "faction": "crown", "about": "Trains Musketeers (with a Powder Mill), Horsemen and Officers (with a Horse Breeder; a Horseman's horse comes in the same click) and Dragoons (both: a Musketeer and his horse); with Armour, the armoured ones too. Refits soldiers. Needs a Cottage. Two openings: Powder Mill first for Musketeers, or Horse Breeder first for a Horseman rush.",
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
		"faction": "brood", "about": "Lays eggs (up to 5); every Brood unit hatches here. Your FIRST Burrow is the capital (the Queen's seat): the only one grubs unload at. It has no ground of its own: every Feeding Pit has its own, in a circle round it. The others only lay eggs. If the capital falls, the next oldest takes over. Allows 1 Brood Pen each; Feeding Pits go on your swamp, as far from the capital as it reaches; plant Clutch Mounds forward to push the swamp out. Upgrades to a Warren (10 eggs), then a Broodmound (15 eggs).",
	},
	"clutch_mound": {
		"name": "Clutch Mound", "hp": 350, "armor": 0, "cost": 75, "time": 18.0, "size": Vector2i(2, 2),
		"supply": 12, "sight": 5, "trains": [], "swamp": 10, "faction": "brood", "about": "12 more supply. Its swamp spreads far around it (10 tiles), so plant it forward and guard it: it must stand on swamp joined to a Burrow's. If it falls, the swamp only it held shrinks back. Each one makes your Burrows lay eggs 10% faster (up to 3).",
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
		"about": "The blueprint of the machine: builds Winders, takes in the cogs, unlocks the other buildings and fills a battery every 2 s. Its gear ring is the biggest: every building must mesh with it, directly or through others, or it stops. Allows 2 Boilers and 2 Cog Presses nearby. Its ground holds a reserve of raw brass for its presses (spent, they yield a quarter), and its Boilers share its coal. A new Clocktower starts its own gear field.",
	},
	"spring_tower": {
		"name": "Spring Tower", "hp": 500, "armor": 2, "cost": 100, "time": 20.0, "size": Vector2i(2, 2),
		"supply": 10, "sight": 6, "trains": [], "field": 7, "faction": "clockwork",
		"about": "10 more supply. Keeps nearby constructs wound up.",
	},
	# THE NEW-STYLE CLOCKWORK ARMY (gear mode; docs/clockwork_ground_up.md). Numbers are first guesses: the Light Works
	# costs like the Crown Barracks, the Regulator houses like the Spring Tower.
	"movement_works": {
		"name": "Light Works", "hp": 1000, "armor": 2, "cost": 150, "time": 40.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": ["clock_soldier", "springer", "ballista", "pendulum", "netter", "great_winder"], "faction": "clockwork",
		"about": "The Clockwork's barracks: a long hall that assembles Clock Soldiers on a hanging line, and Springers, Spring Ballistas, Great Winders, Netters and Pendulums once an Escapement works and a Mainspring's gear ring meshes with its ring (they cost Tension; a Pendulum only while the Works runs on its BIG gear). It researches SHIELD WALL (the Clock Soldiers' SHIELD FORWARD; Tension too). Must stay linked to the gear field.",
	},
	# TIER 2 (gear mode): the tech building, like a Cybernetics Core. A Tension user (Defs.TENSION_USERS): it works only while
	# its ring meshes with a Mainspring's. Numbers are guesses: the Light Works' price and health.
	"escapement": {
		"name": "Escapement", "hp": 1000, "armor": 2, "cost": 150, "time": 40.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 7, "trains": [], "requires": "movement_works", "faction": "clockwork",
		"about": "The Clockwork's tech building: it unlocks the Springer and holds the Tension research (HIGH LEAP). It uses Tension, so its gear ring must mesh with a Mainspring's ring (right beside it; an idler between them counts), and it must stay linked to the gear field: else it stands idle (NEEDS MAINSPRING). Needs a Light Works.",
	},
	# THE AIR (gear mode): the CLOCK AVIARY (id cuckoo_house), the flyers' building (like a Stargate). A tall narrow 2x2 tower
	# on its gear ring; it needs an ACTIVE Escapement to be placed (Game.requirement_text), and everything it makes costs
	# Tension, so it is a Tension user itself (TENSION_USERS: idle unless its ring meshes with a Mainspring's).
	# Guesses: 150 cogs + 50 Tension (a Brood Roost is 175), a Foundry's health (docs/clockwork_economy_study.md).
	"cuckoo_house": {
		"name": "Clock Aviary", "hp": 900, "armor": 2, "cost": 150, "tension": 50, "time": 45.0, "size": Vector2i(2, 2),
		"supply": 0, "sight": 7, "trains": ["cuckoo"], "requires": "escapement", "faction": "clockwork",
		"about": "A tall clock tower whose little doors open for brass birds to fly out. It makes the Swift, the Clockwork's flyer, and researches TICKING OWL (then every Swift can be rebuilt into a Ticking Owl). Costs Tension. Needs a working Escapement to be built; everything it makes costs Tension, so its gear ring must mesh with a Mainspring's ring, else it stands idle (NEEDS MAINSPRING).",
	},
	"regulator": {
		"name": "Regulator", "hp": 500, "armor": 2, "cost": 100, "time": 20.0, "size": Vector2i(2, 2),
		"supply": 10, "sight": 6, "trains": [], "faction": "clockwork",
		"about": "10 more supply. Its pendulum keeps the machine's units in time: each Regulator keeps only so many in step.",
	},
	# the static defence (gear mode): Defs.TURRET; priced at a little under two Clock Soldiers, needs the Light Works
	"ratchet_turret": {
		"name": "Ratchet Turret", "hp": 450, "armor": 1, "cost": 125, "time": 30.0, "size": Vector2i(2, 2),
		"supply": 0, "sight": 8, "trains": [], "requires": "movement_works", "anti_air": true, "faction": "clockwork",
		"about": "Static defence: its head turns to the nearest enemy and fires big screws at ground and air alike. Must stay linked to the gear field or it does not fire. Needs a Light Works.",
	},
	"assembly_works": {
		"name": "Assembly Works", "hp": 1400, "armor": 3, "cost": 200, "time": 45.0, "size": Vector2i(5, 4),
		"supply": 0, "sight": 7, "trains": ["windup_soldier", "thresher", "bulwark", "arc_thrower", "tin_militia", "scrapper", "rail_rifleman"], "faction": "clockwork",
		"about": "Assembles the line: Wind-up Soldiers, Threshers, and (with a Boiler) Bulwarks and Arc Throwers. Faster with blue energy.",
	},
	"engine_hall": {
		"name": "Engine Hall", "hp": 1500, "armor": 3, "cost": 250, "time": 50.0, "size": Vector2i(4, 4),
		"supply": 0, "sight": 7, "trains": ["steam_walker", "tesla_cart", "stormcaller", "ornithopter"],
		"requires": ["assembly_works", "boiler"], "faction": "clockwork",
		"about": "Builds the big engines: Steam Walkers, and (with a Charging Pylon) Tesla Carts, Stormcallers and Ornithopters. They cost energy (stored batteries) too. Needs an Assembly Works and a Boiler.",
	},
	"farm": {
		"name": "Farm", "hp": 500, "armor": 1, "cost": 100, "time": 25.0, "size": Vector2i(6, 6),
		"supply": 0, "sight": 5, "trains": [], "crew": 8, "faction": "crown",
		"about": "Ripens into a 380-gold harvest about every 40 s with a full crew. Up to 8 labourers make it grow faster, each as much as the next. Harvests draw on its Town Hall's soil: spent soil pays nothing (barren).",
	},
	"powder_mill": {
		"name": "Powder Mill", "hp": 600, "armor": 1, "cost": 100, "time": 30.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 5, "trains": [], "crew": 6, "faction": "crown",
		"about": "Up to 6 labourers grind its Town Hall's saltpetre into black powder for the bank: it buys musketeers and wagons and pays for refilling soldiers' powder. Once that saltpetre is spent it grinds nothing. Soldiers and wagons nearby refill here.",
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
		"supply": 0, "sight": 6, "trains": [], "crew": 6, "swamp": 4, "faction": "brood",
		"about": "Grubs haul food from here to the capital (6, and one more for every 4 tiles beyond 6, up to 12). Farther from the capital pays more per grub (best from about 18 to 22 tiles). Each pit has its own ground (3,000 biomass) in a circle 5 tiles round it: spent ground yields nothing, and your pits' circles may not overlap. A pit raised over old ground takes over what was left there. Needs swamp joined to the capital's.",
	},
	"brood_pen": {
		"name": "Brood Pen", "hp": 600, "armor": 0, "cost": 100, "time": 22.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 6, "trains": [], "swamp": 4, "faction": "brood",
		"about": "SACRIFICE: Brood creatures brought here are offered up for essence (35% of their biomass cost: 9 a Raptor). The fallen give essence too: grubs wrap the bodies on the field and carry them home.",
	},
	"roost": {
		"name": "Roost", "hp": 700, "armor": 1, "cost": 175, "time": 35.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 8, "trains": [], "swamp": 4, "requires": "warren", "faction": "brood",
		"about": "Lets your Burrows hatch Skywings. Needs a Spawning Den.",
	},
	"boiler": {
		"name": "Boiler", "hp": 900, "armor": 2, "cost": 150, "time": 30.0, "size": Vector2i(4, 4),
		"supply": 0, "sight": 6, "trains": [], "battery": [1.0, 8], "crew": 7, "faction": "clockwork",
		"about": "Fills a battery every second by itself, burning its Clocktower's coal (spent coal: it stops); the batteries waiting are your Energy. Constructs that stand by it a while get overcharged. Unlocks Bulwarks, Arc Throwers and the Engine Hall.",
	},
	"ore_crusher": {
		"name": "Ore Crusher", "hp": 800, "armor": 2, "cost": 125, "time": 30.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 6, "trains": [], "faction": "clockwork",
		"about": "Winders bring batteries here and the charge becomes ore, drawn from its Clocktower's ore; once that's spent it pays nothing. The farther a battery travelled, the more it holds.",
	},
	"ore_drill": {
		"name": "Ore Drill", "hp": 900, "armor": 2, "cost": 140, "time": 35.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 6, "trains": [], "faction": "clockwork",
		"about": "Digs its Clocktower's ore into a stock (it must stand beside the Line, and works at the Line's pressure). Ore Trains carry the stock to the Clocktower along the rails; once the ore is spent it digs a quarter. Buy trains at the Clocktower.",
	},
	"cog_press": {
		"name": "Cog Press", "hp": 900, "armor": 2, "cost": 140, "time": 35.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 6, "trains": [], "crew": 6, "faction": "clockwork",
		"about": "Presses COGS from its Clocktower's brass: a trickle by itself, and every Winder winding it adds the same share (SMALL gear: faster, up to 6 Winders; BIG gear: slower per Winder but up to 12, and more in all from 9). It works at full speed when its gear ring meshes with the Clocktower's or a Mainspring's, less farther out. Spent brass: a quarter. Must stay linked to the gear field.",
	},
	"mainspring": {
		"name": "Mainspring", "hp": 800, "armor": 2, "cost": 140, "time": 35.0, "size": Vector2i(3, 3),
		"supply": 0, "sight": 6, "trains": [], "crew": 3, "faction": "clockwork",
		"about": "Winds TENSION, the Clockwork's second resource: a little by itself, more for every Winder cranking it (SMALL gear: up to 3; BIG gear: up to 6, more in all at 5 or 6). Each Mainspring stores 200 Tension (big: 400): winding stops when you hold what your Mainsprings store. It also DRIVES the rings that mesh with it, like the Clocktower. Anything that costs Tension is made only where a Mainspring's ring meshes: the Escapement, the Clock Aviary, and a Light Works for its Springers, Netters and Pendulums. Must stay linked to the gear field.",
	},
	"capacitor_works": {
		"name": "Capacitor Works", "hp": 900, "armor": 2, "cost": 250, "time": 50.0, "size": Vector2i(2, 2),
		"supply": 0, "sight": 7, "trains": [], "requires": "assembly_works", "faction": "clockwork",
		"about": "Blue energy: every source fills blue batteries, with more charge and more time before they overload. Needs an Assembly Works.",
	},
	"pressure_relay": {
		"name": "Pressure Relay", "hp": 350, "armor": 2, "cost": 75, "time": 20.0, "size": Vector2i(2, 2),
		"supply": 0, "sight": 6, "trains": [], "faction": "clockwork",
		"about": "Stands beside the Line and boosts its pressure back up for the stretch beyond it (it needs at least a quarter of pressure coming in). Place it where the Line is thinning.",
	},
	"rail_yard": {
		"name": "Rail Yard", "hp": 1100, "armor": 3, "cost": 220, "time": 40.0, "size": Vector2i(4, 3),
		"supply": 0, "sight": 7, "trains": ["work_car", "plate_wagon", "heavy_loco", "carrier_car", "tesla_loco", "storm_engine"],
		"requires": "assembly_works", "faction": "clockwork",
		"about": "Builds the rail vehicles: Work Cars, Plate Wagons, Heavy Locomotives, Carrier Cars, Tesla Locomotives and Storm Engines. They come out onto the Line beside it, so it must touch the Line (it runs at the Line's pressure). Needs an Assembly Works.",
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
	# the Clockwork's Tension research (gear mode), at the Escapement (it must be working: meshed with a Mainspring)
	"high_leap": {"name": "High Leap", "label": "HIGH LEAP", "at": "escapement", "faction": "clockwork", "cost": 150, "cost2": 0, "tension": 100,
		"time": 60.0, "icon": "research_high_leap",
		"about": "A stiffer spring: every Springer can JUMP UP onto high ground too (only where you can see)."},
	# the Light Works' research (gear mode): SHIELD FORWARD for every Clock Soldier (Defs.SHIELD_WALL). It costs
	# Tension, so it is made only at a Works whose ring meshes with a Mainspring's (THE TENSION RULE). Guesses.
	"shield_wall": {"name": "Shield Wall", "label": "SHIELD WALL", "at": "movement_works", "faction": "clockwork", "cost": 100, "cost2": 0,
		"tension": 50, "time": 45.0, "icon": "research_shield",
		"about": "Drilled to hold the shield in front: every Clock Soldier gets SHIELD FORWARD. Raised, it walks 40% slower and swings a little slower, but has 1 more armour and takes half the damage from shots coming from the front (a fifth less from blows from the front)."},
	# the Clock Aviary's research (gear mode): then each Swift can be morphed into a Ticking Owl (Defs.OWL_MORPH)
	# (id owl_morph: the unit is ticking_owl)
	"owl_morph": {"name": "Ticking Owl", "label": "TICKING OWL", "at": "cuckoo_house", "faction": "clockwork", "cost": 150, "cost2": 0, "tension": 150,
		"time": 60.0, "icon": "research_ticking_owl",
		"about": "The plans of the Ticking Owl: every Swift gets MORPH TO OWL (100 cogs and 50 Tension, 20 s each), rebuilding it into a heavy owl that swoops on units and bombs buildings."},
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
	"ore_drill": {"building": "ore_crusher", "portrait": "ore_crusher"},     # (until the Drill sheet is imported)
	"rail_yard": {"building": "engine_hall", "portrait": "engine_hall"},     # (roster prototype: the Engine Hall's picture until a Rail Yard is drawn)
	"pressure_relay": {"building": "charging_pylon", "portrait": "charging_pylon"},     # (phase 1 of the Line: the Pylon's picture, plus a gauge drawn in code: docs/art_style_inconsistency.md)
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


## A unit id read from a save, a replay or the network: an old id (OLD_UNIT_KINDS) as today's.
static func unit_kind(k: String) -> String:
	return String(OLD_UNIT_KINDS.get(k, k))


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
		if CW_KINDS.has(k) and not cw_roster:
			continue
		if CW_RAIL.has(k) and not line_mode:
			continue        # (rail vehicles: shelved with the Line)
		if energy_only(k):
			continue        # (gear mode: no power)
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


## How many workers an economy building takes: its crew, or a Town Hall's haulers.
static func crew_cap(d: Dictionary) -> int:
	return int(d.get("crew", d.get("haulers", 0)))


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
## Observation Balloon as a dropship: who can ride in the basket (all of them die with it).
## A balloon shot down: each man in the basket rolls his fall. [chance, share of his health left]
## (hp share 0 = he dies): bruised, hurt (yellow health), crippled (red health) or killed.
const FALL_ODDS := [[0.20, [0.8, 1.0]], [0.25, [0.45, 0.65]], [0.20, [0.08, 0.2]], [0.35, [0.0, 0.0]]]
const DROPSHIP := {"capacity": 4, "kinds": ["musketeer", "labourer"], "board": 42.0, "give_up": 30.0}
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
## per_supply: essence a harvested body gives for each point of its supply (a float: Game.corpse_value; was 1, raised to
## 1.25 when area shots began to tear bodies up, Defs.BODY_BLAST, and to 2 in 0.14.40 when the Brood Pen stopped taking the
## bodies that fell near it: a Musketeer 2, a Brute 6, a Horseman with his horse 8), plus 1 for each kill it made, up
## to 50 (the kills veterancy counts, VET; 0.14.41).
## take: the seconds a grub takes to wrap a Musketeer-sized body (`ref` health); bigger bodies take a little longer, x the
## square root of their health over `ref`, from `take_min` to `take_max` (Game.harvest_time: a Raptor 0.9 s, a Brute 2.2).
const HARVEST := {"range": 10, "take": 1.2, "per_supply": 2.0, "ref": 70.0, "take_min": 0.8, "take_max": 3.0}
## BODIES ROT (owner, 2026-10-27): a body has the health its unit had in life (a rider's adds his horse's: it lies with him)
## and loses it at one speed for every body, `base` health a second, which doubles every `double` seconds it has lain
## (smoothly: base x 2^(seconds since death / double)). At 0 it is gone. Damage (ground attack, Defs.GROUND, and area shots
## fired at the ground, Defs.BODY_BLAST) takes health off too; a body brought to 0 by damage is torn up (no harvest, no
## raising). base 0.2696: an untouched Musketeer's body (70) lies 2:00, a Raptor's (36) 1:20, a Brute's (240) 3:30, a
## Horseman's with his horse (200) 3:15, a Pendulum's (340) 3:58, a Heavy Locomotive's (600) 4:44 (Unit.rot_life).
const ROT := {"base": 0.2696, "double": 60.0}
## ATTACK GROUND (Ctrl+A or the card's button; owner, 2026-10-27): any unit that can attack (not medics, wagons, horses,
## balloons, the trains on their rails, nor the units in `not`) can be told to attack the ground. A click: everyone attacks
## that spot (melee units and workers take the bodies within `click` tiles of it); a held left-drag: the line is shared out
## among them like the formation drag and each works its own stretch (melee units and workers in a lane `lane` tiles to
## each side of it; shooters spread their fire along it, at the bodies in that lane while there are any). A ranged shot
## lands at its point: an enemy standing there takes it as a normal hit, otherwise the nearest body within `near` tiles,
## otherwise the ground. Units reaching under `ranged` px strike as melee. It goes on until another order.
const GROUND := {"click": 1.5, "lane": 0.5, "near": 0.5, "ranged": 60.0, "scan": 0.5,
	"not": ["netter", "bloater"]}
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
## FIRE AT A SPOT (BOMBARD; owner, 2026-10-26, as in Total Annihilation): Ctrl+A or the BOMBARD button, then a spot on the
## ground (in the fog too): the units of these kinds in the selection walk into range, set up and keep firing at it until
## another order, as long as their shot lasts (Unit.cmd_bombard). Area weapons only: the Field Cannon (round shot or
## canister, whichever it is loaded with), the Mortar, the Brood's Spore Mother (her spit blobs; she roots). And the
## Clockwork's Spring Ballista (its bolt through the spot, scripts/ballista.gd). `queued`: with orders Shift-queued behind it, a unit fires this many shots at the spot and
## then goes on to the next order (the last one it keeps firing).
const BOMBARD := {"kinds": ["cannon", "mortar", "spore_mother", "ballista"], "queued": 3}
## AREA SHOTS DESTROY BODIES (owner, 2026-10-26): a shell, round shot or canister fired at a spot (BOMBARD) tears up the
## bodies lying in its blast (Game.blast_bodies): the Brood can no longer harvest them, a Missionary can no longer raise them
## (the Crown's own dead too: the price of blasting). The blast: a Mortar shell's splash, round shot's small splash where it
## lands and the line it ploughs, canister's cone (and a Ticking Owl bomb's reach on units, were `combat` above 0). Not the
## Spore Mother's spit (acid), nor a keg or a Powder Wagon going up. The bodies of the men a shot kills stay (only what lay
## there before is torn up).
## `combat`: the share of the blast (radius, or the cone's reach) that tears bodies when the shot is ordinary fire at an
## enemy, not BOMBARD. LIMIT (2026-10-26, tools/measure_body_blast.gd): 0, ONLY DELIBERATE GROUND FIRE tears bodies. In two
## Hard Crown AI matches against the Brood (ashford_crossing, hollowfen) ordinary splash tore 0 of 95 and 0 of 187 bodies
## (the computer's 1-3 guns came late and seldom fired where bodies lay), but in a gun line holding against Brood waves
## (the "lab": 4 Cannons, 2 Mortars, 6 waves) it tore 80 of 86 bodies (93%) with the whole blast, 78 of 87 (90%) with half
## its radius and 61 of 87 (70%) with 0.3: guns firing again and again at a swarm over its own dead sweep the pile anyway.
## Denying the harvest stays a choice with a price (powder, and guns busy and reloading if the enemy rushes in), not a
## free side effect of every fight (docs/design_principles.md 1: a punishment should match the mistake).
## `body`: an area shot fired at the ground (BOMBARD) hurts each body in its blast by its damage x this (a Mortar shell
## 300, round shot 320, canister 180, a spit blob 260): enough to tear up most bodies at once (not a Pendulum's 340, a
## Steam Walker's or a train's).
const BODY_BLAST := {"combat": 0.0, "body": 10.0}


static func has_tag(kind: String, tag: String) -> bool:
	return UNITS.has(kind) and (UNITS[kind].get("tags", []) as Array).has(tag)

const ADVANCED := ["barracks", "horse_breeder", "armoury", "foundry", "church", "warren", "gorge_pit", "roost", "assembly_works", "engine_hall", "charging_pylon", "capacitor_works", "rail_yard"]


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
	"foundry": "Casts cannons and mortars, rigs balloons, builds powder wagons (each needs a horse: one standing here, else a Town Hall hauler leads one over from the Horse Breeder, or it walks over by itself when you have no haulers).",
	"farm": "Ripens into a 380-gold harvest about every 40 s with a full crew (up to 8 Labourers).",
	"powder_mill": "Up to 6 Labourers grind the Hall's saltpetre into powder (you start with none). Unlocks Musketeers. Soldiers and wagons nearby refill here.",
	"church": "Sends out one Missionary.",
	# Brood buildings
	"hive": "Lays eggs (up to 5): every Brood unit hatches here. The first Burrow is the capital: the only one grubs unload at. Allows 1 Brood Pen each. Upgrades to a Warren (10 eggs), then a Broodmound (15).",
	"clutch_mound": "12 more supply. Spreads swamp far around it (10 tiles; plant it forward, on swamp joined to a Burrow's); if it falls, the swamp only it held shrinks back. Each makes Burrows lay eggs 10% faster (up to 3).",
	"warren": "Lets your Burrows hatch Raptors and Spitters.",
	"gorge_pit": "Lets your Burrows hatch Brutes, Spore Mothers and Mist Toads; a Warren can grow into a Broodmound.",
	"feeding_pit": "Up to 6 grubs haul food from here to the Burrow. Farther from the Burrow pays more (best 18 to 22 tiles). Its own ground (3,000 biomass) lies in a 5-tile circle round it; your pits' circles may not overlap.",
	"brood_pen": "SACRIFICE Brood creatures here for essence (35% of their biomass cost).",
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
## Gear mode's own tooltips where the old text speaks of batteries, Boilers or coal (no power in gear mode).
const GEAR_TIPS := {
	"clocktower": "The blueprint of the machine: builds Winders, takes in the cogs and unlocks the other buildings. Its gear ring is the biggest: every building must mesh with it, directly or through others, or it stops. Allows 2 Cog Presses nearby. Its ground holds a reserve of raw brass for its presses (spent, they yield a quarter). A new Clocktower starts its own gear field.",
}


static func tip(kind: String) -> String:
	if gear_mode and GEAR_TIPS.has(kind):
		return GEAR_TIPS[kind]
	if TIPS.has(kind):
		return TIPS[kind]
	if train_armoured(kind):
		return String(ARMOURED[train_kind(kind)]["about"])
	for d in [UNITS, BUILDINGS, RESEARCH]:
		if (d as Dictionary).has(kind):
			return String(d[kind].get("about", ""))
	return ""
