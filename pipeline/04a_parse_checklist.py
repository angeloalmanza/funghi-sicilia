"""Estrae la tabella taxa dalla checklist (Europe PMC XML) -> data/checklist_taxa.json"""
import json, re, sys
import xml.etree.ElementTree as ET
from pathlib import Path

D = Path(__file__).resolve().parent.parent / "data"
root = ET.parse(D / "checklist_raw" / "epmc.xml").getroot()
rows = []
for tw in root.iter("table-wrap"):
    for tr in tw.iter("tr"):
        cells = ["".join(td.itertext()).strip() for td in tr if td.tag in ("td", "th")]
        rows.append(cells)
print(len(rows), "righe; esempio:", rows[:3], rows[-2:])
taxa = []
for c in rows:
    if len(c) >= 4 and c[0] and c[0] not in ("Taxon",):
        taxa.append({"name": re.sub(r"\s+", " ", c[0]), "family": c[1], "provinces": c[2], "ecology": c[3]})
(D / "checklist_taxa.json").write_text(json.dumps(taxa, ensure_ascii=False, indent=1))
print(len(taxa), "taxa")
