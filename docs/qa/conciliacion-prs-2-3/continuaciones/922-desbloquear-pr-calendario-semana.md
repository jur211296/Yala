---
toca: .claude/rules/swiftui-ds.md, Yala/App/Logic/RecordsCalendarLayout.swift, Yala/App/ViewModels/RecordsViewModel.swift, Yala/App/Views/Records/Components/RecordsCalendarView.swift, Yala/App/Views/Records/Components/RecordsSelectionBar.swift, Yala/App/Views/Records/RecordsStandaloneView.swift, Yala/App/Views/Statistics/RecordsTabView.swift, Yala/Utils/L10n.swift, YalaTests/RecordsCalendarFoldTests.swift, YalaTests/TabImplicitAnimationsWiringTests.swift, YalaUITests/Flows/RecordsCalendarWeek23UITests.swift, Yala/Resources/
esfuerzo: high
cierre: cierra-sola
pruebas-ui: si
depende: Yala/desbloquear-pr-nota-de-salud-lote-1
---

# Desbloquear el PR «Registros: el calendario se pliega a la semana del día»: traer 2.3, resolver el conflicto y dejarlo mergeado

Rama base: 2.3.

## Contexto

Lo encola la conciliación de PR abiertos de 2.3 del 14-nov (`docs/qa/conciliacion-prs-2-3/` en 2.3). Este PR terminó su sesión en modo cola: quedó en cola de auto-merge y el merge de otro PR lo dejó en conflicto, así que lleva días sin entrar. Su código **no está** en 2.3 (medido: ningún commit suyo en 2.3 y casi ninguna de sus líneas) y **nada mergeado lo reemplaza**. Su card dice «done» o «in qa», pero la conciliación la pasó a `blocked` porque el trabajo no está en la rama.

PR: https://github.com/jur211296/Yala/pull/922 — «Registros: el calendario se pliega a la semana del día». Rama: `encargo/2026-11-11-lote-2-3-calendario-semana`.

Cómo está el conflicto: Medido: `RecordsStandaloneView.swift` choca de forma trivial (los dos lados añaden parámetros a la misma llamada: `loadFailed`/`onRetryLoad` de 2.3 y `keepsCalendarAtReadableWidth` del PR; quédate con todos). `RecordsTabView.swift` choca de forma SEMÁNTICA en 2 hunks: el PR envuelve el cuerpo en un `ScrollViewReader` y pasa el estado del calendario a `RecordsViewModel`, mientras que en 2.3 el calendario se movió a `viewModeArea` con estados de carga y error (PR #926, decisiones 77 y 78) y saltar de mes trajo su propio `ScrollViewReader` (`jumpToMonth`, PR #923). Inferido: el auto-merge quita `@State` de los que `viewModeArea` depende y pinta el calendario dos veces. La parte de `RecordsTabView` hay que rehacerla sobre `viewModeArea`, conservando lo de 2.3. También `docs/TICKETS.md`.

## Qué se pide

1. `git fetch origin` y trabaja **sobre la rama del PR** (`encargo/2026-11-11-lote-2-3-calendario-semana`), no sobre una rama nueva: trae `origin/2.3` con un merge (no rebase: la rama ya está publicada) y resuelve los conflictos.
2. Es el único de la tanda que hay que reescribir: verifica en el simulador (iPhone y iPad) el plegado a la semana, saltar de mes y el estado de error, con capturas.
   Pasa `/gate` entero (build ×2, unit, XCUITest de las áreas tocadas, validación del índice). Sin gate no hay commit.
3. Push a la misma rama. No abras PR nuevo: el PR ya existe y ya tiene el auto-merge activado (compruébalo con `gh pr view 922 --json state,mergeable,autoMergeRequest`; si no lo tiene, `gh pr merge 922 --auto --merge`).
4. **Espera a que tu PR quede `MERGED`** antes de cerrar (excepción a la regla de no esperar el CI, a propósito: este PR ya se quedó una vez colgado por no hacerlo). Mira cada 5 min con `gh pr view 922 --json state,mergeStateStatus` y escribe avance; si vuelve a `DIRTY` porque otro PR entró antes, repite 1-3. Tope: 90 min o dos vueltas; si se pasa, déjalo en cola y dilo en «Necesita de ti».
5. Al quedar `MERGED`: mueve sus cards (rjsz (2.3 · Calendario de Registros: la semana a la vista y el iPad)) de `blocked` a `in qa` con `tablero mover <id> --a "in qa"` y un `tablero comentar` que diga que ya está en 2.3. Añade al cuerpo del PR un bloque «Desbloqueo del 14-nov» con qué se resolvió y cómo se probó.

## Simulador

Tienes permiso para un **segundo simulador en la Max** (tope 2) si el primero lo usa otra sesión, o para el **iPhone 14 por Device MCP**. En la Mini, uno.

## Qué NO hay que tocar

- Nada fuera de los ficheros de este PR salvo lo mínimo para que compile y pase el gate con lo nuevo de 2.3.
- Ninguna funcionalidad nueva ni mejora adyacente: solo resolver y verificar.
- CloudKit Production, el gateway o el conector de producción, y los otros PR abiertos.

## Cómo se sabe que está bien

`/gate` en verde sobre el merge, el PR `922` en `MERGED` (o en cola con la razón dicha si se pasó el tope), y sus cards en `in qa`.
