"""Qué parte de la foto de los widgets ocupa el hilo principal, y en bloques de cuánto (lote 7).

Uso: foto_en_traza.py <traza.trace> [desde_s] [hasta_s] [carpeta exportes]
Cuenta las muestras del hilo principal (1 ms cada una) cuya pila pasa por WidgetDataCache, por pieza, y los bloques
continuos (huecos < 3 ms) de esas muestras.
"""
import os, sys
from collections import Counter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trazas

trace = sys.argv[1]
desde = float(sys.argv[2]) if len(sys.argv) > 2 else 0
hasta = float(sys.argv[3]) if len(sys.argv) > 3 else 1e9
carpeta = sys.argv[4] if len(sys.argv) > 4 else os.path.dirname(os.path.abspath(trace))
xml = trazas.exportar(trace, "time-profile", carpeta)
ms = trazas.muestras(xml)
t0 = min(t for t, _, _ in ms)
PIEZAS = ["buildPeriodSummary", "categoryExpenseSlices", "subcategoryExpenseBreakdown", "buildCashFlowByDay",
          "calculateBudgetSpent", "buildTrendData", "liveBalance", "batchCalculateBalances", "buildProjectedFlow",
          "GroupBridgeStatsAdjustment", "buildPaymentsMonth", "WidgetGroupsSnapshotBuilder", "SiriFinanceSnapshot",
          "saveSnapshot", "reloadAllTimelines", "scheduleReconcile", "fetch"]
por_pieza, por_hoja, bloques = Counter(), Counter(), []
ultimo, inicio_b, n_b = None, None, 0
total = 0
for t, main, pila in sorted(ms):
    r = t - t0
    if not main or r < desde or r > hasta:
        continue
    texto = " | ".join(pila)
    if "WidgetDataCache" not in texto:
        continue
    total += 1
    pieza = next((p for p in PIEZAS if p in texto), "otro")
    por_pieza[pieza] += 1
    hoja = next((f for f in pila if "WidgetDataCache" not in f and "closure" not in f), pila[0] if pila else "?")
    por_hoja[hoja[:110]] += 1
    if ultimo is not None and r - ultimo < 0.003:
        n_b += 1
    else:
        if inicio_b is not None:
            bloques.append((inicio_b, n_b))
        inicio_b, n_b = r, 1
    ultimo = r
if inicio_b is not None:
    bloques.append((inicio_b, n_b))
print(f"muestras de la foto en el hilo principal: {total} ms")
for p, n in por_pieza.most_common():
    print(f"  {p:32} {n:6} ms")
print("bloques > 100 ms (inicio s, ms):")
for b in bloques:
    if b[1] > 100:
        print(f"  {b[0]:7.2f}  {b[1]:5}")
print("hojas más frecuentes:")
for h, n in por_hoja.most_common(15):
    print(f"  {n:6}  {h}")
