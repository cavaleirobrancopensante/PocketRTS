#!/bin/bash
# Balance study v2 (docs/study_v2.md): one machine's whole share, start to finish.
#   tools/study/machine_v2.sh m1|m2|m3|m4 [runs-dir] [games]
# m1 = Crown v Brood, m2 = Crown v Clockwork, m3 = Brood v Clockwork (100 games each, documented openings),
# m4 = 100 exploratory games. Resumable: run it again after a stop and it carries on. touch <runs-dir>/STOP to stop
# after the games under way. Needs GODOT=/path/to/Godot_v4.7-stable_linux.x86_64 (or godot on the PATH), and the project
# imported once (godot --headless --import). When it ends it aggregates into docs/study_v2/data/<machine>/.
set -e
cd "$(dirname "$0")/../.."
M=${1:?machine: m1, m2, m3 or m4}
RUNS=${2:-$HOME/study_v2_runs/$M}
GAMES=${3:-100}
mkdir -p "$RUNS"
case "$M" in
  m1) python3 tools/study/run_study_v2.py --mode openings --pair crown,brood --games "$GAMES" --out "$RUNS" ;;
  m2) python3 tools/study/run_study_v2.py --mode openings --pair crown,clockwork --games "$GAMES" --out "$RUNS" ;;
  m3) python3 tools/study/run_study_v2.py --mode openings --pair brood,clockwork --games "$GAMES" --out "$RUNS" ;;
  m4) python3 tools/study/run_study_v2.py --mode explore --games "$GAMES" --out "$RUNS" ;;
  *) echo "unknown machine $M (m1, m2, m3 or m4)"; exit 2 ;;
esac
python3 tools/study/report_v2.py aggregate --runs "$RUNS" --machine "$M"
echo "data in docs/study_v2/data/$M"
