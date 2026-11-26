import csv, sys
from collections import Counter
path, t0_ms, evp, pant = sys.argv[1], int(open(sys.argv[2]).read().strip()), sys.argv[3], sys.argv[4]
exec(open(sys.argv[0].rsplit('/', 1)[0] + '/perfil_lector.py').read())
ev = list(csv.DictReader(open(evp)))
T = lambda e: (int(e['epoch_ms']) - t0_ms) / 1000
ws = [(T(e) + 3, T(ev[i + 1])) for i, e in enumerate(ev) if e['evento'] == 'quieta_inicio' and e['ciclo'] == pant]
sel = [s for s in samples if s[1] and any(a <= s[0] < b for a, b in ws)]
c = Counter(); cs = Counter()
for _, _, st in sel:
    seen = set()
    for n, b in st:
        if b and 'Yala' in b and n not in seen and 'main' not in n and '$main' not in n and 'deduplicated' not in n:
            c[n] += 1; seen.add(n)
    for n, b in st:
        if b and 'SwiftUI' in b and ('Animat' in n or 'animation' in n.lower() or 'Effect' in n or 'Transaction' in n) and n not in seen:
            cs[n] += 1; seen.add(n)
print(len(sel), 'muestras')
for n, v in c.most_common(25): print(f"{v:6d} {100*v/len(sel):5.1f}% {n[:140]}")
print('-- SwiftUI animación/efectos --')
for n, v in cs.most_common(15): print(f"{v:6d} {100*v/len(sel):5.1f}% {n[:140]}")
