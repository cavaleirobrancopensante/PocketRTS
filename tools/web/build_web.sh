#!/bin/bash
# Builds the web version into build/web the way the site serves it (docs/web_load.md):
#   index.html            Holdfast's loading page (tools/web/shell.html) with the file list filled in
#   index.js / index.wasm the engine (+ index.wasm.gz)
#   index.pck             code, scenes and data: the part that changes with most updates
#   assets.<hash>.pck     art, sounds and voices ("Web assets" preset): only re-downloaded when they change
#   music/<stem>.ogg      every music piece, downloaded by the game when it is first wanted
# Used by .github/workflows/web.yml; run it locally to test (GODOT=path/to/godot).
# Serve build/web with any static server (python3 -m http.server -d build/web) to try it.
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
OUT=build/web

rm -rf "$OUT" build/web_assets
mkdir -p "$OUT" build/web_assets "$OUT/music"
touch build/.gdignore    # keep the editor from importing the exported files
"$GODOT" --headless --export-release "Web" "$OUT/index.html"
"$GODOT" --headless --export-pack "Web assets" build/web_assets/assets.pck
test -s "$OUT/index.pck"
test -s build/web_assets/assets.pck

# Only the art and sound entries, in a fixed order: the same art gives the same bytes and the same
# hash, so the browser keeps its copy across updates (project.binary, which holds the version, stays
# in index.pck).
python3 tools/web/pck_tool.py assets build/web_assets/assets.pck build/web_assets/assets_only.pck
sha() { sha256sum "$1" | cut -c1-12; }
ah=$(sha build/web_assets/assets_only.pck)
mv build/web_assets/assets_only.pck "$OUT/assets.$ah.pck"
rm -rf build/web_assets

# The music: plain .ogg files next to the page (the "Web" preset leaves assets/ out of its pack).
for f in assets/music/*.ogg; do
	cp "$f" "$OUT/music/"
done

# A gzipped copy of the engine (39 MB -> 10 MB): the page unpacks it with DecompressionStream, so
# it comes small whatever the host does (docs/web_load.md). The packs hold pictures and sounds
# that are compressed already and gain nothing from it.
gzip -9 -k -n "$OUT/index.wasm"
cp assets/fonts/Cinzel.ttf "$OUT/cinzel.ttf"

python3 - "$OUT" "assets.$ah.pck" <<'EOF'
import hashlib, json, os, sys
out, assets = sys.argv[1], sys.argv[2]
def h(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()[:12]
files = {}
for name, typ in [('index.wasm', 'application/wasm'), ('index.pck', 'application/octet-stream'),
                  (assets, 'application/octet-stream')]:
    p = os.path.join(out, name)
    e = {'h': h(p), 's': os.path.getsize(p), 'type': typ}
    if os.path.exists(p + '.gz'):
        e['gz'] = name + '.gz'
    files[name] = e
music = {}
for f in sorted(os.listdir(os.path.join(out, 'music'))):
    if f.endswith('.ogg'):
        music[f[:-4]] = {'u': 'music/%s?h=%s' % (f, h(os.path.join(out, 'music', f)))}
data = json.dumps({'files': files, 'assets': assets, 'music': music}, separators=(',', ':'))
page = os.path.join(out, 'index.html')
t = open(page).read()
assert '/*HOLDFAST_FILES*/null' in t, 'index.html is not tools/web/shell.html'
open(page, 'w').write(t.replace('/*HOLDFAST_FILES*/null', data))
total = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(out) for f in fs)
print('web build: %d files, %.1f MB on disk' % (sum(len(fs) for _, _, fs in os.walk(out)), total / 1e6))
for name, e in files.items():
    gz = os.path.getsize(os.path.join(out, e['gz'])) if 'gz' in e else e['s']
    print('  %-28s %7.1f MB (%.1f MB to download)' % (name, e['s'] / 1e6, gz / 1e6))
print('  music: %d pieces, %.1f MB, downloaded one at a time when wanted' % (len(music),
      sum(os.path.getsize(os.path.join(out, 'music', f)) for f in os.listdir(os.path.join(out, 'music'))) / 1e6))
EOF
