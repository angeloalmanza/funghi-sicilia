"""Scarica le foto di photos.json, ridimensiona (lato lungo 448px) e salva in WebP q60.
Gli originali non vengono mai salvati su disco. Riprendibile: salta i file già presenti.
Output: data/photos/<speciesKey>/<occ>.webp, data/photos_done.json
"""
import io
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import requests
from PIL import Image, ImageOps

DATA = Path(__file__).resolve().parent.parent / "data"
PHOTOS = DATA / "photos"
MAX_SIDE = 448
QUALITY = 60
MAX_BYTES = 15_000_000  # scarta download enormi

Image.MAX_IMAGE_PIXELS = 100_000_000
s = requests.Session()


def fetch(job):
    key, p = job
    dest = PHOTOS / key / f"{p['occ']}.webp"
    if dest.exists():
        return key, p, True
    try:
        r = s.get(p["url"], timeout=40, stream=True, headers={"User-Agent": "funghi-sicilia-personal/1.0"})
        r.raise_for_status()
        raw = r.raw.read(MAX_BYTES, decode_content=True)
        im = ImageOps.exif_transpose(Image.open(io.BytesIO(raw)))
        im.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)
        dest.parent.mkdir(parents=True, exist_ok=True)
        im.convert("RGB").save(dest, "WEBP", quality=QUALITY, method=6)
        return key, p, True
    except Exception:
        return key, p, False


def main():
    import sys
    name = sys.argv[1] if len(sys.argv) > 1 else "photos"
    photos = json.loads((DATA / f"{name}.json").read_text())
    jobs = [(k, p) for k, ps in photos.items() for p in ps]
    print(f"{len(jobs)} foto da scaricare", flush=True)
    ok = {k: [] for k in photos}
    with ThreadPoolExecutor(12) as ex:
        for i, (key, p, good) in enumerate(ex.map(fetch, jobs), 1):
            if good:
                ok[key].append(p)
            if i % 500 == 0:
                print(f"{i}/{len(jobs)}", flush=True)
    (DATA / f"{name}_done.json").write_text(json.dumps(ok, ensure_ascii=False))
    print("FINE:", sum(len(v) for v in ok.values()), "scaricate")


if __name__ == "__main__":
    main()
