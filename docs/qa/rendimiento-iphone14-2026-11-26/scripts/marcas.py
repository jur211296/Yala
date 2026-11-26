"""Marcas app.yala.perf del os-signpost: lista eventos e intervalos con tiempo relativo y ciclo."""
import csv, sys
from collections import defaultdict
sys.path.insert(0, sys.argv[0].rsplit('/', 1)[0])
import xtparse
path, t0_ms, evp = sys.argv[1], int(open(sys.argv[2]).read().strip()), sys.argv[3]
ev = list(csv.DictReader(open(evp)))
marks = [((int(e["epoch_ms"]) - t0_ms) / 1000, e["ciclo"], e["evento"]) for e in ev]
def donde(t):
    last = ("arranque", "reposo")
    for tm, c, e in marks:
        if tm > t: break
        last = (c, e)
    return last
abiertos = {}
out = []
for r in xtparse.filas(path):
    sub = (r.get("subsystem") or (None, None))[1]
    if sub != "app.yala.perf": continue
    t = int(r["time"][0]) / 1e9
    tipo = r["event-type"][1]; nombre = r["name"][1]; ident = r["identifier"][1]
    msg = (r.get("message") or (None, None))[1] or ""
    cat = (r.get("category") or (None, None))[1]
    if tipo == "Begin":
        abiertos[(nombre, ident)] = t
    elif tipo == "End":
        t0 = abiertos.pop((nombre, ident), None)
        if t0 is not None:
            out.append((t0, "int", nombre, (t - t0) * 1000, msg, cat))
    else:
        out.append((t, "evt", nombre, None, msg, cat))
out.sort()
for t, k, n, d, m, cat in out:
    c, e = donde(t)
    print(f"{t:8.2f}s  ciclo {c:>4} tras {e:<13} {n:<34} {'' if d is None else f'{d:8.1f} ms'}  {m[:60]}  [{cat}]")
