"""Sceglie 5 foto/specie per l'app: priorità Sicilia > Italia > altro, autori diversi.
Copia in data/app_photos/<speciesKey>/ e lascia in app_db.sqlite solo quelle (con autore/licenza)."""
import shutil
import sqlite3
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "data"
N = 5
RANK = {"sicilia": 0, "italia": 1}
con = sqlite3.connect(DATA / "app_db.sqlite")
out = DATA / "app_photos"
shutil.rmtree(out, ignore_errors=True)
keep, nophoto = [], []
for (k,) in con.execute("SELECT key FROM species").fetchall():
    rows = con.execute("SELECT id,path,author,area FROM photos WHERE species_key=?", (k,)).fetchall()
    rows.sort(key=lambda r: (RANK.get(r[3], 2), r[0]))
    chosen, authors = [], set()
    for r in rows:  # prima autori diversi, poi riempi
        if r[2] not in authors and len(chosen) < N:
            chosen.append(r); authors.add(r[2])
    for r in rows:
        if len(chosen) < N and r not in chosen:
            chosen.append(r)
    if not chosen:
        nophoto.append(k)
    for r in chosen:
        src = DATA / r[1] if not Path(r[1]).is_absolute() else Path(r[1])
        if src.exists():
            (out / str(k)).mkdir(parents=True, exist_ok=True)
            shutil.copy(src, out / str(k) / src.name)
            keep.append(r[0])
con.execute(f"DELETE FROM photos WHERE id NOT IN ({','.join('?'*len(keep))})", keep)
con.commit(); con.execute("VACUUM")
print("foto app:", len(keep), "| specie senza foto:", nophoto)
