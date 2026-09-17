#!/usr/bin/env bash
# terrarium-gen2-crystal — fetch the pinned engine and mod, apply the patches,
# add the new files, and build the mod package.  Nothing here downloads a ROM.
#
#   ./apply.sh [--gen1recomp DIR] [--terrarium DIR] [--all-gens] [--no-fetch]
#
# Output: work/gen1recomp (patched, for the iOS build), work/Terrarium (patched),
#         dist/TERRARIUM/ and dist/TERRARIUM.zip (the mod, ready to install).
set -euo pipefail

GEN1RECOMP_REPO="https://github.com/bryanthaboi/gen1recomp.git"
GEN1RECOMP_TAG="v0.2.60"
GEN1RECOMP_SHA="4dadfd55a88e796c15fa7549b7c56e60e7c9b6d5"
TERRARIUM_REPO="https://github.com/BrenoBertucci/Terrarium.git"
TERRARIUM_SHA="ffecfa14ef8e0a2fc05e2446c54b454c9fe563a5"

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$HERE/work"; DIST="$HERE/dist"
ENGINE_DIR=""; MOD_DIR=""; ALL_GENS=0; FETCH=1
while [ $# -gt 0 ]; do
  case "$1" in
    --gen1recomp) ENGINE_DIR="$2"; shift ;;
    --terrarium) MOD_DIR="$2"; shift ;;
    --all-gens) ALL_GENS=1 ;;
    --no-fetch) FETCH=0 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
  shift
done
say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
for tool in git python3 zip rsync; do command -v "$tool" >/dev/null || fail "$tool is required"; done
mkdir -p "$WORK" "$DIST"

fetch_at() {  # fetch_at <dir> <repo> <sha>  — shallow checkout of one commit
  local dir="$1" repo="$2" sha="$3"
  if [ ! -d "$dir/.git" ]; then
    say "fetching $repo @ ${sha:0:8}"
    git init -q "$dir"
    git -C "$dir" remote add origin "$repo"
  fi
  git -C "$dir" fetch -q --depth 1 origin "$sha" || fail "could not fetch $sha from $repo"
  git -C "$dir" checkout -q --detach FETCH_HEAD
}
check_clean_at() {  # check_clean_at <dir> <sha>
  local head; head="$(git -C "$1" rev-parse HEAD)"
  [ "$head" = "$2" ] || fail "$1 is at ${head:0:8}, expected ${2:0:8}"
  [ -z "$(git -C "$1" status --porcelain --untracked-files=no)" ] || fail "$1 has local modifications; start from a clean checkout"
}

# ---- engine
if [ -z "$ENGINE_DIR" ]; then
  ENGINE_DIR="$WORK/gen1recomp"
  [ $FETCH = 1 ] && fetch_at "$ENGINE_DIR" "$GEN1RECOMP_REPO" "$GEN1RECOMP_SHA"
fi
check_clean_at "$ENGINE_DIR" "$GEN1RECOMP_SHA"
say "engine: gen1recomp $GEN1RECOMP_TAG at $ENGINE_DIR"
for p in "$HERE"/patches/engine/*.patch; do
  git -C "$ENGINE_DIR" apply --check "$p" || fail "engine patch $(basename "$p") does not apply"
  git -C "$ENGINE_DIR" apply "$p"
  say "applied $(basename "$p")"
done

# ---- mod
if [ -z "$MOD_DIR" ]; then
  MOD_DIR="$WORK/Terrarium"
  [ $FETCH = 1 ] && fetch_at "$MOD_DIR" "$TERRARIUM_REPO" "$TERRARIUM_SHA"
fi
check_clean_at "$MOD_DIR" "$TERRARIUM_SHA"
say "mod: Terrarium at $MOD_DIR"
for p in "$HERE"/patches/terrarium/*.patch; do
  git -C "$MOD_DIR" apply --check "$p" || fail "mod patch $(basename "$p") does not apply"
  git -C "$MOD_DIR" apply "$p"
  say "applied $(basename "$p")"
done
rsync -a "$HERE/overlay/terrarium/" "$MOD_DIR/"
say "added $(find "$HERE/overlay/terrarium" -type f | wc -l | tr -d ' ') new files"

# ---- package: everything the mod needs at play time, nothing else
PKG="$DIST/TERRARIUM"; rm -rf "$PKG"; mkdir -p "$PKG"
rsync -a --exclude '.git' --exclude '.github' --exclude 'tests' --exclude 'tools' --exclude 'concepts' \
      --exclude 'publish' --exclude 'publish-zip' --exclude 'probe_out*' --exclude '.modkit' \
      --exclude '.modkitignore' --exclude '.gitignore' --exclude '*.md' "$MOD_DIR/" "$PKG/"
if [ $ALL_GENS = 0 ]; then
  # Gen 2 only: the engine's loader refuses it on Red/Blue/Yellow whatever the
  # options say, so it can sit next to a Gen 1 world mod without a fight.
  python3 - "$PKG/manifest.json" <<'PY'
import json, sys, re
p = sys.argv[1]; t = open(p).read()
if '"gen2compat": true,' in t:
    t = t.replace('"gen2compat": true,', '"games": ["gen2"],', 1)
    open(p, "w").write(t)
json.loads(t)
print("manifest: games = gen2 (use --all-gens to keep gen2compat)")
PY
else
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$PKG/manifest.json"
  say "manifest: upstream gen2compat kept (loads on Gen 1 and Gen 2)"
fi
( cd "$DIST" && rm -f TERRARIUM.zip && zip -qr TERRARIUM.zip TERRARIUM )
say "built $PKG and $DIST/TERRARIUM.zip ($(du -sh "$DIST/TERRARIUM.zip" | cut -f1))"
cat <<TXT

Next:
  iOS      cd "$ENGINE_DIR" && scripts/build_ios.sh --fetch --package-only
           DEVELOPMENT_TEAM=<team id> scripts/build_ios.sh --device --release --install --version 0.2.60
  desktop  install the official gen1recomp $GEN1RECOMP_TAG release
  then     import your Crystal (USA) 1.1 dump, copy dist/TERRARIUM into the app's mods/ folder,
           and set  gold = { pipelines = { terrarium_voxel = 3 } }  in options.lua (see docs/INSTALL.md)
TXT
