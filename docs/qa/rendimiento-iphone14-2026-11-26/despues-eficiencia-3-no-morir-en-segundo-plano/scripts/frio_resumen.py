#!/usr/bin/env python3
"""Resume una pasada de frio.sh: por vuelta, cuándo quedó listo el Panel (PERF arranque), cálculos del Panel, cortes y
si el proceso siguió vivo hasta el final. Uso: frio_resumen.py <carpeta de la pasada>"""
import csv, re, sys, pathlib
d = pathlib.Path(sys.argv[1])
ev = {}
for r in csv.DictReader(open(d / "eventos.csv")):
    ev.setdefault(r["vuelta"], {})[r["evento"]] = int(r["epoch_ms"])
print("vuelta | listo_ms(PERF arranque) | calculos_empezados | cortes_spotlight | consola_viva_hasta_fin | ultima_linea_tras_salir_ms")
for v in sorted(ev, key=int):
    log = d / f"consola.{v}.log"
    lines = log.read_text(errors="replace").splitlines() if log.exists() else []
    perf = [re.search(r"PERF arranque ([\d.]+) ms", l) for l in lines]
    perf = [float(m.group(1)) for m in perf if m]
    calcs = sum("performCalculation #" in l for l in lines)
    cortes = sum("se corta la reconciliación" in l for l in lines)
    stamps = [int(l.split(" ", 1)[0]) for l in lines if l[:13].isdigit()]
    last = stamps[-1] if stamps else 0
    sale = ev[v].get("sale", 0); fin = ev[v].get("fin", 0)
    viva = any("terminated" in l.lower() or "exited" in l.lower() for l in lines)
    print(f"{v} | {perf[0] if perf else '-'} | {calcs} | {cortes} | {'no (terminó)' if viva else 'sí'} | {last - sale if last else '-'}")
