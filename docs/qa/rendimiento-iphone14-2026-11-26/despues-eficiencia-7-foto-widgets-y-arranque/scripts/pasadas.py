"""Pasadas fuera de pantalla y tirones por pantalla durante el scroll de la pasada D.

Uso: pasadas.py <traza.trace> <ciclos.csv>
Exporta de la traza la tabla hitches-renders (fotogramas del servidor de render, columna Offscreen Passes) y la tabla
hitches (tirones de Yala), y los corta por las ventanas scroll_inicio..scroll_fin del csv de pantallas.sh.
"""
import csv, datetime, os, re, statistics, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import xtparse

trace, evp = sys.argv[1], sys.argv[2]
toc = subprocess.run(['xcrun', 'xctrace', 'export', '--input', trace, '--toc'], capture_output=True, text=True).stdout
m = re.search(r'<start-date>([^<]+)</start-date>', toc)
t0 = datetime.datetime.fromisoformat(m.group(1)).timestamp()
tmp = tempfile.mkdtemp()

def tabla(schema):
    out = os.path.join(tmp, schema + '.xml')
    with open(out, 'w') as f:
        subprocess.run(['xcrun', 'xctrace', 'export', '--input', trace, '--xpath',
                        f'/trace-toc/run[1]/data/table[@schema="{schema}"]'], stdout=f, stderr=subprocess.DEVNULL)
    return out

renders = [(int(r['start'][0]) / 1e9, int(r['offscreen-passes'][0]))
           for r in xtparse.filas(tabla('hitches-renders')) if r.get('offscreen-passes') and r['offscreen-passes'][0]]
hit = []
for r in xtparse.filas(tabla('hitches')):
    p = (r.get('process') or (0, ''))[1] or ''
    if 'Yala' in p:
        d = (r.get('narrative-description') or ('', ''))[0] or ''
        hit.append((int(r['start'][0]) / 1e9, int(r['duration'][0]) / 1e6, 'render' in d or 'GPU' in d))

ev = list(csv.DictReader(open(evp)))
T = lambda e: int(e['epoch_ms']) / 1000 - t0
print(f"{'ronda':>5} {'pantalla':<26} {'fotog':>5} {'mediana':>7} {'p90':>4} {'máx':>4} {'tirones':>7} {'tir/s':>5}")
por = {}
for i, e in enumerate(ev):
    if e['evento'] != 'scroll_inicio':
        continue
    a, b = T(e), T(ev[i + 1])
    ps = sorted(p for t, p in renders if a <= t < b)
    hs = [d for t, d, _ in hit if a <= t < b]
    hr = [d for t, d, render in hit if a <= t < b and render]
    por.setdefault(e['pantalla'], []).append((ps, len(hs), b - a, len(hr)))
    if ps:
        print(f"{e['ciclo']:>5} {e['pantalla']:<26} {len(ps):5d} {statistics.median(ps):7.0f} "
              f"{ps[int(len(ps) * .9)]:4d} {max(ps):4d} {len(hs):7d} {len(hs) / (b - a):5.2f}")
print('\nTotal por pantalla (3 rondas)')
todo, ttir, tdur = [], 0, 0
for k, v in por.items():
    ps = sorted(x for r in v for x in r[0]); n = sum(r[1] for r in v); d = sum(r[2] for r in v)
    nr = sum(r[3] for r in v)
    todo += ps; ttir += n; tdur += d; trend = locals().get('trend', 0) + nr
    if ps:
        print(f"  {k:<26} mediana {statistics.median(ps):4.0f}  máx {max(ps):4d}  tirones/s {n / d:5.2f}"
              f"  (de render {nr / d:4.2f})")
todo.sort()
print(f"  {'TODAS':<26} mediana {statistics.median(todo):4.0f}  máx {max(todo):4d}  tirones/s {ttir / tdur:5.2f}"
      f"  (de render {trend / tdur:4.2f})")
