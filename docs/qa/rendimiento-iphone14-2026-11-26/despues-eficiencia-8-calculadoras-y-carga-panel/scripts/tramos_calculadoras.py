"""Tramos sin ceder de las calculadoras compartidas y de la carga del Panel (lote 8).

Uso: tramos_calculadoras.py <traza.trace> [desde_s] [hasta_s] [carpeta exportes]
Para cada pieza, los tramos continuos del hilo principal (muestras de 1 ms con huecos < 3 ms, `GAP_MS`) cuya pila pasa por ella, y
dentro de qué (foto de los widgets o Panel). Un tramo continuo es un bloque sin ceder: una cesión deja un hueco ≥ 1 ms.
"""
import os, sys
from collections import Counter, defaultdict
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trazas

trace = sys.argv[1]
desde = float(sys.argv[2]) if len(sys.argv) > 2 else 0
hasta = float(sys.argv[3]) if len(sys.argv) > 3 else 1e9
carpeta = sys.argv[4] if len(sys.argv) > 4 else os.path.dirname(os.path.abspath(trace))
ms = sorted((t, p) for t, main, p in trazas.muestras(trazas.exportar(trace, "time-profile", carpeta)) if main)
if not ms:
    sys.exit("sin muestras")
t0 = ms[0][0]
GAP = float(os.environ.get("GAP_MS", "3")) / 1000  # como el lote 7: un hueco de 3 ms o más corta. Une tramos separados
# por una cesión (1 ms de espera, hueco de 2 ms) y por eso el «después» sale por lo alto; con 1,5 ms, el muestreo parte
# tramos que no cedieron.
PIEZAS = {
    "saldo vivo": ["LiveBalanceCalculator", "SumaSaldoVivo"],
    "valoración (BalanceValuation)": ["BalanceValuation"],
    "tasas en bloque (rateFactors)": ["rateFactors"],
    "saldos por cuenta": ["AccountBalanceCalculator", "SumaSaldosPorCuenta"],
    "carga del Panel (loadData)": ["PanelViewModel.loadData", "cargarPorTramos", "cargarListas", "aplicarGruposYHuerfanos",
                                   "cargarPlanificacion", "calculateAccountBalances"],
    "curva de la foto (TendenciaFoto)": ["TendenciaFoto"],
    "curva de la app (fillBalanceBuckets)": ["fillBalanceBuckets"],
    "resultado cambiario (FXPnL)": ["FXPnLLogic"],
    "ajuste de grupos": ["GroupBridgeStatsAdjustment"],
    "huérfanos": ["OrphanedRecordsService", "GroupLegEvidence"],
}
def donde(texto):
    if "WidgetDataCache" in texto: return "foto"
    if "PanelViewModel" in texto: return "Panel"
    if "StatisticsViewModel" in texto: return "Estadísticas"
    return "otro"
for nombre, claves in PIEZAS.items():
    runs = []  # (inicio, ms, dónde)
    ultimo = inicio = None; n = 0; lugar = Counter()
    for t, pila in ms:
        r = t - t0
        if r < desde or r > hasta: continue
        texto = " | ".join(pila)
        if not any(c in texto for c in claves): continue
        if ultimo is not None and r - ultimo < GAP:
            n += 1
        else:
            if inicio is not None: runs.append((inicio, n, lugar.most_common(1)[0][0]))
            inicio, n, lugar = r, 1, Counter()
        lugar[donde(texto)] += 1
        ultimo = r
    if inicio is not None: runs.append((inicio, n, lugar.most_common(1)[0][0]))
    total = sum(x[1] for x in runs)
    grandes = sorted([x for x in runs if x[1] > 50], key=lambda x: -x[1])
    mx = max((x[1] for x in runs), default=0)
    print(f"{nombre:32} total {total:5} ms · tramos {len(runs):4} · el mayor {mx:4} ms · > 50 ms: {len(grandes)}")
    for i, d, l in grandes[:8]:
        print(f"      t={i:7.2f}s  {d:4} ms  ({l})")
