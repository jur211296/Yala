---
toca: Yala/App/AppBootstrapper.swift, Yala/App/Logic/Calculators/FinancialScoreCalculator.swift, Yala/App/Models/PanelDefaults.swift, Yala/App/Services/PanelPreferencesMigration.swift, Yala/App/Views/Panel/FinancialScoreCompactCard.swift, Yala/App/Views/Panel/FinancialScoreCopy.swift, Yala/App/Views/Panel/Sections/PanelHealthSection.swift, Yala/App/Views/Panel/Sections/PanelPanoramaSection.swift, Yala/App/Views/Panel/Sheets/FinancialScoreDetailSheet.swift, Yala/App/Views/WhatsNew/WhatsNewConfig.swift, Yala/Utils/L10n.swift, YalaTests/BudgetPeriodIntervalTests.swift, YalaTests/FinancialScoreCalculatorTests.swift, YalaTests/NotaDeSaludLote1Tests.swift, YalaTests/PanelDefaultsTests.swift, YalaTests/PanelPreferencesMigrationTests.swift, YalaUITests/Flows/PanelDashboardUITests.swift, YalaUITests/Flows/PanelHealthCompactUITests.swift, Yala/Resources/
esfuerzo: high
cierre: cierra-sola
pruebas-ui: si
depende: Yala/desbloquear-pr-categorias-recientes
---

# Desbloquear el PR «Nota de salud honesta sin desanimar (lote 1)»: traer 2.3, resolver el conflicto y dejarlo mergeado

Rama base: 2.3.

## Contexto

Lo encola la conciliación de PR abiertos de 2.3 del 14-nov (`docs/qa/conciliacion-prs-2-3/` en 2.3). Este PR terminó su sesión en modo cola: quedó en cola de auto-merge y el merge de otro PR lo dejó en conflicto, así que lleva días sin entrar. Su código **no está** en 2.3 (medido: ningún commit suyo en 2.3 y casi ninguna de sus líneas) y **nada mergeado lo reemplaza**. Su card dice «done» o «in qa», pero la conciliación la pasó a `blocked` porque el trabajo no está en la rama.

PR: https://github.com/jur211296/Yala/pull/912 — «Nota de salud honesta sin desanimar (lote 1)». Rama: `encargo/2026-11-11-lote-2-3-nota-de-salud-honesta`.

Cómo está el conflicto: Medido: 16 `.strings` (un hunk al final), `.claude/agent-memory/frank/MEMORY.md` y `qa/coverage-index.json` (1). Ningún fichero de código; `AppBootstrapper` se mezcla solo.

## Qué se pide

1. `git fetch origin` y trabaja **sobre la rama del PR** (`encargo/2026-11-11-lote-2-3-nota-de-salud-honesta`), no sobre una rama nueva: trae `origin/2.3` con un merge (no rebase: la rama ya está publicada) y resuelve los conflictos.
2. Inferido, sin probar: desde que nació, la bienvenida 2.3 (Primeros pasos) llama a `materializePanelDefaultsIfNeeded`, donde se aplica el cambio de `PanelDefaults` de este PR: prueba una instalación nueva hasta el Panel y mira que la nota de salud sale como pide el PR.
   Pasa `/gate` entero (build ×2, unit, XCUITest de las áreas tocadas, validación del índice). Sin gate no hay commit.
3. Push a la misma rama. No abras PR nuevo: el PR ya existe y ya tiene el auto-merge activado (compruébalo con `gh pr view 912 --json state,mergeable,autoMergeRequest`; si no lo tiene, `gh pr merge 912 --auto --merge`).
4. **Espera a que tu PR quede `MERGED`** antes de cerrar (excepción a la regla de no esperar el CI, a propósito: este PR ya se quedó una vez colgado por no hacerlo). Mira cada 5 min con `gh pr view 912 --json state,mergeStateStatus` y escribe avance; si vuelve a `DIRTY` porque otro PR entró antes, repite 1-3. Tope: 90 min o dos vueltas; si se pasa, déjalo en cola y dilo en «Necesita de ti».
5. Al quedar `MERGED`: mueve sus cards (ninguna de implementación (la de la decisión, ppi2, está bien en done)) de `blocked` a `in qa` con `tablero mover <id> --a "in qa"` y un `tablero comentar` que diga que ya está en 2.3. Añade al cuerpo del PR un bloque «Desbloqueo del 14-nov» con qué se resolvió y cómo se probó.

## Simulador

Tienes permiso para un **segundo simulador en la Max** (tope 2) si el primero lo usa otra sesión, o para el **iPhone 14 por Device MCP**. En la Mini, uno.

## Qué NO hay que tocar

- Nada fuera de los ficheros de este PR salvo lo mínimo para que compile y pase el gate con lo nuevo de 2.3.
- Ninguna funcionalidad nueva ni mejora adyacente: solo resolver y verificar.
- CloudKit Production, el gateway o el conector de producción, y los otros PR abiertos.

## Cómo se sabe que está bien

`/gate` en verde sobre el merge, el PR `912` en `MERGED` (o en cola con la razón dicha si se pasó el tope), y sus cards en `in qa`.
