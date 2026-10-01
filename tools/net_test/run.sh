#!/usr/bin/env bash
# Starts two copies of the game, one hosting and one joining, and runs the
# scripted checks in godot/dev/harness.gd (host_test and join_test).
# Usage: tools/net_test/run.sh [path to godot]
# Passing --window shows both games instead of running them headless.
GODOT="${GODOT:-/d/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe}"
MODE="--headless"
[ "$1" = "--window" ] && MODE="--resolution 576x324"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/out"
mkdir -p "$OUT"
cd "$HERE/../../godot"
"$GODOT" $MODE --path . res://dev/harness.tscn -- "$OUT/host" host_test > "$OUT/host.log" 2>&1 &
HOST=$!
sleep 6
"$GODOT" $MODE --path . res://dev/harness.tscn -- "$OUT/guest" join_test > "$OUT/guest.log" 2>&1 &
GUEST=$!
wait $HOST $GUEST
echo "--- host";  grep -E "HARNESS|SCRIPT ERROR|ERROR: res" -A1 "$OUT/host.log" | grep -v "^--$"
echo "--- guest"; grep -E "HARNESS|SCRIPT ERROR|ERROR: res" -A1 "$OUT/guest.log" | grep -v "^--$"
