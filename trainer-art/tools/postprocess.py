#!/usr/bin/env python3
"""Post-process raw 1024x1024 trainer sprites into 64x64 RGBA PNGs.

For each PNG in work/raw/:
  1. Flood-fill near-white from the four corners to transparency.
  2. Crop to the opaque bounding box.
  3. Scale so the taller side is 60 px (LANCZOS).
  4. Quantize to at most 32 colours, no dithering.
  5. Place on a 64x64 canvas with feet on the bottom row, centred horizontally.
"""

from __future__ import annotations

import argparse
import sys
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "work" / "raw"
OUT_TRAINERS = ROOT / "out" / "trainers"
OUT_PLAYER = ROOT / "out" / "player"
PLAYER_IDS = {"GOLD_BACK", "KRIS_BACK"}

CANVAS = 64
TALL_SIDE = 60
MAX_COLORS = 32
# JPEG compression leaves off-white around true white; 40 covers typical noise.
WHITE_TOLERANCE = 40


def near_white(rgb: tuple[int, int, int], tol: int = WHITE_TOLERANCE) -> bool:
    r, g, b = rgb
    return (255 - r) <= tol and (255 - g) <= tol and (255 - b) <= tol


def flood_white_to_alpha(im: Image.Image, tol: int = WHITE_TOLERANCE) -> Image.Image:
    """Make the near-white background transparent via 4-corner flood-fill."""
    rgba = im.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    visited = bytearray(w * h)

    def idx(x: int, y: int) -> int:
        return y * w + x

    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    q: deque[tuple[int, int]] = deque()
    for x, y in seeds:
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        if near_white((r, g, b), tol):
            q.append((x, y))
            visited[idx(x, y)] = 1

    while q:
        x, y = q.popleft()
        r, g, b, a = px[x, y]
        if a == 0 or not near_white((r, g, b), tol):
            continue
        px[x, y] = (r, g, b, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[idx(nx, ny)]:
                visited[idx(nx, ny)] = 1
                nr, ng, nb, na = px[nx, ny]
                if na != 0 and near_white((nr, ng, nb), tol):
                    q.append((nx, ny))
    return rgba


def opaque_bbox(im: Image.Image, alpha_min: int = 16) -> tuple[int, int, int, int] | None:
    a = im.getchannel("A")
    # getbbox treats 0 as empty; bump near-zero alpha down so JPEG fringe is ignored.
    a = a.point(lambda v: 0 if v < alpha_min else v)
    return a.getbbox()


def quantize_keep_alpha(im: Image.Image, colors: int = MAX_COLORS) -> Image.Image:
    """Quantize RGB to `colors` with no dither; restore original alpha."""
    alpha = im.getchannel("A")
    rgb = im.convert("RGB")
    pal = rgb.quantize(
        colors=colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    out = pal.convert("RGBA")
    out.putalpha(alpha)
    return out


def fit_to_canvas(im: Image.Image) -> Image.Image:
    w, h = im.size
    if w == 0 or h == 0:
        raise ValueError("empty sprite after crop")
    if h >= w:
        new_h = TALL_SIDE
        new_w = max(1, round(w * (TALL_SIDE / h)))
    else:
        new_w = TALL_SIDE
        new_h = max(1, round(h * (TALL_SIDE / w)))
    scaled = im.resize((new_w, new_h), Image.Resampling.LANCZOS)
    quantized = quantize_keep_alpha(scaled)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    x = (CANVAS - new_w) // 2
    y = CANVAS - new_h  # feet on the bottom row
    # Paste without a mask so RGBA is copied as-is (a mask composites
    # against the empty canvas and explodes the 32-colour palette).
    canvas.paste(quantized, (x, y))
    return canvas


def process_one(src: Path, dest: Path) -> None:
    im = Image.open(src)
    keyed = flood_white_to_alpha(im)
    bbox = opaque_bbox(keyed)
    if bbox is None:
        raise ValueError("no opaque pixels after background key")
    cropped = keyed.crop(bbox)
    final = fit_to_canvas(cropped)
    dest.parent.mkdir(parents=True, exist_ok=True)
    final.save(dest, format="PNG")


def dest_for(class_id: str) -> Path:
    if class_id in PLAYER_IDS:
        return OUT_PLAYER / f"{class_id}.png"
    return OUT_TRAINERS / f"{class_id}.png"


def process_all(raw_dir: Path = RAW_DIR) -> list[tuple[str, str]]:
    results: list[tuple[str, str]] = []
    files = sorted(raw_dir.glob("*.png"))
    for src in files:
        class_id = src.stem
        dest = dest_for(class_id)
        try:
            process_one(src, dest)
            results.append((class_id, "OK"))
        except Exception as e:  # noqa: BLE001 — report every failure
            results.append((class_id, f"FAILED postprocess: {e}"))
    return results


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--raw-dir", type=Path, default=RAW_DIR)
    args = p.parse_args(argv)
    if not args.raw_dir.is_dir():
        print(f"no raw dir: {args.raw_dir}", file=sys.stderr)
        return 1
    results = process_all(args.raw_dir)
    ok = sum(1 for _, s in results if s == "OK")
    for cid, status in results:
        print(f"{cid}\t{status}")
    print(f"# processed {len(results)}  OK {ok}  FAILED {len(results) - ok}")
    return 0 if ok == len(results) else 2


if __name__ == "__main__":
    raise SystemExit(main())
