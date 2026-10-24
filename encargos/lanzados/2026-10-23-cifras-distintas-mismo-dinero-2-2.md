# Que el mismo dinero dé la misma cifra en todas las pantallas de Yala (4 cards 2.2)

## Contexto
Sesión 4 de la cola 2.2 de Jürgen (criterios del roadmap, 22-oct). Repo Yala, base origin/2.2 y PR contra 2.2. Cuatro cards del tablero (proyecto Yala, versión 2.2, todas en lista para lanzar, modo cierra sola). Búscalas con `tablero listar --proyecto Yala --version 2.2 --buscar "<palabra>"` y léelas con `tablero ver <slug>`:
1. tablero-ingresos-y-gastos-del-mismo-mes-salen-di-vl1q — «Ingresos y gastos del mismo mes salen distintos según la pantalla cuando un movimiento no tiene categoría o su signo la contradice». Ticket tickets/backlog/records-standalone-amount-discrepancy.md. Convención decidida el 2026-09-06: fallback al signo; aplicarla fuera del helper en todas las pantallas.
2. tablero-panel-y-planificacion-pueden-decir-disti-7ld8 — «Panel y Planificación pueden decir distinto lo que queda de un presupuesto». Ticket tickets/backlog/panel-budget-spent-diverges-from-planning.md. Que el Panel use la misma función que Planificación (ajustes de saldo, interruptor de gastos de grupo, parte neta de gastos de grupo), con test de paridad.
3. tablero-al-filtrar-el-panel-por-una-cuenta-exclu-shhm — «Al filtrar el Panel por una cuenta excluida de estadísticas, el saldo grande enseña el total y los widgets enseñan 0». Ticket tickets/backlog/saldo-con-seleccion-no-contable-diverge-entre-panel-y-estadisticas.md. DECISIÓN de Jürgen (2026-10-08, opción A): si el filtro es una cuenta excluida, mostrar 0 en las tres piezas, como en Estadísticas. Además: borrar una cuenta filtrada debe limpiar selectedAccountIDs.
4. tablero-la-cifra-y-la-curva-del-widget-de-saldo-zyah — «La cifra y la curva del widget de saldo no cuentan lo mismo con movimientos sin cuenta». Ticket tickets/backlog/widget-balance-figure-and-curve-count-different-rows-for-accountless-movements.md. periodBalance incluye filas sin cuenta y el último punto de la curva no: alinear.
Orientarse: STATE.md, CLAUDE.md, índice de DECISIONS.md (solo el ADR concreto), grep en docs/glosario.md. No leer el repo entero.

Dependencias: la sesión arranca ya sobre origin/2.2, sin esperar CI ni merge del PR anterior; justo antes de abrir PR, `git fetch` + un solo rebase sobre origin/2.2, y build/simulador una vez después. Solo si dos sesiones tocan el mismo archivo o una necesita el código de la otra, la segunda espera el merge.

## Qué se pide
- Al empezar, mueve las 4 cards a in progress (`tablero mover <slug> --a "in progress" --agente frank`).
- Arreglar las 4 con una sola fuente de verdad por cifra (no parches por pantalla) y tests de paridad entre pantallas para cada caso.
- Si algo necesita una decisión de UI/UX no tomada, no la inventes: deja propuestas (opciones con recomendación) en la card, muévela a espera decisión a nombre de jurgen con `--pregunta`, y sigue con el resto.
- Tickets resueltos: muévelos según la convención del repo. Bug nuevo que encuentres: ticket nuevo con su card.
- Pipeline Yala serial: 1) limpiar (sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados), 2) build `xcodebuild -jobs 2` sin sim booteado, 3) bootear 1 sim, 4) tests, 5) apagar y borrar ese sim. Prohibido solapar build, sim y UITests. Nunca más de un simulador encendido (mira antes `xcrun simctl list devices booted`); al terminar `xcrun simctl shutdown all`.
- Corre /barrido-qa antes del PR. PR contra 2.2.
- Al terminar, cierre autónomo con /cerrar-total. Solo detente a preguntar ante una decisión primordial de seguridad o de UX muy importante.

## Qué NO hay que tocar
- SOLO SIMULADOR: nunca dispositivos reales (iPhone ni iPad de Jürgen).
- No tocar Yala.xcscheme, ni encargos/pendientes/, ni los .ckdb sin commitear en ~/Yala (no los añadas ni los borres).
- No cambiar el comportamiento visual más allá de lo decidido; nada de deploy a producción.

## Cómo se sabe que está bien
- Para cada card, la misma cifra sale igual en todas las pantallas que la muestran, con test de paridad en verde.
- shhm: con una cuenta excluida filtrada, saldo grande y widgets muestran 0; borrar la cuenta filtrada limpia el filtro.
- Build y tests en verde en el simulador; PR abierto contra 2.2; cards en done (o in qa / espera decisión a jurgen si hace falta su ojo o su decisión), con hechaCuando rellenado.

## Paso 0

Decisiones resueltas antes de tocar código (sesión autónoma, sin preguntas: todo lo que sigue cae dentro de decisiones ya tomadas por Jürgen o es técnico).

**vl1q · ingreso o gasto.** Regla única: `TransactionClassificationLogic.isIncome` (la categoría manda; sin categoría, el signo, `>= 0` ⇒ ingreso). Decisión de Jürgen del 2026-09-06. Se aplica en toda decisión ingreso/gasto que alimente un total, una lista o un filtro de la app: hero del Panel, Flujo de caja (y con él el resumen de Observaciones), widgets de inicio (también su camino de emergencia), Informe (las 5 dimensiones), filtros Ingresos/Gastos de Registros e Informes, modo solo gastos, gasto por cuenta, presupuestos, mayor gasto de Observaciones, día de la semana, etiquetas, salud financiera, búsqueda, colores de filas, prefill del formulario y candidatos a vincular un pago. **Acumulación con signo** en los totales de ingresos/gastos que aún sumaban magnitudes (hero del Panel y widgets de inicio), como ya hacen Registros, Flujo de caja y Tendencias: una devolución en una categoría de gasto resta.
- *Asumido*: los desgloses POR CATEGORÍA (tarta y rankings de categorías/subcategorías, Sankey, distribución por necesidad) siguen sin el movimiento sin categoría: no tienen dónde ponerlo y un trozo «Sin categoría» es una decisión de UI. Va a ticket propio con propuestas, a nombre de Jürgen.
- *Asumido*: Yala IA (contexto del chat, anomalías, sugerencias) y su port `mcp/` quedan fuera: otra superficie, con golden de paridad propio. Ticket propio.
- *Asumido*: los desgloses que suman magnitudes (día de la semana, etiquetas, salud financiera, presupuestos) cambian solo la clasificación, no su forma de sumar.

**7ld8 · presupuestos.** El Panel calcula lo gastado con `BudgetsViewModel.calculateSpending` (la de Planificación), con el neteo de grupo del Panel (`statsAdjustment`). Consecuencia asumida: la tarjeta de presupuestos del Panel deja de restar las categorías excluidas con el filtro de sesión, porque Planificación no lo hace y la card pide la misma cifra. «Presupuestos en riesgo» de Observaciones calcula por su cuenta (solo presupuestos con categoría legada y sobre el conjunto filtrado de Estadísticas): ticket propio.

**shhm · cuenta excluida filtrada.** Opción A de Jürgen (2026-10-08): `LiveBalanceCalculator` deja de hacer fallback al total; el test que lo fijaba se reescribe a conciencia con el nuevo contrato (0). Borrar una cuenta (`EntityDeletionService.deleteAccount`, el embudo de todos los borrados desde la UI) la quita del filtro de sesión.

**zyah · widget de saldo.** Una sola regla para qué filas entran en un saldo (`LiveBalanceCalculator.entersBalance`: las que tienen cuenta), usada por el saldo vivo, la curva del widget y el saldo de período del widget.

Ficheros: más de 3 (modo autónomo: nota, no pregunta). Review adversarial: sí, toca cálculos financieros.
