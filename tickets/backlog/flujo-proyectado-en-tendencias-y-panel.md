---
id: flujo-proyectado-en-tendencias-y-panel
status: backlog
priority: medium
area: "Tendencias, Panel, Flujo de caja, WidgetKit"
created: 2026-11-06
updated: 2026-11-06
source: "card del tablero «Flujo proyectado en Tendencias y Panel» (versión 2.3), sesión de exploración del 2026-11-06"
---

# Flujo proyectado en Tendencias y Panel (con widgets)

## La idea, en lenguaje de usuario

En la gráfica diaria de Tendencias y del Panel, un control «Ver proyectado» enseña cómo seguiría el período desde hoy:
una continuación punteada de lo que se espera por día, con los pagos planificados en su fecha y una estimación del resto
del gasto. Lo mismo en los widgets de inicio.

## Lo que hay hoy (medido en `origin/2.3` el 2026-11-06)

- **La gráfica de tendencia ya distingue pasado y futuro.** `TrendChartView` parte los puntos en pasado (línea del color
  de la métrica) y futuro (punteado gris `[5, 5]`), unidos en hoy. Esa parte futura solo existe si hay movimientos con
  fecha posterior a hoy: `TrendDataProcessor` corta el saldo en hoy (`LiveBalanceCalculator.TodayCutoff`) y, en ingresos
  y gastos, llega hasta el último movimiento dentro del período. La usan el widget Tendencia del Panel
  (`PanelViewModel.calculateTrendData`) y Estadísticas › Tendencias (`TrendsTabView`, `StatisticsViewModel`).
- **Tendencias ya tiene una píldora de comparación** («Ver el mes anterior», `showPreviousPeriodToggle`), que cambia
  `TrendChartView` por `PeriodComparisonChartView` (la curva anterior va punteada).
- **El plan de Flujo de caja (Reportes) estima por MES y por línea**, no por día: `CashFlowProjectionCalculator` da, por
  mes y línea, planificado y real (`EstimationMethod`: promedio 3/6/12 meses, mes anterior, tendencia, manual,
  personalizado, pago planificado) más «Otros gastos/ingresos». El plan es opcional y la versión base es gratis
  (`FeatureGate.cashFlowAdvanced` cubre métodos, horizonte y gráficas avanzadas).
- **Los pagos planificados** (`ScheduledPayment`) sí tienen fecha: `nextDueDate`, recurrencia, fin, saltados y
  `lastPaidDate`; `PlannedOccurrenceBuilder` ya expande las ocurrencias pendientes de un intervalo y descuenta las pagadas
  (lo usa el Sankey).
- **«Flujo de caja» del Panel no es el plan**: el `CashFlowWidget` del Panel y el de inicio son «Entradas y salidas» del
  período. El proyectado se apoya en el plan de Reportes y en los pagos planificados, no en ese widget.
- **Widgets de inicio con gráfica diaria**: «Gasto» (`ExpenseWidget`, `ExpensePaceChart`: acumulado del período hasta
  hoy y, punteada gris, la curva del período anterior) y «Saldo» (`BalanceWidget`, `BalanceTrendChart`). Los datos los
  escribe la app en la foto del App Group (`WidgetDataService`), que ya lleva `scheduledPayments`. Los widgets no tienen
  «Ocultar montos».

## Preguntas a Jürgen (enviadas al bot el 2026-11-06 a las 11:15, Lima)

Cada una con la opción recomendada primero. Las respuestas se apuntan abajo al llegar.

1. **Estimación del gasto no planificado**: A) del plan de flujo de caja (lo que falta de cada línea del mes, repartido
   entre los días que quedan; pagos planificados en su día; sin plan, B) · B) ritmo: gasto diario medio de los últimos 3
   meses sin los pagos planificados, más los pagos · C) solo pagos planificados.
2. **Métricas**: A) gastos, ingresos y saldo (saldo de hoy + ingresos estimados − gastos estimados) · B) gastos y saldo ·
   C) solo gastos.
3. **Horizonte**: A) hasta el final del período elegido; sin control en períodos que terminan hoy o antes · B) 7/14/30
   días elegibles, alargando el eje · C) 30 días fijos.
4. **Sin plan o sin líneas ese mes**: A) ritmo (1B), con el rótulo «Estimado con tu ritmo de gasto» · B) solo pagos
   planificados · C) sin proyección, invitación a armar el plan.
5. **Línea del plan ya superada**: A) deja de sumar (cero, nunca negativo) · B) sigue al ritmo actual de esa línea.
6. **Pago planificado vencido sin registrar**: A) sigue pendiente y se dibuja mañana · B) se ignora.
7. **Movimientos con fecha futura** (hoy ya punteados): A) entran en la proyección, una sola línea · B) dos estilos.
8. **Con «Ver el mes anterior»** de Tendencias: A) excluyentes · B) las tres curvas a la vez.
9. **Activación**: A) píldora en la tarjeta, en las dos pantallas, recordada y compartida · B) igual, recordada por
   pantalla · C) en el Panel como opción del widget en «Configurar panel».
10. **Filtros de sesión**: A) los respeta (con filtro de cuenta, ritmo filtrado, porque el plan no se divide por
    cuenta) · B) con filtro, el control desaparece · C) los ignora.
11. **Otra moneda**: A) tipo de cambio de hoy y «≈» si una tasa es aproximada, como el flujo de caja · B) solo lo que
    está en la moneda principal.
12. **Widgets y privacidad**: A) opción «Mostrar proyectado» en «Gasto» y «Saldo», apagada por defecto, solo la línea;
    la cifra «Al ritmo actual: ≈ S/ X a fin de mes» solo en la app, oculta con «Ocultar montos» · B) el widget también
    con la cifra · C) un widget nuevo «Flujo proyectado».
13. **Precio**: A) gratis · B) pagos gratis y estimación con el plan Pro · C) todo Pro.

## Respuestas

Jürgen, 2026-11-06: **todas A** (1A 2A 3A 4A 5A 6A 7A 8A 9A 10A 11A 12A 13A).

1. Gasto no planificado: del plan de flujo de caja (lo que falta de cada línea del mes, repartido entre los días que
   quedan); pagos planificados en su día; sin plan, ritmo.
2. Métricas: gastos, ingresos y saldo.
3. Horizonte: hasta el final del período elegido; sin control si el período termina hoy o antes.
4. Sin plan o sin líneas ese mes: ritmo, con el rótulo «Estimado con tu ritmo de gasto».
5. Línea del plan ya superada: deja de sumar (cero, nunca negativo).
6. Pago planificado vencido sin registrar: sigue pendiente y se dibuja mañana.
7. Movimientos con fecha futura: entran en la proyección, una sola línea.
8. Con «Ver el mes anterior»: excluyentes.
9. Activación: píldora en la tarjeta, en Tendencias y en el Panel, recordada y compartida.
10. Filtros de sesión: se respetan (con filtro de cuenta, ritmo filtrado).
11. Otra moneda: tipo de cambio de hoy y «≈» si una tasa es aproximada.
12. Widgets: opción «Mostrar proyectado» en «Gasto» y «Saldo», apagada por defecto, solo la línea; la cifra solo en la
    app, oculta con «Ocultar montos».
13. Precio: gratis.

El plan de abajo ya estaba escrito con estas opciones: no cambia.

## Siguiente paso, aparte (anotación de Jürgen, 2026-11-06)

Le preocupa que el proyectado dependa del flujo de caja: casi nadie lo usa y es difícil de configurar. Con la 4A el
proyectado no se queda vacío sin plan (cae al ritmo), pero para que el plan lo nutra de verdad hace falta **darle una
vuelta a la experiencia del flujo de caja** (armarlo y mantenerlo). Es una idea para después, con su propia card; no
entra en esta exploración ni en la implementación de este ticket.

## Plan de implementación (con las respuestas de arriba)

1. **Calculador puro `ProjectedFlowCalculator`** (`Yala/App/Logic/Calculators/`): recibe hoy, el intervalo del período,
   la métrica, los pagos planificados, las líneas del plan del mes (planificado y real por línea), el ritmo histórico y
   los filtros; devuelve un punto por día desde hoy hasta el final del período, acumulado sobre el último punto real
   (gasto/ingreso) o sobre el saldo vivo (saldo), más la cifra de cierre y si es aproximada. Reusa
   `PlannedOccurrenceBuilder` para las ocurrencias, `CashFlowProjectionCalculator` para el mes en curso y
   `CashFlowCalculator.resolvedAmount` / `TransactionClassificationLogic.isIncome` para no abrir una regla nueva de
   ingreso y gasto. Tests con el fixture de paridad (sin categoría de cada signo, signo contrario a su categoría), cambio
   de mes y el día 1 a medianoche (regla del `DateInterval` cerrado).
2. **Preferencia**: `AppPreferences.showsProjectedFlow` (una clave compartida por las dos pantallas), con su fila en el
   checklist de preferencias de la regla de área.
3. **Tendencias** (`TrendsTabView` + `StatisticsViewModel`): píldora «Ver proyectado» junto a «Ver el mes anterior»,
   excluyentes; `TrendChartView` recibe `projectedPoints` y los pinta punteados en el color de la métrica (los
   movimientos futuros se funden en ellos); la línea «Al ritmo actual: ≈ …» bajo la gráfica, con `amountsHidden`. Solo
   si el período tiene días por delante.
4. **Panel** (`PanelViewModel.calculateTrendData` + `TrendChartView`): la misma píldora y los mismos puntos, sin calcular
   si el widget de tendencia está oculto. El cálculo lee pagos planificados, el plan y el reloj: entra en la firma de
   recarga del Panel (`PanelReloadFreshness`) o no se verá al volver.
5. **Widgets**: campo OPCIONAL `projectedTrend` en la foto del App Group (un campo Codable no opcional apaga todos los
   widgets, y el DTO está duplicado en la app y en la extensión); parámetro «Mostrar proyectado» en los intents de
   «Gasto» y «Saldo»; `ExpensePaceChart` y `BalanceTrendChart` pintan la continuación con un estilo distinto del período
   anterior. La foto se rehace al cambiar de día (`refreshIfBuiltOnAnotherDay`) y al cambiar pagos o plan.
6. **Copy y l10n**: textos nuevos en los 16 idiomas, con BRAND-VOICE; el «≈» por `AmountText.isEstimate`, sin glifo en
   el copy.
7. **QA**: XCUITest de la píldora en Tendencias y Panel (aparece solo con días por delante; excluyente con el mes
   anterior), unit tests del calculador y `qa/coverage-index.json` al día. Device-QA del widget en el iPhone de pruebas.

**Review adversarial obligatoria** al implementar: es un cálculo financiero (saldo proyectado, monedas, filtros).

## Riesgos y huecos

- Dos punteados en el mismo widget «Gasto» (período anterior y proyectado) se confunden: el estilo del proyectado tiene
  que distinguirse (color de la métrica atenuado o una banda).
- El ritmo histórico con poca historia (usuario nuevo) proyecta poco o nada: hace falta un mínimo de días.
- **La foto del widget la escribe la app, y la extensión solo la relee.** Si la persona no abre Yala, la proyección del
  widget se queda con el «hoy» del día en que se escribió (`refreshIfBuiltOnAnotherDay` corre al volver a primer plano y
  con el cambio de día en la app viva). Dos salidas para decidir al implementar: guardar la proyección por fecha y que el
  widget recorte lo ya pasado, o que la extensión la recalcule con los pagos planificados que ya trae la foto.
- El saldo proyectado con varias monedas usa la tasa de hoy para días futuros: es una estimación y va con «≈».
- Esta card y `cashflow-spend-prediction` (cierre estimado del mes en curso por línea) comparten el cálculo de «lo que
  falta de una línea»: conviene construir ese trozo una sola vez.
