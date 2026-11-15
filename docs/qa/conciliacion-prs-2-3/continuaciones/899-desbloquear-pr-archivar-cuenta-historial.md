---
toca: .claude/rules/session-filters.md, Yala/App/Logic/AccountCardLogic.swift, Yala/App/Logic/AccountScopeLogic.swift, Yala/App/Logic/Calculators/DailySpendingCalculator.swift, Yala/App/Logic/Calculators/HeroBucketsCalculator.swift, Yala/App/Logic/Calculators/LiveBalanceCalculator.swift, Yala/App/Logic/ChatTopicAreasLogic.swift, Yala/App/Logic/PanelBalanceScopeLogic.swift, Yala/App/Logic/PanelTotalAccountsLogic.swift, Yala/App/Services/AccountLineService.swift, Yala/App/Services/ChatSuggestionsLLMService.swift, Yala/App/ViewModels/Accounts/AccountFormViewModel.swift, Yala/App/ViewModels/PanelViewModel.swift, Yala/App/ViewModels/RecordsViewModel.swift, Yala/App/ViewModels/StatisticsViewModel.swift, Yala/App/Views/Accounts/AccountFormView.swift, Yala/App/Views/Statistics/TrendsTabView.swift, Yala/App/Views/Subscription/DowngradeResolutionSheet.swift, Yala/Services/Chat/FullFinancialContextBuilder.swift, Yala/Services/FilterService.swift, Yala/Services/ReportNotificationService.swift, Yala/Services/Spotlight/SpotlightIndexService.swift, Yala/Services/TrendDataProcessor.swift, Yala/Services/WidgetDataCache.swift, Yala/Utils/L10n.swift, YalaTests/AccountCardAIContextTests.swift, YalaTests/AccountCardCaptureTests.swift, YalaTests/AccountCardRouteTests.swift, YalaTests/AccountFormViewModelTests.swift, YalaTests/AccountLineCardViewTests.swift, YalaTests/ArchivedAccountKeepsHistoryTests.swift, YalaTests/ChatContextPanelParityAndMonthToDateTests.swift, YalaTests/MCP/MCPAppParityGoldenTests.swift, YalaTests/PanelTotalAccountsLogicTests.swift, YalaUITests/Flows/AccountsCrudUITests.swift, YalaUITests/Flows/ArchivedAccountKeepsHistoryUITests.swift, mcp/src/logic/balances.ts, mcp/src/logic/summary.ts, mcp/src/toolCore.ts, mcp/test/golden/app-parity.json, mcp/test/logic.test.ts, Yala/Resources/
esfuerzo: high
cierre: cierra-sola
pruebas-ui: si
depende: Yala/desbloquear-pr-nube-cambiar-de-cuenta
---

# Desbloquear el PR «Cuentas: archivar saca la cuenta del saldo y conserva su historial»: traer 2.3, resolver el conflicto y dejarlo mergeado

Rama base: 2.3.

## Contexto

Lo encola la conciliación de PR abiertos de 2.3 del 14-nov (`docs/qa/conciliacion-prs-2-3/` en 2.3). Este PR terminó su sesión en modo cola: quedó en cola de auto-merge y el merge de otro PR lo dejó en conflicto, así que lleva días sin entrar. Su código **no está** en 2.3 (medido: ningún commit suyo en 2.3 y casi ninguna de sus líneas) y **nada mergeado lo reemplaza**. Su card dice «done» o «in qa», pero la conciliación la pasó a `blocked` porque el trabajo no está en la rama.

PR: https://github.com/jur211296/Yala/pull/899 — «Cuentas: archivar saca la cuenta del saldo y conserva su historial». Rama: `encargo/2026-11-11-lote-2-3-archivar-cuenta-historial`.

Cómo está el conflicto: Medido: chocan `mcp/src/logic/balances.ts`, `mcp/src/logic/summary.ts` y `mcp/src/toolCore.ts`, porque los cimientos de Yala web (#959) los movieron a `shared-core/` y dejaron en `mcp/` un reexport. Resolverlo: quedarte con el reexport y llevar los tres cambios pequeños del PR (un filtro, una condición y una descripción) a `shared-core/src/logic/`. Eso cambia también el saldo de Yala web, que usa ese núcleo: corre los tests de `shared-core`, `mcp` y `webapp`. El Swift se mezcla solo. El último rojo de `tests` en CI fue el runner perdido («The hosted runner lost communication with the server») a los 62 min, sin test fallido: vuelve a mirarlo tras tu push.

## Qué se pide

1. `git fetch origin` y trabaja **sobre la rama del PR** (`encargo/2026-11-11-lote-2-3-archivar-cuenta-historial`), no sobre una rama nueva: trae `origin/2.3` con un merge (no rebase: la rama ya está publicada) y resuelve los conflictos.
2. Dos cosas a revisar al resolver: (1) desde el 11-nov entraron dos sitios que filtran con `!excludeFromStatistics` (`MonthEndBalanceLogic`, PR #906, y `FinancialScoreAlertsLogic`, PR #904): decide si deben usar `sumsInBalance`, con test. (2) El cuerpo del PR dice que las cuentas sistema de Grupos archivadas siguen sumando, pero su versión del conector excluye toda cuenta archivada (`is_archived !== true`): haz que el núcleo compartido cuadre con la app y fíjalo con un test de paridad.
   Pasa `/gate` entero (build ×2, unit, XCUITest de las áreas tocadas, validación del índice). Sin gate no hay commit.
3. Push a la misma rama. No abras PR nuevo: el PR ya existe y ya tiene el auto-merge activado (compruébalo con `gh pr view 899 --json state,mergeable,autoMergeRequest`; si no lo tiene, `gh pr merge 899 --auto --merge`).
4. **Espera a que tu PR quede `MERGED`** antes de cerrar (excepción a la regla de no esperar el CI, a propósito: este PR ya se quedó una vez colgado por no hacerlo). Mira cada 5 min con `gh pr view 899 --json state,mergeStateStatus` y escribe avance; si vuelve a `DIRTY` porque otro PR entró antes, repite 1-3. Tope: 90 min o dos vueltas; si se pasa, déjalo en cola y dilo en «Necesita de ti».
5. Al quedar `MERGED`: mueve sus cards (ninguna de implementación (la de la decisión, 9brj, está bien en done). Pasa a done `tickets/backlog/archiving-exclusion-open-decisions.md` si el PR lo hace) de `blocked` a `in qa` con `tablero mover <id> --a "in qa"` y un `tablero comentar` que diga que ya está en 2.3. Añade al cuerpo del PR un bloque «Desbloqueo del 14-nov» con qué se resolvió y cómo se probó.

## Simulador

Tienes permiso para un **segundo simulador en la Max** (tope 2) si el primero lo usa otra sesión, o para el **iPhone 14 por Device MCP**. En la Mini, uno.

## Qué NO hay que tocar

- Nada fuera de los ficheros de este PR salvo lo mínimo para que compile y pase el gate con lo nuevo de 2.3.
- Ninguna funcionalidad nueva ni mejora adyacente: solo resolver y verificar.
- CloudKit Production, el gateway o el conector de producción, y los otros PR abiertos.

## Cómo se sabe que está bien

`/gate` en verde sobre el merge, el PR `899` en `MERGED` (o en cola con la razón dicha si se pasó el tope), y sus cards en `in qa`.
