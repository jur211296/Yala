# Uso: cuelgues_por_vuelta.py <prefijo>  (lee <p>.t0_ms, <p>.ciclos.csv, <p>.potential-hangs.xml)
# Cuelgues que empiezan entre cada vuelta y la siguiente salida: lo que la persona nota con Yala delante.
import sys, csv, xml.etree.ElementTree as ET
p = sys.argv[1]; t0 = int(open(p + ".t0_ms").read()); ev = list(csv.DictReader(open(p + ".ciclos.csv")))
ids = {}; rows = []
for _, el in ET.iterparse(p + ".potential-hangs.xml", events=("end",)):
    if el.tag != "row": continue
    for sub in el.iter():
        if sub.get("id"): ids[sub.get("id")] = sub.text
    k = list(el)[:2]; v = [ids[x.get("ref")] if x.get("ref") else x.text for x in k]
    rows.append((int(v[0]) / 1e9, int(v[1]) / 1e6)); el.clear()
T = lambda e: (int(e["epoch_ms"]) - t0) / 1000
vuelve = [e for e in ev if e["evento"] == "vuelve"]; sale = [e for e in ev if e["evento"] in ("sale", "fin")]
tot = []
for v in vuelve:
    a = T(v); b = min([T(s) for s in sale if T(s) > a], default=a + 60)
    hs = [d for s, d in rows if a <= s < b]; tot += hs
    print("ciclo", v["ciclo"], "cuelgues", len(hs), "máx", round(max(hs, default=0)), "ms suma", round(sum(hs)), "ms")
print("TOTAL", len(tot), "cuelgues, máx", round(max(tot, default=0)), "ms, suma", round(sum(tot)), "ms")
