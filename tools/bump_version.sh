#!/bin/sh
# Advance the patch number of the game version (project.godot config/version), e.g. 0.7.3 -> 0.7.4.
# Run before every commit that changes the game, so a log or a screenshot says which build it was.
cd "$(dirname "$0")/.."
v=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
new=$(echo "$v" | awk -F. '{ if (NF < 3) print $1"."$2".1"; else print $1"."$2"."$3+1 }')
sed -i "s/^config\/version=\".*\"/config\/version=\"$new\"/" project.godot
sed -i "s/^\*\*Play in your browser (version [^)]*)/**Play in your browser (version $new)/" README.md
echo "$new"
