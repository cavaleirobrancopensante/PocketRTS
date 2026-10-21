class_name Entity
extends Node2D
## Anything on the map: units, buildings and deposits (rock outcrops).

const TEAM_SHADER := preload("res://shaders/team.gdshader")

var game: Game
var team := -1
var kind := ""
var hp := 1.0
var max_hp := 1.0
var armor := 0.0
var sight := 7
var dead := false
var selected := false
var seen_by_human := false     # enemy buildings stay on screen once spotted
var flash := 0.0
var last_hit_by := ""           # kind that last hurt us, for battle stats
var last_hit_team := -1
var last_hitter: Entity = null  # who dealt the last blow (veterancy)
var off_field := false             # a soldier being bandaged: off the field for a moment
var cross_t := 0.0              # just bandaged: can't be bandaged again yet
var acid_t := 0.0               # Spitter acid: burns and strips 2 armour while > 0
var _mat: ShaderMaterial


func is_unit() -> bool:
	return false


func is_building() -> bool:
	return false


func is_deposit() -> bool:
	return false


func is_air() -> bool:
	return false


## Missionaries can't be hurt away from enemy buildings.
func untouchable() -> bool:
	return off_field or (kind == "missionary" and not game.near_enemy_building(team, global_position, Defs.MISSIONARY_DANGER))


func alive() -> bool:
	return not dead and is_inside_tree()


## Footprint for buildings and deposits; a small box for units.
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
		_mat.set_shader_parameter("team", game.team_colour(team) if team >= 0 else Color.RED)
	return _mat


func take_damage(amount: float, _from: Entity) -> void:
	if dead or untouchable():
		return
	var arm := armor - (2.0 if acid_t > 0.0 else 0.0)
	# a hit always does at least 1, but damage over time (storm, gas clouds: tiny amounts
	# every tick) is applied as it is, or the 1-point floor turns it into 30 a second
	var dmg := minf(hp, maxf(1.0, amount - maxf(arm, 0.0)) if amount >= 1.0 else amount)
	hp -= dmg
	if _from and is_instance_valid(_from) and game.hostile(_from.team, team):
		last_hit_by = _from.kind
		last_hit_team = _from.team
		last_hitter = _from
		game.stats[_from.team]["damage"] += dmg
		if team == game.human:
			game.under_attack(self)
		if Music.me and (team == game.human or _from.team == game.human):
			Music.me.add_heat(0.6 if is_unit() else 0.4)
	flash = 0.12
	if hp <= 0.0:
		hp = 0.0
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


## always: units show theirs all the time; buildings only when hurt or selected.
func draw_health(top: float, width: float, always := false) -> void:
	if hp >= max_hp and not selected and not always:
		return
	var w := width
	var r := Rect2(-w * 0.5, top, w, 4)
	draw_rect(r.grow(1), Color(0, 0, 0, 0.7))
	var f := hp / max_hp
	var col := Color(0.3, 0.9, 0.3) if f > 0.5 else (Color(0.95, 0.8, 0.2) if f > 0.25 else Color(0.95, 0.3, 0.2))
	draw_rect(Rect2(r.position, Vector2(w * f, 4)), col)
	if acid_t > 0.0:
		# (above the bar: under it units show their reload)
		draw_rect(Rect2(r.position + Vector2(0, -3), Vector2(w, 2)), Color(0.75, 0.95, 0.2))
