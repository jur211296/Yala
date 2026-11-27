"""Impacto de energía de Yala por ventana (reposo, 10 s tras volver, fuera), como `../../scripts/energia.py` del informe.

Uso: energia.py <traza.trace> <reposo.csv> <ciclos.csv> [carpeta de exportes]
Lee la tabla ProcessSubsystemPowerImpact del Power Profiler (una fila por proceso y segundo).
"""
import csv
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trazas  # noqa: E402

trace, rep, cic = sys.argv[1], sys.argv[2], sys.argv[3]
carpeta = sys.argv[4] if len(sys.argv) > 4 else os.path.dirname(os.path.abspath(trace))
t0 = trazas.inicio(trace)
filas = []
for r in trazas.filas(trazas.exportar(trace, "ProcessSubsystemPowerImpact", carpeta)):
    nombre = (r.get("process-name") or (None, ""))[1] or (r.get("process-name") or ("",))[0] or ""
    if nombre != "Yala":
        continue
    if (r.get("row-kind") or ("0",))[0] not in ("0", None):
        continue
    f = lambda k: float((r.get(k) or ("0",))[0] or 0)
    filas.append((int(r["start"][0]) / 1e9, f("cpu-impact"), f("gpu-impact"), f("display-impact")))


def ventanas(path, evento, hasta=None):
    e = list(csv.DictReader(open(path)))
    out = []
    for i, x in enumerate(e):
        if x["evento"] == evento:
            a = int(x["epoch_ms"]) / 1000 - t0
            b = a + hasta if hasta else int(e[i + 1]["epoch_ms"]) / 1000 - t0
            out.append((a, b))
    return out


V = {"reposo en el Panel": ventanas(rep, "quieta_inicio"),
     "10 s tras volver": ventanas(cic, "vuelve", 10),
     "fuera (otra app delante)": ventanas(cic, "sale")}
for k, ws in V.items():
    sel = [x for x in filas if any(a <= x[0] < b for a, b in ws)]
    if not sel:
        print(k, "sin filas")
        continue
    n = len(sel)
    print(f"{k:<28} CPU {sum(x[1] for x in sel) / n:5.2f}  GPU {sum(x[2] for x in sel) / n:5.2f}  "
          f"pantalla {sum(x[3] for x in sel) / n:5.2f}  (impacto medio por segundo, {n} muestras)")
