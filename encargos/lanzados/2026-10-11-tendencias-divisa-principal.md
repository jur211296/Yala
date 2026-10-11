# Tendencias: curvas por cuenta, históricos y saldos suman importes guardados en otra divisa principal

## Contexto
Card del tablero `tablero-las-curvas-por-cuenta-los-historicos-y-l-u9ni` (Yala 2.1, medium). El PR #438 arregló la vista agregada de Tendencias para que convierta importes guardados con otra divisa principal (p. ej. el usuario cambió la divisa principal y hay movimientos viejos convertidos/guardados en la anterior). Quedó pendiente el resto de Tendencias: las curvas por cuenta, los históricos y los saldos todavía suman esos importes tal cual, así que el usuario ve totales incorrectos. Lee el PR #438 (diff y cuerpo) para reutilizar el mismo mecanismo de conversión, no inventes otro. Revisa también si existe ticket en `tickets/backlog/` sobre esto.

## Qué se pide
- Localizar todos los cálculos de Tendencias que quedan (curvas por cuenta, históricos, saldos) y aplicar la misma normalización a la divisa principal actual que usa la vista agregada tras #438.
- Tests unitarios que fallen antes y pasen después (mezcla de importes guardados con dos divisas principales distintas).
- Capturas antes/después de Tendencias si cambia lo que se ve (`capturas/antes.png`, `capturas/despues.png`; mira `~/Claude/referencias-ui/README.md`).

## Qué NO hay que tocar
- Widgets (card aparte j3n2), esquema de CloudKit, delivery multi-divisa, nada de marketing/.
- No cambies el modelo de datos ni migraciones.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior: arranca ya sobre `origin/2.1`; no esperes el CI de PRs previos. Justo antes de abrir el PR: `git fetch` + rebase sobre `origin/2.1` (sim apagado); si 2.1 se movió, rebuild/test una sola vez.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
Tendencias (curvas por cuenta, históricos, saldos) muestra los mismos importes que la vista agregada para datos con divisas principales mezcladas; tests nuevos en verde; PR abierto a 2.1 con antes/después en el cuerpo. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

## Paso 0

Medido sobre `origin/2.1` (36a0b55ab). Ticket: `tickets/backlog/trends-aggregators-sum-stored-amounts-from-other-preferred-currencies.md`.

- **Mecanismo:** `CashFlowCalculator.resolvedAmount`, el mismo de #438. No se copia ninguna rama de la regla.
- **Superficies (4):** curvas por cuenta de ingreso/gasto y saldo (`StatisticsViewModel.calculatePerAccountTrend`), histórico (`calculateHistoricalTotals`) y saldo agregado (`TrendDataProcessor.fillBalanceBuckets`, que alimenta también la comparativa de Tendencias, la tarjeta del Panel y el KPI de saldo de período cerrado).
- **Saldos — decidido (asumido, el ticket lo dejaba abierto):** reconvierten con la tasa de su fecha vía `resolvedAmount(adjustment: .none)`. Es lo que ya guarda una fila sellada en la divisa vigente, así que la curva no mezcla dos criterios; y `.none` conserva la semántica de hoy (el saldo cuenta la fila entera, sin «mi parte»). El dot de «hoy» sigue saliendo de `LiveBalanceCalculator`, sin tocar.
- **`BalanceKPICalculator`:** pasa su `converter` a `processTrendData`; si no, su camino de período cerrado convertiría con el compartido y no con el inyectado.
- **Testabilidad:** el histórico y las curvas por cuenta se extraen a funciones estáticas puras (molde de `periodTotals` en #438). Sin cambio de comportamiento con una sola divisa.
- **Capturas — asumido: no.** Con datos de una sola divisa no cambia nada visible, y no hay seed de filas sin recalcular; fabricarlo es alcance nuevo. Lo cubren los tests (mezcla + una sola divisa + control rojo).
- **Review adversarial:** sí, es cálculo financiero.
- **Ficheros:** `StatisticsViewModel.swift`, `TrendDataProcessor.swift`, `BalanceKPICalculator.swift`, test nuevo `TrendsPreferredCurrencyTests.swift`, ticket → done, `docs/TICKETS.md`, `qa/coverage-index.json`.
