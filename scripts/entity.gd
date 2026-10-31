class_name Entity
extends Node2D
## Anything on the map: units and buildings.

const TEAM_SHADER := preload("res://shaders/team.gdshader")

var game: Game
var team := -1
var kind := ""
var net_id := 0                # online: the id both players know it by (0: none yet)
## Its number in the match, in the order things were made (Game._add_unit / _add_building). The game
## uses it, never the engine's instance id, where it needs a fixed way to tell things apart (a
## unit's turn for separation, a raptor's side of its prey): the instance id differs from run to
## run (it counts every object the engine has made, sounds and menus too), so the same match with
## the same seed would not play out the same.
var serial := 0
var hp := 1.0
var max_hp := 1.0
var armor := 0.0
var sight := 7
var dead := false
var selected := false
var seen_by_human := false     # enemy buildings stay on screen once spotted
var seen_mask := 0             # demo: the players (bits) that have spotted this building
var hit_clock := -99.0         # match clock of the last enemy hit (the spectator looks for fights)
var flash := 0.0
var last_hit_by := ""           # kind that last hurt us, for battle stats
var last_hit_team := -1
var last_hitter: Entity = null  # who dealt the last blow (veterancy)
var last_blow := ""             # the kind of the last blow (BLOW_*, "" area): a dying rider's horse may bolt
var off_field := false             # a soldier being bandaged: off the field for a moment
var cross_t := 0.0              # just bandaged: can't be bandaged again yet
var acid_t := 0.0               # Spitter acid: burns and strips 2 armour while > 0
var _mat: ShaderMaterial


func is_unit() -> bool:
	return false


func is_building() -> bool:
	return false


func is_air() -> bool:
	return false


## Missionaries can't be hurt away from enemy buildings.
func untouchable() -> bool:
	# a Missionary is untouchable only near one of his side's Churches (Defs.MISSIONARY_SAFE tiles; the owner,
	# 2026-10-31: one strolled untouched through a Brood base, which has no buildings), and never by enemy buildings
	return off_field or ((kind == "missionary" or kind == "mounted_missionary") and game.near_own_kind(team, global_position, "church", Defs.MISSIONARY_SAFE)
		and not game.near_enemy_building(team, global_position, Defs.MISSIONARY_DANGER))


func alive() -> bool:
	return not dead and is_inside_tree()


## Footprint for buildings; a small box for units.
func rect() -> Rect2:
	return Rect2(global_position - Vector2(8, 8), Vector2(16, 16))


## Distance from a point to this entity's edge.
func edge_distance(p: Vector2) -> float:
	var r := rect()
	var c := p.clamp(r.position, r.end)
	return c.distance_to(p)


func center() -> Vector2:
	return rect().get_center()


func team_material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = TEAM_SHADER
		_mat.set_shader_parameter("team", cloth_colour())
	return _mat


## The colour its team's reds are painted in: its side's, a loose horse's plain brown
## (nobody's), else as painted.
func cloth_colour() -> Color:
	if team >= 0:
		return game.team_colour(team)
	return Defs.NEUTRAL_CLOTH if kind == "horse" else Color.RED


## Kinds of blow (`take_damage`'s `blow`), for what a dying rider's horse does (Defs.HORSES
## bolt_*): a single shot landing on one target at range, a single blow in melee (Crown or
## Clockwork), the Brood's jaws and claws, or "" for anything with splash or area (round
## shot, canister, shells, blasts, chain lightning, clouds, spells) and unknown sources.
const BLOW_RANGED := "ranged"
const BLOW_MELEE := "melee"
const BLOW_BROOD := "brood"


## `blow`: what kind of blow it is (BLOW_*; "" = area or unknown).
func take_damage(amount: float, _from: Entity, blow := "") -> void:
	if dead or untouchable():
		return
	last_blow = blow
	var arm := armor - (2.0 if acid_t > 0.0 else 0.0)
	# a hit always does at least 1, but damage over time (storm, gas clouds: tiny amounts
	# every tick) is applied as it is, or the 1-point floor turns it into 30 a second
	var dmg := minf(hp, maxf(1.0, amount - maxf(arm, 0.0)) if amount >= 1.0 else amount)
	hp -= dmg
	if _from and is_instance_valid(_from) and game.hostile(_from.team, team):
		last_hit_by = _from.kind
		last_hit_team = _from.team
		last_hitter = _from
		hit_clock = game.clock
		game.stats[_from.team]["damage"] += dmg
		if team == game.human or (team >= 0 and team != game.human and game.allied(team, game.human)):
			game.under_attack(self)          # (an ally's too: "Our allies are under attack!")
		if Music.me and (team == game.human or _from.team == game.human):
			Music.me.add_heat(0.6 if is_unit() else 0.4)
	flash = 0.12
	if hp <= 0.0:
		hp = 0.0
		# friendly fire (round shot, shells, blasts on one's own men): counted on the
		# shooter's card for interest; it never counts toward veterancy
		if self is Unit and _from is Unit and _from != self and is_instance_valid(_from) and game.allied(_from.team, team):
			_from.friendly_kills += 1
		die()


func die() -> void:
	dead = true


func _process_acid(delta: float) -> void:
	if acid_t > 0.0 and not dead:
		acid_t -= delta
		hp -= 2.5 * delta
		if hp <= 0.0:
			hp = 0.0
			die()


func faction() -> String:
	return game.faction_of(team) if team >= 0 else ""


func _process_flash(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(flash - delta, 0.0)
		if _mat:
			_mat.set_shader_parameter("flash", 0.7 if flash > 0.0 else 0.0)


## THE BARS, StarCraft 2 style (the owner's playtest, 2026-10-31: "too cluttered... smaller, all the bars thinner... boxes
## that show how much health a unit has"; docs/bars_ghost_sil.md): the health bar is BAR_H px (a building's BAR_H_BIG)
## with a 1 px dark outline, cut into boxes of hp_box() health by thin dark gaps; the secondary bars (reload, charge,
## powder) are SUB_H px, flush under it (draw_sub_bar), never more than two.
const BAR_H := 3.0
const BAR_H_BIG := 4.0            # (a bar wider than BAR_BIG_W: buildings)
const BAR_BIG_W := 60.0
const SUB_H := 2.0
const BAR_EDGE := Color(0.0, 0.0, 0.0, 0.8)


## Health in one box of the bar: 25 up to 300 max health, 50 to 800, 100 to 2,000, 250 above; doubled until a box is at
## least 3 px wide on a bar `w` px wide, so the boxes stay readable.
static func hp_box(mhp: float, w: float) -> float:
	var box := 25.0 if mhp <= 300.0 else (50.0 if mhp <= 800.0 else (100.0 if mhp <= 2000.0 else 250.0))
	while mhp > 0.0 and w * box / mhp < 3.0:
		box *= 2.0
	return box


## Is the health bar drawn now? Hurt, or always (Settings HEALTH BARS: ALL BARS). A full bar is not drawn, selected or
## not (the owner, 2026-10-31: "any bar that is full should disappear, to avoid clutter").
func health_bar_shown() -> bool:
	return hp < max_hp or Settings.health_bars == 1


## The health bar (when health_bar_shown); `always` is kept for the callers (unused). Returns where the secondary bars
## go: flush under the drawn bar, or `top` itself when no bar was drawn.
func draw_health(top: float, width: float, always := false) -> float:
	if not health_bar_shown():
		return top
	var w := width
	var h := BAR_H_BIG if w > BAR_BIG_W else BAR_H
	var r := Rect2(-w * 0.5, top, w, h)
	draw_rect(r.grow(1), BAR_EDGE)
	var f := clampf(hp / max_hp, 0.0, 1.0)
	var col := Color(0.3, 0.9, 0.3) if f > 0.5 else (Color(0.95, 0.8, 0.2) if f > 0.25 else Color(0.95, 0.3, 0.2))
	draw_rect(Rect2(r.position, Vector2(w * f, h)), col)
	# the boxes: a thin dark gap every hp_box() health
	var box := hp_box(max_hp, w)
	var n := int(ceil(max_hp / box))
	if n > 1:
		var pts := PackedVector2Array()
		for k in range(1, n):
			var x := -w * 0.5 + w * float(k) * box / max_hp
			pts.append(Vector2(x, top))
			pts.append(Vector2(x, top + h))
		draw_multiline(pts, BAR_EDGE, 1.0)
	if acid_t > 0.0:
		# (above the bar: under it units show their reload)
		draw_rect(Rect2(r.position + Vector2(0, -3), Vector2(w, 2)), Color(0.75, 0.95, 0.2))
	return top + h + 1.0


## A thin secondary bar (reload, charge, powder) at y, `w` wide, filled to f: SUB_H px with a 1 px outline that it shares
## with the bar above it. Returns the y for the next one.
func draw_sub_bar(y: float, w: float, f: float, col: Color) -> float:
	var r := Rect2(-w * 0.5, y, w, SUB_H)
	draw_rect(r.grow(1), BAR_EDGE)
	draw_rect(Rect2(r.position, Vector2(w * clampf(f, 0.0, 1.0), SUB_H)), col)
	return y + SUB_H + 1.0
