#!/bin/bash
# Runs every scenario of tools/stress_swarm.gd and prints a table (docs/swarm_perf.md).
#   tools/stress_swarm.sh <outdir> [render] [mobile] [secs:30] [scenarios...]
# render: xvfb-run with the OpenGL renderer at 1600x900 (on a machine without a graphics card that is
# llvmpipe, a software renderer). Each run's numbers go to <outdir>/<scenario>[_render][_mobile].json.
set -u
OUT=${1:?outdir}; shift
mkdir -p "$OUT"
RENDER=0; MOBILE=""; SECS="secs:30"; SCENS=()
for a in "$@"; do
	case $a in
		render) RENDER=1;;
		mobile) MOBILE=mobile;;
		secs:*) SECS=$a;;
		*) SCENS+=("$a");;
	esac
done
[ ${#SCENS[@]} -eq 0 ] && SCENS=(idle walk melee offmelee grubs muskets)
cd "$(dirname "$0")/.."
for s in "${SCENS[@]}"; do
	tag=$s
	[ $RENDER = 1 ] && tag=${tag}_render
	[ -n "$MOBILE" ] && tag=${tag}_mobile
	if [ $RENDER = 1 ]; then
		timeout 1800 xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 60 \
			--script res://tools/stress_swarm.gd -- $s $SECS $MOBILE out:"$OUT/$tag.json" shot:"$OUT/$tag.png" 2>&1 | grep -E "^SWARM|SCRIPT ERROR" | head -c 20000
	else
		timeout 1800 godot --headless --path . --fixed-fps 60 \
			--script res://tools/stress_swarm.gd -- $s $SECS $MOBILE out:"$OUT/$tag.json" 2>&1 | grep -E "^SWARM|SCRIPT ERROR" | head -c 20000
	fi
done
python3 - "$OUT" <<'EOF'
import json, sys, glob, os
rows = []
for f in sorted(glob.glob(sys.argv[1] + "/*.json")):
	r = json.load(open(f))
	rows.append((os.path.basename(f)[:-5], r))
print("| run | fps avg | median ms | 1% low fps | worst ms | >16.7ms | >33ms | sim ms/tick | units ms/tick | unit draw ms/frame | hud draw ms/frame | render cpu ms | cpu s |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for name, r in rows:
	print("| %s | %.1f | %.2f | %.1f | %.1f | %d | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.1f |" % (name, r["fps"], r["median_ms"], r["low1_fps"], r["worst_ms"],
		r["over16"], r["over33"], r["sim_ms_per_tick"], r["ms/tick units"], r["ms/frame unit draw"], r["ms/frame hud draw"], r["render_cpu_ms"], r["cpu_s"]))
EOF
