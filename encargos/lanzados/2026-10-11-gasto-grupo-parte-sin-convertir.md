# Un gasto de grupo con una parte sin convertir aparece en mis estadísticas con el importe del grupo entero y sin marca

## Contexto
Card del tablero `tablero-un-gasto-de-grupo-con-una-parte-sin-conv-kbld` (Yala 2.1, low, pero las estadísticas salen mal). Ticket: `tickets/backlog/bridge-synthesis-trusts-a-zero-converted-amount.md`. Según la card, `GroupBridgeStatsAdjustment.build` suma el importe convertido sin tratar el 0 (un 0 de «aún sin convertir» cuenta como real), y así un gasto de grupo con una parte sin convertir entra en mis estadísticas con el importe del grupo entero y sin la marca «≈». Ojo: el PR #452 ya retiró `WidgetDataCache.preferredAmount` y unificó el criterio del cero entre el widget y la síntesis del bridge, y dejó una nota en este ticket. PRIMERO verifica en `origin/2.1` qué queda realmente del bug; si ya no queda nada, cierra el ticket con evidencia (test que lo fije) en vez de inventar un arreglo.
Reutiliza la regla de conversión de #451, #452 y #458 (`CashFlowCalculator.resolvedAmount`, `TrendDataProcessor.balanceAmount`, el envoltorio con magnitud dudosa para «≈»); no inventes otra.

## Qué se pide
- Test rojo antes / verde después: gasto de grupo con una parte sin convertir ⇒ mis estadísticas cuentan solo mi parte, reconvertida, con «≈» si la tasa es aproximada.
- Arreglo acotado a la síntesis del bridge/ajuste de estadísticas de grupo.
- Capturas solo si cambia algo visible (`capturas/antes.png`, `capturas/despues.png`).

## Qué NO hay que tocar
- El modelo de datos de grupos, la sincronización, nube/CloudKit, el conector `mcp/` salvo que repita el mismo cálculo (si lo toca, dilo en el PR: necesita deploy), marketing/.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior (#459): arranca ya sobre `origin/2.1`; no partas de su rama. Justo antes del gate, mira si #459 sigue en CI; si sigue, espera a que entre y rebasa una sola vez con el sim apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya. Build y simulador van después de ese rebase, una sola vez.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
Un gasto de grupo con una parte sin convertir ya no infla mis estadísticas (test rojo antes / verde después), o el ticket se cierra con evidencia de que #452 ya lo resolvió; PR abierto a 2.1. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

## Paso 0

- **¿Queda bug en `origin/2.1`?** Sí, medido: `GroupBridgeStatsAdjustment.build` suma `amountInPreferredCurrency` de las patas sin mirar el 0. #452 solo igualó el criterio del widget (ahora también se fía del 0); no arregló la síntesis.
- **Dónde se arregla:** en `build`, una vez, para que los ~30 consumidores (`resolvedAmount` y los 9 que leen `amountInPreferredCurrency(_:)` directo) reciban el número bueno sin tocarlos.
- **Qué regla:** la de `CashFlowCalculator.resolvedAmount` rama «se convirtió a otra»: reconvertir el nativo con la tasa de su fecha, y la duda es la de ESA conversión. Se extrae a un helper que usan las dos (una sola regla).
- **Qué pata se reconvierte:** la que trae `amountInPreferredCurrency == 0` con `amount != 0` (conversión ausente) o la que se guardó con OTRA divisa preferida que la pata real (sumar las dos mezcla divisas, misma familia que #451/#452). Las demás conservan su valor guardado y su flag.
- **«≈»:** la pata reconvertida aporta su magnitud a `approximatePreferred` solo si la tasa no es exacta (lo pide el encargo; con tasa exacta el número es correcto).
- **`mcp/`:** repite el mismo cálculo (`groups.ts`), así que se porta y se añade el caso al golden de paridad. Necesita deploy: va en el PR.
- **Asumido:** el cero de una fila suelta (no de grupo) queda fuera: no infla nada y no es la síntesis del bridge.
