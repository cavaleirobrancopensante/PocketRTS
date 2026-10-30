#!/bin/sh
# The Armoury study and the Marching Band's fights (tools/study_armoury_band.gd; docs/armoury_study.md, docs/marching_band.md):
# every group against every enemy, each in its own Godot process, PAR at a time; the fights go to <out dir>/<group>_<enemy>.jsonl,
# then tools/study_armoury_band_report.py <out dir> prints the tables.
#   tools/study_armoury_band.sh <out dir> [seeds] [par]
cd "$(dirname "$0")/.."
OUT=${1:?out dir}
SEEDS=${2:-4}
PAR=${3:-4}
mkdir -p "$OUT"
for g in AR AG AC MB MD; do
	for e in raptor clock musk; do
		echo "$g $e"
	done
done | xargs -P "$PAR" -L 1 sh -c 'godot --headless --fixed-fps 30 --script res://tools/study_armoury_band.gd -- group:$0 enemy:$1 seeds:'"$SEEDS"' out:'"$OUT"'/$0_$1.jsonl > '"$OUT"'/$0_$1.log 2>&1; echo "done $0 $1"'
