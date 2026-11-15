---
toca: .claude/rules/l10n.md, Yala/App/Logic/BridgeToggleSheetLogic.swift, Yala/App/Logic/GroupArchivedEntryLogic.swift, Yala/App/Logic/OpeningBalanceErrorCopyLogic.swift, Yala/App/ViewModels/GroupDetailViewModel.swift, Yala/App/Views/Groups/GroupDetailView.swift, Yala/App/Views/Groups/GroupOpeningBalanceFormView.swift, Yala/App/Views/Groups/GroupSettingsView.swift, Yala/App/Views/Groups/GroupSplitEditorCard.swift, Yala/App/Views/Groups/GroupsGlobalSettingsView.swift, Yala/App/Views/Groups/SettlementFormView.swift, Yala/Services/Groups/GroupExpenseService.swift, Yala/Utils/L10n.swift, YalaTests/GroupsLote13FixesTests.swift, YalaTests/GroupsNecesarias23Lote01Tests.swift, YalaTests/OpeningBalanceReplacePromptTests.swift, YalaTests/SettlementRetryDuplicateTests.swift, YalaUITests/Flows/GroupOpeningBalanceAdminUITests.swift, YalaUITests/Flows/GroupSplitAmountFieldUITests.swift, YalaUITests/Flows/GroupsBridgeHistoryImportUITests.swift, YalaUITests/Flows/GroupsLote19DecididoUITests.swift, Yala/Resources/
esfuerzo: high
cierre: cierra-sola
pruebas-ui: si
---

# Desbloquear el PR «Grupos: pagos que no se duplican, reparto sin dígitos perdidos y cambios que preguntan»: traer 2.3, resolver el conflicto y dejarlo mergeado

Rama base: 2.3.

## Contexto

Lo encola la conciliación de PR abiertos de 2.3 del 14-nov (`docs/qa/conciliacion-prs-2-3/` en 2.3). Este PR terminó su sesión en modo cola: quedó en cola de auto-merge y el merge de otro PR lo dejó en conflicto, así que lleva días sin entrar. Su código **no está** en 2.3 (medido: ningún commit suyo en 2.3 y casi ninguna de sus líneas) y **nada mergeado lo reemplaza**. Su card dice «done» o «in qa», pero la conciliación la pasó a `blocked` porque el trabajo no está en la rama.

PR: https://github.com/jur211296/Yala/pull/894 — «Grupos: pagos que no se duplican, reparto sin dígitos perdidos y cambios que preguntan». Rama: `encargo/2026-11-10-lote-2-3-grupos-cifras-planificacion`.

Cómo está el conflicto: Medido: un solo hunk de código, semántico y pequeño, en `Yala/App/Views/Groups/SettlementFormView.swift` (~línea 524): 2.3 (PR #947, saldar como en Splitwise) confirma el pago solo si `SettlementSaldar23Logic.confirmsOnRecord(...)` lo permite, y este PR lo crea con `confirmed: true`. Resolución propuesta: `confirmed: SettlementSaldar23Logic.confirmsOnRecord(...)`, y comprobar con test que el pago pendiente sigue sin puente. Además `.claude/rules/l10n.md`, `docs/TICKETS.md`, `qa/coverage-index.json` y memoria de Frank.

## Qué se pide

1. `git fetch origin` y trabaja **sobre la rama del PR** (`encargo/2026-11-10-lote-2-3-grupos-cifras-planificacion`), no sobre una rama nueva: trae `origin/2.3` con un merge (no rebase: la rama ya está publicada) y resuelve los conflictos.
2. Es el bridge SplitExpense ↔ TransactionItem y cifras de Grupos: review adversarial del hunk resuelto antes del commit.
   Pasa `/gate` entero (build ×2, unit, XCUITest de las áreas tocadas, validación del índice). Sin gate no hay commit.
3. Push a la misma rama. No abras PR nuevo: el PR ya existe y ya tiene el auto-merge activado (compruébalo con `gh pr view 894 --json state,mergeable,autoMergeRequest`; si no lo tiene, `gh pr merge 894 --auto --merge`).
4. **Espera a que tu PR quede `MERGED`** antes de cerrar (excepción a la regla de no esperar el CI, a propósito: este PR ya se quedó una vez colgado por no hacerlo). Mira cada 5 min con `gh pr view 894 --json state,mergeStateStatus` y escribe avance; si vuelve a `DIRTY` porque otro PR entró antes, repite 1-3. Tope: 90 min o dos vueltas; si se pasa, déjalo en cola y dilo en «Necesita de ti».
5. Al quedar `MERGED`: mueve sus cards (d8nx (Mejoras necesarias 2.3 · Grupos: pagos que se duplican, dígitos que se pierden…)) de `blocked` a `in qa` con `tablero mover <id> --a "in qa"` y un `tablero comentar` que diga que ya está en 2.3. Añade al cuerpo del PR un bloque «Desbloqueo del 14-nov» con qué se resolvió y cómo se probó.

## Simulador

Tienes permiso para un **segundo simulador en la Max** (tope 2) si el primero lo usa otra sesión, o para el **iPhone 14 por Device MCP**. En la Mini, uno.

## Qué NO hay que tocar

- Nada fuera de los ficheros de este PR salvo lo mínimo para que compile y pase el gate con lo nuevo de 2.3.
- Ninguna funcionalidad nueva ni mejora adyacente: solo resolver y verificar.
- CloudKit Production, el gateway o el conector de producción, y los otros PR abiertos.

## Cómo se sabe que está bien

`/gate` en verde sobre el merge, el PR `894` en `MERGED` (o en cola con la razón dicha si se pasó el tope), y sus cards en `in qa`.
