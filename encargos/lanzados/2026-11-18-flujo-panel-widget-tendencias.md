Yala
# Flujo de caja: Panel, widget de Saldo y Tendencias usan el mismo motor del mes
---
toca: Yala/App/Views/Panel/CashFlowWidget.swift,Yala/App/Logic/Calculators/ProjectedFlowBuilder.swift,Yala/App/Logic/PanelTrendSummaryLogic.swift,YalaWidgets/Widgets/BalanceWidget.swift,YalaWidgets/Widgets/CashFlowWidget.swift,YalaWidgets/Widgets/CashFlowPortraitView.swift,YalaTests/FlujoConsumidores/,tickets/backlog/projected-flow-with-plan-counts-a-future-dated-row-twice-in-a-future-month.md,tickets/done/projected-flow-with-plan-counts-a-future-dated-row-twice-in-a-future-month.md,tickets/backlog/cash-flow-advanced-gate-never-limits-free-users.md,tickets/done/cash-flow-advanced-gate-never-limits-free-users.md,tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md,tickets/done/2026-11-17-flujo-de-caja-replanteo.md
esfuerzo: medium
cierre: cierra-sola
depende: Yala/flujo-crear-plan
---

Decisiones de Jürgen del 18-nov (06:26 Lima), registradas: aceptó todo lo recomendado del análisis «Flujo de caja: replanteo» (ticket `tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md`, evidencia en `docs/analisis/2026-11-17-flujo-de-caja-replanteo/`):
- P1 modelo A: mes real + lo que falta.
- P2 línea excedida: cuenta lo real y no proyecta más.
- P3 al cambiar un límite, por defecto «desde este mes en adelante».
- P4 el límite es un monto fijo, sembrado con tu promedio al crear.
- P5 se retira el saldo inicial manual: se parte del saldo de tus cuentas.
- P6 lo que no tiene línea en meses futuros: gastos por la mediana de 6 meses; los ingresos no se proyectan.
- AJUSTE OBLIGATORIO: el nivel de detalle siempre llega a SUBCATEGORÍA, que es el id base. La categoría se deriva de sus subcategorías (suma) y se muestra como agrupador, puede ser colapsable. Nunca una línea solo a nivel categoría que pierda el detalle de subcategoría.

Sesión S6, la última del plan del ticket.

## Qué hacer
- «Ver proyectado» del Panel, widget de Saldo y Tendencias con la misma pieza del motor (otros por mediana, sin doble conteo). Paridad de cifras entre Flujo de caja, Panel y widget, con test.
- Cierra `projected-flow-with-plan-counts-a-future-dated-row-twice-in-a-future-month` (vigente) y pasa a done `cash-flow-advanced-gate-never-limits-free-users` (obsoleto).
- No toques `PanelViewModel.swift` ni `WidgetDataCache.swift` salvo que la sesión de cuelgues ya haya cerrado y haga falta; si hace falta, anótalo.
- Mueve el ticket del replanteo a done con el resumen de las seis sesiones.

## Cómo entregar
- Base 2.3, un PR. Toca solo lo declarado; si algo imprescindible queda fuera, ponlo en una carpeta nueva dentro de lo declarado y anótalo.
- Tests de lo nuevo. Capturas antes y después (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad) cuando haya UI.
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con antes y después y lo decidido.
- Commits y PR sin firma de IA. Textos nuevos solo en la tabla de strings declarada de cada `.lproj`, nunca en `Localizable.strings`. Nunca un botón debajo del otro.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto). Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas por la sesión (modo nocturno, sin decisión vital pendiente): las recomendaciones se dan por buenas. Se
> discuten en el PR.

Medido al arrancar: Panel («Ver proyectado» y «Al 30»), Tendencias y el widget de Saldo pasan los tres por
`ProjectedFlowBuilder.build`. Con plan ya salían del motor del mes (S1). Sin plan, o con filtros de sesión, seguían con
el ritmo de 90 días: ingresos y gastos por día, sin mediana. Eso es lo que cambia S6.

1. **Sin plan o con filtros, lo no planificado sale del mismo motor, sin líneas.** Gastos: «otros» por la mediana de 6
   meses, menos lo que el mes ya tiene (real o fechado). Ingresos: no se proyectan (P6); solo los pagos planificados y
   lo ya fechado. Se retira el ritmo del builder. *Alternativa descartada:* dejar el ritmo sin plan (dos cuentas para
   la misma cifra, y el gasto puntual de hace 45 días se seguía repartiendo; hallazgo 10).
2. **De qué historia sale la mediana.** Sin filtros, de todos los movimientos, como con plan: la misma cifra en Panel,
   Tendencias y widget. Con filtros, de los filtrados: la mediana de «Solo Comida» es la de Comida.
3. **Rótulo, sin textos nuevos.** El gasto estimado sigue diciendo «Estimado con tu ritmo de gasto» (la mediana es tu
   gasto de un mes normal). El lado de ingresos sin plan pasa a «Estimado con tus pagos planificados», que es lo que
   proyecta. Sin historia de un mes completo, nada que estimar: «pagos planificados».
4. **No se tocan `PanelViewModel` ni `WidgetDataCache`:** heredan el cambio por el builder.
5. **`CashFlowWidget` del Panel, los widgets «Entradas y salidas» y `PanelTrendSummaryLogic` no proyectan nada:** se
   revisan y no cambian.
6. **Fuera de lo declarado e imprescindible:** los casos del ritmo de `ProjectedFlowCalculatorTests` (fijaban la
   conducta retirada; se reescriben con la nueva), la regla de `.claude/rules/ingreso-gasto.md` que la describía y
   `qa/coverage-index.json`.
7. **Paridad con test** en `YalaTests/FlujoConsumidores/`: «Al 30» del flujo de caja = «Ver proyectado» del Panel = fin
   de mes del widget de Saldo, con plan y sin plan, con el fixture discriminante (sin categoría de cada signo,
   devolución, fechado por delante y gasto enlazado a un pago).
