"""Memoria (huella física) de Yala por ciclo. Uso: mem_por_ciclo.py <sysmon.xml> <t0_ms> <ciclos.csv> [patron]"""
import csv, sys
sys.path.insert(0, sys.argv[0].rsplit("/", 1)[0] or ".")
import xtparse
path, t0, ciclos = sys.argv[1], int(open(sys.argv[2]).read().strip()), sys.argv[3]
patron = sys.argv[4] if len(sys.argv) > 4 else "Yala"
serie = {}
for r in xtparse.filas(path):
    p = r.get("process", (None, None)); p = p[1] or p[0]
    t = r.get("time", (None,))[0]; m = r.get("memory-physical-footprint", (None,))[0]
    if not p or t is None or m is None or patron not in p: continue
    serie.setdefault(p, []).append((int(t)/1e9, int(m)))
ev = list(csv.DictReader(open(ciclos)))
for p, v in serie.items():
    v.sort()
    def at(ts):
        prev = v[0][1]
        for t, m in v:
            if t > ts: break
            prev = m
        return prev
    print(f"{p}: {len(v)} muestras, de {v[0][1]/2**20:.0f} a {v[-1][1]/2**20:.0f} MiB, máx {max(m for _,m in v)/2**20:.0f}")
    print("ciclo, MiB al volver, MiB al irse (siguiente sale), máx en la vuelta")
    vueltas = [e for e in ev if e["evento"] == "vuelve"]
    for i, e in enumerate(vueltas):
        tv = (int(e["epoch_ms"]) - t0)/1000
        sal = [x for x in ev if x["evento"] == "sale" and int(x["ciclo"]) == int(e["ciclo"]) + 1]
        fin = [x for x in ev if x["evento"] == "fin"]
        ts = (int((sal or fin)[0]["epoch_ms"]) - t0)/1000
        mx = max([m for t, m in v if tv <= t <= ts] or [0])
        print(f"{e['ciclo']:>3}  {at(tv)/2**20:7.0f}  {at(ts)/2**20:7.0f}  {mx/2**20:7.0f}")
