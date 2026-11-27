import os, sys
from collections import Counter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trazas
xml = sys.argv[1]
PIEZAS = ["buildPeriodSummary", "buildTrendData", "liveBalance", "calculateBudgetSpent", "batchCalculateBalances",
          "GroupBridgeStatsAdjustment", "fetch", "saveSnapshot"]
c = Counter()
for t, main, pila in trazas.muestras(xml):
    if not main: continue
    texto = " | ".join(pila)
    if "WidgetDataCache" not in texto or any(p in texto for p in PIEZAS): continue
    # pila: hoja primero. El frame justo por debajo (hacia la hoja) del más interno de WidgetDataCache.
    idx = max(i for i, f in enumerate(pila) if "WidgetDataCache" in f)
    inner = min(i for i, f in enumerate(pila) if "WidgetDataCache" in f)
    callee = pila[inner - 1] if inner > 0 else pila[0]
    c[(pila[inner][:90], callee[:90])] += 1
for (a, b), n in c.most_common(25):
    print(f"{n:6}  {a}  ->  {b}")
