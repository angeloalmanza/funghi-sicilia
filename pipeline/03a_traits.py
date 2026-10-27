"""Testo descrittivo delle schede: Wikipedia (it + en) e nomi volgari italiani da GBIF.

Wikipedia NON è usata per la commestibilità (quella la decide solo 03_build_db.py da fonti
ufficiali). Qui restano solo: nomi italiani, caratteri morfologici, habitat, stagione/ecologia,
descrizione, specie simili. Ogni campo ha l'URL della fonte; se manca resta assente.
Input : data/checklist_species.json + data/tossiche.json + data/edibili_legali.json (chiavi GBIF)
Output: data/traits.json  {speciesKey: scheda}, data/traits_coverage.txt
Uso   : 03a_traits.py [--seed]   (--seed: solo le specie prioritarie, per test)
"""
import json
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import requests

DATA = Path(__file__).resolve().parent.parent / "data"
s = requests.Session()
s.headers["User-Agent"] = "funghi-sicilia-personal/1.0 (uso personale)"

SEED = [
    # mortali / tossiche
    "Amanita phalloides", "Amanita verna", "Amanita virosa", "Amanita muscaria", "Amanita pantherina",
    "Cortinarius orellanus", "Omphalotus olearius", "Entoloma sinuatum", "Clitocybe rivulosa",
    "Clitocybe dealbata", "Lepiota brunneoincarnata", "Lepiota helveola", "Galerina marginata",
    "Gyromitra esculenta", "Agaricus xanthodermus", "Hypholoma fasciculare", "Tricholoma pardinum",
    "Boletus satanas", "Rubroboletus satanas", "Paxillus involutus", "Ramaria pallida",
    "Chlorophyllum molybdites", "Inocybe erubescens", "Psilocybe semilanceata",
    # commestibili comuni
    "Pleurotus eryngii", "Pleurotus ostreatus", "Boletus aereus", "Boletus aestivalis", "Boletus edulis",
    "Cantharellus cibarius", "Amanita caesarea", "Lactarius deliciosus", "Macrolepiota procera",
    "Agaricus campestris", "Armillaria mellea", "Cyclocybe aegerita", "Craterellus cornucopioides",
    "Hydnum repandum", "Clitopilus prunulus", "Marasmius oreades", "Coprinus comatus",
    "Lepista nuda", "Calocybe gambosa", "Morchella esculenta", "Tuber melanosporum", "Terfezia arenaria",
]


def api(lang, **params):
    params.update(format="json")
    for attempt in range(5):
        try:
            r = s.get(f"https://{lang}.wikipedia.org/w/api.php", params=params, timeout=60)
            r.raise_for_status()
            return r.json()
        except requests.RequestException:
            time.sleep(2 ** attempt)
    return {}


def wiki_pages(lang, names):
    """{nome richiesto: (titolo, wikitext)} per le pagine esistenti, 40 titoli per richiesta."""
    out = {}
    for i in range(0, len(names), 40):
        chunk = names[i:i + 40]
        d = api(lang, action="query", prop="revisions", rvprop="content", rvslots="main",
                titles="|".join(chunk), redirects=1)
        q = d.get("query", {})
        # catena normalized/redirects -> titolo finale
        fwd = {n: n for n in chunk}
        for m in q.get("normalized", []):
            for k, v in fwd.items():
                if v == m["from"]:
                    fwd[k] = m["to"]
        for m in q.get("redirects", []):
            for k, v in fwd.items():
                if v == m["from"]:
                    fwd[k] = m["to"]
        pages = {p["title"]: p for p in q.get("pages", {}).values() if "revisions" in p}
        for req, final in fwd.items():
            p = pages.get(final)
            if p:
                out[req] = (p["title"], p["revisions"][0]["slots"]["main"]["*"])
    return out


def strip_wiki(t):
    t = re.sub(r"<!--.*?-->", "", t, flags=re.S)
    t = re.sub(r"<ref[^>]*?/>", "", t)
    t = re.sub(r"<ref[^>]*>.*?</ref>", "", t, flags=re.S)
    for _ in range(6):  # template annidati
        t = re.sub(r"\{\{[^{}]*\}\}", "", t)
    t = re.sub(r"\[\[(?:File|Immagine|Image|Categoria|Category):[^\]]*\]\]", "", t, flags=re.I)
    t = re.sub(r"\[\[(?:[^\]|]*\|)?([^\]]*)\]\]", r"\1", t)
    t = re.sub(r"'{2,}", "", t)
    t = re.sub(r"<[^>]+>", "", t)
    t = re.sub(r"\[https?://\S+ ([^\]]+)\]", r"\1", t)
    return re.sub(r"[ \t]+", " ", re.sub(r"\n{3,}", "\n\n", t)).strip()


def template_fields(wt, names):
    """Campi |k=v del primo template il cui nome (minuscolo) è in `names`."""
    for m in re.finditer(r"\{\{\s*([^|{}\n]+?)\s*\n?\|", wt):
        if m.group(1).strip().lower() not in names:
            continue
        i, depth, j = m.start(), 0, m.start()
        while j < len(wt):
            if wt.startswith("{{", j):
                depth += 1; j += 2
            elif wt.startswith("}}", j):
                depth -= 1; j += 2
                if depth == 0:
                    break
            else:
                j += 1
        body = wt[i + 2:j - 2]
        f = {}
        for line in re.split(r"\n\s*\|", "\n" + body.split("|", 1)[1] if "|" in body else ""):
            if "=" in line:
                k, v = line.split("=", 1)
                f[k.strip().lower()] = strip_wiki(v).strip()
        return f
    return {}


SECTIONS = {
    "descrizione": ("descrizione", "description", "morfologia", "caratteristiche"),
    "habitat": ("habitat", "ecologia", "distribuzione e habitat", "ecology", "habitat and distribution"),
    "commestibilita": ("commestibilità", "edibility", "usi", "uso", "uso alimentare", "usi alimentari", "culinary uses"),
    "tossicita": ("tossicità", "tossicologia", "sintomatologia", "avvelenamento", "toxicity", "tossicità e sintomi"),
    "specie_simili": ("specie simili", "confusione con altre specie", "similar species", "possibili confusioni",
                      "confusione", "somiglianze", "specie simili e confusione"),
}


def sections(wt):
    parts = re.split(r"^(={2,4})\s*(.+?)\s*\1\s*$", wt, flags=re.M)
    found = {}
    for i in range(1, len(parts) - 2, 3):
        title = strip_wiki(parts[i + 1]).lower()
        for key, names in SECTIONS.items():
            if title in names and key not in found:
                txt = strip_wiki(parts[i + 2])
                if txt:
                    found[key] = txt[:1500]
    return found


def lead(wt):
    body = re.split(r"^==", wt, flags=re.M)[0]
    txt = strip_wiki(body)
    paras = [p for p in txt.split("\n\n") if len(p) > 80]
    return paras[0][:900] if paras else None


def valid(name, title, wt):
    """La pagina deve riguardare davvero quella specie (non il genere, non una disambigua)."""
    if re.search(r"\{\{\s*(disambigua|disambig)", wt, flags=re.I):
        return False
    epithet = name.split()[-1].lower()
    return epithet in title.lower() or epithet in wt[:4000].lower()


def vernacular_it(key):
    names = []
    for attempt in range(3):
        try:
            r = s.get(f"https://api.gbif.org/v1/species/{key}/vernacularNames", params={"limit": 200}, timeout=40)
            r.raise_for_status()
            for v in r.json().get("results", []):
                if v.get("language") in ("ita", "it"):
                    names.append(v["vernacularName"])
            break
        except requests.RequestException:
            time.sleep(2)
    names = [n.strip(" *.") for n in names]
    return list(dict.fromkeys(n for n in names if n and "vedi testo" not in n.lower()))


def build(species):
    names = []
    for sp in species:
        names += [n for n in sp["names"] if n not in names]
    it = wiki_pages("it", names)
    en = wiki_pages("en", names)
    with ThreadPoolExecutor(8) as ex:
        vern = dict(zip((sp["key"] for sp in species), ex.map(lambda sp: vernacular_it(sp["key"]), species)))
    out = {}
    for sp in species:
        name = sp["canonicalName"]
        sch = {"nome_scientifico": name, "nomi_italiani": [], "fonti": []}
        sch["nomi_italiani"] = list(vern.get(sp["key"], []))
        if sch["nomi_italiani"]:
            sch["fonti"].append(f"https://api.gbif.org/v1/species/{sp['key']}/vernacularNames")
        it_name = next((n for n in sp["names"] if n in it and valid(n, *it[n])), None)
        en_name = next((n for n in sp["names"] if n in en and valid(n, *en[n])), None)
        if it_name:
            title, wt = it[it_name]
            url = "https://it.wikipedia.org/wiki/" + title.replace(" ", "_")
            sch["fonti"].append(url)
            tb = template_fields(wt, {"tassobox"})
            for n in re.split(r",|;|\n", tb.get("nomicomuni", "")):
                n = n.strip(" *.")
                if n and "vedi testo" not in n.lower() and not n.startswith("(") and n not in sch["nomi_italiani"]:
                    sch["nomi_italiani"].append(n)
            fg = template_fields(wt, {"fungo", "micomorfobox"})
            for k_src, k_dst in (("tipo_imenio", "imenio"), ("tipo_lamelle", "lamelle"), ("cappello", "cappello"),
                                 ("velo", "velo"), ("ecologia", "ecologia"), ("sporata", "sporata"), ("carne", "carne")):
                if fg.get(k_src):
                    sch[k_dst] = fg[k_src]
            sec = sections(wt)
            sec.pop("commestibilita", None)  # mai commestibilità da Wikipedia
            sch.update(sec)
            sch["riassunto"] = lead(wt)
            sch["wikipedia_it"] = url
        if en_name:
            title, wt = en[en_name]
            url = "https://en.wikipedia.org/wiki/" + title.replace(" ", "_")
            mb = template_fields(wt, {"mycomorphbox"})
            for k_src, k_dst in (("ecologicaltype", "ecologia_en"), ("sporeprintcolor", "sporata_en"),
                                 ("hymeniumtype", "imenio_en"), ("capshape", "cappello_en")):
                if mb.get(k_src):
                    sch[k_dst] = mb[k_src]
            if url not in sch["fonti"]:
                sch["fonti"].append(url)
            sch["wikipedia_en"] = url
            for k, v in sections(wt).items():
                if k != "commestibilita":
                    sch.setdefault(k + "_en", v)
        simili = " ".join(sch.get(k, "") for k in ("specie_simili", "specie_simili_en"))
        if re.search(r"mortal|velen|tossic|poison|deadly|toxic|phalloides|virosa|verna", simili, re.I):
            sch["avvertenza_sosia"] = "Le fonti segnalano possibili confusioni con specie tossiche/mortali: vedi 'specie simili'."
        out[str(sp["key"])] = sch
    return out


def load_species():
    """Specie da descrivere: checklist siciliana + tossiche + elenchi legali (chiavi GBIF)."""
    sp = {}
    for r in json.loads((DATA / "checklist_species.json").read_text()):
        k = r.get("speciesKey")
        if not k:
            continue
        e = sp.setdefault(k, {"key": k, "canonicalName": r["accepted_name"], "names": []})
        for n in (r["accepted_name"], " ".join(r["checklist_name"].split()[:2])):
            if n not in e["names"]:
                e["names"].append(n)
    for r in json.loads((DATA / "tossiche.json").read_text())["specie"]:
        k = r["gbif"].get("speciesKey")
        if k and k not in sp:
            sp[k] = {"key": k, "canonicalName": r["gbif"]["nome_accettato"], "names": [r["gbif"]["nome_accettato"]]}
    ed = json.loads((DATA / "edibili_legali.json").read_text())
    for lst in ("dpr376_allegatoI", "sicilia_2009_vigente"):
        for r in ed[lst]:
            k = r.get("speciesKey") or (r.get("acceptedKey") if r.get("rank_accettato") == "SPECIES" else None)
            if k and k not in sp:
                sp[k] = {"key": k, "canonicalName": r["nome_accettato"], "names": [r["nome_accettato"]]}
    return list(sp.values())


def main():
    species = load_species()
    if "--seed" in sys.argv:
        species = [sp for sp in species if sp["canonicalName"] in SEED]
    traits = build(species)
    suffix = "_seed" if "--seed" in sys.argv else ""
    (DATA / f"traits{suffix}.json").write_text(json.dumps(traits, ensure_ascii=False, indent=1))
    n = len(traits)
    rep = (f"specie: {n}\n"
           f"con nome italiano: {sum(1 for t in traits.values() if t['nomi_italiani'])}\n"
           f"con testo Wikipedia it: {sum(1 for t in traits.values() if 'wikipedia_it' in t)}\n"
           f"con testo Wikipedia en: {sum(1 for t in traits.values() if 'wikipedia_en' in t)}\n"
           f"con habitat/ecologia: {sum(1 for t in traits.values() if 'habitat' in t or 'ecologia' in t)}\n")
    (DATA / f"traits_coverage{suffix}.txt").write_text(rep)
    print(rep)


if __name__ == "__main__":
    main()
