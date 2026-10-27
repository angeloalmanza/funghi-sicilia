"""Valutazione su test + calibrazione soglie (su val) + metriche di sicurezza.
Output: data/model/metrics.json, data/model/thresholds.json, data/model/per_species.csv"""
import json
from pathlib import Path

import numpy as np

M = Path(__file__).resolve().parents[2] / "data" / "model"
lab = json.loads((M / "labels.json").read_text())
classes, cats = lab["classes"], lab["categorie"]
NC = len(classes); ALTRO = NC - 1
DANGER = {"mortale", "tossico_grave", "tossico", "vietato_per_legge", "condizionato"}
cat_of = np.array([cats.get(c, "altro") for c in classes], dtype=object)
is_danger = np.array([c in DANGER for c in cat_of]); is_ed = cat_of == "commestibile_sicilia"
is_ital = cat_of == "commestibile_italia_non_sicilia"; is_mort = cat_of == "mortale"
pv, yv = (lambda z: (z["p"], z["y"]))(np.load(M / "probs_val.npz"))
pt, yt = (lambda z: (z["p"], z["y"]))(np.load(M / "probs_test.npz"))
nonval = {classes.index(c) for c in lab["non_valutabili"]}

def stats(p, y, tau=0.0):
    top = p.argmax(1); conf = p.max(1); acc = conf >= tau          # accettati (non "non riconosciuto")
    out = {}
    known = (y != ALTRO) & ~np.isin(y, list(nonval))
    out["n"] = int(len(y)); out["n_known"] = int(known.sum()); out["n_altro"] = int((y == ALTRO).sum())
    out["top1_known"] = float((top == y)[known].mean())
    out["top5_known"] = float(np.mean([y[i] in np.argsort(-p[i])[:5] for i in np.where(known)[0]]))
    out["accettati_frac_known"] = float(acc[known].mean())
    out["top1_known_accettati"] = float((top == y)[known & acc].mean()) if (known & acc).any() else None
    out["altro_riconosciuto_come_altro_o_rifiutato"] = float(((top == ALTRO) | ~acc)[y == ALTRO].mean())
    out["altro_predetto_commestibile_sicilia"] = float((is_ed[top] & acc)[y == ALTRO].mean())
    t_d = is_danger[y] & known
    out["pericolose_n"] = int(t_d.sum())
    out["pericolose_predette_commestibile_sicilia"] = float((is_ed[top] & acc)[t_d].mean())
    out["pericolose_predette_commestibile_sicilia_n"] = int((is_ed[top] & acc)[t_d].sum())
    t_e = is_ed[y] & known
    out["commestibili_predette_pericolose"] = float((is_danger[top] & acc)[t_e].mean())
    m = is_mort[y] & known
    out["mortali_n"] = int(m.sum())
    if m.any():
        out["mortali_top1"] = float((top == y)[m].mean())
        out["mortali_top5"] = float(np.mean([y[i] in np.argsort(-p[i])[:5] for i in np.where(m)[0]]))
        out["mortali_predette_commestibile_sicilia"] = float((is_ed[top] & acc)[m].mean())
    return out

# --- calibrazione tau su VAL: errore di sicurezza (pericolosa/altro -> "commestibile") <= 2% tra accettati, massimizzando copertura
cands = []
for tau in np.round(np.arange(0.0, 0.96, 0.025), 3):
    s = stats(pv, yv, tau)
    risk = max(s["pericolose_predette_commestibile_sicilia"], s["altro_predetto_commestibile_sicilia"])
    cands.append((float(tau), risk, s["accettati_frac_known"], s["top1_known_accettati"]))
ok = [c for c in cands if c[1] <= 0.02]
tau = min(ok, key=lambda c: c[0])[0] if ok else max(c[0] for c in cands)
tau = max(tau, 0.30)   # mai sotto 0.30: prudenza
# soglia avviso pericolo: prob minima di una specie pericolosa nei top-5 (val)
rows = []
for pa in (0.02, 0.05, 0.10, 0.20):
    pdg = pv[:, is_danger]
    fire = (pdg >= pa).any(1)
    known = (yv != ALTRO)
    rows.append((pa, float(fire[is_danger[yv] & known].mean()), float(fire[is_ed[yv] & known].mean())))
alert = 0.05
thr = {"unknown_below": tau, "danger_alert_prob": alert, "aggregation": "mean_prob", "calibrated_on": "val",
       "danger_alert_table(prob, recall_pericolose, falsi_allarmi_commestibili)": rows}
(M / "thresholds.json").write_text(json.dumps(thr, indent=1))

res = {"tau": tau, "single": {"no_threshold": stats(pt, yt, 0.0), "with_tau": stats(pt, yt, tau)}}
# multi-foto: 3 foto di osservazioni diverse della stessa classe (media prob), ripetuto 20 volte
rng = np.random.default_rng(0)
agg_p, agg_y = [], []
for c in range(NC):
    idx = np.where(yt == c)[0]
    if len(idx) < 3: continue
    for _ in range(20):
        agg_p.append(pt[rng.choice(idx, 3, replace=False)].mean(0)); agg_y.append(c)
res["multi3"] = {"with_tau": stats(np.array(agg_p), np.array(agg_y), tau)}
# per specie
top = pt.argmax(1); lines = ["speciesKey,categoria,n_test,recall_top1,valutabile"]
for c in range(NC):
    m = yt == c
    lines.append(f"{classes[c]},{cat_of[c]},{int(m.sum())},{(top[m]==c).mean() if m.any() else ''},{'no' if c in nonval else 'si'}")
(M / "per_species.csv").write_text("\n".join(lines))
# errori pericolosi: elenco
err = [(classes[yt[i]], classes[top[i]], float(pt[i].max())) for i in range(len(yt)) if is_danger[yt[i]] and is_ed[top[i]]]
res["errori_pericolosa_come_commestibile"] = err
res["calibrazione_val"] = cands
(M / "metrics.json").write_text(json.dumps(res, indent=1, default=float))
print("tau", tau)
for k in ("no_threshold", "with_tau"):
    print(k, json.dumps(res["single"][k], indent=0, default=float))
print("multi3", json.dumps(res["multi3"]["with_tau"], default=float))
print("errori pericolosa->commestibile:", err)
