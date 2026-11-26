"""Impacto de energía de Yala por ventana (reposo, 10 s tras volver, fuera). Uso: energia.py <PowerImpact.xml> <t0> <reposo.csv> <ciclos.csv>"""
import csv, sys
sys.path.insert(0, sys.argv[0].rsplit('/', 1)[0])
import xtparse
pi, t0_ms, rep, cic = sys.argv[1], int(open(sys.argv[2]).read().strip()), sys.argv[3], sys.argv[4]
rows = []
for r in xtparse.filas(pi):
    if (r.get('process-name') or (0, ''))[1] != 'Yala': continue
    if (r.get('row-kind') or ('',))[0] != '0': continue
    t = int(r['start'][0]) / 1e9; d = int(r['duration'][0]) / 1e9
    f = lambda k: float((r.get(k) or ('0',))[0] or 0)
    rows.append((t, d, f('cpu-impact'), f('gpu-impact'), f('display-impact')))
def W(p, ev, hasta=None):
    e = list(csv.DictReader(open(p))); out = []
    for i, x in enumerate(e):
        if x['evento'] == ev:
            a = (int(x['epoch_ms']) - t0_ms) / 1000
            b = a + hasta if hasta else (int(e[i + 1]['epoch_ms']) - t0_ms) / 1000
            out.append((a, b))
    return out
V = {'reposo en el Panel': W(rep, 'quieta_inicio'), '10 s tras volver': W(cic, 'vuelve', 10), 'fuera (otra app delante)': W(cic, 'sale')}
for k, ws in V.items():
    sel = [x for x in rows if any(a <= x[0] < b for a, b in ws)]
    if not sel: print(k, 'sin filas'); continue
    n = len(sel)
    print(f"{k:<28} CPU {sum(x[2] for x in sel)/n:5.2f}  GPU {sum(x[3] for x in sel)/n:5.2f}  pantalla {sum(x[4] for x in sel)/n:5.2f}  (impacto medio por segundo, {n} muestras)")
