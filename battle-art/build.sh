#!/usr/bin/env bash
# Build the CRYSTAL_BATTLE_ART mod: Black/White battle sprites for Gold/Silver/Crystal.
#
#   ./battle-art/build.sh [--battle-art DIR] [--release TAG] [--set gen5|gen3]
#
# The sprite atlases are NOT in this repository (they are Game Freak's art, shipped
# by absol89's Battle Art Voxel Fork in its release zips, not in its git tree).
# Give the script an unpacked Battle Art mod folder with --battle-art, or let it
# download the release zip (default tag below) into work/.
#
# Output: dist/CRYSTAL_BATTLE_ART/ and dist/CRYSTAL_BATTLE_ART.zip
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$HERE/work"; DIST="$HERE/dist"
BA_DIR=""; TAG="1.11.0"; SET="gen5"
while [ $# -gt 0 ]; do
  case "$1" in
    --battle-art) BA_DIR="$2"; shift ;;
    --release) TAG="$2"; shift ;;
    --set) SET="$2"; shift ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
  shift
done
mkdir -p "$WORK" "$DIST"
python3 -c 'import PIL' 2>/dev/null || { echo "needs Pillow: pip3 install pillow" >&2; exit 1; }
if [ -z "$BA_DIR" ]; then
  ZIP="$WORK/BATTLE_ART_VOXEL_FORK-$TAG.zip"
  if [ ! -f "$ZIP" ]; then
    echo "fetching Battle Art $TAG release zip ..."
    curl -fL --progress-bar -o "$ZIP" \
      "https://github.com/absol89/DramaticShapeVoxelMod/releases/download/$TAG/BATTLE_ART_VOXEL_FORK-$TAG.zip"
  fi
  rm -rf "$WORK/battle-art"; mkdir -p "$WORK/battle-art"
  unzip -q "$ZIP" -d "$WORK/battle-art"
  BA_DIR="$(dirname "$(find "$WORK/battle-art" -name manifest.json -path '*BATTLE_ART*' | head -1)")"
  [ -n "$BA_DIR" ] || BA_DIR="$(dirname "$(find "$WORK/battle-art" -name manifest.json | head -1)")"
fi
[ -f "$BA_DIR/data/animated_battle_sprites_$SET.lua" ] || { echo "no data/animated_battle_sprites_$SET.lua under $BA_DIR" >&2; exit 1; }
OUT="$DIST/CRYSTAL_BATTLE_ART"; rm -rf "$OUT"; mkdir -p "$OUT"
cp "$HERE/battle-art/mod/manifest.json" "$HERE/battle-art/mod/main.lua" "$OUT/"
python3 "$HERE/battle-art/tools/slice_sprites.py" "$BA_DIR" "$HERE/battle-art/tools/species_gen2.txt" "$OUT" "--set=$SET"
(cd "$DIST" && rm -f CRYSTAL_BATTLE_ART.zip && zip -qr CRYSTAL_BATTLE_ART.zip CRYSTAL_BATTLE_ART)
echo "built $OUT and $DIST/CRYSTAL_BATTLE_ART.zip"
