class_name PowderKeg
extends Entity
## A POWDER KEG ON THE GROUND (the owner, 2026-10-29 08:06: kegs never go back into the stores). A hauler who cannot
## deliver his keg (the wagon destroyed, ordered away, his job cut short, his Town Hall gone) drops it where he stands,
## with what is left in it (Defs.WAGON "keg" musket shots when full). It is:
##  - A POWDER SUPPLY: its side's soldiers in reach refill from it as from a Powder Wagon (Unit._powder_tick, at the same
##    rate; a cannon shot takes 3 musket shots) until it is empty, then it is gone.
##  - A BOMB: enemies shoot it (Game.find_target, after everything that fights back; a click on it attacks it);
##    destroyed it blows up like a keg on a killed hauler's back (Defs.KEG blast and radius), scaled by the powder left.
##  - CARRIED ON: a free hauler of its side picks it up before fetching a new keg from the Mill (Game.haul_dispatch).
## Kept in saves (SaveGame "kegs") and online snapshots and replays (NetSnapshot "kg").

var powder := 0.0              # musket shots in it
var claimed: Unit = null       # the hauler on his way to pick it up
var sprite: Sprite2D
var _shown := -1.0


func setup(g: Game, t: int, p: Vector2, shots: float) -> void:
	game = g
	team = t
	kind = "powder_keg"
	position = p
	powder = shots
	max_hp = float(Defs.KEG["hp"])
	hp = max_hp
	armor = 0.0
	sight = 1


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = false
	var tex: Texture2D = Game.tex("res://assets/effects/keg.png")
	var at := AtlasTexture.new()
	at.atlas = tex
	var fs: Vector2i = ArtData.EFFECTS["keg"]["size"]
	at.region = Rect2(0, 0, fs.x, fs.y)       # (the first frame: the keg standing, as the haulers carry it)
	sprite.texture = at
	sprite.scale = Vector2(1.4, 1.4)
	sprite.offset = Vector2(-fs.x * 0.5, -fs.y + 2)
	add_child(sprite)
	z_index = 0


## The keg itself (a small barrel standing on its spot), for shots, clicks and reach.
func rect() -> Rect2:
	return Rect2(global_position - Vector2(9, 22), Vector2(18, 24))


func _physics_process(delta: float) -> void:
	_process_flash(delta)
	if dead:
		return
	if claimed and (not is_instance_valid(claimed) or claimed.dead or claimed.haul_job.get("pk") != self):
		claimed = null
	if powder < 0.5 and not game.puppet:
		remove()          # (drunk dry by the soldiers round it)
		return
	var key := hp * 1000.0 + powder
	if key != _shown:
		_shown = key
		queue_redraw()


func _draw() -> void:
	if dead:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	draw_health(-30.0, 18.0, true)


## Shot to pieces: it blows up, as a keg on a killed hauler's back, scaled by the powder left in it.
func die() -> void:
	if dead:
		return
	dead = true
	var f := clampf(powder / float(Defs.WAGON["keg"]), 0.0, 1.0)
	if not game.puppet and f > 0.0:
		game.powder_blast(self, global_position, float(Defs.KEG["blast"]) * maxf(f, 0.3), float(Defs.KEG["radius"]) * (0.6 + 0.4 * f))
	if game.mlog:
		game.mlog.add("%s's dropped powder keg blew up" % game.mlog.who(team))
	remove()


func remove() -> void:
	dead = true
	game.kegs.erase(self)
	queue_free()
