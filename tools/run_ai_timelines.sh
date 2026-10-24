#!/bin/bash
# Measures every faction and plan (two at a time) and prints the TL lines:
#   tools/run_ai_timelines.sh [map] [seed]
cd "$(dirname "$0")/.."
MAP=${1:-ashford_crossing}; SEED=${2:-4242}
run() { timeout 280 /home/claude/godot/godot --headless --fixed-fps 30 --script res://tools/measure_ai_timelines.gd -- faction:$1 plan:$2 map:$MAP seed:$SEED 2>&1 | grep "^TL"; }
JOBS=("crown balanced" "crown economy" "crown rush" "crown timing" "brood balanced" "brood economy" "brood rush" "brood timing" "brood air" "brood xrush" "clockwork balanced" "clockwork economy" "clockwork rush" "clockwork timing")
i=0
for j in "${JOBS[@]}"; do
  run $j &
  i=$((i+1)); if [ $((i%2)) -eq 0 ]; then wait; fi
done
wait
