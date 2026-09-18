#!/usr/bin/env python3
"""Generate raw trainer sprites via the xAI Images API, then post-process.

Resumable: a class whose work/raw/<CLASS_ID>.png already exists is skipped.
Sequential, 1.5 s between requests. One generic reword on moderation refusal.
"""

from __future__ import annotations

import json
import ssl
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path

import certifi
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import postprocess  # noqa: E402

RAW_DIR = ROOT / "work" / "raw"
REPORT = ROOT / "out" / "report.md"
LOG = ROOT / "work" / "generate.log"
AUTH_JSON = Path.home() / ".grok" / "auth.json"
API_URL = "https://api.x.ai/v1/images/generations"
MODEL = "grok-imagine-image"
DELAY_S = 1.5
TIMEOUT_S = 120

STYLE = (
    "Game Boy Advance era pixel-art battle sprite, full body, standing, "
    "facing the viewer, centered, plain pure white background, crisp black "
    "outlines, flat colours, limited palette, no text, no watermark"
)
BACK_STYLE = (
    "Game Boy Advance era pixel-art battle sprite, full body, standing, "
    "seen from behind, one arm extended forward as if throwing a ball, "
    "centered, plain pure white background, crisp black outlines, flat "
    "colours, limited palette, no text, no watermark"
)

# (kind, primary outfit, fallback outfit)  kind = trainer | player
JOBS: list[tuple[str, str, str, str]] = [
    (
        "BEAUTY",
        "trainer",
        "young woman with long wavy hair in a stylish one-piece dress, posing with a parasol",
        "young woman in a stylish dress holding a parasol",
    ),
    (
        "BIKER",
        "trainer",
        "tough man in a leather jacket, bandana and boots, arms crossed",
        "tough man in a leather jacket and bandana",
    ),
    (
        "BIRD_KEEPER",
        "trainer",
        "young man in a khaki safari vest and cap, binoculars around his neck",
        "young man in a safari vest and cap",
    ),
    (
        "BLACKBELT_T",
        "trainer",
        "bald muscular martial artist in a white gi with a black belt, fighting stance",
        "bald muscular man in a martial arts gi",
    ),
    (
        "BLAINE",
        "trainer",
        "older man with wild spiky hair, dark sunglasses and a white lab coat",
        "older man with wild hair, sunglasses and a white coat",
    ),
    (
        "BLUE",
        "trainer",
        "young man with spiky brown hair, black jacket over a white shirt, blue jeans",
        "young man with spiky brown hair in a black jacket and jeans",
    ),
    (
        "BOARDER",
        "trainer",
        "teen snowboarder in winter clothes and goggles, holding a snowboard",
        "teen in winter clothes holding a snowboard",
    ),
    (
        "BROCK",
        "trainer",
        "tan young man with spiky hair, sleeveless brown shirt, khaki pants and a confident grin",
        "tan young man with spiky hair in a sleeveless brown shirt",
    ),
    (
        "BRUNO",
        "trainer",
        "huge muscular man in a karate gi with a black belt, stern face, arms folded",
        "huge muscular martial artist in a gi",
    ),
    (
        "BUGSY",
        "trainer",
        "young boy with a green hat, yellow shirt and shorts, curious smile",
        "young boy in a green hat and yellow shirt",
    ),
    (
        "BUG_CATCHER",
        "trainer",
        "boy in a straw hat and shorts, holding a bug-catching net over his shoulder",
        "boy in a straw hat holding a net",
    ),
    (
        "BURGLAR",
        "trainer",
        "man in a black outfit with a striped shirt and a burglar eye-mask",
        "man in a striped shirt and eye-mask",
    ),
    (
        "CAL",
        "trainer",
        "teen boy with a backwards yellow-and-black cap, red jacket, white shirt and blue jeans",
        "teen boy in a backwards yellow cap and red jacket",
    ),
    (
        "CAMPER",
        "trainer",
        "boy in an orange camping vest, shorts and a small backpack",
        "boy in a camping vest and shorts",
    ),
    (
        "CHAMPION",
        "trainer",
        "man with long orange-red hair, black cape over dark clothes, dragon-scale pattern on the cape",
        "man with long orange-red hair wearing a black cape",
    ),
    (
        "CHUCK",
        "trainer",
        "large smiling martial artist in a gi with a black belt, round belly, hands on hips",
        "large smiling martial artist in a gi",
    ),
    (
        "CLAIR",
        "trainer",
        "tall woman with long blue hair, black outfit and a short cape, confident pose",
        "tall woman with long blue hair in a black outfit",
    ),
    (
        "COOLTRAINERF",
        "trainer",
        "fashionable young woman in a sleek red-and-white crop jacket, shorts and boots",
        "fashionable young woman in a red-and-white outfit",
    ),
    (
        "COOLTRAINERM",
        "trainer",
        "fashionable young man in a sleek blue-and-white jacket, shorts and boots",
        "fashionable young man in a blue-and-white outfit",
    ),
    (
        "ERIKA",
        "trainer",
        "young woman in a traditional floral kimono, long black hair with a flower, calm smile",
        "young woman in a floral kimono with a flower in her hair",
    ),
    (
        "EXECUTIVEF",
        "trainer",
        "stylish woman in a white coat over a black dress, blonde hair, cool expression",
        "stylish blonde woman in a white coat and black dress",
    ),
    (
        "EXECUTIVEM",
        "trainer",
        "man in a black business suit, sunglasses and slicked-back hair",
        "man in a black suit and sunglasses",
    ),
    (
        "FALKNER",
        "trainer",
        "young man with blue hair in a blue kimono-style jacket with a feather motif",
        "young man with blue hair in a blue jacket",
    ),
    (
        "FIREBREATHER",
        "trainer",
        "bald man in a tank top and baggy pants, a small flame at his lips",
        "bald man in a tank top with a small flame",
    ),
    (
        "FISHER",
        "trainer",
        "fisherman in a life-vest and bucket hat, holding a fishing rod",
        "fisherman in a vest and hat holding a rod",
    ),
    (
        "GENTLEMAN",
        "trainer",
        "older gentleman in a suit with a top hat and cane",
        "older man in a suit with a top hat",
    ),
    (
        "GRUNTF",
        "trainer",
        "young woman in a black uniform with a red letter-R badge, ponytail, smug smile",
        "young woman in a black uniform with a red badge, ponytail",
    ),
    (
        "GRUNTM",
        "trainer",
        "young man in a black uniform with a red letter-R badge, messy hair",
        "young man in a black uniform with a red badge",
    ),
    (
        "GUITARIST",
        "trainer",
        "rock musician with spiky hair, leather vest, holding an electric guitar",
        "rock musician with spiky hair holding a guitar",
    ),
    (
        "HIKER",
        "trainer",
        "burly bearded hiker with a big backpack, hiking stick and boots",
        "burly bearded man with a backpack and hiking stick",
    ),
    (
        "JANINE",
        "trainer",
        "ninja girl with purple hair in a ninja outfit, throwing-star motif",
        "ninja girl with purple hair in a ninja outfit",
    ),
    (
        "JASMINE",
        "trainer",
        "gentle woman with long brown hair, white dress and a shy smile",
        "gentle woman with long brown hair in a white dress",
    ),
    (
        "JUGGLER",
        "trainer",
        "man in a colorful circus outfit juggling three balls",
        "man in a colorful outfit juggling balls",
    ),
    (
        "KAREN",
        "trainer",
        "woman with long silver-blonde hair in a yellow-and-black dress, one hand on her hip",
        "woman with long blonde hair in a yellow-and-black dress",
    ),
    (
        "KIMONO_GIRL",
        "trainer",
        "young woman in an ornate kimono holding a fan",
        "young woman in a kimono holding a fan",
    ),
    (
        "KOGA",
        "trainer",
        "ninja man with a mustache in purple ninja garb, stern pose",
        "ninja man with a mustache in purple garb",
    ),
    (
        "LASS",
        "trainer",
        "young girl in a miniskirt and short hair, cheerful pose, hands behind her back",
        "young girl in a miniskirt, cheerful pose",
    ),
    (
        "LT_SURGE",
        "trainer",
        "muscular blond man in a military tank top and camouflage pants, cocky grin",
        "muscular blond man in a tank top and camouflage pants",
    ),
    (
        "MEDIUM",
        "trainer",
        "older woman in a kimono with a mystic look, hands raised as if channeling",
        "older woman in a kimono with a mystic look",
    ),
    (
        "MISTY",
        "trainer",
        "girl with orange hair in a yellow tank top and red shorts, hands on hips",
        "girl with orange hair in a yellow top and red shorts",
    ),
    (
        "MORTY",
        "trainer",
        "blond young man in a purple scarf and long dark coat",
        "blond young man in a purple scarf and dark coat",
    ),
    (
        "MYSTICALMAN",
        "trainer",
        "eccentric man with teal hair, purple cape and an ornate high-collar outfit",
        "eccentric man with teal hair and a purple cape",
    ),
    (
        "OFFICER",
        "trainer",
        "police officer in a blue uniform and peaked cap, standing at attention",
        "police officer in a blue uniform and cap",
    ),
    (
        "PICNICKER",
        "trainer",
        "girl in a sunhat and picnic dress, holding a small basket",
        "girl in a sunhat and picnic dress",
    ),
    (
        "POKEFANF",
        "trainer",
        "plump woman in a polka-dot dress and sunhat, delighted expression",
        "plump woman in a polka-dot dress and sunhat",
    ),
    (
        "POKEFANM",
        "trainer",
        "plump man in a sunhat and a shirt covered in round ball patterns",
        "plump man in a sunhat and a patterned shirt",
    ),
    (
        "POKEMANIAC",
        "trainer",
        "man with long wild purple hair, dark clothes, intense stare",
        "man with long wild purple hair in dark clothes",
    ),
    (
        "POKEMON_PROF",
        "trainer",
        "elderly professor in a lab coat with white hair, kind smile",
        "elderly man in a lab coat with white hair",
    ),
    (
        "PRYCE",
        "trainer",
        "elderly man in a heavy winter coat and scarf, calm weathered face",
        "elderly man in a heavy winter coat and scarf",
    ),
    (
        "PSYCHIC_T",
        "trainer",
        "slender person in a purple robe with a mystic pose, hands raised",
        "person in a purple robe with a mystic pose",
    ),
    (
        "RED",
        "trainer",
        "silent teen boy in a red-and-white cap, red sleeveless vest, blue jeans and a yellow backpack",
        "teen boy in a red cap, red vest, jeans and a yellow backpack",
    ),
    (
        "RIVAL1",
        "trainer",
        "teen with long red hair covering one eye, black turtleneck, scowling",
        "teen with long red hair covering one eye in a black turtleneck",
    ),
    (
        "RIVAL2",
        "trainer",
        "older teen with long red hair covering one eye, black jacket with gold trim, scowling",
        "older teen with long red hair in a black jacket",
    ),
    (
        "SABRINA",
        "trainer",
        "woman with long black hair in a red dress, calm psychic pose, eyes half-lidded",
        "woman with long black hair in a red dress",
    ),
    (
        "SAGE",
        "trainer",
        "elderly man in traditional monk robes, balding, serene expression",
        "elderly man in traditional monk robes",
    ),
    (
        "SAILOR",
        "trainer",
        "sailor in a navy uniform and sailor cap, sturdy stance",
        "sailor in a navy uniform and cap",
    ),
    (
        "SCHOOLBOY",
        "trainer",
        "boy in a school uniform with a backpack, neat hair",
        "boy in a school uniform with a backpack",
    ),
    (
        "SCIENTIST",
        "trainer",
        "scientist in a lab coat and glasses, holding a test tube",
        "scientist in a lab coat and glasses",
    ),
    (
        "SKIER",
        "trainer",
        "woman skier in winter gear and goggles, holding ski poles",
        "woman in winter ski gear holding poles",
    ),
    (
        "SUPER_NERD",
        "trainer",
        "skinny young man with glasses, messy hair and an awkward sweater",
        "skinny young man with glasses and messy hair",
    ),
    (
        "SWIMMERF",
        "trainer",
        "young woman in a one-piece swimsuit, standing on a plain white background",
        "young woman in a swimsuit",
    ),
    (
        "SWIMMERM",
        "trainer",
        "young man in swim trunks, standing on a plain white background",
        "young man in swim trunks",
    ),
    (
        "TEACHER",
        "trainer",
        "woman with glasses in a modest dress, holding a pointer stick",
        "woman with glasses in a dress holding a pointer",
    ),
    (
        "TWINS",
        "trainer",
        "two identical young girls in matching outfits standing side by side, holding hands",
        "two identical young girls in matching dresses standing together",
    ),
    (
        "WHITNEY",
        "trainer",
        "cheerful girl with pink pigtails in a white and pink outfit",
        "cheerful girl with pink pigtails in a pink-and-white outfit",
    ),
    (
        "WILL",
        "trainer",
        "young man with red hair in a psychic robe with a fox-like mask motif",
        "young man with red hair in a colorful mystic robe",
    ),
    (
        "YOUNGSTER",
        "trainer",
        "cheerful boy in a backwards cap, t-shirt and shorts, hands on hips",
        "cheerful boy in a backwards cap, t-shirt and shorts",
    ),
    (
        "GOLD_BACK",
        "player",
        "boy seen from behind, backwards yellow-and-black cap, red jacket, black shorts, big backpack, one arm out throwing",
        "boy seen from behind wearing a backwards yellow cap, red jacket, black shorts and a backpack, one arm extended",
    ),
    (
        "KRIS_BACK",
        "player",
        "girl seen from behind, teal hair in pigtails, red-and-white top, yellow shorts, backpack, one arm out throwing",
        "girl seen from behind with teal pigtails, red-and-white top, yellow shorts and a backpack, one arm extended",
    ),
]


def log(msg: str) -> None:
    line = f"{datetime.now(timezone.utc).strftime('%H:%M:%S')} {msg}"
    print(line, flush=True)
    with LOG.open("a", encoding="utf-8") as f:
        f.write(line + "\n")


def load_jwt() -> str:
    auth = json.loads(AUTH_JSON.read_text())
    rec = next(iter(auth.values()))
    exp = rec.get("expires_at")
    if exp:
        log(f"jwt expires_at={exp}")
    return rec["key"]


def ssl_context() -> ssl.SSLContext:
    return ssl.create_default_context(cafile=certifi.where())


def full_prompt(kind: str, outfit: str) -> str:
    style = BACK_STYLE if kind == "player" else STYLE
    return f"{style}. {outfit}."


def is_refusal(status: int, body: str) -> bool:
    if status not in (400, 403, 422):
        return False
    b = body.lower()
    keys = (
        "moderat",
        "violat",
        "safety",
        "content policy",
        "refused",
        "not allowed",
        "disallowed",
        "blocked",
        "image request rejected",
    )
    return any(k in b for k in keys)


def request_image(prompt: str, jwt: str, ctx: ssl.SSLContext) -> tuple[str, bytes | None, str]:
    """Return (status, jpeg_bytes_or_None, detail). status is ok|refusal|error."""
    payload = json.dumps(
        {
            "model": MODEL,
            "prompt": prompt,
            "n": 1,
            "aspect_ratio": "1:1",
        }
    ).encode()
    req = urllib.request.Request(
        API_URL,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {jwt}",
            "User-Agent": "crystal-trainer-art/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=TIMEOUT_S) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        if is_refusal(e.code, body):
            return "refusal", None, f"HTTP {e.code} {body[:300]}"
        return "error", None, f"HTTP {e.code} {body[:300]}"
    except Exception as e:  # noqa: BLE001
        return "error", None, f"{type(e).__name__}: {e}"

    items = data.get("data") or []
    if not items or not items[0].get("url"):
        return "error", None, f"no url in response: {json.dumps(data)[:300]}"
    url = items[0]["url"]
    ireq = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(ireq, context=ctx, timeout=TIMEOUT_S) as resp:
            jpeg = resp.read()
    except Exception as e:  # noqa: BLE001
        return "error", None, f"download {type(e).__name__}: {e}"
    if jpeg[:2] != b"\xff\xd8":
        return "error", None, f"not jpeg magic={jpeg[:8]!r}"
    return "ok", jpeg, url


def jpeg_to_png(jpeg: bytes, dest: Path) -> None:
    im = Image.open(BytesIO(jpeg))
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest, format="PNG")


def write_report(rows: list[dict], extra: str = "") -> None:
    ok = sum(1 for r in rows if r["status"] == "OK")
    failed = sum(1 for r in rows if r["status"].startswith("FAILED"))
    pending = sum(1 for r in rows if r["status"] == "PENDING")
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    lines = [
        "# Crystal trainer art",
        "",
        f"Updated: {now}",
        f"OK: {ok}  FAILED: {failed}  PENDING: {pending}  TOTAL: {len(rows)}",
        extra.strip(),
        "",
        "class_id | status | attempts | prompt",
        "---|---|---|---",
    ]
    for r in rows:
        prompt = r["prompt"].replace("|", "/")
        lines.append(f"{r['id']} | {r['status']} | {r['attempts']} | {prompt}")
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")


def generate_one(
    class_id: str,
    kind: str,
    primary: str,
    fallback: str,
    jwt: str,
    ctx: ssl.SSLContext,
) -> dict:
    dest = RAW_DIR / f"{class_id}.png"
    if dest.exists() and dest.stat().st_size > 0:
        prompt = full_prompt(kind, primary)
        log(f"SKIP {class_id} raw exists")
        return {
            "id": class_id,
            "status": "OK",
            "attempts": 0,
            "prompt": prompt,
            "note": "resumed existing raw",
        }

    attempts = 0
    last_err = ""
    used_prompt = ""
    for outfit in (primary, fallback):
        prompt = full_prompt(kind, outfit)
        used_prompt = prompt
        attempts += 1
        log(f"GEN {class_id} attempt {attempts}")
        status, jpeg, detail = request_image(prompt, jwt, ctx)
        if status == "ok" and jpeg:
            jpeg_to_png(jpeg, dest)
            log(f"OK  {class_id} {dest.stat().st_size} bytes")
            return {
                "id": class_id,
                "status": "OK",
                "attempts": attempts,
                "prompt": prompt,
                "note": "",
            }
        last_err = detail
        log(f"{status.upper()} {class_id}: {detail[:200]}")
        if status == "refusal":
            continue
        # transient error: one extra retry of the same prompt
        time.sleep(2)
        status, jpeg, detail = request_image(prompt, jwt, ctx)
        attempts += 1
        if status == "ok" and jpeg:
            jpeg_to_png(jpeg, dest)
            log(f"OK  {class_id} {dest.stat().st_size} bytes (retry)")
            return {
                "id": class_id,
                "status": "OK",
                "attempts": attempts,
                "prompt": prompt,
                "note": "transient retry",
            }
        last_err = detail
        log(f"{status.upper()} {class_id}: {detail[:200]}")
        if status == "refusal":
            continue
        break

    return {
        "id": class_id,
        "status": f"FAILED {last_err[:180]}",
        "attempts": attempts,
        "prompt": used_prompt,
        "note": last_err,
    }


def main() -> int:
    LOG.parent.mkdir(parents=True, exist_ok=True)
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    rows = [
        {
            "id": cid,
            "status": "PENDING",
            "attempts": 0,
            "prompt": full_prompt(kind, primary),
            "note": "",
        }
        for cid, kind, primary, _ in JOBS
    ]
    by_id = {r["id"]: r for r in rows}
    write_report(rows, extra="Starting generation.")
    jwt = load_jwt()
    ctx = ssl_context()

    for i, (cid, kind, primary, fallback) in enumerate(JOBS):
        row = generate_one(cid, kind, primary, fallback, jwt, ctx)
        by_id[cid].update(row)
        write_report(rows, extra=f"Last: {cid} {row['status']}")
        if i != len(JOBS) - 1:
            time.sleep(DELAY_S)

    log("postprocess begin")
    pp = postprocess.process_all(RAW_DIR)
    pp_map = dict(pp)
    for r in rows:
        if r["status"] == "OK":
            pstatus = pp_map.get(r["id"])
            if pstatus is None:
                r["status"] = "FAILED postprocess: no output"
            elif pstatus != "OK":
                r["status"] = pstatus
    write_report(rows, extra="Generation and post-process complete.")
    ok = sum(1 for r in rows if r["status"] == "OK")
    failed = len(rows) - ok
    log(f"DONE OK={ok} FAILED={failed} report={REPORT}")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
