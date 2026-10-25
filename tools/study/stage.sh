#!/bin/bash
# Re-aggregate the finished games into docs/study_data (CSVs, tables.json, figures) and write STATUS.json:
#   tools/study/stage.sh [runs-dir]
set -e
RUNS=${1:-/home/claude/study_runs}
python3 tools/study/aggregate.py --runs "$RUNS" --out docs/study_data
python3 tools/study/analysis.py --data docs/study_data --out docs/study_data/tables.json
python3 tools/study/examples.py --data docs/study_data --out docs/study_data/tables.json
python3 - <<PY
import json, glob, collections, time
c = collections.Counter()
for p in glob.glob("$RUNS/games/*.json"):
    c[json.load(open(p))["id"].rsplit("_", 1)[0]] += 1
fails = 0
try:
    fails = sum(1 for _ in open("$RUNS/failures.jsonl"))
except OSError:
    pass
json.dump({"games_done": sum(c.values()), "per_matchup": dict(c), "failure_records": fails, "updated": time.strftime("%Y-%m-%d %H:%M:%S")}, open("docs/study_data/STATUS.json", "w"), indent=1)
PY
