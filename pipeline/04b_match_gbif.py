"""Normalizza i taxa della checklist su GBIF (species/match) -> data/checklist_species.json + checklist_unmatched.json"""
import json, time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import requests

D = Path(__file__).resolve().parent.parent / "data"
taxa = json.loads((D / "checklist_taxa.json").read_text())
s = requests.Session()
INFRA = (" subsp. ", " var. ", " f. ", " fo. ", " forma ", " subvar. ")


def match(t):
    name = t["name"]
    for a in range(5):
        try:
            r = s.get("https://api.gbif.org/v1/species/match", params={"name": name, "kingdom": "Fungi", "strict": "false"}, timeout=40)
            r.raise_for_status()
            return t, r.json()
        except requests.RequestException:
            time.sleep(2 ** a)
    return t, {}


ok, bad = [], []
with ThreadPoolExecutor(8) as ex:
    for t, m in ex.map(match, taxa):
        sk = m.get("speciesKey")
        infra = any(i in t["name"] for i in INFRA)
        note = f"Province: {t['provinces']}; ecologia: {t['ecology']}" + ("; infraspecifico ricondotto alla specie" if infra else "")
        if sk and m.get("matchType") in ("EXACT", "FUZZY", "HIGHERRANK") and m.get("rank") in ("SPECIES", "SUBSPECIES", "VARIETY", "FORM", "INFRASPECIFIC_NAME") and m.get("kingdom") == "Fungi":
            ok.append({"checklist_name": t["name"], "accepted_name": m.get("species") or m.get("canonicalName"), "speciesKey": sk,
                       "family": m.get("family") or t["family"], "match_confidence": m.get("confidence"),
                       "match_type": m.get("matchType"), "gbif_status": m.get("status"), "synonym": m.get("synonym"),
                       "note_checklist": note})
        else:
            bad.append({"checklist_name": t["name"], "family": t["family"], "matchType": m.get("matchType"), "rank": m.get("rank"), "note_checklist": note})
(D / "checklist_species.json").write_text(json.dumps(ok, ensure_ascii=False, indent=1))
(D / "checklist_unmatched.json").write_text(json.dumps(bad, ensure_ascii=False, indent=1))
keys = {o["speciesKey"] for o in ok}
print(len(ok), "abbinati,", len(bad), "non abbinati,", len(keys), "speciesKey distinte")
print("sinonimi:", sum(1 for o in ok if o["synonym"]), "| confidenza<90:", sum(1 for o in ok if (o["match_confidence"] or 0) < 90), "| FUZZY:", sum(1 for o in ok if o["match_type"] == "FUZZY"), "| HIGHERRANK:", sum(1 for o in ok if o["match_type"] == "HIGHERRANK"))
