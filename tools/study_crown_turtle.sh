#!/bin/bash
# The Crown turtle study (docs/crown_turtle_study.md): each config in its own process, JOBS at a time.
#   tools/study_crown_turtle.sh OUT_DIR SEEDS G M H          (whole groups; the config names come from "list")
#   tools/study_crown_turtle.sh OUT_DIR SEEDS G_OB_x10_pull_p (single configs: any argument with an "_")
# A config whose .jsonl already holds SEEDS lines is skipped, so the same command resumes a cut run.
# GODOT (default: godot on the PATH), JOBS (2), TIMEOUT (seconds a config, 2400).
set -u
cd "$(dirname "$0")/.."
OUT="$1"; SEEDS="$2"; shift 2
GODOT="${GODOT:-godot}"
JOBS="${JOBS:-2}"
TIMEOUT="${TIMEOUT:-2400}"
mkdir -p "$OUT"
CFGS=()
for a in "$@"; do
  if [[ "$a" == *_* ]]; then
    CFGS+=("$a")
  else
    for at in CW OB NB; do
      while read -r line; do
        [[ "$line" == CFG* ]] && CFGS+=("${line#CFG }")
      done < <("$GODOT" --headless --script res://tools/study_crown_turtle.gd -- "only:${a}_${at}_list" list 2>/dev/null)
    done
  fi
done
run_one() {
  c="$1"
  f="$OUT/$c.jsonl"
  if [ -f "$f" ] && [ "$(wc -l < "$f")" -ge "$SEEDS" ]; then
    echo "skip $c"; return
  fi
  timeout "$TIMEOUT" "$GODOT" --headless --fixed-fps 30 --script res://tools/study_crown_turtle.gd -- "only:$c" "seeds:$SEEDS" "out:$f" > "$OUT/$c.log" 2>&1
  echo "done $c ($(wc -l < "$f" 2>/dev/null || echo 0) fights)"
}
export -f run_one
export OUT SEEDS GODOT TIMEOUT
printf '%s\n' "${CFGS[@]}" | sort -u | xargs -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {}
echo "ALL DONE"
