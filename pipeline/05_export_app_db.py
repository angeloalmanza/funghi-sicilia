"""Esporta data/app_db.sqlite: solo le specie con categoria != 'sconosciuta' (quelle mostrate nell'app).
Le 'sconosciute' restano in species_db.sqlite e servono solo come classe negativa nell'addestramento.
"""
import shutil
import sqlite3
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "data"
SRC, DST = DATA / "species_db.sqlite", DATA / "app_db.sqlite"

shutil.copy(SRC, DST)
con = sqlite3.connect(DST)
keys = [r[0] for r in con.execute("SELECT key FROM species WHERE categoria='sconosciuta'")]
con.executemany("DELETE FROM species_fts WHERE rowid=?", [(k,) for k in keys])
con.execute("DELETE FROM photos WHERE species_key IN (SELECT key FROM species WHERE categoria='sconosciuta')")
con.execute("DELETE FROM species WHERE categoria='sconosciuta'")
con.commit()
con.execute("VACUUM")
n = con.execute("SELECT count(*) FROM species").fetchone()[0]
print("specie nell'app:", n)
print(con.execute("SELECT categoria,count(*) FROM species GROUP BY 1").fetchall())
print("FTS test 'amanita':", con.execute("SELECT count(*) FROM species_fts WHERE species_fts MATCH 'amanita'").fetchone()[0])
