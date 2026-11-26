# Uso: donde.py <time-profile.xml> <t0_ms> <ciclos.csv> <texto de función>
import sys, csv
path = sys.argv[1]
exec(open(sys.argv[0].rsplit('/', 1)[0] + '/perfil_lector.py').read())
t0 = int(open(sys.argv[2]).read().strip()); ev = list(csv.DictReader(open(sys.argv[3]))); fn = sys.argv[4]
marks = [((int(e['epoch_ms']) - t0) / 1000, e['ciclo'], e['evento']) for e in ev]
hits = sorted(s[0] for s in samples if s[1] and any(fn in (f[0] or '') for f in s[2]))
from collections import Counter
c = Counter()
for t in hits:
    prev = None
    for m in marks:
        if m[0] <= t: prev = m
    c[(prev[1], prev[2]) if prev else ('antes', 'arranque')] += 1
for k, v in sorted(c.items(), key=lambda x: (x[0][0] != 'antes', x[0][0].zfill(3), x[0][1])): print(k, v, 'ms')
