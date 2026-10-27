"""Foto extra (qualsiasi licenza, uso personale) per specie senza foto con licenza libera.
Fonti: GBIF senza filtro licenza, poi iNaturalist (research grade). Max 20 foto/specie.
Aggiorna data/photos.json e data/photos_done.json; salva WebP in data/photos/<key>/<id>.webp."""
import io
import json
import time
from pathlib import Path

import requests
from PIL import Image, ImageOps

DATA = Path(__file__).resolve().parent.parent / "data"
SPECIES = {2534290: "Pholiota nameko", 2594623: "Morchella hortensis", 5241396: "Volvariella esculenta",
           5497524: "Discina fastigiata", 7243143: "Psilocybe moravica"}
MAX = 20
s = requests.Session()
s.headers["User-Agent"] = "funghi-sicilia-personal/1.0"


def getj(url, params):
    for a in range(6):
        try:
            r = s.get(url, params=params, timeout=60)
            r.raise_for_status()
            return r.json()
        except requests.RequestException:
            time.sleep(min(2 ** a, 20))
    return {}


def gbif(key):
    out, seen = [], set()
    d = getj("https://api.gbif.org/v1/occurrence/search", {"speciesKey": key, "mediaType": "StillImage", "limit": 300})
    for o in d.get("results", []):
        for m in o.get("media", []):
            u = m.get("identifier")
            if m.get("type") == "StillImage" and u and u.startswith("http") and u not in seen:
                seen.add(u)
                out.append({"occ": o["key"], "url": u, "license": m.get("license") or o.get("license") or "all rights reserved",
                            "author": m.get("creator") or m.get("rightsHolder") or o.get("recordedBy"),
                            "source": m.get("references") or o.get("references"), "country": o.get("countryCode"),
                            "month": o.get("month"), "lat": o.get("decimalLatitude"), "lon": o.get("decimalLongitude"), "area": "gbif-any"})
                break
    return out


def inat(name):
    out = []
    d = getj("https://api.inaturalist.org/v1/observations",
             {"taxon_name": name, "quality_grade": "research", "photos": "true", "per_page": 30, "order_by": "votes"})
    for o in d.get("results", []):
        for ph in o.get("photos", [])[:2]:
            u = (ph.get("url") or "").replace("square", "large")
            if u:
                out.append({"occ": f"inat{ph['id']}", "url": u,
                            "license": ph.get("license_code") or "all rights reserved",
                            "author": (o.get("user") or {}).get("name") or (o.get("user") or {}).get("login"),
                            "source": o.get("uri"), "country": None, "month": None, "lat": None, "lon": None, "area": "inat-any"})
    return out


def fetch(p, key):
    dest = DATA / "photos" / str(key) / f"{p['occ']}.webp"
    if dest.exists():
        return True
    try:
        r = s.get(p["url"], timeout=40)
        r.raise_for_status()
        im = ImageOps.exif_transpose(Image.open(io.BytesIO(r.content[:15_000_000])))
        im.thumbnail((448, 448), Image.LANCZOS)
        dest.parent.mkdir(parents=True, exist_ok=True)
        im.convert("RGB").save(dest, "WEBP", quality=60, method=6)
        return True
    except Exception:
        return False


photos = json.loads((DATA / "photos.json").read_text())
done = json.loads((DATA / "photos_done.json").read_text())
for key, name in SPECIES.items():
    cands = gbif(key)
    if len(cands) < 8:
        cands += inat(name)
    ok = []
    for p in cands:
        if len(ok) >= MAX:
            break
        if fetch(p, key):
            ok.append(p)
        time.sleep(0.3)
    photos[str(key)] = ok
    done[str(key)] = ok
    print(f"{name}: candidate {len(cands)}, scaricate {len(ok)}", flush=True)
(DATA / "photos.json").write_text(json.dumps(photos, ensure_ascii=False))
(DATA / "photos_done.json").write_text(json.dumps(done, ensure_ascii=False))
