# Las tartas y rankings de Estadísticas siguen contando 0 un movimiento con la conversión sin escribir

## Contexto
Card del tablero `tablero-las-tartas-y-rankings-de-estadisticas-si-985z` (Yala 2.1). Hallazgo del PR #461: siete calculadores de Estadísticas (tartas de categorías, días de la semana, proyección, rankings…) leen el importe convertido guardado sin pasar por `CashFlowCalculator.resolvedAmount`, así que un movimiento con la conversión sin escribir (0) sigue contando 0 y sin «≈». #461 ya arregló la regla compartida (`storedConversionMissing`) para `resolvedAmount`, el contexto de IA y `mcp/`. Lee #451, #452, #458, #460, #461 y `.claude/rules/currency-fx.md`. Reutiliza esa regla; no inventes otra. Busca el ticket en `tickets/backlog/` (lo dejó #461).

## Qué se pide
- Localizar todos los calculadores que leen el convertido crudo (los siete de #461 y los que aparezcan con un grep del mismo patrón) y pasarlos por `resolvedAmount` (o su envoltorio con magnitud dudosa para «≈").
- Tests por calculador con control rojo con el código viejo: fila sin convertir ⇒ cuenta reconvertida; una sola divisa ⇒ no cambia.
- Si `mcp/` repite alguno de estos cálculos, pórtalo con su golden y dilo claro en el PR (necesitará deploy a staging).
- Capturas solo si cambia algo visible.

## Qué NO hay que tocar
- Modelo de datos, nube/CloudKit, prompts de IA, marketing/.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior (#464): arranca ya sobre `origin/2.1`; no partas de su rama. Justo antes del gate, mira si #464 (y #463) siguen en CI; si siguen, espera a que entren y rebasa una sola vez con el sim apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya. Build y simulador van después de ese rebase, una sola vez.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
Ningún calculador de Estadísticas cuenta 0 un movimiento sin convertir; tests en verde; PR abierto a 2.1 que cierre el ticket. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Alcance medido** (`grep "preferredCurrencyCode == "` y `amountInPreferredCurrency` en `Yala/`):

| Sitio | Pantalla | Qué se hace |
|---|---|---|
| `TopSpendingCategoriesCalculator` | tarta de categorías (Estadísticas, Panel, avisos de informe) | se arregla |
| `TopSubcategoriesCalculator` | ranking de subcategorías | se arregla |
| `WeekdaySpendingCalculator` | gasto por día de la semana | se arregla |
| `TransactionIndex` (`CashFlowProjectionCalculator`) | real vs planificado del Flujo de caja | se arregla |
| `NeedTrendHelper` | tendencia por necesidad | se arregla |
| `ReportNotificationService.accumulateReportTotals` | aviso de informe | se arregla |
| `InsightsCalculator.txAmount` | Observaciones y contexto de Yala IA | se arregla |
| `FXPnLLogic.entryRate` | tarjeta de P&L cambiario | ya trata el 0 como ausente: no se toca |
| `BalanceTrendCalculator`, `BalanceHelper.initialBalanceForTrend` | ninguna: solo los llaman sus tests | no se toca; card aparte |
| `TransactionDetailSheet.conversionRow` | detalle de un registro (pinta «≈ 0,00») | no es un calculador; card aparte |
| `mcp/` `buscar_movimientos` | `importe_en_divisa_preferida` = 0 | se porta |

1. **¿Cómo pasa cada calculador por la regla?** Con un predicado nuevo, `CashFlowCalculator.readsStoredAmount`, que
   es la condición EXACTA de la primera rama de `resolvedAmount` (misma divisa y, o pata ajustada, o convertido
   escrito) y que `resolvedAmount` también usa. Cada calculador cambia su `if` por ese predicado y conserva su rama
   de conversión. Alternativa descartada: sustituir el `if/else` entero por `resolvedAmount(...).value`; cambiaría
   también la rama de conversión de dos calculadores (fallback de códigos desconocidos y precisión `Decimal` del
   aviso de informe), que nadie pidió tocar. **Asumido.**
2. **¿«≈»?** Ninguno de los siete pinta hoy la marca de aproximado; añadírsela es una función nueva. Se queda fuera y
   lo digo en el PR. **Asumido.**
3. **`mcp/` `buscar_movimientos`:** con la conversión sin escribir, `importe_en_divisa_preferida` sale `null`, como
   cuando se guardó en otra divisa (no hay importe guardado que enseñar), con `storedConversionMissing`. Reconvertir
   pediría cargar tasas en una herramienta que lista filas. El resumen (`summary.ts`) ya lo portó #461. **Pide deploy
   del conector.** **Asumido.**
4. **Tests:** una suite por calculador con la escena de #461 (USD con el convertido a 0, principal PEN, tasa 3,7):
   fila sin convertir ⇒ cuenta reconvertida; control monodivisa con una tasa absurda ⇒ no cambia. Rojo exigido con
   el predicado apagado.
5. **Ticket:** no existe en `tickets/backlog/` (#461 dejó solo la card). Se crea en `tickets/done/` al cerrar.
