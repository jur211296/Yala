"""Cuenta actualizaciones de SwiftUI por vista en la ventana de reposo y tras volver (swiftui-updates)."""
import csv, sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
path, t0_ms, rep, cic = sys.argv[1], int(open(sys.argv[2]).read().strip()), sys.argv[3], sys.argv[4]
def ventanas(p, a_ev, b_ev=None, desde=0, hasta=None):
    ev = list(csv.DictReader(open(p))); out = []
    for i, e in enumerate(ev):
        if e['evento'] == a_ev:
            a = (int(e['epoch_ms']) - t0_ms) / 1000 + desde
            b = a - desde + hasta if hasta else (int(ev[i + 1]['epoch_ms']) - t0_ms) / 1000
            out.append((a, b))
    return out
W = {'reposo Panel (20 s)': ventanas(rep, 'quieta_inicio'), '10 s tras volver': ventanas(cic, 'vuelve', hasta=10)}
cache = {}
cnt = {k: Counter() for k in W}; dur = {k: defaultdict(float) for k in W}
cols = []
for ev, el in ET.iterparse(path, events=('end',)):
    if el.tag == 'mnemonic': cols.append(el.text); continue
    if el.tag != 'row': continue
    vals = {}
    for c in el.iter():
        if c.get('id') and c.tag in ('string', 'view-hierarchy', 'process'):
            cache[c.get('id')] = c.get('fmt')
    for i, c in enumerate(el):
        name = cols[i] if i < len(cols) else None
        if name not in ('start', 'duration', 'view-name', 'description', 'module', 'process'):
            continue
        r = c.get('ref')
        if r: v = cache.get(r, '?')
        else:
            v = c.get('fmt') if name in ('view-name', 'description', 'module', 'process') else c.text
            if c.get('id'): cache[c.get('id')] = v
        vals[name] = v
    el.clear()
    try:
        t = int(vals.get('start') or 0) / 1e9; d = int(vals.get('duration') or 0) / 1e6
    except ValueError:
        continue
    for k, ws in W.items():
        if any(a <= t < b for a, b in ws):
            vn = vals.get('view-name') or '?'
            key = (vals.get('description') or '?')[:110] + '  ⟨' + (vn or '?')[:40] + '⟩'
            cnt[k][key] += 1; dur[k][key] += d
for k in W:
    tot = sum(cnt[k].values()); dsec = sum(b - a for a, b in W[k])
    print(f"\n=== {k}: {tot} actualizaciones en {dsec:.0f} s ({tot/dsec:.0f}/s), {sum(dur[k].values()):.0f} ms")
    for n, c in cnt[k].most_common(25):
        print(f"  {c:7d} ({c/dsec:6.0f}/s) {dur[k][n]:8.1f} ms  {n[:110]}")
