# El contexto de Yala IA suma los gastos de grupo aunque el interruptor de Estadísticas los excluya

## Contexto
Card del tablero `tablero-el-contexto-de-yala-ia-suma-los-gastos-d-l0cq` (Yala 2.1). Hallazgo del PR #461. Con «Incluir gastos de grupo en estadísticas» apagado, el Panel y Estadísticas dejan fuera los movimientos de grupo (`BridgedTransactionFilter`). `FullFinancialContextBuilder` no lee ese interruptor: los periodos, categorías y destacados que recibe Yala IA siguen contando «mi parte» de cada gasto de grupo, así que la IA puede citar un gasto del mes mayor que el del Panel. Las sugerencias del chat ya lo siguen desde #461; reutiliza exactamente ese mismo camino (y `BridgedTransactionFilter`), no inventes otro. El conector `mcp/` no conoce las preferencias del teléfono (como con «Grupos en el total»): **no lo toques**; si crees que debería, anótalo en el PR y crea card.

## Qué se pide
- Que `FullFinancialContextBuilder` respete el interruptor igual que el Panel/Estadísticas y las sugerencias (periodos, categorías, destacados).
- Tests con control rojo con el código viejo: interruptor apagado ⇒ el contexto no cuenta los gastos de grupo y cuadra con el Panel; encendido ⇒ igual que hoy.
- Sin capturas salvo que cambie algo visible.

## Qué NO hay que tocar
- Prompts/modelos de IA, `mcp/`, modelo de datos, nube/CloudKit, marketing/.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior (#465): arranca ya sobre `origin/2.1`; no partas de su rama. Justo antes del gate, mira si #465 sigue en CI; si sigue, espera a que entre y rebasa una sola vez con el sim apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya. Build y simulador van después de ese rebase, una sola vez.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
Con el interruptor apagado, Yala IA recibe los mismos totales que el Panel; tests en verde; PR abierto a 2.1 que cierre el ticket. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

## Paso 0

Decisiones tomadas antes de escribir código (sesión lanzada, auto-contestadas):

1. **Dónde se lee el interruptor:** en `ChatAssistantService.runAskFlow`, igual que las sugerencias
   (`UserDefaults.standard` → `AppPreferences.Keys.includeGroupTransactionsInStats`, default `true`), y viaja
   como parámetro a `FullFinancialContextBuilder.build` → `buildFromArrays(includeGroupTransactionsInStats:)`.
   El builder no lee preferencias: lo recibe, como «Grupos en el total». Default `true` en `buildFromArrays`
   para tests y el golden del conector (que así no cambia).
2. **Qué secciones lo siguen:** todo lo que en la app pasa por el filtro de Estadísticas/Panel — periodos
   (y semanas), categorías, sin categoría, comercios, patrones (día de la semana y necesidades), etiquetas,
   destacados por subcategoría y anomalías. Filtro único con `BridgedTransactionFilter.shouldInclude` sobre el
   conjunto elegible, una sola vez.
3. **Qué NO lo sigue, a propósito:** presupuestos (la pantalla de Presupuestos tiene su propio «incluir gastos
   compartidos» por presupuesto; el contexto ya usa `BudgetsViewModel.calculateSpending`) y saldos (el Panel no
   aplica el interruptor al saldo: son montos reales). Asumido como default sensato.
4. **Caché:** la entrada de 60 s guarda el valor del interruptor; si cambia, se recalcula.
5. **Tests:** fichero nuevo, sin `ModelContext`. Apagado ⇒ el contexto cuadra con el Panel (mismo
   `CashFlowCalculator` sobre el conjunto que filtra el Panel) y con `ChatSuggestionsLLMService.monthSums`;
   encendido ⇒ igual que hoy (cuenta «mi parte»). Control rojo con un mutante que ignora el parámetro. Más un
   source-scan del cableado en `runAskFlow`.
6. **`mcp/`:** no se toca (no conoce las preferencias del teléfono); se anota en el PR.
