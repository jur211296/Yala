"""Reposo (pasada E): % de un núcleo del hilo principal de Yala con la app quieta, por pantalla.

Uso: reposo.py <traza.trace> <ciclos.csv> [carpeta de exportes]
Cada ventana va de `quieta_inicio` a `quieta_fin`; se descartan los 3 primeros segundos (lo que dejó el toque).
"""
import csv
import os
import sys
from bisect import bisect_left

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trazas  # noqa: E402

trace, evp = sys.argv[1], sys.argv[2]
carpeta = sys.argv[3] if len(sys.argv) > 3 else os.path.dirname(os.path.abspath(trace))
t0 = trazas.inicio(trace)
ev = list(csv.DictReader(open(evp)))
T = lambda e: int(e["epoch_ms"]) / 1000 - t0
main = sorted(t for t, es_main, _ in trazas.muestras(trazas.exportar(trace, "time-profile", carpeta)) if es_main)
print("pantalla           ventana   % de un núcleo (hilo principal)")
for i, e in enumerate(ev):
    if e["evento"] != "quieta_inicio":
        continue
    fin = next(x for x in ev[i + 1:] if x["evento"] == "quieta_fin" and x["ciclo"] == e["ciclo"])
    a, b = T(e) + 3, T(fin)
    n = bisect_left(main, b) - bisect_left(main, a)
    print(f"{e['ciclo']:<18} {b - a:5.1f} s   {100 * n / 1000 / (b - a):5.1f} %")
