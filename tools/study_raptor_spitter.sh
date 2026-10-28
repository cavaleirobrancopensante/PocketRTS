#!/bin/bash
# Runs groups of the Raptor + Spitter study (tools/study_raptor_spitter.gd) one after another, a JSON-lines file each:
#   tools/study_raptor_spitter.sh <outdir> <seeds> <group>...
# then: python3 tools/study/raptor_spitter_table.py <outdir>/*.jsonl
cd "$(dirname "$0")/.."
out="$1"; shift
seeds="$1"; shift
mkdir -p "$out"
for g in "$@"; do
	godot --headless --fixed-fps 30 --script res://tools/study_raptor_spitter.gd -- group:$g seeds:$seeds out:"$out/$g.jsonl" 2>&1 \
		| grep -E "^(STUDY|field|[A-Z]_)|SCRIPT ERROR" > "$out/$g.log"
done
