"""Inclusivo (cualquier binario) en ventanas [evento+a, evento+b). Uso: ventana_libre.py <tp.xml> <t0> <csv> <evento> <a> <b> <ciclos,coma> [top]"""
import csv, sys
from collections import Counter
path, t0_ms, evp, evento, a, b, cic = sys.argv[1], int(open(sys.argv[2]).read().strip()), sys.argv[3], sys.argv[4], float(sys.argv[5]), float(sys.argv[6]), sys.argv[7].split(",")
top = int(sys.argv[8]) if len(sys.argv) > 8 else 45
exec(open(sys.argv[0].rsplit('/', 1)[0] + '/perfil_lector.py').read())
ev = list(csv.DictReader(open(evp)))
vs = [((int(e["epoch_ms"]) - t0_ms) / 1000 + a, (int(e["epoch_ms"]) - t0_ms) / 1000 + b) for e in ev if e["evento"] == evento and (cic == ["*"] or e["ciclo"] in cic)]
sel = [s for s in samples if s[1] and any(x <= s[0] < y for x, y in vs)]
dur = sum(y - x for x, y in vs)
inc = Counter()
for _, _, st in sel:
    seen = set()
    for n, bn in st:
        k = f"{n[:110]}  [{(bn or '?')[:18]}]"
        if k not in seen:
            inc[k] += 1; seen.add(k)
print(f"{len(sel)} muestras en {dur:.0f} s ({len(sel)/dur/10:.0f} % núcleo)")
for k, c in inc.most_common(top):
    print(f"{c:7d} {100*c/len(sel):5.1f}%  {k}")
