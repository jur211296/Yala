import csv, sys, json, bisect
tp, t0f, evp, evento, seg, out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5]), sys.argv[6]
path = tp
exec(open(sys.argv[0].rsplit('/', 1)[0] + '/perfil_lector.py').read())
t0_ms = int(open(t0f).read().strip())
ev = list(csv.DictReader(open(evp)))
main = sorted(s[0] for s in samples if s[1])
M = {}
for e in ev:
    if e['evento'] != evento: continue
    t = (int(e['epoch_ms']) - t0_ms) / 1000
    M[e['ciclo']] = [bisect.bisect_left(main, t + i + 1) - bisect.bisect_left(main, t + i) for i in range(seg)]
json.dump(M, open(out, 'w'))
for k, v in M.items():
    blk = 0
    for x in v:
        if x >= 900: blk += 1
        elif blk > 0: break
    print(k, 'bloque continuo ≥90% desde volver:', blk, 's; total ms en', seg, 's:', sum(v))
