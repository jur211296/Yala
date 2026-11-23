Yala
# Marcar como aproximados los importes convertidos en Informes, la curva de saldo y el total de Análisis del gasto
---
toca: Yala/App/Views/Reports/,Yala/App/Views/Panel/PieChartVariationHeader.swift,YalaTests/MarcaAproximado/,tickets/backlog/financial-report-amounts-unmarked.md,tickets/backlog/fx-historical-balance-curve-unmarked.md,tickets/backlog/pie-header-total-unmarked.md,tickets/done/financial-report-amounts-unmarked.md,tickets/done/fx-historical-balance-curve-unmarked.md,tickets/done/pie-header-total-unmarked.md,tickets/backlog/2026-11-22-marca-aproximado-informes-y-graficas.md,tickets/done/2026-11-22-marca-aproximado-informes-y-graficas.md
esfuerzo: medium
cierre: cierra-sola
---

Jürgen pidió el 22-nov (15:08 Lima) encolar todo lo pendiente del backlog que esté claro o tenga decisión. Este encargo junta tickets afines.

## Tickets
- `tickets/backlog/financial-report-amounts-unmarked.md`
- `tickets/backlog/fx-historical-balance-curve-unmarked.md`
- `tickets/backlog/pie-header-total-unmarked.md`

## Qué hacer
Usa la misma marca de «aproximado» que ya muestra el Panel para los importes convertidos con tasa: los de Informes, el saldo de un mes cerrado en la curva histórica y el total de «Análisis del gasto». Capturas antes y después, claro y oscuro.

## Reglas
- Antes de tocar nada, verifica contra `origin/2.3` que cada ticket siga pasando (varios son viejos). Si uno ya no pasa o ya está hecho, muévelo a done con la evidencia y sigue con los demás.
- Si un ticket resulta ser una decisión de diseño o de producto que solo Jürgen puede tomar, no la inventes: déjalo en backlog con la pregunta y las opciones con su recomendación, y anótalo en el cierre.
- Textos nuevos en su propia tabla `.strings` (la del toca), no en Localizable.strings ni L10n.swift, en los 16 idiomas y siempre en español neutro latinoamericano (en es-ES también, sin vosotros).
- Si hace falta tocar algo fuera del toca, toca lo mínimo y anótalo en el cierre.
- Producción (iCloud Production, Supabase prod, gateway, web publicada) no se toca: déjalo probado en desarrollo y anotado para Dan, con el OK de Jürgen.
- Nada de pago.

## Dispositivos
Antes de usar un simulador, comprueba si el iPhone 14 conectado por DeviceMCP está libre; no lo des por ocupado sin comprobarlo. En la Max puedes usar un segundo simulador si otra sesión ya usa uno (tope 2); en la Mini, 1.

## Cierre
Commits y PR sin firma de IA y sin saltarse hooks. Espera el merge real del PR en 2.3 antes de `/cerrar-total`. Si a los ~45 min el CI sigue rojo por algo ajeno al PR, cierra y anótalo. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».

## Paso 0 — decisiones (resueltas en autónomo, bypass, modo nocturno)

Medido contra `origin/2.3` (5f80ae710) antes de tocar nada:

- **`financial-report-amounts-unmarked`: sigue a medias.** Las filas de la tabla ya marcan, pero solo la tarjeta con
  varias divisas (`PivotTableCalculator.convertsCard`). «Te quedó» y la cifra del período anterior en su frase, sin
  marca. → Se hace: neto con `resolvedAmount` + `ApproximateMarkThreshold` contra el neto mostrado (resta), y cada fila
  en divisa preferida con el mismo umbral contra su suma con signo. Las filas en nativo (Divisa, Cuenta) no convierten:
  sin marca, escrito en el código.
- **`fx-historical-balance-curve-unmarked`: sigue.** `fillBalanceBuckets` no guarda la duda y
  `BalanceKPICalculator` devuelve `false` fijo en el cerrado. Premisa cambiada desde el ticket: el hero de Distribución
  ya no usa ese KPI (desde el 20-nov enseña «Tu dinero hoy»). Lo que sí enseña el saldo de cierre hoy: la fila
  «inicio → fin» bajo la gráfica de saldo del Panel y el KPI de saldo de Tendencias. → Se hace con
  `BalanceValuation.value(...).approximateMagnitude` del último bucket, contra el saldo mostrado.
- **`pie-header-total-unmarked`: sigue.** → Pieza nueva `PieTotalApproximateMark`, que mide sobre las mismas
  transacciones y el mismo filtro de cada tarta (categorías, subcategorías, etiquetas), en Distribución y en el Panel
  (el header es compartido). Cuando el total pintado es solo lo seleccionado (subconjunto), sin marca: esa cifra no se
  mide (misma familia que `fx-category-totals-unmarked`).
- **Asumido:** el KPI de ingresos/gastos de Tendencias tampoco marca hoy; no es de estos tickets y no se toca.
- **Asumido:** sin textos nuevos (el glifo «≈» lo pone `AmountText`), así que no hay tabla `.strings` que crear.
- **Fuera del `toca`, mínimo y necesario:** `TrendDataProcessor`, `BalanceKPICalculator`, `PivotTableCalculator`,
  `FinancialReportViewModel`, `PanelViewModel`, `StatisticsViewModel`, `TrendsTabView`, `TrendsCarouselWidget`,
  `CategoriesTabView`, `PanelWidgetSection`, los tres widgets de tarta y la pieza nueva en `Logic/Calculators/`.
