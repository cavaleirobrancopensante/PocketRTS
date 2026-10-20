"""Quick QA of generated audio: duration, peak, RMS, leading silence, clipping, length limits.

    python3 tools/audio/analyze.py [dir ...]     (default: assets/audio assets/voice)
Only files in sub-folders (the legacy flat assets/audio/*.wav are skipped). Prints one line per file and a list of outliers at the end."""
import glob
import os
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def limit_for(rel):
    if rel.startswith("audio/ui/"):
        return 1.6 if "start_match" in rel else 0.5
    if rel.startswith("audio/combat/"):
        return 2.0 if "missionary_heal" in rel else 1.5
    if rel.startswith("voice/"):
        return 2.5
    if rel.startswith("audio/ambience/"):
        return 31
    return 2.6


def main(dirs):
    rows, bad = [], []
    for d in dirs:
        for f in sorted(glob.glob(os.path.join(ROOT, d, "*", "**", "*.*"), recursive=True)):
            if not f.endswith((".wav", ".ogg")):
                continue
            x, sr = sf.read(f, always_2d=True)
            x = x.mean(axis=1)
            rel = os.path.relpath(f, os.path.join(ROOT, "assets"))
            dur = len(x) / sr
            pk = np.max(np.abs(x)) + 1e-12
            rms = np.sqrt(np.mean(x ** 2)) + 1e-12
            idx = np.nonzero(np.abs(x) > pk * 0.1)[0]
            lead = (idx[0] / sr * 1000) if len(idx) else 9999
            clip = int(np.sum(np.abs(x) > 0.999))
            pkdb, rmsdb = 20 * np.log10(pk), 20 * np.log10(rms)
            rows.append((rel, dur, pkdb, rmsdb, lead, sr))
            issues = []
            if sr != 44100:
                issues.append(f"sr {sr}")
            if dur > limit_for(rel):
                issues.append(f"too long {dur:.2f}s")
            if dur < 0.03:
                issues.append("too short")
            if lead > 30 and not rel.startswith("audio/ambience"):
                issues.append(f"lead {lead:.0f}ms")
            if clip > 2:
                issues.append(f"clip {clip}")
            if pkdb < -20:
                issues.append(f"quiet peak {pkdb:.1f}")
            if issues:
                bad.append((rel, issues))
            print(f"{rel:52s} {dur:6.2f}s  pk {pkdb:6.1f}  rms {rmsdb:6.1f}  lead {lead:5.0f}ms")
    print(f"\n{len(rows)} files")
    print("OUTLIERS:" if bad else "no outliers")
    for rel, iss in bad:
        print("  ", rel, ", ".join(iss))


if __name__ == "__main__":
    main(sys.argv[1:] or ["assets/audio", "assets/voice"])
