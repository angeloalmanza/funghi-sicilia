"""Campione generico di foto di funghi per la classe 'altro' (solo addestramento, mai nell'app).
Foto di funghi in Sicilia (e Italia) NON appartenenti alle 112 specie dell'app. Max 1500, una per osservazione.
Output: data/photos_altro.json  {"altro": [...]}
"""
import json
import sqlite3
from pathlib import Path

import requests

OUT = Path(__file__).resolve().parent.parent / "data"
API = "https://api.gbif.org/v1/occurrence/search"
SICILY = "POLYGON((12.3 37.9,12.3 36.6,15.7 36.6,15.7 38.0,15.65 38.35,12.7 38.35,12.3 37.9))"
LIC = ["CC0_1_0", "CC_BY_4_0", "CC_BY_NC_4_0"]
MAX = 1500
app = {r[0] for r in sqlite3.connect(OUT / "app_db.sqlite").execute("SELECT key FROM species")}
out, seen = [], set()
for scope, tag in (({"geometry": SICILY}, "sicilia"), ({"country": "IT"}, "italia")):
    offset = 0
    while len(out) < MAX and offset < 9000:
        r = requests.get(API, params={**scope, "kingdomKey": 5, "mediaType": "StillImage", "license": LIC, "limit": 300, "offset": offset}, timeout=90)
        r.raise_for_status()
        d = r.json()
        for o in d["results"]:
            if o["key"] in seen or o.get("speciesKey") in app or not o.get("speciesKey"):
                continue
            for m in o.get("media", []):
                u = m.get("identifier")
                if m.get("type") == "StillImage" and u and u.startswith("http"):
                    seen.add(o["key"])
                    out.append({"occ": o["key"], "url": u, "license": m.get("license") or o.get("license"),
                                "author": m.get("creator") or m.get("rightsHolder") or o.get("recordedBy"),
                                "area": tag, "speciesKey": o["speciesKey"]})
                    break
        if d["endOfRecords"]:
            break
        offset += 300
    print(tag, len(out), flush=True)
out = out[:MAX]
(OUT / "photos_altro.json").write_text(json.dumps({"altro": out}, ensure_ascii=False))
print("FINE altro:", len(out))
