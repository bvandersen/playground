#!/usr/bin/env bash
# Builds Rail Yard (game1/rail-yard) for Android, headlessly -- see
# docs/game1.md, "Android build and Google Play release".
#
#   scripts/game1-android.sh aab   # signed release .aab for Google Play
#   scripts/game1-android.sh apk   # debug .apk to sideload with adb install
#
# Output goes to build/game1-android/ (gitignored). Unlike the Web export
# the result is never committed.
#
# Uses Godot 4.7.2, not the 4.3 the Web build uses: 4.3's Android
# libraries are 4 KB page aligned and Google Play only takes 16 KB aligned
# ones. It exports from a copy of the project so the 4.7 editor's import
# and upgrade never touch the 4.3 source tree.
#
# Needs:
#   JAVA_HOME     JDK 17 or newer
#   ANDROID_HOME  Android SDK (the Gradle build installs the platform and
#                 build-tools it wants, if the SDK licences are accepted)
#   aab only:     GODOT_ANDROID_KEYSTORE_RELEASE_PATH, ..._USER (key
#                 alias) and ..._PASSWORD -- the upload key; never commit it
# Optional:
#   VERSION_CODE  overrides version/code in the preset; every upload to
#                 Play needs a higher one (CI passes its run number)
#   GODOT47       an existing Godot 4.7.2 editor binary; otherwise it and
#                 its export templates are downloaded into ~/.cache
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD

KIND="${1:-aab}"
case "$KIND" in
  aab|apk) ;;
  *) echo "usage: $0 [aab|apk]" >&2; exit 2 ;;
esac

GODOT_VERSION=4.7.2
GODOT_TAG="${GODOT_VERSION}-stable"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rail-yard-android"
BUILD="$ROOT/build/game1-android"
PROJECT="$BUILD/rail-yard"

: "${JAVA_HOME:?set JAVA_HOME to a JDK 17+}"
: "${ANDROID_HOME:?set ANDROID_HOME to the Android SDK}"
if [[ $KIND == aab ]]; then
  for v in GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
    [[ -n "${!v:-}" ]] || { echo "$v is not set (the upload key -- see docs/game1.md)" >&2; exit 2; }
  done
fi

# --- Godot 4.7.2 editor + Android templates --------------------------------
mkdir -p "$CACHE"
if [[ -z "${GODOT47:-}" ]]; then
  GODOT47="$CACHE/Godot_v${GODOT_TAG}_linux.x86_64"
  if [[ ! -x "$GODOT47" ]]; then
    echo "Downloading Godot $GODOT_VERSION editor..."
    curl -fsSL -o "$CACHE/editor.zip" \
      "https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/Godot_v${GODOT_TAG}_linux.x86_64.zip"
    unzip -o -q "$CACHE/editor.zip" -d "$CACHE" && rm "$CACHE/editor.zip"
  fi
fi
if [[ ! -f "$TEMPLATE_DIR/android_source.zip" ]]; then
  echo "Downloading Godot $GODOT_VERSION export templates (~1 GB, once)..."
  curl -fsSL -o "$CACHE/templates.tpz" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/Godot_v${GODOT_TAG}_export_templates.tpz"
  mkdir -p "$TEMPLATE_DIR"
  unzip -o -q -j "$CACHE/templates.tpz" 'templates/android*' 'templates/version.txt' -d "$TEMPLATE_DIR"
  rm "$CACHE/templates.tpz"
fi

# Point the editor at the JDK and SDK. Its settings file only picks up
# JAVA_HOME / ANDROID_HOME when it's first created, so write them in.
SETTINGS_DIR="$HOME/.config/godot"
SETTINGS="$SETTINGS_DIR/editor_settings-4.7.tres"
mkdir -p "$SETTINGS_DIR"
if [[ ! -f "$SETTINGS" ]]; then
  printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$SETTINGS"
fi
sed -i '/^export\/android\/\(android_sdk_path\|java_sdk_path\) = /d' "$SETTINGS"
printf 'export/android/android_sdk_path = "%s"\nexport/android/java_sdk_path = "%s"\n' \
  "$ANDROID_HOME" "$JAVA_HOME" >> "$SETTINGS"

# --- A throwaway copy of the project ---------------------------------------
rm -rf "$PROJECT"
mkdir -p "$PROJECT"
# (Anchored excludes: a bare "android" would also drop art/android/.)
tar -C game1/rail-yard --exclude=./.godot --exclude=./android -cf - . | tar -C "$PROJECT" -xf -
PRESETS="$PROJECT/export_presets.cfg"
# A missing launcher icon only logs an error and falls back to Godot's
# default icon, so check them up front.
for icon in $(sed -n 's/^launcher_icons\/[a-z_0-9x]*="res:\/\/\(.*\)"$/\1/p' "$PRESETS"); do
  [[ -f "$PROJECT/$icon" ]] || { echo "Missing launcher icon: $icon" >&2; exit 1; }
done
if [[ -n "${VERSION_CODE:-}" ]]; then
  sed -i "s/^version\/code=.*/version\/code=${VERSION_CODE}/" "$PRESETS"
fi
if [[ $KIND == apk ]]; then
  sed -i 's/^gradle_build\/export_format=.*/gradle_build\/export_format=0/' "$PRESETS"
fi

# Import pass (builds the class_name cache), then install the Gradle build
# template into the copy and export.
"$GODOT47" --headless --editor --quit --path "$PROJECT" >/dev/null 2>&1 || true
OUT="$BUILD/rail-yard.$KIND"
rm -f "$OUT"
if [[ $KIND == aab ]]; then
  EXPORT=--export-release
else
  EXPORT=--export-debug
fi
"$GODOT47" --headless --path "$PROJECT" --install-android-build-template "$EXPORT" Android "$OUT"

[[ -s "$OUT" ]] || { echo "Export failed: no $OUT" >&2; exit 1; }
CODE=$(sed -n 's/^version\/code=//p' "$PRESETS")
echo "Built $OUT ($(du -h "$OUT" | cut -f1), version code $CODE)"
