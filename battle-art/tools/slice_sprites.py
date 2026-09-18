#!/usr/bin/env python3
"""Build the CRYSTAL_BATTLE_ART asset tree: one Black/White still frame per
Gold/Silver/Crystal species (front, back, shiny), plus data/sprites.lua.

usage: slice_sprites.py --species FILE --out MOD_DIR [--fetch-cache DIR | --battle-art DIR] [--set gen5]

Sources, one of:
  --fetch-cache DIR   download each species' Black/White animated PNG from the
                      Bulbagarden Archives (the same public archive absol89's
                      Battle Art importers use) into DIR, cached, and take its
                      first frame.  Needs network access.
  --battle-art DIR    slice frame 0 out of a Battle Art mod folder that already
                      has assets/battle/{front,back}-animated/<set>/ atlases and
                      their data/animated_battle_sprites_<set>*.lua tables.

--species FILE has one "SPECIES_ID DEX_NUMBER" per line (species_gen2.txt), or is
the engine's Crystal cache dir (…/crystal/data/generated) to read ids and dex
numbers from its pokemon.lua.
"""
import argparse, os, re, ssl, sys, time, urllib.parse, urllib.request
from io import BytesIO
from PIL import Image

# python.org builds of Python on macOS ship without a certificate bundle; use
# certifi's when it is installed, the system default otherwise.
try:
    import certifi
    SSL_CTX = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    SSL_CTX = ssl.create_default_context()

ARCHIVE = "https://archives.bulbagarden.net/wiki/Special:Redirect/file/"
USER_AGENT = "crystal-battle-art build (github.com/BlinkingSun/Gen1recomp-IOS-Crystal-v1.1)"
ALIAS = {"MR__MIME": "MR_MIME", "FARFETCH_D": "FARFETCHD"}   # Battle Art table keys

ap = argparse.ArgumentParser()
ap.add_argument("--species", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--fetch-cache")
ap.add_argument("--battle-art")
ap.add_argument("--set", default="gen5")
ap.add_argument("--delay", type=float, default=0.6, help="seconds between downloads")
args = ap.parse_args()
if not (args.fetch_cache or args.battle_art):
    sys.exit("give --fetch-cache DIR or --battle-art DIR")

# ---- species list -----------------------------------------------------------
def read_species(src):
    if os.path.isdir(src):
        t = open(os.path.join(src, "pokemon.lua")).read()
        out = []
        for m in re.finditer(r'^\s{2}([A-Z_0-9]+) = \{(.*?)^\s{2}\},', t, re.S | re.M):
            d = re.search(r'^\s{4}dex = (\d+),', m.group(2), re.M)
            out.append((m.group(1), int(d.group(1)) if d else None))
        return out
    out = []
    for line in open(src):
        line = line.strip()
        if not line or line.startswith("#"): continue
        parts = line.split()
        out.append((parts[0], int(parts[1]) if len(parts) > 1 else None))
    return out

species = read_species(args.species)

# ---- source A: Bulbagarden Archives ----------------------------------------
def download(url, retries=4):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=60, context=SSL_CTX) as r:
                return r.read(), r.headers.get("Content-Type", "")
        except urllib.error.HTTPError as e:
            if e.code == 404: return None, None
            if attempt == retries: raise
        except Exception:
            if attempt == retries: raise
        time.sleep(1.5 * attempt)
    return None, None

def archive_names(dex, side, shiny):
    prefix = "Spr 5b" if side == "front" else "Spr b 5b"
    s = " s" if shiny else ""
    n = f"{dex:03d}"
    return [f"{prefix} {n}{s}.png", f"{prefix} {n} m{s}.png", f"{prefix} {n} f{s}.png"]

def fetch_frame(dex, side, shiny):
    for name in archive_names(dex, side, shiny):
        cached = os.path.join(args.fetch_cache, name)
        if os.path.isfile(cached):
            raw = open(cached, "rb").read()
        else:
            raw, ctype = download(ARCHIVE + urllib.parse.quote(name))
            time.sleep(args.delay)
            if raw is None or not raw.startswith(b"\x89PNG"):
                continue
            os.makedirs(args.fetch_cache, exist_ok=True)
            open(cached, "wb").write(raw)
        im = Image.open(BytesIO(raw))
        # an APNG may carry a "default image" that is not part of the animation
        if getattr(im, "n_frames", 1) > 1 and im.info.get("default_image"):
            im.seek(1)
        return im.convert("RGBA")
    return None

# ---- source B: Battle Art atlases ------------------------------------------
def parse_table(path):
    t = open(path).read(); out = {}
    for m in re.finditer(r'^\s{2}([A-Z_0-9]+) = \{(.*?)^\s{2}\},', t, re.S | re.M):
        rec = {}
        for side in ("front", "back"):
            sm = re.search(side + r' = \{ image = "([^"]+)", width = (\d+), height = (\d+), columns = (\d+), frames = (\d+)', m.group(2))
            if sm: rec[side] = {"image": sm.group(1), "w": int(sm.group(2)), "h": int(sm.group(3))}
        out[m.group(1)] = rec
    return out

if args.battle_art:
    T_NORMAL = parse_table(os.path.join(args.battle_art, "data", f"animated_battle_sprites_{args.set}.lua"))
    T_SHINY = parse_table(os.path.join(args.battle_art, "data", f"animated_battle_sprites_{args.set}_shiny.lua"))

def atlas_frame(sp, side, shiny):
    rec = (T_SHINY if shiny else T_NORMAL).get(ALIAS.get(sp, sp), {}).get(side)
    if not rec: return None
    p = os.path.join(args.battle_art, rec["image"])
    if not os.path.exists(p):
        alt = p[:-4] + "-a.png"          # Unown ships one atlas per letter
        if not os.path.exists(alt): return None
        p = alt
    im = Image.open(p).convert("RGBA")
    if rec["w"] > im.width or rec["h"] > im.height: return None
    return im.crop((0, 0, rec["w"], rec["h"]))

# ---- slice + scale ----------------------------------------------------------
def scale_for(w, h, side):
    m = max(w, h)
    # keep some of Black/White's size relationships instead of normalising fully:
    # fronts land between ~44 and 56 px (the 7-tile enemy box is 56), backs ~38-48.
    target = (44 + 12 * min(1.0, m / 96)) if side == "front" else (38 + 10 * min(1.0, m / 96))
    return round(target / m, 4)

entries, missing, n = [], [], 0
for sp, dex in species:
    fields = []
    for tag, side, shiny in (("front", "front", False), ("back", "back", False),
                             ("front_shiny", "front", True), ("back_shiny", "back", True)):
        if args.battle_art: img = atlas_frame(sp, side, shiny)
        elif dex is None: img = None
        else: img = fetch_frame(dex, side, shiny)
        bbox = img.getbbox() if img is not None else None
        if not bbox:
            missing.append(f"{sp}.{tag}"); continue
        img = img.crop(bbox)
        rel = f"battle/{tag.replace('_', '-')}/{sp}.png"
        dst = os.path.join(args.out, "assets", rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        img.save(dst, optimize=True); n += 1
        fields.append(f'    {tag} = {{ path = "{rel}", w = {img.width}, h = {img.height}, scale = {scale_for(img.width, img.height, side)} }},')
    if fields:
        entries.append(f"  {sp} = {{\n" + "\n".join(fields) + "\n  },")
    print(f"{sp:<12s} {len(fields)}/4", flush=True)

os.makedirs(os.path.join(args.out, "data"), exist_ok=True)
with open(os.path.join(args.out, "data", "sprites.lua"), "w") as f:
    f.write("-- Generated by tools/slice_sprites.py. Do not edit.\n")
    f.write("-- One Black/White still frame per species; scale = draw scale for the engine's battle pic box.\n")
    f.write("return {\n" + "\n".join(entries) + "\n}\n")
print(f"species: {len(species)} | pics written: {n} | missing: {len(missing)}")
if missing: print("missing:", missing[:24])
