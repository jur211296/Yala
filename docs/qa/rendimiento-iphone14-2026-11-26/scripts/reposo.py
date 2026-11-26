import csv, sys
from collections import Counter
path, t0_ms, evp = sys.argv[1], int(open(sys.argv[2]).read().strip()), sys.argv[3]
exec(open(sys.argv[0].rsplit('/', 1)[0] + '/perfil_lector.py').read())
ev = list(csv.DictReader(open(evp)))
T = lambda e: (int(e['epoch_ms']) - t0_ms) / 1000
for i, e in enumerate(ev):
    if e['evento'] != 'quieta_inicio': continue
    a, b = T(e) + 3, T(ev[i + 1])  # descarta 3 s de asentamiento
    sel = [s for s in samples if s[1] and a <= s[0] < b]
    allt = [s for s in samples if a <= s[0] < b]
    c = Counter()
    for _, _, st in sel:
        names = {n for n, _ in st}
        for k in ('ViewGraphDisplayLink.displayLinkTimer', 'TrendChartView.body', 'spokenSummary', 'liquidTrendChart', 'GlassContainer', 'Skeleton', 'performCalculation', 'Spotlight', 'WidgetDataCache', 'StatisticsRecalculation'):
            if any(k in n for n in names): c[k] += 1
    print(f"{e['ciclo']:<26} {b-a:4.0f} s  hilo ppal {len(sel)/(b-a)/10:5.1f}%  todos los hilos {len(allt)/(b-a)/10:5.1f}%  | " + ", ".join(f"{k} {100*v/max(len(sel),1):.0f}%" for k, v in c.most_common(5)))
