"""Manifest + split (per osservazione, stratificato) + cache immagini 224x224 uint8.
Classi: 112 speciesKey (ordinate) + 'altro'. Foto 'affine-serbica': solo train, peso basso, mai valutazione.
Specie con <5 foto: tutte in train ('non valutabile').
Output: data/model/manifest.json, data/model/cache.npz, data/model/labels.json
"""
import json
import math
import random
import sqlite3
from pathlib import Path

import numpy as np
from PIL import Image

D = Path(__file__).resolve().parents[2] / "data"
M = D / "model"
SIZE = 224
random.seed(42)

done = json.loads((D / "photos_done.json").read_text())
altro = json.loads((D / "photos_altro_done.json").read_text())["altro"]
cat = dict(sqlite3.connect(D / "app_db.sqlite").execute("SELECT key,categoria FROM species"))
keys = sorted(int(k) for k in done if int(k) in cat)
assert len(keys) == 112, len(keys)
classes = [str(k) for k in keys] + ["altro"]
cidx = {c: i for i, c in enumerate(classes)}

items = []  # (path, class, occ, weight, eligible_eval)
for k in keys:
    for p in done[str(k)]:
        f = D / "photos" / str(k) / f"{p['occ']}.webp"
        aff = p.get("area") == "affine-serbica"
        items.append(dict(path=str(f.relative_to(D)), cls=cidx[str(k)], occ=str(p["occ"]), w=0.3 if aff else 1.0, aff=aff))
for p in altro:
    items.append(dict(path=f"photos/altro/{p['occ']}.webp", cls=cidx["altro"], occ=str(p["occ"]), w=1.0, aff=False))

by = {}
for it in items:
    by.setdefault(it["cls"], []).append(it)
notevaluable = []
for c, its in by.items():
    pool = [i for i in its if not i["aff"]]
    for i in its:
        i["split"] = "train"
    if len(pool) < 5:
        notevaluable.append(classes[c])
        continue
    occs = sorted({i["occ"] for i in pool}); random.shuffle(occs)
    n = len(occs); nt = max(1, math.ceil(0.15 * n)); nv = max(1, math.ceil(0.15 * n))
    test, val = set(occs[:nt]), set(occs[nt:nt + nv])
    for i in pool:
        i["split"] = "test" if i["occ"] in test else "val" if i["occ"] in val else "train"

X = np.zeros((len(items), SIZE, SIZE, 3), np.uint8)
for n, it in enumerate(items):
    im = Image.open(D / it["path"]).convert("RGB").resize((SIZE, SIZE), Image.BILINEAR)
    X[n] = np.asarray(im)
np.savez(M / "cache.npz", X=X, y=np.array([i["cls"] for i in items]), w=np.array([i["w"] for i in items], np.float32),
         split=np.array([i["split"] for i in items]))
(M / "manifest.json").write_text(json.dumps(items))
(M / "labels.json").write_text(json.dumps({"classes": classes, "categorie": {c: cat.get(int(c)) for c in classes if c != "altro"},
                                           "input_size": SIZE, "non_valutabili": notevaluable}, indent=1))
from collections import Counter
print(Counter(i["split"] for i in items), "non valutabili:", notevaluable)
