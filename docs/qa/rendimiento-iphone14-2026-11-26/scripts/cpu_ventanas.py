"""CPU por ventana (quieta delante, scroll, quieta tras scroll, fuera) para varios procesos.
Uso: cpu_ventanas.py <sysmon-process.xml> <t0_ms> <ciclos.csv> <proc1> [proc2 ...]"""
import csv
import sys
from collections import defaultdict

sys.path.insert(0, sys.argv[0].rsplit("/", 1)[0])
import xtparse  # noqa: E402

path, t0_ms, ciclos = sys.argv[1], int(open(sys.argv[2]).read().strip()), sys.argv[3]
procs = sys.argv[4:]
serie = defaultdict(list)
for r in xtparse.filas(path):
    p = r.get("process", (None, None))[1]
    if p not in procs:
        continue
    t = int(r["time"][0]) / 1e9
    cpu = int(r.get("cpu-total-user", (0,))[0] or 0) + int(r.get("cpu-total-system", (0,))[0] or 0)
    serie[p].append((t, cpu))
for v in serie.values():
    v.sort()


def cpu_at(p, ts):
    prev = serie[p][0][1]
    for t, c in serie[p]:
        if t > ts:
            break
        prev = c
    return prev


ev = list(csv.DictReader(open(ciclos)))
T = lambda e: (int(e["epoch_ms"]) - t0_ms) / 1000  # noqa: E731
ventanas = defaultdict(list)  # tipo -> [(a,b)]
primero = T(ev[0])
ventanas["reposo inicial (delante, quieta)"].append((2, primero - 1))
for i, e in enumerate(ev):
    if e["evento"] == "sale":
        nxt = next(x for x in ev[i + 1:] if x["evento"] == "vuelve")
        ventanas["fuera (otra app delante)"].append((T(e) + 1, T(nxt)))
    if e["evento"] == "vuelve":
        si = next(x for x in ev[i + 1:] if x["evento"] == "scroll_inicio")
        ventanas["primeros 2 s al volver"].append((T(e), T(si)))
    if e["evento"] == "scroll_inicio":
        sf = next(x for x in ev[i + 1:] if x["evento"] == "scroll_fin")
        ventanas["scroll (12 flicks)"].append((T(e), T(sf)))
    if e["evento"] == "scroll_fin":
        nx = next((x for x in ev[i + 1:] if x["evento"] in ("sale", "fin")), None)
        if nx:
            ventanas["quieta tras scroll"].append((T(e) + 0.5, T(nx)))
fin = next(e for e in ev if e["evento"] == "fin")
ventanas["reposo final (delante, quieta)"].append((T(fin) + 1, T(fin) + 14))

print("ventana".ljust(34), "dur(s)", *[p[:24].rjust(24) for p in procs])
for k, vs in ventanas.items():
    d = sum(b - a for a, b in vs)
    vals = []
    for p in procs:
        c = sum(cpu_at(p, b) - cpu_at(p, a) for a, b in vs) / 1e9
        vals.append(f"{100*c/d:5.1f}% núcleo")
    print(k.ljust(34), f"{d:6.1f}", *[v.rjust(24) for v in vals])
