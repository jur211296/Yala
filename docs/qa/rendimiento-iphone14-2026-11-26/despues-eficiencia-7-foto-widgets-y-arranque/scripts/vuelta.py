"""Por vuelta: hilo principal, cuelgues, tirones y estado térmico de la pasada «vuelta» (como B2 del informe).

Uso: vuelta.py <traza.trace> <ciclos.csv> [carpeta de exportes]
Por ciclo: ms de CPU del hilo principal en los 20 y 36 s tras volver, el bloque continuo más largo con el hilo ≥ 90 %,
cuelgues (potential-hangs) con Yala delante (de volver a la siguiente salida) y tirones > 250 ms en los 36 s.
"""
import csv
import os
import sys
from bisect import bisect_left
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trazas  # noqa: E402

trace, evp = sys.argv[1], sys.argv[2]
carpeta = sys.argv[3] if len(sys.argv) > 3 else os.path.dirname(os.path.abspath(trace))
t0 = trazas.inicio(trace)
ev = list(csv.DictReader(open(evp)))
T = lambda e: int(e["epoch_ms"]) / 1000 - t0

main = sorted(t for t, es_main, _ in trazas.muestras(trazas.exportar(trace, "time-profile", carpeta)) if es_main)
def ms(a, b):
    return bisect_left(main, b) - bisect_left(main, a)

hangs = []
for r in trazas.filas(trazas.exportar(trace, "potential-hangs", carpeta)):
    p = (r.get("process") or (None, ""))[1] or ""
    if "Yala" in p:
        hangs.append((int(r["start"][0]) / 1e9, int(r["duration"][0]) / 1e6))
tirones = []
for r in trazas.filas(trazas.exportar(trace, "hitches", carpeta)):
    p = (r.get("process") or (None, ""))[1] or ""
    if "Yala" in p:
        tirones.append((int(r["start"][0]) / 1e9, int(r["duration"][0]) / 1e6))
termico = []
for r in trazas.filas(trazas.exportar(trace, "device-thermal-state-intervals", carpeta)):
    termico.append((int(r["start"][0]) / 1e9, (r.get("thermal-state") or (None, ""))[1] or (r.get("thermal-state") or ("",))[0]))

vueltas = [e for e in ev if e["evento"] == "vuelve"]
salidas = [e for e in ev if e["evento"] in ("sale", "fin")]
print("ciclo  fuera  cpu20s  cpu36s  bloque≥90%  cuelgues(n, máx ms)  tirones>250ms(n, máx ms)")
filas_out = []
for v in vueltas:
    a = T(v)
    b = min([T(s) for s in salidas if T(s) > a], default=a + 36)
    seg = [ms(a + i, a + i + 1) for i in range(36)]
    bloque = mejor = 0
    for x in seg:
        bloque = bloque + 1 if x >= 900 else 0
        mejor = max(mejor, bloque)
    hs = [d for s, d in hangs if a <= s < b]
    ts_ = [d for s, d in tirones if a <= s < a + 36 and d > 250]
    fila = (v["ciclo"], v["detalle"].replace("fuera=", ""), ms(a, a + 20), ms(a, a + 36), mejor,
            len(hs), round(max(hs, default=0)), len(ts_), round(max(ts_, default=0)))
    filas_out.append(fila)
    print("{:>5}  {:>5}  {:>6}  {:>6}  {:>9} s  {:>3}, {:>5}            {:>3}, {:>5}".format(*fila))
c2 = [f for f in filas_out if f[0] != "1"]
if c2:
    cpu20 = sorted(f[2] for f in c2)
    print(f"\nCiclos 2-10: cpu20s mediana {cpu20[len(cpu20)//2]} ms (min {cpu20[0]}, máx {cpu20[-1]}), "
          f"bloque ≥90 % máx {max(f[4] for f in c2)} s, cuelgues {sum(f[5] for f in c2)}, "
          f"tirones>250ms {sum(f[7] for f in c2)}")
print("\nEstado térmico (intervalos):", Counter(s for _, s in termico).most_common() or "sin datos")
for t, s in termico:
    print(f"  t={t:7.1f}s  {s}")
