#!/bin/bash
# Runs groups of the Raptor + Spitter study (tools/study_raptor_spitter.gd) one after another, a JSON-lines file each:
#   tools/study_raptor_spitter.sh <outdir> <seeds> <group>...
# then: python3 tools/study/raptor_spitter_table.py <outdir>/*.jsonl
# PER_CONFIG=1: each config of a group in its own process (JOBS at a time, default 2; each killed after TIMEOUT s,
# default 900), a file <outdir>/<group>/<config>.jsonl each: a run that stalls loses one row, and running the same
# command again re-runs only the rows with fewer than <seeds> lines.
cd "$(dirname "$0")/.."
out="$1"; shift
seeds="$1"; shift
mkdir -p "$out"
for g in "$@"; do
	if [ -n "$PER_CONFIG" ]; then
		mkdir -p "$out/$g"
		godot --headless --script res://tools/study_raptor_spitter.gd -- group:$g list 2>/dev/null | grep '^CFG ' | cut -d' ' -f2 \
			| while read -r c; do
				f="$out/$g/$c.jsonl"
				if [ ! -f "$f" ] || [ "$(grep -c '^{' "$f")" -lt "$seeds" ]; then echo "$c"; fi
			done > "$out/$g.todo"
		# (through sh -c ... || true: godot can exit 255 on the way out, and xargs stops at a 255)
		xargs -P "${JOBS:-2}" -I{} sh -c 'timeout "$0" godot --headless --fixed-fps 30 \
			--script res://tools/study_raptor_spitter.gd -- only:"$1" seeds:"$2" out:"$3/$1.jsonl" || true' \
			"${TIMEOUT:-900}" {} "$seeds" "$out/$g" < "$out/$g.todo" > /dev/null 2>&1
		continue
	fi
	godot --headless --fixed-fps 30 --script res://tools/study_raptor_spitter.gd -- group:$g seeds:$seeds out:"$out/$g.jsonl" 2>&1 \
		| grep -E "^(STUDY|field|[A-Z]+_)|SCRIPT ERROR" > "$out/$g.log"
done
