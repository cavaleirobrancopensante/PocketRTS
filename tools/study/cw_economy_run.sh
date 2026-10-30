#!/bin/bash
# The Clockwork v Crown economy study's matches (docs/cw_economy_study.md): every job of the list below, P at a time,
# each through tools/measure_economy.gd; the minute lines go to OUT/<tag>.log, the RESULT lines to OUT/results.jsonl.
#   tools/study/cw_economy_run.sh OUT [P] [maps] [seeds]
# Jobs per map and seed:
#   cw_idle_ms0/1/2   the Hard Clockwork (peaceful) against an idle Crown, Mainsprings: no cap (today) / 1 / 2 per Clocktower
#   cr_idle           the Hard Crown (peaceful) against an idle Clockwork
#   hvh_ms0/1         the Hard Crown against the Hard Clockwork (fighting), Mainsprings: no cap / 1 per Clocktower
cd "$(dirname "$0")/../.."
OUT=${1:-/tmp/cw_economy}
P=${2:-2}
MAPS=${3:-"greenhold highmoor dune_sea"}
SEEDS=${4:-"1 2"}
SECS=${SECS:-900}
mkdir -p "$OUT"
jobs=()
for m in $MAPS; do
	for s in $SEEDS; do
		for ms in 0 1 2; do
			jobs+=("tag:cw_idle_ms${ms}_${m}_${s} map:$m seed:$s a:clockwork b:crown wa:hard wb:idle ms:$ms secs:$SECS")
		done
		jobs+=("tag:cr_idle_${m}_${s} map:$m seed:$s a:crown b:clockwork wa:hard wb:idle secs:$SECS")
		for ms in 0 1; do
			jobs+=("tag:hvh_ms${ms}_${m}_${s} map:$m seed:$s a:crown b:clockwork wa:hard wb:hard ms:$ms secs:$SECS")
		done
	done
done
run_one() {
	local tag
	tag=$(echo "$1" | sed 's/.*tag:\([^ ]*\).*/\1/')
	[ -s "$OUT/$tag.log" ] && grep -q '^RESULT' "$OUT/$tag.log" && return 0
	# shellcheck disable=SC2086
	timeout 2400 godot --headless --fixed-fps 30 --script res://tools/measure_economy.gd -- $1 2>&1 | grep -E '^ ?[0-9]+:00 t|^RESULT|SCRIPT ERROR|ERROR:' > "$OUT/$tag.log"
	echo "done $tag $(date +%H:%M:%S)"
}
export -f run_one
export OUT
# ONLY: a regular expression the job's tag must match (e.g. ONLY='cw_idle_ms[01]|cr_idle' leaves out the fights)
printf '%s\n' "${jobs[@]}" | grep -E "tag:(${ONLY:-.*})_" | xargs -P "$P" -I{} bash -c 'run_one "$@"' _ {}
cat "$OUT"/*.log | grep '^RESULT' | sed 's/^RESULT //' > "$OUT/results.jsonl"
echo "all done: $(wc -l < "$OUT/results.jsonl") results"
