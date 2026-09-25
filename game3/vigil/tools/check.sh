#!/usr/bin/env bash
# Parse/load check for game3/vigil (docs/game3.md, "Testing without a phone"):
# an editor import pass (which also builds the class_name cache the other
# tools need), a headless boot of the app, the breath recipes run to the
# end and the 30-day draw simulation. Fails on any ERROR / SCRIPT ERROR.
#
#   GODOT=/path/to/godot-4.7.2 game3/vigil/tools/check.sh
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
fail=0

run() {
  local label="$1"; shift
  local out
  out="$(timeout 180 "$GODOT" --headless "$@" 2>&1)"
  if grep -qE "ERROR|Parse Error" <<<"$out"; then
    echo "FAIL $label"; grep -E -A3 "ERROR|Parse Error" <<<"$out" | head -40
    fail=1
  else
    echo "ok   $label"
  fi
  LAST="$out"
}

run "import"        --editor --quit --path .
run "boot"          --path . --quit-after 120
for id in free.breath.001 free.breath.002 deep.breath.001; do
  run "rite $id"    --path . -s tools/run_rite.gd -- "$id"
  if ! grep -q "^outcome: done" <<<"$LAST"; then echo "FAIL rite $id: $(tail -1 <<<"$LAST")"; fail=1; fi
done
run "draw 30 days"  --path . -s tools/draw_sim.gd -- 30
if ! grep -q "^draw: ok" <<<"$LAST"; then echo "$LAST" | tail -5; fail=1; fi
VIGIL_SAVE="$(mktemp -u /tmp/vigil-flow-XXXXXX.json)"; export VIGIL_SAVE
run "flow"          --path . -s tools/flow_test.gd
if ! grep -q "^flow: ok" <<<"$LAST"; then echo "$LAST" | tail -5; fail=1; fi
rm -f "$VIGIL_SAVE"
exit $fail
