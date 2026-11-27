"""Bloques del hilo principal del Panel en el arranque (lote 8).

Uso: bloques_panel.py <traza.trace> [hasta_s=60] [carpeta exportes]
Bloques continuos del hilo principal (muestras de 1 ms con huecos < 3 ms, `GAP_MS`) en los que la mayoría de muestras pasa por PanelViewModel, con su
duración y las funciones del Panel que más pesan dentro. Un bloque > 100 ms es lo que el encargo quiere quitar.
"""
import os, re, sys
from collections import Counter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trazas
trace = sys.argv[1]
hasta = float(sys.argv[2]) if len(sys.argv) > 2 else 60
carpeta = sys.argv[3] if len(sys.argv) > 3 else os.path.dirname(os.path.abspath(trace))
ms = sorted((t, p) for t, main, p in trazas.muestras(trazas.exportar(trace, "time-profile", carpeta)) if main)
t0 = ms[0][0]
GAP = float(os.environ.get("GAP_MS", "3")) / 1000  # como el lote 7: un hueco de 3 ms o más corta. Une tramos separados
# por una cesión (1 ms de espera, hueco de 2 ms) y por eso el «después» sale por lo alto; con 1,5 ms, el muestreo parte
# tramos que no cedieron.
bloques = []; actual = []; ultimo = None
for t, pila in ms:
    r = t - t0
    if r > hasta: break
    if ultimo is not None and r - ultimo >= GAP:
        bloques.append(actual); actual = []
    actual.append((r, pila)); ultimo = r
if actual: bloques.append(actual)
def funcion_panel(pila):
    # La función del Panel más profunda de la pila (la más cercana a la hoja).
    for f in pila:
        if "PanelViewModel" in f and "closure" not in f:
            return re.sub(r"\(.*", "", f.split("PanelViewModel.")[-1])[:60]
    return None
print("inicio s  dura ms  panel%  funciones del Panel (ms)")
grandes = 0
for b in bloques:
    if len(b) < 100: continue
    panel = [funcion_panel(p) for _, p in b]
    n_panel = sum(1 for x in panel if x)
    if n_panel < len(b) / 2: continue
    grandes += 1
    c = Counter(x for x in panel if x)
    top = ", ".join(f"{k} {v}" for k, v in c.most_common(5))
    print(f"{b[0][0]:8.2f}  {len(b):7}  {100*n_panel//len(b):5}%  {top}")
print(f"\n{grandes} bloques > 100 ms del Panel en los primeros {hasta:.0f} s")
