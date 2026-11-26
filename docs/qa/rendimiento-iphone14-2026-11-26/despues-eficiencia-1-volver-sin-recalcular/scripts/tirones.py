# Uso: tirones.py <hitches.xml> <hangs.xml> <t0_ms> <ciclos.csv> [seg]
# Por ciclo: tirones (hitches) y cuelgues (potential-hangs) de Yala en los <seg> s tras volver.
import sys, csv, xml.etree.ElementTree as ET
hp, gp, t0f, evp = sys.argv[1:5]
seg = int(sys.argv[5]) if len(sys.argv) > 5 else 36
t0 = int(open(t0f).read().strip())
def rows(path, want_proc=True):
    out = []; ids = {}
    for ev, el in ET.iterparse(path, events=("end",)):
        if el.tag != "row": continue
        vals = []
        for c in el:
            if c.get("ref"): vals.append(ids.get(c.get("ref")))
            else:
                ids[c.get("id")] = (c.tag, c.text, c.get("fmt"))
                for sub in c.iter():
                    if sub.get("id") and sub is not c: ids[sub.get("id")] = (sub.tag, sub.text, sub.get("fmt"))
                vals.append(ids[c.get("id")])
        el.clear()
        start = int(vals[0][1]) / 1e9; dur = int(vals[1][1]) / 1e6
        proc = " ".join(str(v[2]) for v in vals if v and v[0] == "process")
        out.append((start, dur, proc))
    return out
H = [r for r in rows(hp) if "Yala" in r[2]]
try: G = [r for r in rows(gp) if "Yala" in r[2]]
except Exception: G = []
ev = [e for e in csv.DictReader(open(evp)) if e["evento"] == "vuelve"]
tot_h = []; tot_g = []
for e in ev:
    t = (int(e["epoch_ms"]) - t0) / 1000
    h = [d for s, d, _ in H if t <= s < t + seg]
    g = [d for s, d, _ in G if t <= s < t + seg]
    tot_h += h; tot_g += g
    print(f"ciclo {e['ciclo']}: tirones {len(h)} (>250 ms: {sum(1 for d in h if d > 250)}, máx {max(h, default=0):.0f} ms) · cuelgues {len(g)} (máx {max(g, default=0):.0f} ms, suma {sum(g):.0f} ms)")
print(f"TOTAL tras volver: tirones {len(tot_h)}, >250 ms {sum(1 for d in tot_h if d > 250)}, máx {max(tot_h, default=0):.0f} ms; cuelgues {len(tot_g)}, máx {max(tot_g, default=0):.0f} ms, suma {sum(tot_g):.0f} ms")
