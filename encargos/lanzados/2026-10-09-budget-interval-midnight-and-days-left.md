# Un gasto del día 1 a medianoche cuenta en el presupuesto del mes anterior, y el último día dice «quedan 0 días»

## Contexto
Card del tablero `tablero-un-gasto-del-dia-1-a-medianoche-cuenta-e-w7ai` (prioridad medium, vence 2026-10-10). Tickets en `origin/2.1`: `tickets/backlog/budget-interval-counts-next-period-midnight.md` y `tickets/backlog/budget-days-left-counts-today.md`. Triage 2026-10-07: problema confirmado vivo en 2.1.

CADENA nocturna tras cerrar `nightly-ui-suite-hits-its-110-minute-cap` (PR #415 en cola de auto-merge a 2.1, solo CI; card 7zso en in qa → frank). Las cards high que quedan necesitan backend/deploy o están en manos de Jürgen, así que toca la mejor medium sin decisión pendiente, sin deploy, sin secretos y sin gasto de API.

Dos fallos del mismo cálculo de fechas de presupuestos:
1. **Intervalo cerrado que se come la medianoche siguiente.** `DateInterval` es cerrado en los dos extremos y estos sitios ponen `end` = inicio del periodo siguiente: `BudgetsViewModel.getBudgetDateInterval` (~`BudgetsViewModel.swift:705`, filtra con `interval.contains` en ~:546), `PanelViewModel.getBudgetDateInterval` (~`PanelViewModel.swift:2453`) e `InsightsCalculator.currentBudgetInterval` (~`InsightsCalculator.swift:565`, que también usa el chat vía `FullFinancialContextBuilder.buildBudgets`). Un gasto del 1 de octubre a las 00:00 cuenta también en septiembre (igual con semanales y anuales). El conector `mcp/src/logic/budgets.ts` ya cuenta bien por días inclusivos: no lo toques salvo para comparar.
2. **«Quedan 0 días» el último día.** Decisión de Jürgen (2026-09-06): **queda 1, hoy todavía cuenta**. `FullFinancialContextBuilder` (~:627) calcula `daysLeft` con `from: now, to: interval.end` y trunca. Hay que barrer todos los sitios que cuentan «días que quedan» y dejarlos iguales.

Regla de `CLAUDE.md` sobre `DateInterval` y `dateComponents([.day])`: léela antes de tocar. Las líneas citadas son pistas: greppea, pueden haber cambiado.

Pipeline serial Mini (obligatorio si compilas o usas simulador): (1) limpiar sims muertos/DerivedData de sesiones cerradas/cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar; (2) `xcodebuild -jobs 2` sin sim booteado; (3) boot 1 sim; (4) tests; (5) apagar y limpiar ese sim. Prohibido solapar swift-frontend + SpringBoard + app + UITests. Un simulador a la vez. Disco de la Mini ~29 GB libres (umbral 32); si baja de ~20 GB, para, limpia y sigue.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo. Si el borrado falla, dilo en el cierre.

Gate después del CI del PR anterior: justo antes del gate, mira si el PR #415 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez sobre `origin/2.1` con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. Build y simulador van después de ese rebase, una sola vez.

## Que se pide
1. Test rojo con el código de hoy: una transacción a las 00:00 del primer día del periodo siguiente no entra en el periodo anterior (semanal, mensual y anual) en los tres sitios; y `daysLeft` = 1 si el presupuesto acaba hoy, 2 si acaba mañana, 0 si acabó ayer.
2. Arreglar el `end` en las ramas semanal, mensual y anual de los tres sitios (mejor con un helper compartido que con tres copias). En el caso «único», mira cómo se guarda `endDate` antes de tocarlo.
3. Barrido de todos los sitios que cuentan «días que quedan» (Presupuestos, Panel, Insights, chat, widget si aplica): mismo resultado en todos, fijado con un test parametrizado. El promedio diario disponible nunca divide entre cero.
4. Si hace falta el texto «te queda 1 día» en singular, que esté bien en los 16 idiomas con `qa/scripts/add-l10n-key.sh` (español neutro latinoamericano). Sin cambios de diseño.
5. Gate del repo; anota lo resuelto en los dos tickets y muévelos según las convenciones; `coverage-index` si aplica.
6. Card `w7ai`: si los tests cubren el criterio, **done → frank**; si queda algo que solo se ve en el teléfono, **in qa → jurgen** con el guion en `tickets/qa/`.
7. Al terminar: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, card bien puesta, quitar worktree/tmux/DerivedData/cachés de XcodeBuildMCP de este worktree, ningún sim encendido).

## Que NO hay que tocar
- El conector MCP (`mcp/`) salvo para comparar.
- Nada de diseño ni de copy fuera del «día/días» que quedan.
- Ni deploy, ni secretos, ni llamadas de pago a APIs de IA.
- No relajar aserciones existentes.

## Como se sabe que esta bien
Los tests nuevos salen rojos con el código de hoy y verdes con el arreglo; ningún gasto de las 00:00 del periodo siguiente entra en el anterior; el último día dice que queda 1 día en todos los sitios; gate verde; PR a 2.1 en auto-merge; card bien puesta.

## Paso 0

Modo autónomo (cadena nocturna). Decisiones auto-contestadas, medidas en el árbol:

1. **Un helper puro, `BudgetPeriodInterval`** (`Yala/App/Logic/`): periodo semanal/mensual/anual = `[inicio, inicio del siguiente − 1 s]`, y `daysLeft(now:interval:calendar:)` cuenta desde `startOfDay(now)` hasta el día del `end`, ambos incluidos.
2. **Sitios con el mismo bug (medido con grep, no solo los tres del ticket):** `BudgetsViewModel.getBudgetDateInterval` **y** `getHistoricalSpending` (periodos pasados: donde más muerde), `PanelViewModel.getBudgetDateInterval`, `InsightsCalculator.currentBudgetInterval` (+ chat), `BudgetAlertService.getCurrentPeriodInterval`, `BudgetChartsView.localDateInterval` (navega a periodos pasados) y el gasto por bucket de `FinancialScoreCalculator`. Todos pasan por el helper.
3. **Único:** el editor elige solo el día (`DateFieldButton` → `DatePicker [.date]`) y el valor inicial es `Date.now` con hora. Se lee como días inclusivos `[startOfDay(inicio), fin del día de fin]`, igual que el conector MCP (`dayInZone`). No se migra nada guardado.
4. **Días que quedan:** Presupuestos y Panel conservan sus códigos de UI (−1 = terminado, 0 = aún no empieza); en curso usan el helper. Chat: 0 si terminó. MCP no se toca (dice 0 el último día: divergencia anotada).
5. **Promedio diario disponible:** no existe en la app (grep); lo calcula el modelo del chat con `days_left`, que dentro del periodo ya nunca es 0. Se fija con test.
6. **Singular:** key nueva `budgets.days.remaining.one` en los 16 idiomas; las tres vistas eligen por `n == 1`. Sin cambio de diseño.
7. **Fuera:** `HeroMonthCalculator.daysRemaining` (no es de presupuestos ni se pinta) y `FinancialScoreCalculator.scoreForBucket` (su cuenta de días no cambia: el bucket de puntuación sigue igual, solo el del gasto se cierra).
