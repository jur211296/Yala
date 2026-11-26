"""CPU por proceso a partir de sysmon-process (acumulados user+system) y CPU de Yala por ciclo.
Uso: cpu_por_proceso.py <sysmon-process.xml> <t0_ms> <ciclos.csv> <patron_proceso_yala> [top]"""
import csv
import sys
from collections import defaultdict

sys.path.insert(0, sys.argv[0].rsplit("/", 1)[0])
import xtparse  # noqa: E402

path, t0_ms, ciclos, patron = sys.argv[1], int(open(sys.argv[2]).read().strip()), sys.argv[3], sys.argv[4]
top = int(sys.argv[5]) if len(sys.argv) > 5 else 15

serie = defaultdict(list)  # proceso -> [(t_s, cpu_ns, mem_bytes)]
for r in xtparse.filas(path):
    p = r.get("process", (None, None))[1]
    t = r.get("time", (None,))[0]
    u = r.get("cpu-total-user", (None,))[0]
    s = r.get("cpu-total-system", (None,))[0]
    m = r.get("memory-physical-footprint", (None,))[0]
    if p is None or t is None:
        continue
    cpu = int(u or 0) + int(s or 0)
    serie[p].append((int(t) / 1e9, cpu, int(m or 0)))

tot = []
for p, v in serie.items():
    v.sort()
    tot.append(((v[-1][1] - v[0][1]) / 1e9, p, v[0][2], v[-1][2]))
tot.sort(reverse=True)
dur = max(x[0] for v in serie.values() for x in v)
print(f"Duración traza: {dur:.0f} s · CPU por proceso (s de CPU en toda la traza, % de un núcleo):")
for c, p, m0, m1 in tot[:top]:
    print(f"  {c:8.2f} s  {100*c/dur:5.1f} %  {p}   mem {m0/2**20:.0f}→{m1/2**20:.0f} MiB")

# CPU de Yala por ciclo: del «vuelve» al siguiente «sale»
ev = list(csv.DictReader(open(ciclos)))
yala = [p for p in serie if patron in p]
print("Procesos Yala:", yala)
for yp in yala:
    v = serie[yp]

    def cpu_at(ts):
        prev = None
        for t, c, m in v:
            if t > ts:
                break
            prev = (c, m)
        return prev or (v[0][1], v[0][2])

    print(f"\n{yp}: ciclo, CPU desde volver hasta irse (s), duración (s), % núcleo, CPU en fondo previo (s), mem al volver (MiB)")
    vuelve = {}
    sale = {}
    for e in ev:
        if e["evento"] == "vuelve":
            vuelve[e["ciclo"]] = (int(e["epoch_ms"]) - t0_ms) / 1000
        if e["evento"] == "sale":
            sale[e["ciclo"]] = (int(e["epoch_ms"]) - t0_ms) / 1000
    fin = [e for e in ev if e["evento"] == "fin"]
    for k in sorted(vuelve, key=int):
        a = vuelve[k]
        nxt = str(int(k) + 1)
        b = sale.get(nxt) or ((int(fin[0]["epoch_ms"]) - t0_ms) / 1000 if fin else dur)
        ca, ma = cpu_at(a)
        cb, _ = cpu_at(b)
        sb, _ = cpu_at(sale[k])
        print(f"  {k:>2}  {(cb-ca)/1e9:6.2f}  {b-a:5.1f}  {100*(cb-ca)/1e9/(b-a):5.1f}  {(ca-sb)/1e9:5.2f}  {ma/2**20:6.0f}")
