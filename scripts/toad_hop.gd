class_name ToadHop
extends RefCounted
## The Mist Toad HOPS instead of walking (the owner, 2026-10-29). Its walk_<dir> strips are one hop each
## (tools/import_toad_hop.py, from the owner's ChatGPT sheets art/redraws/mist_toad_hop_<dir>_chatgpt.png):
##   0 crouched   1 pushing off   2 stretched in the air   3 top of the hop   4 coming down   5 landed (a small splash)
## the airborne frames drawn high over the anchor (the ground point), so the lift is in the art.
##
## The frames follow the GROUND COVERED, not the clock (like the Labourer's stride, Unit.LAB_STRIDE): one hop per HOP px
## walked, whatever its speed (42 px/s: a hop every 0.76 s; faster on swamp or slowed, the hop keeps its length).
## The unit itself glides at an even speed (the simulation is untouched), so its feet would slide while it sits crouched
## or landed. The SPRITE is shifted along the way it goes instead (sprite.position, drawing only): it holds still on the
## ground frames (5, 0, 1) and covers the whole hop in the air (2, 3, 4). The shift averages zero over a hop and stays
## within +-0.24 HOP (+-8 px); its shadow and selection ring go with it (Unit._draw). Stopping, it eases back to the
## unit's spot.

## px walked per hop
const HOP := 32.0
## each frame's share of the hop (sums to 1)
const SHARE := [0.16, 0.14, 0.18, 0.16, 0.18, 0.18]
## the airborne part of the hop: from the end of the push-off to the end of coming down
const AIR_FROM := 0.30
const AIR_TO := 0.82
## the health bar's top over the anchor: the crouched toad's (its cell grew 25 px for the hop)
const BAR_TOP := 58.0


## Every physics tick (Unit._physics_process): counts the ground unit u covered while it hops, picks the frame and shifts
## its sprite. Both are set every tick, not on the 15 Hz animation tick: between those the unit glides on and a planted toad would
## jitter a pixel back and forth.
static func track(u: Unit, delta: float) -> void:
	if u.anim == "walk" and not u.dead:
		if not u._hop_on:
			u._hop_on = true
			u._hop_d = 0.0          # (a new hop starts from the crouch)
			u._hop_prev = u.position
		var moved := u.position.distance_to(u._hop_prev)
		if moved < 40.0:            # (a jump, e.g. a tongue pull, is not a hop)
			u._hop_d += moved
		if u.velocity.length() > 5.0:
			u._hop_way = u.velocity.normalized()
		u._hop_off = u._hop_way * lead(phase(u._hop_d))
		if u.sprite and u._an_n > 0:
			u.frame_i = frame(u, u._an_n)       # (the frame with the shift, not up to a 15 Hz tick behind it)
			u.sprite.frame = clampi(u.frame_i, 0, u.sprite.hframes - 1)
	else:
		u._hop_on = false
		u._hop_off = u._hop_off.move_toward(Vector2.ZERO, delta * 60.0)
	u._hop_prev = u.position
	if u.sprite:
		u.sprite.position = u._hop_off.round()


## The hop strip's frame for unit u (n frames) now.
static func frame(u: Unit, n: int) -> int:
	var p := phase(u._hop_d)
	if n != SHARE.size():
		return mini(int(p * n), n - 1)
	var acc := 0.0
	for i in SHARE.size():
		acc += float(SHARE[i])
		if p < acc:
			return i
	return n - 1


## Fraction of a hop done after d px walked.
static func phase(d: float) -> float:
	return fposmod(d, HOP) / HOP


## How far along its way the drawn toad is ahead of (+) or behind (-) the unit, `p` into a hop, in px.
static func lead(p: float) -> float:
	var shown := clampf((p - AIR_FROM) / (AIR_TO - AIR_FROM), 0.0, 1.0)
	return (shown - p - (0.5 - (AIR_FROM + AIR_TO) * 0.5)) * HOP


## A small number that changes when the drawn shadow should move (Unit's redraw key).
static func draw_key(u: Unit) -> int:
	var o := u._hop_off.round()
	return (int(o.x) + 16) + 33 * (int(o.y) + 16)
