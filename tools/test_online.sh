#!/bin/sh
# Online play on one computer: a relay, a host and a guest process (see tools/test_online.gd).
#   tools/test_online.sh [coop] [fac_host:brood fac_guest:clockwork ...]
# Needs godot on the PATH and node. Prints the CHECK lines; exit code 1 if any failed.
cd "$(dirname "$0")/.." || exit 1
PORT=${PORT:-8799}
OUT=${TMPDIR:-/tmp}/holdfast_online_$$
mkdir -p "$OUT"
node tools/relay/local_relay.mjs $PORT > "$OUT/relay.log" 2>&1 &
RELAY=$!
sleep 1
godot --headless --script res://tools/test_online.gd -- role:host relay:ws://127.0.0.1:$PORT code:TEST "$@" > "$OUT/host.log" 2>&1 &
HOST=$!
sleep 3
godot --headless --script res://tools/test_online.gd -- role:guest relay:ws://127.0.0.1:$PORT code:TEST "$@" > "$OUT/guest.log" 2>&1 &
GUEST=$!
wait $GUEST
wait $HOST
kill $RELAY 2>/dev/null
grep -h "CHECK\|RESULT\|ALL OK\|SOME FAILED\|hash\|FAILED\|TIMEOUT\|SCRIPT ERROR" "$OUT/host.log" "$OUT/guest.log"
echo "(full logs in $OUT)"
! grep -q "SOME FAILED\|TIMEOUT\|SCRIPT ERROR" "$OUT/host.log" "$OUT/guest.log"
