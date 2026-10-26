#!/bin/bash
# Re-aggregate the finished games into docs/study_data (CSVs, tables.json, figures), write STATUS.json and render the
# report (docs/ai_balance_study.md):
#   tools/study/stage.sh [runs-dir] [stage label]
set -e
RUNS=${1:-/home/claude/study_runs}
STAGE=${2:-}
python3 tools/study/aggregate.py --runs "$RUNS" --out docs/study_data
python3 tools/study/analysis.py --data docs/study_data --out docs/study_data/tables.json
python3 tools/study/examples.py --data docs/study_data --out docs/study_data/tables.json
python3 tools/study/deepdive.py --data docs/study_data --out docs/study_data/tables.json
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
DIAG=""
[ -f docs/study_data/diag/diag.json ] && DIAG="--diag docs/study_data/diag/diag.json"
python3 tools/study/report.py --data docs/study_data --out docs/ai_balance_study.md --stage "$STAGE" $DIAG
