#!/usr/bin/env bash
# Build the CRYSTAL_BATTLE_ART mod: Black/White battle sprites for Gold/Silver/Crystal.
#
#   ./battle-art/build.sh [--battle-art DIR] [--set gen5]
#
# No sprite art is in this repository.  By default the slicer downloads each
# species' Black/White animated PNG (front, back, shiny) from the Bulbagarden
# Archives into work/sprites-src (cached; ~1000 files, a few minutes) and keeps
# its first frame.  --battle-art DIR slices the same frames out of an absol89
# Battle Art mod folder that already has its assets/battle/*-animated/<set>/
# atlases instead (no network needed).
#
# Output: dist/CRYSTAL_BATTLE_ART/ and dist/CRYSTAL_BATTLE_ART.zip
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$HERE/work"; DIST="$HERE/dist"
BA_DIR=""; SET="gen5"
while [ $# -gt 0 ]; do
  case "$1" in
    --battle-art) BA_DIR="$2"; shift ;;
    --set) SET="$2"; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
  shift
done
mkdir -p "$WORK" "$DIST"
python3 -c 'import PIL' 2>/dev/null || { echo "needs Pillow: pip3 install pillow" >&2; exit 1; }
# python.org builds of Python on macOS ship without a certificate bundle and
# would fail every HTTPS download; certifi's bundle fixes that when present.
if [ -z "${SSL_CERT_FILE:-}" ] && CERT="$(python3 -m certifi 2>/dev/null)" && [ -n "$CERT" ]; then
  export SSL_CERT_FILE="$CERT"
fi
OUT="$DIST/CRYSTAL_BATTLE_ART"; rm -rf "$OUT"; mkdir -p "$OUT"
cp "$HERE/battle-art/mod/manifest.json" "$HERE/battle-art/mod/main.lua" "$OUT/"
if [ -n "$BA_DIR" ]; then
  python3 "$HERE/battle-art/tools/slice_sprites.py" --species "$HERE/battle-art/tools/species_gen2.txt" \
    --out "$OUT" --battle-art "$BA_DIR" --set "$SET"
else
  python3 "$HERE/battle-art/tools/slice_sprites.py" --species "$HERE/battle-art/tools/species_gen2.txt" \
    --out "$OUT" --fetch-cache "$WORK/sprites-src"
fi
(cd "$DIST" && rm -f CRYSTAL_BATTLE_ART.zip && zip -qr CRYSTAL_BATTLE_ART.zip CRYSTAL_BATTLE_ART)
echo "built $OUT and $DIST/CRYSTAL_BATTLE_ART.zip"
