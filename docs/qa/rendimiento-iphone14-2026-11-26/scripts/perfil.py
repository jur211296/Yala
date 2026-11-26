"""Perfil de tiempo por ventanas. Uso:
perfil.py <time-profile.xml> <t0_ms> <eventos.csv> [--hilo main|all] [--top N]
Ventanas: definidas por los eventos del csv (vuelve→scroll_inicio = «volver», scroll = «scroll», etc.).
Cuenta muestras (1 ms) INCLUSIVAS por función de Yala y EXCLUSIVAS (hoja) por función cualquiera."""
import csv
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict

args = sys.argv[1:]
path, t0_ms, evpath = args[0], int(open(args[1]).read().strip()), args[2]
hilo = "main"
top = 25
if "--hilo" in args:
    hilo = args[args.index("--hilo") + 1]
if "--top" in args:
    top = int(args[args.index("--top") + 1])

frames = {}   # id -> (name, binary)
bts = {}      # id -> [frame names]
threads = {}  # id -> fmt
binaries = {}


def frame_of(el):
    ref = el.get("ref")
    if ref:
        return frames.get(ref)
    name = el.get("name") or "?"
    b = el.find("binary")
    bname = None
    if b is not None:
        if b.get("ref"):
            bname = binaries.get(b.get("ref"))
        else:
            bname = b.get("name")
            binaries[b.get("id")] = bname
    frames[el.get("id")] = (name, bname)
    return frames[el.get("id")]


samples = []  # (t_s, is_main, [(name, bin)])
for ev, el in ET.iterparse(path, events=("end",)):
    if el.tag != "row":
        continue
    t = th = None
    stack = None
    for c in el:
        if c.tag == "sample-time":
            t = int(c.text) / 1e9 if c.text else None
            if c.get("id"):
                threads["st" + c.get("id")] = t
            elif c.get("ref"):
                t = threads.get("st" + c.get("ref"))
        elif c.tag == "thread":
            if c.get("ref"):
                th = threads.get(c.get("ref"))
            else:
                th = c.get("fmt")
                threads[c.get("id")] = th
        elif c.tag in ("backtrace", "tagged-backtrace"):
            if c.get("ref"):
                stack = bts.get(c.get("ref"))
            else:
                stack = [frame_of(f) for f in c.findall("frame")]
                bts[c.get("id")] = stack
    if t is not None and stack is not None:
        samples.append((t, bool(th and th.startswith("Main Thread")), stack))
    el.clear()

ev = list(csv.DictReader(open(evpath)))
T = lambda e: (int(e["epoch_ms"]) - t0_ms) / 1000  # noqa: E731
ventanas = defaultdict(list)
for i, e in enumerate(ev):
    nxt = ev[i + 1] if i + 1 < len(ev) else None
    if not nxt:
        continue
    if e["evento"] == "vuelve":
        ventanas["volver (hasta el scroll)"].append((T(e), T(nxt)))
    elif e["evento"] == "scroll_inicio":
        ventanas["scroll"].append((T(e), T(nxt)))
    elif e["evento"] == "scroll_fin":
        ventanas["quieta tras scroll"].append((T(e), T(nxt)))
    elif e["evento"] == "sale":
        ventanas["fuera"].append((T(e), T(nxt)))
ventanas["reposo inicial (incluye arranque)"].append((0, T(ev[1]) if len(ev) > 1 else 20))


def en(t, vs):
    return any(a <= t < b for a, b in vs)


for nombre, vs in ventanas.items():
    dur = sum(b - a for a, b in vs)
    sel = [s for s in samples if en(s[0], vs) and (hilo == "all" or s[1])]
    inc = Counter()
    hoja = Counter()
    for _, _, st in sel:
        vistos = set()
        for n, b in st:
            if b and ("Yala" in b) and n not in vistos:
                inc[n] += 1
                vistos.add(n)
        if st:
            hoja[f"{st[0][0]}  [{st[0][1]}]"] += 1
    print(f"\n=== {nombre}: {dur:.1f} s, {len(sel)} muestras {'hilo principal' if hilo=='main' else 'todos los hilos'} "
          f"(≈{len(sel)/max(dur,0.001)/10:.1f} % de un núcleo)")
    print("  -- inclusivo, funciones de Yala --")
    for n, c in inc.most_common(top):
        print(f"  {c:6d}  {n[:150]}")
    print("  -- exclusivo (hoja) --")
    for n, c in hoja.most_common(12):
        print(f"  {c:6d}  {n[:150]}")
