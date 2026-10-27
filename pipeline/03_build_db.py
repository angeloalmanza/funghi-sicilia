"""Costruisce data/species_db.sqlite (con FTS5) da fonti ufficiali.

Specie     : data/checklist_species.json (checklist macrofunghi siciliani) + specie delle liste
             tossiche/legali non presenti in checklist (in_checklist=0).
Descrizioni: data/traits.json (Wikipedia, SOLO testo descrittivo: mai commestibilità).
Commestibilità (regole tassative, nessun'altra fonte la decide):
  1. in tossiche.json (mortale/tossico/condizionato/vietato) -> sempre NON RACCOGLIERE;
  2. elenco regionale Sicilia 2009 e non tossica -> "commestibile (elenco legale Sicilia)",
     consiglio solo con controllo ispettorato; solo Allegato I nazionale -> NON RACCOGLIERE/verifica;
  3. tutto il resto -> "sconosciuta", NON RACCOGLIERE.
Foto: photos_done.json se presente, altrimenti photos.json (foto opzionali).
"""
import json
import re
import sqlite3
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "data"
DB = DATA / "species_db.sqlite"

NO = "NON RACCOGLIERE"
OK = "RACCOGLIBILE SOLO CON CONTROLLO ISPETTORATO MICOLOGICO"
SOSIA_DEFAULT = "Nessun carattere distintivo nelle fonti consultate: far controllare all'ispettorato micologico."
DISCLAIMER = ("Supporto informativo, non sostituisce il controllo dell'Ispettorato Micologico ASP "
              "(gratuito per uso personale). Mai consumare un fungo senza controllo di un micologo. "
              "In caso di sintomi: Pronto Soccorso / 118 / Centro Antiveleni, portando un campione.")

# (categoria, testo commestibilità, ordine di sicurezza: più basso = più pericoloso, in cima)
CAT = {
    "mortale": ("MORTALE", 0),
    "tossico_grave": ("Tossico (grave)", 1),
    "tossico": ("Tossico", 2),
    "vietato_per_legge": ("Raccolta vietata per legge", 3),
    "condizionato": ("Commestibile solo con trattamento/condizioni (vedi note): NON RACCOGLIERE", 4),
    "commestibile_italia_non_sicilia": (
        "Commestibile in Italia (Allegato I DPR 376/1995), non nell'elenco siciliano: non raccogliere/verifica", 5),
    "sconosciuta": ("Sconosciuta", 6),
    "commestibile_sicilia": ("Commestibile", 7),
}

# Eccezioni a voci di genere "tutte le specie" (DPR 376/1995: Cantharellus escluse subcibarius,
# tubaeformis var. lutescens e muscigenus). Prudenza: escluso l'epiteto anche sotto Craterellus.
GENUS_EXCLUDE = {"cantharellus": {"subcibarius", "muscigenus", "lutescens"},
                 "craterellus": {"lutescens"}}

SCHEMA = """
CREATE TABLE species (
  key INTEGER PRIMARY KEY,
  nome_scientifico TEXT NOT NULL,   -- nome accettato (GBIF)
  nomi_checklist TEXT,              -- JSON: nomi/sinonimi come nella checklist siciliana
  famiglia TEXT, genere TEXT, ordine TEXT, classe TEXT, phylum TEXT,
  in_checklist INTEGER NOT NULL,
  province_checklist TEXT,
  sicily_records INTEGER,
  n_photos INTEGER,
  categoria TEXT NOT NULL,          -- codice (vedi CAT)
  commestibilita TEXT NOT NULL,
  consiglio TEXT NOT NULL,          -- NON RACCOGLIERE | RACCOGLIBILE SOLO CON CONTROLLO ISPETTORATO MICOLOGICO
  etichetta TEXT,                   -- es. "NON RACCOGLIERE (MORTALE)"
  ordine_sicurezza INTEGER NOT NULL,
  fonti_commestibilita TEXT NOT NULL,  -- JSON [{fonte,titolo,url,nota}]
  regole_raccolta TEXT,             -- JSON [testo]
  sindrome TEXT, latenza TEXT, sintomi TEXT, note_tossicita TEXT,
  sosia TEXT NOT NULL,              -- JSON [{con,caratteri_discriminanti,avvertenze,gravita,fonti}]
  sosia_nota TEXT,
  disclaimer TEXT NOT NULL,
  nomi_italiani TEXT, nomi_siciliani TEXT,   -- JSON
  scheda TEXT NOT NULL              -- JSON: testo descrittivo (Wikipedia) + fonti descrizione
);
CREATE TABLE photos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  species_key INTEGER NOT NULL REFERENCES species(key),
  path TEXT NOT NULL,
  author TEXT, license TEXT, source TEXT, url_originale TEXT,
  area TEXT, country TEXT, month INTEGER, lat REAL, lon REAL
);
CREATE INDEX photos_species ON photos(species_key);
CREATE INDEX species_cat ON species(categoria);
CREATE VIEW species_ordinata AS SELECT * FROM species ORDER BY ordine_sicurezza, nome_scientifico;
CREATE VIRTUAL TABLE species_fts USING fts5(
  nome_scientifico, nomi_checklist, nomi_italiani, nomi_siciliani, famiglia, genere,
  tokenize = 'unicode61 remove_diacritics 2'
);
"""


def binomial(name):
    return " ".join(re.sub(r"\(.*?\)", " ", name).split()[:2]).lower()


def load(name, default=None):
    p = DATA / name
    return json.loads(p.read_text()) if p.exists() else default


def main():
    checklist = load("checklist_species.json", [])
    species_json = {s["key"]: s for s in load("species.json", [])}
    traits = load("traits.json", {})
    tox = load("tossiche.json")
    edib = load("edibili_legali.json")
    sosia_src = load("sosia_pericolosi.json")
    sic_names = load("nomi_siciliani.json", {})
    pf = DATA / "photos_done.json"
    photos = load("photos_done.json") if pf.exists() else load("photos.json", {})

    # --- anagrafica specie ---
    sp = {}
    for r in checklist:
        k = r.get("speciesKey")
        if not k:
            continue
        e = sp.setdefault(k, {"key": k, "name": r["accepted_name"], "family": r.get("family"), "in_checklist": 1,
                              "checklist_names": [], "province": None})
        if r["checklist_name"] not in e["checklist_names"]:
            e["checklist_names"].append(r["checklist_name"])
        m = re.search(r"Province:\s*([A-Z, ]+)", r.get("note_checklist") or "")
        if m and not e["province"]:
            e["province"] = m.group(1).strip(" ,")
    tox_by_key = {}
    for t in tox["specie"]:
        k = t["gbif"]["speciesKey"]
        tox_by_key[k] = t
        sp.setdefault(k, {"key": k, "name": t["gbif"]["nome_accettato"], "family": t["gbif"].get("famiglia"),
                          "in_checklist": 0, "checklist_names": [], "province": None})
    sic_sp, sic_gen, naz_sp, naz_gen = {}, {}, {}, {}
    for lst, dsp, dgen in (("sicilia_2009_vigente", sic_sp, sic_gen), ("dpr376_allegatoI", naz_sp, naz_gen)):
        for r in edib[lst]:
            if r["ambito"] == "genere" and r.get("genusKey"):
                dgen[r["nome_accettato"].lower()] = r
            elif r["ambito"] == "specie":
                k = r.get("speciesKey") or (r.get("acceptedKey") if r.get("rank_accettato") == "SPECIES" else None)
                if k:
                    dsp[k] = r
                    sp.setdefault(k, {"key": k, "name": r["nome_accettato"], "family": None, "in_checklist": 0,
                                      "checklist_names": [], "province": None})
    by_name = {v["name"].lower(): k for k, v in sp.items()}
    # fallback per nome accettato (mai per sinonimi di checklist)
    for lst, dsp in (("sicilia_2009_vigente", sic_sp), ("dpr376_allegatoI", naz_sp)):
        for r in edib[lst]:
            if r["ambito"] == "specie" and r.get("speciesKey") is None and r.get("rank_accettato") == "SPECIES":
                k = by_name.get(r["nome_accettato"].lower())
                if k:
                    dsp[k] = r

    cap3 = {binomial(x) for x in edib["limite_cappello_3cm"]["specie"]}
    cap3_txt = {binomial(x): x for x in edib["limite_cappello_3cm"]["specie"]}

    def legal(key, name, table_sp, table_gen):
        """Voce dell'elenco che copre la specie (specie o genere con eccezioni), o None."""
        if key in table_sp:
            return table_sp[key]
        genus, _, epithet = name.lower().partition(" ")
        g = table_gen.get(genus)
        if g and epithet.split(" ")[0] not in GENUS_EXCLUDE.get(genus, set()):
            return g
        return None

    # --- sosia ---
    pairs = sosia_src["coppie"]

    def sosia_for(name, t):
        b = binomial(name)
        out = []
        for c in pairs:
            if b in c["commestibile"].lower() or b in c["pericoloso"].lower():
                other = c["pericoloso"] if b in c["commestibile"].lower() else c["commestibile"]
                out.append({"con": other, "caratteri_discriminanti": c["caratteri_discriminanti"],
                            "avvertenze": c.get("avvertenze"), "gravita": c.get("gravita"), "fonti": c.get("fonti", [])})
        if t:
            for s in t.get("sosia_commestibili", []):
                if not any(s[:30] in o["con"] for o in out):
                    out.append({"con": s, "caratteri_discriminanti": [], "avvertenze": None, "gravita": None,
                                "fonti": t.get("fonti", [])})
        return out

    fonti_tox = tox["fonti"]
    fonti_ed = edib["fonti"]

    if DB.exists():
        DB.unlink()
    con = sqlite3.connect(DB)
    con.executescript(SCHEMA)
    n_ph = 0
    counts = {}
    for key, e in sorted(sp.items(), key=lambda kv: kv[1]["name"]):
        name = e["name"]
        t = tox_by_key.get(key)
        fonti, regole, sindrome = [], [], {}
        sic = legal(key, name, sic_sp, sic_gen)
        naz = legal(key, name, naz_sp, naz_gen)
        # 1) tossiche prevalgono sempre
        if t:
            cat = {"mortale": "mortale", "vietato_per_legge": "vietato_per_legge",
                   "condizionato": "condizionato"}.get(t["categoria"])
            cat = cat or ("tossico_grave" if t.get("gravita") == "grave" else "tossico")
            consiglio = NO
            etichetta = t.get("consiglio_app") or NO
            if cat == "condizionato" or not etichetta.startswith(NO):
                etichetta = NO
            for f in t["fonti"]:
                fonti.append({"fonte": f, **{k: fonti_tox.get(f, {}).get(k) for k in ("titolo", "url")}, "nota": None})
            if cat == "condizionato":
                regole.append("Condizioni (solo informative, NON RACCOGLIERE): " + (t.get("note") or ""))
            sindrome = {"sindrome": t.get("sindrome"), "latenza": t.get("latenza"), "sintomi": t.get("sintomi"),
                        "note": t.get("note")}
        elif sic:
            cat, consiglio, etichetta = "commestibile_sicilia", OK, OK
            r = fonti_ed["sicilia2009"]
            fonti.append({"fonte": "sicilia2009", "titolo": r["titolo"], "url": r["url"],
                          "nota": "voce: " + sic["nome_nel_testo"]})
            if sic["condizioni"]:
                regole.append("Condizioni elenco: " + "; ".join(sic["condizioni"]))
        elif naz:
            cat, consiglio, etichetta = "commestibile_italia_non_sicilia", NO, NO + " (verifica)"
            r = fonti_ed["dpr376"]
            fonti.append({"fonte": "dpr376", "titolo": r["titolo"], "url": r["url"],
                          "nota": "voce: " + naz["nome_nel_testo"] + "; non presente nell'elenco regionale Sicilia 2009"})
        else:
            cat, consiglio, etichetta = "sconosciuta", NO, NO
        if not fonti:
            fonti.append({"fonte": None, "titolo": "Nessuna fonte ufficiale consultata classifica questa specie",
                          "url": None, "nota": None})
        if cat in ("commestibile_sicilia",) or sic or naz:
            if binomial(name) in cap3:
                regole.append("Raccolta vietata con cappello < 3 cm (D.P.Reg. 4/8/2009 art. 2): "
                              + cap3_txt[binomial(name)])
            if cat == "commestibile_sicilia":
                regole.append("Raccolta consentita solo previo controllo dell'Ispettorato Micologico ASP; "
                              "rispettare tesserino/quantità vigenti.")
        sosia = sosia_for(name, t)
        has_chars = any(s["caratteri_discriminanti"] for s in sosia)
        sosia_nota = None if has_chars else SOSIA_DEFAULT

        tr = traits.get(str(key), {})
        nomi_it = tr.get("nomi_italiani", [])
        nomi_sic = list(sic_names.get(name, []))
        if t:
            for n in t.get("nomi_locali_da_fonti", []):
                nomi_sic.append(n if isinstance(n, dict) else {"nome": n, "fonte": ", ".join(t["fonti"])})
        scheda = {k: v for k, v in tr.items() if k not in ("nome_scientifico", "nomi_italiani") and v not in (None, "", [], {})}
        sj = species_json.get(key, {})
        ph = photos.get(str(key), [])
        genus = name.split()[0]
        con.execute(
            "INSERT INTO species VALUES (" + ",".join("?" * 29) + ")",
            (key, name, json.dumps(e["checklist_names"], ensure_ascii=False), e["family"] or sj.get("family"), genus,
             sj.get("order"), sj.get("class"), sj.get("phylum"), e["in_checklist"], e["province"],
             sj.get("sicily_records"), len(ph), cat, CAT[cat][0], consiglio, etichetta, CAT[cat][1],
             json.dumps(fonti, ensure_ascii=False), json.dumps(regole, ensure_ascii=False),
             sindrome.get("sindrome"), sindrome.get("latenza"), sindrome.get("sintomi"), sindrome.get("note"),
             json.dumps(sosia, ensure_ascii=False), sosia_nota, DISCLAIMER,
             json.dumps(nomi_it, ensure_ascii=False), json.dumps(nomi_sic, ensure_ascii=False),
             json.dumps(scheda, ensure_ascii=False)))
        con.execute("INSERT INTO species_fts(rowid, nome_scientifico, nomi_checklist, nomi_italiani, nomi_siciliani,"
                    " famiglia, genere) VALUES (?,?,?,?,?,?,?)",
                    (key, name, " ".join(e["checklist_names"]), " ".join(nomi_it),
                     " ".join(n["nome"] for n in nomi_sic), e["family"] or "", genus))
        for p in ph:
            if pf.exists() and not (DATA / "photos" / str(key) / f"{p['occ']}.webp").exists():
                continue
            con.execute(
                "INSERT INTO photos(species_key,path,author,license,source,url_originale,area,country,month,lat,lon)"
                " VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                (key, f"photos/{key}/{p['occ']}.webp", p.get("author"), p.get("license"), p.get("source"),
                 p.get("url"), p.get("area"), p.get("country"), p.get("month"), p.get("lat"), p.get("lon")))
            n_ph += 1
        counts[cat] = counts.get(cat, 0) + 1
    con.commit()

    # --- test automatici di sicurezza ---
    for k, t in tox_by_key.items():
        r = con.execute("SELECT consiglio, categoria FROM species WHERE key=?", (k,)).fetchone()
        assert r, f"specie tossica mancante: {t['nome_scientifico_fonte']}"
        assert r[0] == NO, f"consiglio non sicuro per {t['nome_scientifico_fonte']}: {r[0]}"
        assert r[1] != "commestibile_sicilia"
    assert con.execute("SELECT COUNT(*) FROM species WHERE categoria!='commestibile_sicilia' AND consiglio!=?",
                       (NO,)).fetchone()[0] == 0, "consiglio incoerente"
    assert con.execute("SELECT COUNT(*) FROM species WHERE categoria='commestibile_sicilia' "
                       "AND key IN (%s)" % ",".join(map(str, tox_by_key)) ).fetchone()[0] == 0
    n_mort = con.execute("SELECT COUNT(*) FROM species WHERE categoria='mortale'").fetchone()[0]
    top = con.execute("SELECT categoria FROM species_ordinata LIMIT ?", (n_mort,)).fetchall()
    assert n_mort > 0 and all(c[0] == "mortale" for c in top), "mortali non in cima"
    con.execute("INSERT INTO species_fts(species_fts) VALUES('optimize')")
    con.commit()
    con.execute("VACUUM")
    n = con.execute("SELECT COUNT(*) FROM species").fetchone()[0]
    con.close()
    print(f"{n} specie, {n_ph} foto -> {DB} ({DB.stat().st_size / 1e6:.1f} MB)")
    for c, (txt, _) in sorted(CAT.items(), key=lambda kv: kv[1][1]):
        print(f"  {c:34s} {counts.get(c, 0)}")
    print("TEST OK: tossiche sempre NON RACCOGLIERE, mortali in cima, nessun consiglio incoerente")


if __name__ == "__main__":
    main()
