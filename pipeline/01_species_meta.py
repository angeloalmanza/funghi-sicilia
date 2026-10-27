"""Elenco specie dell'app (112, da app_db.sqlite) + metadati foto (max 50/specie).

Priorità foto: Sicilia > Italia > resto Europa/Mediterraneo. Solo licenze CC0, CC BY, CC BY-NC.
Output: data/species.json, data/photos.json
"""
import json
import time
from pathlib import Path

import requests

API = "https://api.gbif.org/v1/occurrence/search"
OUT = Path(__file__).resolve().parent.parent / "data"
MAX_PHOTOS = 50
LICENSES = ["CC0_1_0", "CC_BY_4_0", "CC_BY_NC_4_0"]
SICILY = "POLYGON((12.3 37.9,12.3 36.6,15.7 36.6,15.7 38.0,15.65 38.35,12.7 38.35,12.3 37.9))"
# Mediterraneo/Europa meridionale per le foto di riempimento
MED = "POLYGON((-10 35,-10 46,30 46,30 35,-10 35))"

s = requests.Session()


def get(params):
    for attempt in range(8):
        try:
            r = s.get(API, params=params, timeout=90)
            r.raise_for_status()
            return r.json()
        except requests.RequestException:
            time.sleep(min(2 ** attempt, 30))
    raise RuntimeError(f"GBIF fallita: {params}")


def sicily_species():
    """Specie dalla checklist dei macrofunghi siciliani (data/checklist_species.json)."""
    import sqlite3
    con = sqlite3.connect(OUT / "app_db.sqlite")  # solo le 112 specie dell'app
    return sorted(r[0] for r in con.execute("SELECT key FROM species"))


def species_info(key):
    r = s.get(f"https://api.gbif.org/v1/species/{key}", timeout=60)
    r.raise_for_status()
    j = r.json()
    return {k: j.get(k) for k in ("key", "scientificName", "canonicalName", "family", "genus", "order", "class", "phylum")}


def photos_for(key, scope, seen, budget):
    """Una foto per osservazione, fino a `budget`."""
    out = []
    offset = 0
    base = {"speciesKey": key, "mediaType": "StillImage", "license": LICENSES, "limit": 300}
    base.update(scope)
    while len(out) < budget:
        d = get({**base, "offset": offset})
        for o in d["results"]:
            if o["key"] in seen:
                continue
            for m in o.get("media", []):
                url = m.get("identifier")
                if m.get("type") == "StillImage" and url and url.startswith("http"):
                    seen.add(o["key"])
                    out.append({
                        "occ": o["key"], "url": url, "license": m.get("license") or o.get("license"),
                        "author": m.get("creator") or m.get("rightsHolder") or o.get("recordedBy"),
                        "source": m.get("references") or o.get("references"),
                        "country": o.get("countryCode"), "month": o.get("month"),
                        "lat": o.get("decimalLatitude"), "lon": o.get("decimalLongitude"),
                    })
                    break
            if len(out) >= budget:
                break
        if d["endOfRecords"] or offset > 3000:
            break
        offset += 300
    return out


def process(key):
    try:
        return _process(key)
    except Exception as e:
        print(f"ERRORE {key}: {e}"[:200], flush=True)
        return None


def _process(key):
    info = species_info(key)
    n = get({"geometry": SICILY, "speciesKey": key, "limit": 0})["count"]
    info["sicily_records"] = n
    seen, ph = set(), []
    for scope, tag in (({"geometry": SICILY}, "sicilia"), ({"country": "IT"}, "italia"), ({"geometry": MED}, "med")):
        if len(ph) >= MAX_PHOTOS:
            break
        for p in photos_for(key, scope, seen, MAX_PHOTOS - len(ph)):
            p["area"] = tag
            ph.append(p)
    info["n_photos"] = len(ph)
    return info, ph


def main():
    from concurrent.futures import ThreadPoolExecutor
    OUT.mkdir(exist_ok=True)
    keys = sicily_species()
    print(f"{len(keys)} specie dalla checklist", flush=True)
    species, photos = [], {}
    with ThreadPoolExecutor(4) as ex:
        for i, res in enumerate(ex.map(process, keys), 1):
            if res:
                info, ph = res
                species.append(info)
                photos[str(info["key"])] = ph
            if i % 50 == 0:
                print(f"{i}/{len(keys)}", flush=True)
    (OUT / "species.json").write_text(json.dumps(species, ensure_ascii=False, indent=1))
    (OUT / "photos.json").write_text(json.dumps(photos, ensure_ascii=False))
    tot = sum(len(v) for v in photos.values())
    print(f"FINE: {len(species)} specie, {tot} foto, senza foto: {sum(1 for v in photos.values() if not v)}")


if __name__ == "__main__":
    main()
