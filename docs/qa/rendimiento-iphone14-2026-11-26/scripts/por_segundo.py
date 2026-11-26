"""Muestras del hilo principal por segundo tras cada evento. Uso: por_segundo.py <tp.xml> <t0_ms_file> <csv> <evento> <seg>"""
import csv, sys
path, t0_ms, evp, evento, seg = sys.argv[1], int(open(sys.argv[2]).read().strip()), sys.argv[3], sys.argv[4], int(sys.argv[5])
exec(open(sys.argv[0].rsplit('/', 1)[0] + '/perfil_lector.py').read())
ev = list(csv.DictReader(open(evp)))
main = sorted(s[0] for s in samples if s[1])
import bisect
print("ciclo  " + " ".join(f"{i:>4}" for i in range(seg)) + "   (ms de hilo principal en cada segundo tras «" + evento + "»)")
for e in ev:
    if e["evento"] != evento: continue
    t = (int(e["epoch_ms"]) - t0_ms) / 1000
    row = [bisect.bisect_left(main, t + i + 1) - bisect.bisect_left(main, t + i) for i in range(seg)]
    print(f"{e['ciclo']:>5}  " + " ".join(f"{x:>4}" for x in row))
