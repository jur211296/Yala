"""Por pantalla y ronda: ms de hilo principal/s durante el scroll, tirones y ms congelados. Uso: por_pantalla.py <tp.xml> <hitches.xml> <t0> <csv>"""
import csv, sys, bisect
sys.path.insert(0, sys.argv[0].rsplit('/', 1)[0])
import xtparse
tp, hp, t0_ms, evp = sys.argv[1], sys.argv[2], int(open(sys.argv[3]).read().strip()), sys.argv[4]
exec(open(sys.argv[0].rsplit('/', 1)[0] + '/perfil_lector.py').read().replace('path', 'tp'))
main = sorted(s[0] for s in samples if s[1])
hit = []
for r in xtparse.filas(hp):
    p = (r.get('process') or (0, ''))[1] or ''
    if 'Yala' in p:
        hit.append((int(r['start'][0]) / 1e9, int(r['duration'][0]) / 1e6))
ev = list(csv.DictReader(open(evp)))
T = lambda e: (int(e['epoch_ms']) - t0_ms) / 1000
print(f"{'ronda':>5} {'pantalla':<26} {'dur s':>5} {'hilo ppal %':>11} {'tirones':>7} {'ms en tirón':>11} {'peor ms':>7}")
for i, e in enumerate(ev):
    if e['evento'] != 'scroll_inicio': continue
    a, b = T(e), T(ev[i + 1])
    n = bisect.bisect_left(main, b) - bisect.bisect_left(main, a)
    hs = [d for t, d in hit if a <= t < b]
    print(f"{e['ciclo']:>5} {e['pantalla']:<26} {b-a:5.1f} {n/(b-a)/10:10.0f}% {len(hs):7d} {sum(hs):11.0f} {max(hs or [0]):7.0f}")
# vuelta: 6 s tras volver
for e in ev:
    if e['evento'] == 'vuelve':
        a = T(e); row = [bisect.bisect_left(main, a + k + 1) - bisect.bisect_left(main, a + k) for k in range(8)]
        print('ronda', e['ciclo'], 'ms hilo ppal por segundo tras volver:', row)
