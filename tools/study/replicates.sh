#!/bin/bash
# Same seed and settings, N times: how much does the outcome vary from run to run? (one game at a time)
#   tools/study/replicates.sh OUT_DIR N a b map seed swap [pa pb]
OUT=$1; N=$2; A=$3; B=$4; MAP=$5; SEED=$6; SWAP=$7; PA=${8:-balanced}; PB=${9:-balanced}
cd "$(dirname "$0")/../.."
for i in $(seq 1 $N); do
  /home/claude/godot/godot --headless --fixed-fps 30 --script res://tools/study/study_game.gd -- a:$A b:$B pa:$PA pb:$PB map:$MAP seed:$SEED swap:$SWAP out:$OUT id:rep_${A}_${B}_${MAP}_$i end:1800 fast:1 gg:1 > /dev/null 2>&1
done
