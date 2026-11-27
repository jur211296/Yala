"""Qué ocupa el hilo principal durante el scroll de una pantalla (pasada D). Uso: quien_en_scroll.py <traza> <ciclos.csv> <pantalla>"""
import csv, os, sys
from collections import Counter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trazas
trace, evp, pant = sys.argv[1:4]
t0 = trazas.inicio(trace)
ev = list(csv.DictReader(open(evp)))
vent = []
for i, e in enumerate(ev):
    if e["evento"] == "scroll_inicio" and pant in (e.get("detalle") or e.get("pantalla") or e.get("ciclo") or ""):
        vent.append((int(e["epoch_ms"]) / 1000 - t0, int(ev[i + 1]["epoch_ms"]) / 1000 - t0))
ms = trazas.muestras(trazas.exportar(trace, "time-profile", os.path.dirname(os.path.abspath(trace))))
tmin = min(t for t, _, _ in ms)
c = Counter(); n = 0
for t, main, p in ms:
    r = t - tmin
    if main and any(a <= r <= b for a, b in vent):
        n += 1
        yala = [f for f in p if any(k in f for k in ("Yala", "Panel", "Widget", "View", "Model"))]
        c[(yala[0] if yala else (p[0] if p else "?"))[:120]] += 1
print(f"{len(vent)} ventanas, {n} ms de hilo principal")
for k, v in c.most_common(15): print(f"{v:6}  {k}")
