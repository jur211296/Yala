# Estadísticas de un grupo deduplica los gastos por id y su total cuadra con el de Registros

## Contexto
Card del tablero `tablero-estadisticas-de-un-grupo-no-deduplica-ga-8lui` (lista para lanzar, vence 2026-10-10). Ticket: `tickets/backlog/groups-stats-no-deduplica-gastos.md` (hallazgo de la review adversarial de `groups-budget`, 2026-09-07). El triage de Frank del 2026-10-07 lo confirmó vivo en el código de 2.1.

Lo que ve el usuario: en un grupo con un gasto duplicado de S/ 400 y un presupuesto de S/ 3.000, la pestaña Registros dice «S/ 2.100 de S/ 3.000» y Estadísticas dice «Total gastado: S/ 2.500». La que está mal es Estadísticas.

Según el ticket (son pistas, verifícalas en este árbol antes de tocar nada):
- `GroupStatsViewModel.periodExpenses` (`Yala/App/ViewModels/GroupStatsViewModel.swift`, privada, hacia la L284 en 2.1 de hoy) agrupa y suma sobre `GroupDetailViewModel.expenses` tal cual, sin deduplicar por `id`.
- Sus vecinos sí deduplican con el mismo molde, `Dictionary(grouping:by:\.id).values.compactMap(\.first)`: `GroupBalanceService.calculateBalances`, `GroupShareableSummaryLogic` y `GroupBudgetLogic.progress`. Los duplicados llegan por merges del canal de sync; la premisa está escrita en `GroupBalanceService`.
- El mismo ViewModel lee los gastos en otros sitios (por ejemplo, la lista de monedas hacia la L183): revisa que todo lo que deriva de `expenses` en esa pantalla use la lista deduplicada.
- Plantilla del test: `GroupBudgetLogicTests.duplicadosPorIdNoInflanElTotal`.

Antes de esta sesión va en la cola `account-currency-change-leaves-scheduled-and-favorites-stale`; no depende de ella.

Para orientarte: `CLAUDE.md`, `.claude/rules/testing.md` y el ticket.

## Que se pide
1. Reproducir con test: un grupo con un gasto duplicado por `id` → hoy Estadísticas suma de más.
2. Deduplicar en `GroupStatsViewModel.periodExpenses` con el mismo molde que los otros tres, y que todo lo que la pantalla deriva de los gastos (total, por miembro, por categoría, monedas) salga de esa lista. Si ya hay un helper compartido para ese molde, úsalo; no refactorices los otros tres.
3. Test que muera si se revierte, con un control que salga rojo con el código viejo, y uno que fije que el total de Estadísticas coincide con el de la barra de presupuesto de Registros para el mismo grupo.
4. Si el cambio se ve en el simulador, deja `capturas/antes.png` y `capturas/despues.png` en el worktree, con rutas absolutas en el cierre. Si no se puede ver sin inventar datos, no hagas capturas y deja un guion de device-QA en `tickets/qa/`.
5. Anota lo hecho en el ticket y muévelo según las convenciones del repo.
6. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-estadisticas-de-un-grupo-no-deduplica-ga-8lui` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.

## Que NO hay que tocar
- `GroupBalanceService`, `GroupShareableSummaryLogic` y `GroupBudgetLogic`: ya deduplican.
- El filtro de `isOpeningBalance`, que ya es correcto en Estadísticas.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): entre las 06:00 y las 21:00, si aparece una decisión de producto o de riesgo, pregúntala con AskUserQuestion. Entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~32 GB libres el 2026-10-08, justo en el umbral de 32).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Gate tras el CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR de `account-currency-change-leaves-scheduled-and-favorites-stale` sigue en CI (si el orden de lanzamiento cambió, el del encargo lanzado justo antes que este). Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Con un gasto duplicado, Estadísticas y Registros dan el mismo total.
- Test con control rojo con el código viejo.
- Builds `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, ticket movido, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0

Medido en este árbol (823cb3b79):
- `periodExpenses` (L284) suma `allExpenses` sin dedup. `availableCurrencies` (L185) también lee los gastos sin dedup y NO pasa por `periodExpenses`.
- No hay helper compartido del molde: los tres vecinos lo escriben en línea. Se escribe en línea igual.

Decisiones (autocontestadas):
1. **Dónde se deduplica:** en `loadStats`, al guardar `allExpenses`, que es la única entrada de gastos del ViewModel. Así `periodExpenses` (total, por miembro, categorías, tendencia, totales por moneda, mi parte) y `availableCurrencies` salen todos de la lista deduplicada. Deduplicar solo en `periodExpenses` dejaría fuera las monedas.
2. **Orden:** dedup y luego fuera saldos de apertura, como `GroupBudgetLogic.progress`.
3. **Repartos (`SplitShare`) duplicados:** fuera de alcance. «Mi parte» se dobla si un reparto llega repetido, pero es otro objeto con su propio ticket (`group-balance-service-shares-not-deduped`); se anota allí que Estadísticas tiene el mismo hueco.
4. **Capturas:** no hay forma de sembrar un gasto duplicado por `id` desde la UI ni con los `DevSeed` actuales sin inventar datos. Sin capturas; guion de device-QA en `tickets/qa/`.
