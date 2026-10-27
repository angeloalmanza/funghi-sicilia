"""Elenco legale delle specie commestibili: DPR 376/1995 All. I + D.P.Reg. Sicilia 19/11/2007 e 4/8/2009.

Legge i testi ufficiali estratti in data/fonti/, abbina i nomi a GBIF (speciesKey / nome accettato).
Output: data/edibili_legali.json
Nessun nome entra se non è nel testo ufficiale.
"""
import json
import re
import time
from pathlib import Path

import requests

DATA = Path(__file__).resolve().parent.parent / "data"
FONTI = DATA / "fonti"
S = requests.Session()

SRC = {
    "dpr376": {
        "titolo": "D.P.R. 14 luglio 1995, n. 376, Allegato I (specie commercializzabili in Italia, art. 4 c.1)",
        "url": "https://faolex.fao.org/docs/pdf/ita33146.pdf",
        "nota": "Art. 4 c.2: le Regioni integrano l'elenco per la commercializzazione locale.",
    },
    "sicilia2009": {
        "titolo": "D.P.Reg. 4 agosto 2009 (GURS Parte I n. 40/2009): elenco vigente delle specie di cui è consentita raccolta e commercializzazione in Sicilia, modifica del D.P.Reg. 19/11/2007",
        "url": "http://www.gurs.regione.sicilia.it/Gazzette/g09-40/g09-40-p1.html",
        "nota": "Sostituisce l'elenco 2007 dopo parere Assessorato Sanità e Ministero della salute (nota 14139 del 12/5/2009). Art. 2: divieto raccolta con cappello < 3 cm per alcune specie. Fungaioli Siciliani (agg. 3/10/2024) lo indica ancora come testo regionale in vigore; modifiche successive non verificate.",
    },
    "sicilia2007": {
        "titolo": "D.P.Reg. 19 novembre 2007 (GURS Parte I n. 57/2007), SUPERATO dal D.P.Reg. 4/8/2009",
        "url": "http://www.gurs.regione.sicilia.it/Gazzette/g07-57/g07-57-p7.html",
        "nota": "Usato solo per segnalare le specie tolte nel 2009 (ritenute non commestibili dal Ministero/Assessorato Sanità).",
    },
}


def clean(s):
    return re.sub(r"\s+", " ", s.replace("\xa0", " ")).strip()


def split_entry(raw):
    """-> (testo_originale, nome_per_match, rank, condizioni)"""
    raw = clean(raw).rstrip(";. ")
    cond = re.findall(r"\(([^)]*)\)", raw)
    cond = [c for c in cond if re.search(r"escluso|solo|tutte|da consumarsi|=", c, re.I)]
    words = re.sub(r"\([^)]*\)", "", raw).split()
    if any("tutte" in c for c in cond):
        return raw, words[0], "GENUS", [c for c in cond]
    name = " ".join(words[:2])
    if "var." in raw:
        m = re.search(r"var\. (\w+)", raw)
        cond = cond + [f"varietà {m.group(1)}"]
    if re.search(r"specie affini|Sezione", raw):
        cond = cond + ["comprende specie affini / sezione indicata nel testo: " + raw]
    return raw, name, "SPECIES", cond


def parse_dpr():
    t = (FONTI / "dpr376_1995_allegatoI.txt").read_text()
    t = re.sub(r"=====PAGE \d+\n", "", t)
    body = t.split("primo capoverso)", 1)[1]
    body = re.sub(r"\n(?!\d+\. )", " ", body)  # righe spezzate
    return [split_entry(m) for m in re.findall(r"\d+\.\s*(.+?)[;.]\s*(?=\d+\.|$)", body + " ")]


def parse_dp(fname, pat):
    t = (FONTI / fname).read_text()
    return [split_entry(m.group(1)) for m in (re.match(pat, l) for l in t.splitlines()) if m]


def match(name, rank):
    for a in range(5):
        try:
            r = S.get("https://api.gbif.org/v1/species/match", params={"name": name, "kingdom": "Fungi"}, timeout=60)
            r.raise_for_status()
            return r.json()
        except requests.RequestException:
            time.sleep(2 ** a)
    return {}


def candidati(name):
    """Sinonimi GBIF il cui nome inizia con `name` (solo funghi): per i nomi non risolti dal match esatto."""
    for a in range(5):
        try:
            r = S.get("https://api.gbif.org/v1/species/search", params={"q": name, "rank": "SPECIES", "highertaxonKey": 5, "limit": 20}, timeout=60)
            r.raise_for_status()
            break
        except requests.RequestException:
            time.sleep(2 ** a)
    else:
        return []
    out = []
    for x in r.json().get("results", []):
        if x.get("scientificName", "").startswith(name + " ") and x.get("taxonomicStatus") != "DOUBTFUL":
            out.append({"nome_gbif": x["scientificName"], "stato": x["taxonomicStatus"], "accettato": x.get("accepted"), "acceptedKey": x.get("acceptedKey") or x.get("key")})
    return out


def resolve(entries, fonte):
    out = []
    seen = set()
    for raw, name, rank, cond in entries:
        j = match(name, rank)
        acc = None
        if j.get("matchType") in ("EXACT", "HIGHERRANK", "FUZZY", "VARIANT") and j.get("usageKey"):
            acc_key = j.get("acceptedUsageKey") or j["usageKey"]
            if j.get("synonym"):
                ar = S.get(f"https://api.gbif.org/v1/species/{acc_key}", timeout=60).json()
                acc = {"key": acc_key, "nome": ar.get("canonicalName"), "rank": ar.get("rank")}
            else:
                acc = {"key": acc_key, "nome": j.get("canonicalName"), "rank": j.get("rank")}
        rec = {
            "nome_nel_testo": raw, "nome_cercato": name, "ambito": "genere" if rank == "GENUS" else "specie",
            "condizioni": cond, "fonte": fonte,
            "gbif_match": j.get("matchType"), "gbif_status": j.get("status"), "gbif_nome_usato": j.get("scientificName"),
            "nome_accettato": acc["nome"] if acc else None,
            "speciesKey": (j.get("speciesKey") if rank != "GENUS" else None) or (acc["key"] if acc and acc["rank"] == "SPECIES" else None),
            "genusKey": j.get("genusKey") if rank == "GENUS" else None,
            "acceptedKey": acc["key"] if acc else None, "rank_accettato": acc["rank"] if acc else None,
            "candidati_gbif": [] if (rank == "GENUS" or j.get("matchType") == "EXACT") else candidati(name),
            "da_verificare": bool(not acc or (rank == "SPECIES" and j.get("matchType") != "EXACT") or (rank == "GENUS" and (not acc or acc["rank"] != "GENUS")) or (rank == "SPECIES" and acc["rank"] != "SPECIES")),
        }
        out.append(rec)
    return out


def main():
    dpr = resolve(parse_dpr(), "dpr376")
    s09 = resolve(parse_dp("gurs_dpreg_2009-08-04.txt", r"^\s*\d+\.\s+(.*)$"), "sicilia2009")
    s07 = resolve(parse_dp("gurs_dpreg_2007-11-19.txt", r"^\s*\d+\)\s+(.*)$"), "sicilia2007")

    def keys(lst):
        return {(r["acceptedKey"]) for r in lst if r["acceptedKey"]}

    k09 = keys(s09)
    g09 = {r["acceptedKey"] for r in s09 if r["ambito"] == "genere"}
    # specie 2007 non più in elenco 2009 (nome accettato assente e genere non coperto da voce di genere 2009)
    tolte = []
    for r in s07:
        if r["acceptedKey"] in k09:
            continue
        genus_name = (r["nome_accettato"] or r["nome_cercato"]).split()[0]
        if any((x["nome_accettato"] or "") == genus_name and x["ambito"] == "genere" for x in s09):
            continue
        tolte.append(r)

    doc = {
        "generato": time.strftime("%Y-%m-%d"),
        "fonti": SRC,
        "regola_app": "Specie 'commestibile da elenco legale' in Sicilia = presente in sicilia_2009 (raccolta e commercializzazione consentite). "
                      "dpr376 = elenco nazionale per la vendita. Una specie in dpr376 ma non in sicilia_2009 NON è consentita in Sicilia secondo l'elenco regionale. "
                      "Essere nell'elenco non sostituisce il controllo dell'Ispettorato Micologico.",
        "limite_cappello_3cm": {
            "fonte": "D.P.Reg. 4/8/2009 art. 2",
            "specie": ["Amanita caesarea (anche vietata allo stadio di ovulo)", "Boletus aestivalis", "Boletus aereus", "Boletus pinophilus", "Calocybe gambosa", "Cantharellus cibarius", "Pleurotus nebrodensis"],
        },
        "dpr376_allegatoI": dpr,
        "sicilia_2009_vigente": s09,
        "sicilia_2007_tolte_nel_2009": tolte,
        "nota_tolte": "Elenco DERIVATO automaticamente (nome 2007 non presente nel 2009, né come specie né coperto da una voce di genere). "
                      "Possibili falsi positivi per sinonimia: Boletus pinicola (=B. pinophilus, in lista 2009), Agaricus hortensis (=A. bisporus), "
                      "Boletus badius (=Xerocomus badius, in lista 2009), Boletus scaber (Leccinum, genere in lista 2009), Amanita cesarea (refuso di caesarea). "
                      "Gli altri (es. Marasmius oreades, Boletus erythropus/luridus, Hydnum rufescens, Laetiporus sulphureus, Tricholoma columbetta/imbricatum/populinum) "
                      "non sono più nell'elenco regionale del 2009: in app NON presentarli come commestibili legali in Sicilia.",
    }
    (DATA / "edibili_legali.json").write_text(json.dumps(doc, ensure_ascii=False, indent=1))
    print("DPR:", len(dpr), "Sicilia2009:", len(s09), "Sicilia2007:", len(s07), "tolte:", len(tolte))
    for lbl, lst in (("DPR", dpr), ("S09", s09), ("S07", s07)):
        for r in lst:
            if r["da_verificare"]:
                print("VERIFICARE", lbl, "|", r["nome_nel_testo"], "->", r["gbif_nome_usato"], r["gbif_match"], r["nome_accettato"], r["rank_accettato"])


if __name__ == "__main__":
    main()
