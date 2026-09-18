# Crystal trainer art — generation charter (Grok worker)

Goal: a coloured battle-sprite set for the Gold/Silver/Crystal trainer classes,
to be shown by a LÖVE game mod. You generate and post-process the images; the
mod code is written separately. Work only inside this directory.

## What to produce

1. `out/trainers/<CLASS_ID>.png` — one FRONT-facing, full-body sprite per row of
   `classes.tsv` (67 classes). Gym leaders / Elite Four / rival / champions are
   keyed by character name; the display name tells you the archetype.
2. `out/player/GOLD_BACK.png` and `out/player/KRIS_BACK.png` — the two player
   characters seen FROM BEHIND (standing, seen from behind, one arm out as if
   throwing a ball): GOLD = boy with a backwards yellow-and-black cap, red
   jacket, black shorts, big backpack; KRIS = girl with teal hair in pigtails,
   red-and-white top, yellow shorts, backpack.
3. `out/report.md` — one line per file: class id, prompt used, attempts, and
   OK / FAILED (reason).

## How to generate

- Use the xAI Images API you already verified works from here
  (`POST https://api.x.ai/v1/images/generations`, model `grok-imagine-image`,
  1024x1024). Keep raw downloads in `work/raw/<CLASS_ID>.png`; never
  re-generate a class whose raw file already exists (resumable).
- Style, in every prompt: "Game Boy Advance era pixel-art battle sprite, full
  body, standing, facing the viewer, centered, plain pure white background,
  crisp black outlines, flat colours, limited palette, no text, no watermark".
  `work/style_test_from_grok.png` is the look we want.
- Describe each class by OUTFIT AND ROLE, never by franchise or character
  names — prompts naming the franchise or its characters get blocked by
  moderation. Examples: YOUNGSTER = "cheerful boy in a backwards cap, t-shirt
  and shorts, hands on hips"; HIKER = "burly bearded hiker with a big
  backpack, hiking stick and boots"; KIMONO_GIRL = "young woman in an ornate
  kimono holding a fan"; FALKNER = "young man with blue hair in a blue
  kimono-style jacket with a feather motif"; WHITNEY = "cheerful girl with
  pink pigtails in a white and pink outfit"; MORTY = "blond young man in a
  purple scarf and long dark coat". Write a sensible description for every
  class from your own knowledge of the Gen 2 trainer classes.
- If a prompt is refused, reword once (more generic outfit wording) and retry;
  after two refusals mark FAILED in the report and move on.
- Sequential requests, 1–2 s apart.

## Post-processing (Python 3 + Pillow; script it as `tools/postprocess.py`)

For each raw 1024x1024 image:
1. Make the near-white background transparent (flood-fill from the four
   corners with a tolerance, so white inside the sprite survives), then crop
   to the opaque bounding box.
2. Fit into a 64x64 canvas keeping aspect: scale so the taller side is 60 px
   (LANCZOS), quantize to at most 32 colours without dithering, then place it
   with its feet on the bottom row and centred horizontally.
3. Save as RGBA PNG with real transparency. Every sprite's feet on the bottom
   edge — that is the ground line the game uses.

## Definition of done

- 69 PNGs (or FAILED lines for the ones moderation would not allow) in `out/`,
  `report.md` filled in, `tools/postprocess.py` re-runnable on `work/raw/`.
- Do not touch anything outside this directory. Do not commit to git.
