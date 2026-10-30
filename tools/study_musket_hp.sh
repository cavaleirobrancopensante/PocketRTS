#!/bin/bash
# The Musketeer health test (docs/musket_hp_test.md): runs groups of tools/study_musket_hp.gd, each config in its own
# process (JOBS at a time, default 2; each killed after TIMEOUT s, default 900), a file <outdir>/<group>/<config>.jsonl:
#   tools/study_musket_hp.sh <outdir> <seeds> <group>...
# HPV=55/65,60/80 tests more variants (each config name ends with its health). Running it again re-runs only the configs with fewer than <seeds> lines. Then:
#   python3 tools/study/musket_hp_table.py <outdir>
cd "$(dirname "$0")/.."
out="$1"; shift
seeds="$1"; shift
mkdir -p "$out"
for g in "$@"; do
	mkdir -p "$out/$g"
	godot --headless --script res://tools/study_musket_hp.gd -- group:$g hpv:${HPV:-55/65} list 2>/dev/null | grep '^CFG ' | cut -d' ' -f2 \
		| while read -r c; do
			f="$out/$g/$c.jsonl"
			if [ ! -f "$f" ] || [ "$(grep -c '^{' "$f")" -lt "$seeds" ]; then echo "$c"; fi
		done > "$out/$g.todo"
	xargs -P "${JOBS:-2}" -I{} sh -c 'timeout "$0" godot --headless --fixed-fps 30 \
		--script res://tools/study_musket_hp.gd -- only:"$1" seeds:"$2" out:"$3/$1.jsonl" hpv:"$4" || true' \
		"${TIMEOUT:-900}" {} "$seeds" "$out/$g" "${HPV:-55/65}" < "$out/$g.todo" > /dev/null 2>&1
done
