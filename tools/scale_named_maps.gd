extends SceneTree
## One-off helper of the map enlargement (0.15.0, docs/map_sizes.md): prints MapData.NAMED with every map grown by
## its factor (FACTOR, or DEFAULT) as GDScript, to paste into scripts/map_data.gd and then hand-tune the base sites.
## Positions scale with the map; widths do not (ramps, rivers, treelines, fords stay as wide); a main keeps its
## plateau (moved with the hill's middle), its ramp and natural keep their place relative to it; lakes and
## mesas grow a little, forests with the map, random woods with the area.
##   godot --headless --script res://tools/scale_named_maps.gd > /abs/out.txt

const DEFAULT := 1.31
const FACTOR := {"ashford_crossing": 1.2, "thornwood_maze": 1.16, "saltmarsh_isles": 1.15, "frostmere": 1.15,
	"hollowfen": 1.15, "amberfall_vale": 1.21}
var fx := 1.0
var fy := 1.0


func _initialize() -> void:
	var out := ""
	for id in MapData.NAMED:
		out += _map(id, MapData.NAMED[id])
	print(out)
	quit(0)


func _n(v: float) -> String:
	var r := snappedf(v, 0.5)
	if is_equal_approx(r, roundf(r)):
		return str(int(roundf(r)))
	return str(r)


func _p(p: Array) -> Array:
	return [float(p[0]) * fx, float(p[1]) * fy]


func _ps(a: Array) -> String:
	return "[%s, %s]" % [_n(a[0]), _n(a[1])]


func _line(pts: Array) -> String:
	var s: Array = []
	for p in pts:
		s.append(_ps(_p(p)))
	return "[" + ", ".join(s) + "]"


func _map(id: String, m: Dictionary) -> String:
	var f: float = FACTOR.get(id, DEFAULT)
	var sz: Array = m["size"]
	var w := int(roundf(float(sz[0]) * f / 2.0)) * 2
	var h := int(roundf(float(sz[1]) * f / 2.0)) * 2
	fx = float(w) / float(sz[0])
	fy = float(h) / float(sz[1])
	var head := "\t\"%s\": {\"name\": \"%s\", \"size\": [%d, %d], \"mode\": \"%s\", \"biome\": \"%s\"" % [id, m["name"], w, h, m["mode"], m["biome"]]
	for k in ["mix", "water", "ford"]:
		if m.has(k):
			head += ", \"%s\": \"%s\"" % [k, m[k]]
	head += ", \"seed\": %d,\n" % int(m["seed"])
	var s := head + "\t\t\"about\": \"%s\",\n" % m["about"]
	var bases: Array = []
	for b in m["bases"]:
		var hill: Array = b["hill"]
		var nc := _p([hill[0], hill[1]])
		var d := Vector2(nc[0] - float(hill[0]), nc[1] - float(hill[1]))
		var mv := func(p: Array) -> String:
			return _ps([roundf(float(p[0]) + d.x), roundf(float(p[1]) + d.y)])
		bases.append("{\"hall\": %s, \"hill\": [%s, %s, %s, %s], \"ramp\": %s, \"nat\": %s}" % [mv.call(b["hall"]), _n(nc[0]), _n(nc[1]),
			_n(float(hill[2]) + 1.0), _n(float(hill[3]) + 1.0), mv.call(b["ramp"]), mv.call(b["nat"])])
	s += "\t\t\"bases\": [" + ",\n\t\t\t".join(bases) + "],\n"
	var th: Array = []
	for t in m.get("thirds", []):
		var tp := _p(t)
		th.append(_ps([roundf(tp[0]), roundf(tp[1])]))
	s += "\t\t\"thirds\": [" + ", ".join(th) + "],\n"
	s += "\t\t\"pieces\": [\n"
	for pc in m.get("pieces", []):
		s += "\t\t\t" + _piece(pc) + ",\n"
	s += "\t\t],\n"
	var sites: Array = []
	for st in m.get("sites", []):
		var p := _p(st)
		sites.append("[%s, %s, \"%s\"]" % [_n(p[0]), _n(p[1]), st[2]])
	s += "\t\t\"woods\": %d, \"sites\": [%s]" % [int(roundf(float(m.get("woods", 0)) * fx * fy)), ", ".join(sites)]
	if m.has("decor"):
		s += ", \"decor\": %s" % str(m["decor"])
	s += "},\n"
	return s


func _piece(f: Array) -> String:
	var k: String = f[0]
	var g := (fx + fy) * 0.5
	match k:
		"hill":
			var c := _p([f[1], f[2]])
			var rs: Array = []
			for r in f[5]:
				rs.append(_ps([c[0] + float(r[0]) - float(f[1]), c[1] + float(r[1]) - float(f[2])]))
			return "[\"hill\", %s, %s, %s, %s, [%s]]" % [_n(c[0]), _n(c[1]), _n(float(f[3]) * 1.1), _n(float(f[4]) * 1.1), ", ".join(rs)]
		"mesa":
			var c := _p([f[1], f[2]])
			return "[\"mesa\", %s, %s, %s, %s]" % [_n(c[0]), _n(c[1]), _n(float(f[3]) * 1.15), _n(float(f[4]) * 1.15)]
		"ridge":
			return "[\"ridge\", %s, %s]" % [_line(f[1]), _n(f[2])]
		"lake":
			var c := _p([f[1], f[2]])
			return "[\"lake\", %s, %s, %s, %s]" % [_n(c[0]), _n(c[1]), _n(float(f[3]) * 1.15), _n(float(f[4]) * 1.15)]
		"river":
			return "[\"river\", %s, %s, %s, %s]" % [_line(f[1]), _n(f[2]), str(f[3]), _n(f[4])]
		"forest", "rocks":
			var c := _p([f[1], f[2]])
			return "[\"%s\", %s, %s, %s, %s, %s]" % [k, _n(c[0]), _n(c[1]), _n(float(f[3]) * g), _n(float(f[4]) * g), str(f[5])]
		"treeline":
			var s := "[\"treeline\", %s, %s, %s, %s" % [_line(f[1]), _n(f[2]), str(f[3]), _n(f[4])]
			if f.size() > 5:
				s += ", \"%s\"" % f[5]
			return s + "]"
		"clear":
			var c := _p([f[1], f[2]])
			return "[\"clear\", %s, %s, %s]" % [_n(c[0]), _n(c[1]), _n(f[3])]
	return str(f)
