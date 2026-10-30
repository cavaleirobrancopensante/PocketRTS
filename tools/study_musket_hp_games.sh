#!/bin/bash
# The Musketeer health test's games (docs/musket_hp_test.md): runs a list of runs, one a line:
#   <id> <tool script> <args...>          e.g.  m_brood_greenhold_1_now study_musket_hp_match.gd foe:brood map:greenhold seed:1 secs:900 hpv:now
# JOBS at a time (default 2); each run's console goes to <outdir>/<id>.log (a run with a log ending in RESULT/ALL PASS/FAILED is skipped):
#   tools/study_musket_hp_games.sh <outdir> <listfile>
cd "$(dirname "$0")/.."
out="$1"; list="$2"
mkdir -p "$out"
grep -v '^#' "$list" | grep -v '^$' | while read -r id rest; do
	if [ -f "$out/$id.log" ] && grep -qE '^(RESULT|ALL PASS|[0-9]+ FAILED)' "$out/$id.log"; then continue; fi
	echo "$id $rest"
done | xargs -P "${JOBS:-2}" -L 1 sh -c 'id="$0"; s="$1"; shift; timeout "${TIMEOUT:-2400}" godot --headless --fixed-fps 30 \
	--script "res://tools/$s" -- "$@" > "'"$out"'/$id.log" 2>&1 || true'
