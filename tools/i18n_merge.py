#!/usr/bin/env python3
"""Author translations by number: python3 tools/i18n_merge.py list.tsv answers.tsv out.txt
list.tsv: "id<TAB>English" lines (from tools/i18n_scan.py --number); answers.tsv: "id<TAB>pt<TAB>es".
Writes the canonical tools/i18n entry file (English keys are stripped of edge spaces)."""
import sys
lst = {}
for l in open(sys.argv[1], encoding="utf-8").read().split("\n"):
    if "\t" in l:
        i, en = l.split("\t", 1)
        lst[i] = en.split("\t#")[0]
out = []
for l in open(sys.argv[2], encoding="utf-8").read().split("\n"):
    if not l.strip() or l.startswith("#"):
        continue
    parts = [x.strip() for x in l.split(";;")]
    if len(parts) != 3 or not (parts[0] in lst or parts[0].startswith("=")):
        print("BAD ANSWER LINE:", l[:80]); continue
    en = (parts[0][1:] if parts[0].startswith("=") else lst[parts[0]]).strip().replace("\n", "\\n")
    # pieces that are joined onto a text with " · " or ": " are translated without that joint
    en = en.strip(" ·:")
    parts[1] = parts[1].strip(" ·:") if parts[1].strip(" ·:") else parts[1]
    parts[2] = parts[2].strip(" ·:") if parts[2].strip(" ·:") else parts[2]
    out.append("> %s\npt %s\nes %s\n" % (en, parts[1].strip(), parts[2].strip()))
open(sys.argv[3], "w", encoding="utf-8").write("\n".join(out))
print(len(out), "entries")
