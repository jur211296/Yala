---
toca: .claude/rules/l10n.md, Yala/App/Logic/CategoryQuickPickLogic.swift, Yala/App/Logic/TransactionFormDecided02BLogic.swift, Yala/App/ViewModels/NewTransactionViewModel.swift, Yala/App/Views/Transactions/Components/CategoryQuickPickRow.swift, Yala/App/Views/Transactions/Components/SelectionChip.swift, Yala/App/Views/Transactions/NewTransactionView.swift, Yala/App/Views/Transactions/SubcategorySelectorSheet.swift, Yala/Utils/L10n.swift, YalaTests/CategoryQuickPick23Tests.swift, YalaTests/LocalizationParityTests.swift, YalaTests/TranslationLot124GuardTests.swift, YalaTests/UXAudit22Decidido02BLogicTests.swift, YalaUITests/Flows/CategoryQuickPick23UITests.swift, YalaUITests/Support/XCUIApplication+Yala.swift, Yala/Resources/
esfuerzo: high
cierre: cierra-sola
pruebas-ui: si
depende: Yala/desbloquear-pr-estadisticas-voiceover
---

# Desbloquear el PR «Nuevo registro: categorías a un toque y un buscador que entiende «café»»: traer 2.3, resolver el conflicto y dejarlo mergeado

Rama base: 2.3.

## Contexto

Lo encola la conciliación de PR abiertos de 2.3 del 14-nov (`docs/qa/conciliacion-prs-2-3/` en 2.3). Este PR terminó su sesión en modo cola: quedó en cola de auto-merge y el merge de otro PR lo dejó en conflicto, así que lleva días sin entrar. Su código **no está** en 2.3 (medido: ningún commit suyo en 2.3 y casi ninguna de sus líneas) y **nada mergeado lo reemplaza**. Su card dice «done» o «in qa», pero la conciliación la pasó a `blocked` porque el trabajo no está en la rama.

PR: https://github.com/jur211296/Yala/pull/920 — «Nuevo registro: categorías a un toque y un buscador que entiende «café»». Rama: `encargo/2026-11-11-lote-2-3-categorias-recientes`.

Cómo está el conflicto: Medido: 16 `.strings` (un hunk al final), `qa/coverage-index.json` (3), `.claude/rules/l10n.md` (ambos añaden viñetas) y `YalaTests/LocalizationParityTests.swift` (ambos añaden entradas a la lista de exentos: quédate con las dos). Ningún Swift de la app choca.

## Qué se pide

1. `git fetch origin` y trabaja **sobre la rama del PR** (`encargo/2026-11-11-lote-2-3-categorias-recientes`), no sobre una rama nueva: trae `origin/2.3` con un merge (no rebase: la rama ya está publicada) y resuelve los conflictos.
2. Inferido, sin probar: nació antes de la fila de favoritos por tipo (#921) y de la guía del tutorial en Nuevo registro (#938); se mezclan solos y la fila cae entre el chip de reparto y los chips de categoría. Mira esa convivencia en el simulador (iPhone pequeño y en dólares, que el PR ya avisaba largo) y saca captura.
   Pasa `/gate` entero (build ×2, unit, XCUITest de las áreas tocadas, validación del índice). Sin gate no hay commit.
3. Push a la misma rama. No abras PR nuevo: el PR ya existe y ya tiene el auto-merge activado (compruébalo con `gh pr view 920 --json state,mergeable,autoMergeRequest`; si no lo tiene, `gh pr merge 920 --auto --merge`).
4. **Espera a que tu PR quede `MERGED`** antes de cerrar (excepción a la regla de no esperar el CI, a propósito: este PR ya se quedó una vez colgado por no hacerlo). Mira cada 5 min con `gh pr view 920 --json state,mergeStateStatus` y escribe avance; si vuelve a `DIRTY` porque otro PR entró antes, repite 1-3. Tope: 90 min o dos vueltas; si se pasa, déjalo en cola y dilo en «Necesita de ti».
5. Al quedar `MERGED`: mueve sus cards (4xrs (2.3 · Categorías recientes y el buscador que entiende «café»)) de `blocked` a `in qa` con `tablero mover <id> --a "in qa"` y un `tablero comentar` que diga que ya está en 2.3. Añade al cuerpo del PR un bloque «Desbloqueo del 14-nov» con qué se resolvió y cómo se probó.

## Simulador

Tienes permiso para un **segundo simulador en la Max** (tope 2) si el primero lo usa otra sesión, o para el **iPhone 14 por Device MCP**. En la Mini, uno.

## Qué NO hay que tocar

- Nada fuera de los ficheros de este PR salvo lo mínimo para que compile y pase el gate con lo nuevo de 2.3.
- Ninguna funcionalidad nueva ni mejora adyacente: solo resolver y verificar.
- CloudKit Production, el gateway o el conector de producción, y los otros PR abiertos.

## Cómo se sabe que está bien

`/gate` en verde sobre el merge, el PR `920` en `MERGED` (o en cola con la razón dicha si se pasó el tope), y sus cards en `in qa`.
