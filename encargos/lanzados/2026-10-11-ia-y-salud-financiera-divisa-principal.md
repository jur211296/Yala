# Yala IA y la salud financiera suman importes guardados en otra divisa principal

## Contexto
Dos cards del tablero en una sola sesión (Yala 2.1), ambas hallazgos del barrido del PR #438:
- `tablero-yala-ia-recibe-totales-con-importes-guar-sw1y` — el contexto de Yala IA (sugerencias del chat y la pata real de grupo) suma importes guardados con otra divisa principal. Ticket: `tickets/backlog/yala-ia-context-sums-stored-amounts-from-other-preferred-currencies.md`.
- `tablero-la-salud-financiera-suma-el-ingreso-guar-zqqt` — `FinancialScoreCalculator` no mira la divisa de cada fila al sumar el ingreso. Ticket: `tickets/backlog/health-score-income-sums-stored-amounts-from-other-preferred-currencies.md`.
El PR #438 arregló la vista agregada de Tendencias; el #451 extendió la conversión a la divisa principal al resto de Tendencias (`CashFlowCalculator.resolvedAmount`, `TrendDataProcessor.balanceAmount`) y el #452 la llevó a los widgets (con un memo de conversiones por snapshot). Lee esos tres PRs y REUTILIZA esa misma regla; no inventes otra.

## Qué se pide
- Aplicar `CashFlowCalculator.resolvedAmount` (o su envoltorio de #451/#452) en el contexto que se manda a Yala IA y en la salud financiera.
- Tests unitarios por superficie con dos casos, como #451/#452: mezcla (filas de dos divisas principales → total en la vigente) y una sola divisa (con una tasa absurda, el total no cambia). Control rojo con el código viejo.
- Capturas solo si cambia algo visible (`capturas/antes.png`, `capturas/despues.png`).

## Qué NO hay que tocar
- Prompts/modelos de IA (solo los números que reciben), Tendencias y widgets (ya cubiertos), nube/CloudKit, modelo de datos, marketing/.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior (#457): arranca ya sobre `origin/2.1`; no partas de su rama. Justo antes del gate, mira si #457 sigue en CI; si sigue, espera a que entre y rebasa una sola vez con el sim apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya. Build y simulador van después de ese rebase, una sola vez.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
Yala IA y la salud financiera usan los mismos importes que la app para datos con divisas principales mezcladas; tests nuevos en verde; PR abierto a 2.1 que cierre los dos tickets. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

## Paso 0

Sesión lanzada en worktree → rama + PR a `2.1`, auto-merge en cola al cerrar. Ficheros previstos:
`ChatSuggestionsLLMService.swift`, `FullFinancialContextBuilder.swift`, `AnomalyDetectionCalculator.swift`,
`FinancialScoreCalculator.swift`, un fichero de tests nuevo, `qa/coverage-index.json`, los dos tickets y
`docs/TICKETS.md`.

Decisiones (asumidas, sin nadie delante):

1. **Sugerencias del chat**: cada fila se resuelve con `CashFlowCalculator.resolvedAmount` en
   `CurrencyDefaults.currentPreferred` con el converter compartido y `adjustment: .none`. Las sugerencias
   no aplicaban el ajuste de gastos de grupo y añadirlo es otro cambio (otro bug); se abre card. Las
   sumas se extraen a una función estática para poder probarlas, como #438/#451.
2. **Contexto de Yala IA y anomalías**: solo cambia la rama de la pata real de un gasto de grupo
   (`adjusted != amountInPreferredCurrency`), que devolvía la escala guardada. Pasa a
   `abs(resolvedAmount(...).value)`. El resto sigue con `chatAmount`, que ya mira la divisa: así el golden
   de paridad con el conector `mcp/` no se mueve (con filas de una sola divisa ambas ramas dan lo mismo).
3. **Salud financiera**: `sumIncomeTransactions` recibe la divisa principal y el converter que el
   calculador ya tenía, y resuelve con la misma regla (con el ajuste de grupo, como hasta hoy).
4. **Capturas**: no. Con datos de una sola divisa no cambia nada visible y no hay semilla con filas sin
   recalcular; como #438/#451/#452, los tests cubren el caso.
5. Presupuestos dentro de la salud financiera: medidos, ya convierten desde la divisa nativa
   (`BudgetsViewModel.budgetAmount`). Fuera.
