"""Sincronizza data/app_db.sqlite + data/app_photos dentro app/assets e aggiorna pubspec.yaml.

Flutter non elenca le sottocartelle degli asset in modo ricorsivo: ogni assets/photos/<key>/ va
dichiarata a parte. Rieseguibile in ogni momento (copia solo ciò che serve, riscrive version.txt:
l'app ricopia il DB specie quando la versione cambia, il diario è in un DB separato e non si perde).
"""
import hashlib
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA, APP = ROOT / "data", ROOT / "app"
SRC_DB, SRC_PHOTOS = DATA / "app_db.sqlite", DATA / "app_photos"
ASSETS = APP / "assets"
BEGIN, END = "# BEGIN ASSETS (generato da pipeline/07_sync_app_assets.py)", "# END ASSETS"


def main():
    (ASSETS / "db").mkdir(parents=True, exist_ok=True)
    shutil.copy2(SRC_DB, ASSETS / "db" / "species_db.sqlite")

    dst = ASSETS / "photos"
    shutil.rmtree(dst, ignore_errors=True)
    shutil.copytree(SRC_PHOTOS, dst)

    h = hashlib.sha1((ASSETS / "db" / "species_db.sqlite").read_bytes())
    for f in sorted(dst.rglob("*.webp")):
        h.update(str(f.relative_to(dst)).encode())
        h.update(str(f.stat().st_size).encode())
    version = h.hexdigest()[:16]
    (ASSETS / "db" / "version.txt").write_text(version)

    dirs = sorted(p.name for p in dst.iterdir() if p.is_dir())
    block = "\n".join([f"  {BEGIN}", "    - assets/db/", *[f"    - assets/photos/{d}/" for d in dirs], f"  {END}"])
    pub = (APP / "pubspec.yaml").read_text()
    if BEGIN in pub:
        pub = re.sub(re.escape("  " + BEGIN) + r".*?" + re.escape("  " + END), lambda _: block, pub, flags=re.S)
    else:  # prima esecuzione: sostituisce la sezione assets manuale
        pub = re.sub(r"  assets:\n(?:    - [^\n]*\n)+", lambda _: "  assets:\n" + block + "\n", pub, count=1)
    (APP / "pubspec.yaml").write_text(pub)
    n = len(list(dst.rglob("*.webp")))
    print(f"versione {version}: {len(dirs)} cartelle specie, {n} foto, DB {SRC_DB.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
