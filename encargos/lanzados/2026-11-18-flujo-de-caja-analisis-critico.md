Yala
# Flujo de caja: análisis crítico de cálculos y experiencia, con propuestas de replanteo
---
toca: docs/analisis/2026-11-17-flujo-de-caja-replanteo/,tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md
esfuerzo: high
cierre: cierra-sola
---

Pedido de Jürgen del 17-nov (20:47 Lima). Es solo análisis: no cambia código de la app. Base 2.3. Enfocado solo en la vista Flujo de caja y lo que alimenta (Jürgen: una vista por sesión). Flujo de caja es clave porque sus proyecciones se usan en varias vistas (Panel, widget, Estadísticas).

## Lo que Jürgen siente hoy (textual resumido)
1. No queda claro de dónde sale «falta salir». No se ve si está proyectando gastos o no.
2. Líneas excedidas: ¿debería proyectar o asumir el monto ya excedido? Líneas no excedidas: debería considerar el límite ya puesto.
3. ¿Cómo se cambia el límite? ¿Se cambia para siempre? Es difícil de cambiar.
4. La vista dentro de una línea es incompleta: necesita ver todos los registros de esa línea (no solo los últimos 5), gestionar mejor el límite y ver proyecciones si las hay.
5. Ingresos: deben contar todos, incluso los que no tienen línea, porque es lo real. Gastos igual: todos, aunque no tengan línea, en sus montos reales actuales.
6. Sospecha de cálculos imprecisos: el mes de inicio ya parte del saldo actual, que ya incluye los ingresos del mes, y parece que solo lo castiga con gastos; le dice que acabará el mes muy mal.
7. En general no lo siente intuitivo ni fácil.

## Qué hacer
- Auditar a fondo los cálculos: `CashFlowCalculator`, `CashFlowProjectionCalculator`, `CashFlowMonthSummaryLogic`, `CashFlowRealEstimateBarLogic`, `CashFlowAmountChangeLogic`, `CashFlowLineSideLogic`, `CashFlowSetupLogic`, overrides y el ViewModel. Reproducir con datos reales de semilla (`DevSeedCashFlow`) y casos armados: mes de inicio con saldo inicial e ingresos ya cobrados, líneas excedidas y no excedidas, registros sin línea, registros con fecha futura, multi-divisa. Confirmar o descartar con números cada sospecha del punto 6 (doble conteo o castigo solo por gastos). Revisa también los tickets ya abiertos `projected-flow-with-plan-counts-a-future-dated-row-twice-in-a-future-month.md` y `cash-flow-advanced-gate-never-limits-free-users.md` y di si están vigentes.
- Revisar la experiencia en el simulador: tabla, cápsulas de mes, detalle de mes, detalle de línea, hoja de límite/configuración de línea, saldo inicial, horizonte. Dónde se pierde el usuario.
- Mapear qué otras vistas consumen estas proyecciones y qué cambiaría si cambia el modelo.
- Proponer un modelo claro, con 2 o 3 alternativas y una recomendada, respondiendo explícitamente: qué es real y qué proyectado y cómo se distingue a la vista; cómo tratar excedidas y no excedidas; qué entra en ingresos y gastos (incluidos los sin línea); cómo se calcula el mes de inicio sin doble conteo; cómo se cambia un límite (solo este mes, desde este mes en adelante, para siempre) de forma fácil; cómo debe ser el detalle de línea (todos los registros, gestión del límite, proyección).
- Maquetas de las pantallas propuestas (antes y después) y el ejemplo numérico de un mes explicado paso a paso.
- Dejar el plan de arreglo partido en sesiones de una sola vista cada una, con esfuerzo estimado, en `tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md`. No implementar nada.

## Cómo entregar
- Entregable visual: artifact de Claude, fácil para decidir (hallazgos de cálculo con números, maquetas comparables, alternativas con la recomendada marcada). Nada de Markdown suelto como entregable; en `docs/analisis/2026-11-17-flujo-de-caja-replanteo/` deja capturas y evidencia.
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Commits y PR sin firma de IA. Toca solo lo declarado. Lo menor, con la opción recomendada, anotado en «Decidido sin consultar». Las decisiones de producto quedan como propuestas para Jürgen, no las asumas.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto).
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, modo nocturno): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Cómo se miden los cálculos sin tocar la app?** → Una prueba-sonda temporal en `YalaTests/` (escenario armado + semilla real), que imprime las cifras; se borra antes del commit y su copia queda como evidencia en `docs/analisis/…/sonda/`.
Por qué: el calculador lee el reloj por dentro y solo una corrida real da números citables. Alternativa descartada: razonar sobre el código sin medir (la regla del repo pide medir).

**D2 · ¿Qué se commitea?** → Solo `docs/analisis/2026-11-17-flujo-de-caja-replanteo/` (capturas, sonda, informe fuente del artifact) y `tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md`, más este encargo.
Por qué: el `toca:` lo declara así y es solo análisis. Alternativa descartada: mover los dos tickets revisados a `done`/`discarded` (fuera de lo declarado: se dice en el cierre).

**D3 · ¿Dónde se entrega?** → Rama + PR (es worktree), aunque el diff es solo docs; auto-merge en cola al cerrar.
Por qué: el encargo lo pide («Commits y PR») y el cierre `cierra-sola` con CI verde.

**D4 · ¿Simulador?** → El único de la Mini (iPhone 17 Pro, ya arrancado), con `-uitest -uitest-seed rendimiento` para el plan de semilla, por turno (`sim-lock`). Sin iPhone 14.
Por qué: en la Mini solo uno; la semilla `rendimiento` es la que crea el plan.

**D5 · ¿Decisiones de producto?** → No se toman: el artifact presenta 3 alternativas con una recomendada y un selector para que Jürgen elija. Nada vital bloquea el entregable, así que no hay checkpoint nocturno.
Por qué: el encargo pide propuestas, no implementación.

**D6 · ¿Gate?** → El diff no tiene nada que compilar (docs/tickets/encargos): el gate se reduce a la validación del índice; la sonda no se commitea.
