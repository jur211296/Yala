"""Cuelgues (potential-hangs, > 250 ms) de los primeros N s de una traza, con su dueño por las muestras del hilo principal.

Uso: arranque_cuelgues.py <traza.trace> [segundos=60] [carpeta exportes]
Dueño: la pieza con más muestras dentro del cuelgue (foto de widgets, recálculo del Panel, proyección, Spotlight u otro).
"""
import os, sys
from bisect import bisect_left, bisect_right
from collections import Counter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trazas
trace = sys.argv[1]
hasta = float(sys.argv[2]) if len(sys.argv) > 2 else 60
carpeta = sys.argv[3] if len(sys.argv) > 3 else os.path.dirname(os.path.abspath(trace))
ms = sorted((t, p) for t, main, p in trazas.muestras(trazas.exportar(trace, "time-profile", carpeta)) if main)
t0 = trazas.inicio(trace)
tiempos = [t for t, _ in ms]
def dueno(pila):
    s = " | ".join(pila)
    if "ProjectedFlowBuilder" in s or "FlujoMotorMes" in s: return "proyección"
    if "WidgetDataCache" in s: return "foto de widgets"
    if "PanelViewModel" in s: return "Panel"
    if "Spotlight" in s: return "Spotlight"
    return "otro"
hangs = []
for r in trazas.filas(trazas.exportar(trace, "potential-hangs", carpeta)):
    p = (r.get("process") or (None, ""))[1] or ""
    if "Yala" not in p: continue
    s = int(r["start"][0]) / 1e9; d = int(r["duration"][0]) / 1e6
    hangs.append((s, d))
# Las muestras van en tiempo absoluto del dispositivo; los cuelgues, relativos a la traza: se alinean por el primero.
base = tiempos[0] if tiempos else 0
tot = Counter(); n = 0; suma = 0; mx = 0
print("inicio s  dura ms  dueño (muestras)")
for s, d in sorted(hangs):
    if s > hasta: continue
    a = bisect_left(tiempos, base + s); b = bisect_right(tiempos, base + s + d / 1000)
    c = Counter(dueno(p) for _, p in ms[a:b])
    quien = c.most_common(1)[0][0] if c else "sin muestras"
    tot[quien] += d; n += 1; suma += d; mx = max(mx, d)
    print(f"{s:8.1f}  {d:7.0f}  {quien} {dict(c)}")
print(f"\n{n} cuelgues > 250 ms en los primeros {hasta:.0f} s · total {suma/1000:.1f} s · el más largo {mx:.0f} ms")
for k, v in tot.most_common():
    print(f"  {k:16} {v/1000:5.1f} s")
