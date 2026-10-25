#!/usr/bin/env python3
"""List the English string literals of GDScript files that look like player-facing text
(for writing translations): python3 tools/i18n_scan.py scripts/ui/hud.gd ...
With --missing it lists only those that have no entry in tools/i18n/*.txt yet."""
import glob, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SKIP_LINE = re.compile(r'^\s*#|print\(|printerr|push_warning|push_error|mlog\.add|mlog\.log|Prof\.add|preload\(|\bload\(|assert\(|ResourceLoader|FileAccess|DirAccess|class_name|add_theme_|JavaScriptBridge|begins_with|ends_with|\.contains\(|Sfx\.play')
LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')


def known():
    ks = set()
    for path in glob.glob(os.path.join(HERE, "i18n", "*.txt")):
        for line in open(path, encoding="utf-8"):
            if line.startswith("> "):
                ks.add(line[2:].rstrip("\n"))
    return ks


def candidates(path):
    out = []
    in_doc = False
    for n, line in enumerate(open(path, encoding="utf-8").read().split("\n"), 1):
        if SKIP_LINE.search(line):
            continue
        for m in LIT.finditer(line):
            s = m.group(1)
            if not re.search(r"[A-Za-z]{3,}", s):
                continue
            if re.fullmatch(r"[a-z0-9_./:#\-\+]+", s) and " " not in s:
                continue          # identifiers, paths, keys
            if s.startswith(("res://", "user://", "#")) or re.fullmatch(r"[a-z_]+\.[a-z]+", s):
                continue
            out.append((n, s.replace('\\"', '"')))
    return out


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    miss = "--missing" in sys.argv
    ks = known() if miss else set()
    seen = set()
    for p in args:
        for n, s in candidates(p):
            if s in ks or s in seen:
                continue
            seen.add(s)
            print("%s:%d\t%s" % (os.path.basename(p), n, s))
