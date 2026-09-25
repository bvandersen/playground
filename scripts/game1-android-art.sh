#!/usr/bin/env bash
# Renders Rail Yard's Android launcher icons and Google Play listing art
# (docs/game1.md, "Android build") with game1/rail-yard/tools/store_art.gd.
# Needs a real renderer, so it runs Godot under Xvfb (xvfb-run) with the
# OpenGL driver; software Mesa (llvmpipe) is fine.
#
#   scripts/game1-android-art.sh            # everything
#   scripts/game1-android-art.sh icons      # just the launcher icons
#
# Outputs: game1/rail-yard/art/android/*.png (used by the Android export
# preset, committed) and game1/store/rail-yard/*.png (uploaded by hand in
# Play Console, committed so they're versioned with the game).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot4}"
PROJECT=game1/rail-yard

shot() { # name, window size
  xvfb-run -a -s "-screen 0 2048x2048x24" \
    "$GODOT" --path "$PROJECT" --rendering-driver opengl3 --audio-driver Dummy \
    --resolution "$2" --script res://tools/store_art.gd -- "$1" 2>&1 \
    | grep -E '^(wrote|FAILED)|SCRIPT ERROR' || true
}

want="${1:-all}"
if [[ $want == all || $want == icons ]]; then
  shot icon_bg 1728x1728
  shot icon_fg 1728x1728
  shot icon_mono 1728x1728
  shot icon_192 768x768
fi
if [[ $want == all || $want == store ]]; then
  shot store_icon 2048x2048 # icons render at 4x, see ICON_SUPERSAMPLE
  shot feature 1024x500
  shot phone_design 1080x1920
  shot phone_sheet 1080x1920
  shot phone_play 1080x1920
fi
