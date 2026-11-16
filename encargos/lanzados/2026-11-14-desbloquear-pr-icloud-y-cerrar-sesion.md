---
toca: .claude/rules/swiftui-ds.md, Yala/App/AppBootstrapper.swift, Yala/App/ContentView.swift, Yala/App/Logic/CloudProgressStepsLogic.swift, Yala/App/Logic/WelcomePrivateICloudGateLogic.swift, Yala/App/Views/Onboarding/WelcomeRestoreView.swift, Yala/App/Views/Settings/StorageSettingsView.swift, Yala/Services/CloudSync/CloudBeacon.swift, Yala/Services/CloudSync/CloudMigrationController.swift, Yala/Services/CloudSync/CloudSessionSignOut.swift, Yala/Services/CloudSync/CloudSyncEngine.swift, Yala/Services/CloudSync/MigrationRunner.swift, Yala/Services/CloudSync/MigrationWorkExecutor.swift, YalaTests/BarridoBugsLoteB/PreCloudNoteAfterLinkTests.swift, YalaTests/BarridoBugsLoteB/SignOutRelaunchCoverWaitsForSwapTests.swift, YalaTests/BarridoBugsLoteB/SwapReleasesEveryServiceContextTests.swift, YalaTests/CloudSync/MigrationJournalUnreadableTests.swift, YalaTests/CloudSync/WelcomePrivateICloudGateTests.swift, YalaTests/ICloudReturnAndEmpty/ICloudEmptyAndReverseScreenTests.swift, YalaTests/ICloudReturnAndEmpty/ReverseDrainBatchesTests.swift, YalaTests/RestoreLoteN3Tests.swift
esfuerzo: high
cierre: cierra-sola
pruebas-ui: si
---

# Desbloquear el PR «iCloud y cerrar sesión»: traer 2.3, resolver el conflicto y dejarlo mergeado

Rama base: 2.3.

## Contexto

Lo encola la conciliación de PR abiertos de 2.3 del 14-nov (`docs/qa/conciliacion-prs-2-3/` en 2.3). Este PR terminó su sesión en modo cola: quedó en cola de auto-merge y el merge de otro PR lo dejó en conflicto, así que lleva días sin entrar. Su código **no está** en 2.3 (medido: ningún commit suyo en 2.3 y casi ninguna de sus líneas) y **nada mergeado lo reemplaza**. Su card dice «done» o «in qa», pero la conciliación la pasó a `blocked` porque el trabajo no está en la rama.

PR: https://github.com/jur211296/Yala/pull/973 — «iCloud y cerrar sesión». Rama: `encargo/2026-11-14-barrido-bugs-icloud-y-cerrar-sesion`.

Cómo está el conflicto: Medido: solo 23 commits detrás de 2.3, ninguno de nube. Choca un hunk de `docs/DECISIONS.md` y uno de `qa/coverage-index.json` (los dos lados reescriben la línea `coverage` de la misma área). Ningún `.swift` ni `.strings` choca. Lleva dentro el PR «Volver a tu iCloud sin quedarse trabado» (#962), que se cerró por eso: no lo reabras. Jürgen ya autorizó desbloquearlo.

## Qué se pide

1. `git fetch origin` y trabaja **sobre la rama del PR** (`encargo/2026-11-14-barrido-bugs-icloud-y-cerrar-sesion`), no sobre una rama nueva: trae `origin/2.3` con un merge (no rebase: la rama ya está publicada) y resuelve los conflictos.
2. Es lógica de sync: tras resolver, corre las suites de `YalaTests/BarridoBugsLoteB/`, `YalaTests/ICloudReturnAndEmpty/` y `YalaTests/CloudSync/`, y comprueba que lo que entró hoy en 2.3 (el arreglo de «Empezar» y de «Cancelar la activación», PR #971, que también toca `MigrationRunner`, `MigrationWorkExecutor` y `CloudMigrationController`) convive con este: el merge textual no choca, pero son los mismos ficheros.
   Pasa `/gate` entero (build ×2, unit, XCUITest de las áreas tocadas, validación del índice). Sin gate no hay commit.
3. Push a la misma rama. No abras PR nuevo: el PR ya existe y ya tiene el auto-merge activado (compruébalo con `gh pr view 973 --json state,mergeable,autoMergeRequest`; si no lo tiene, `gh pr merge 973 --auto --merge`).
4. **Espera a que tu PR quede `MERGED`** antes de cerrar (excepción a la regla de no esperar el CI, a propósito: este PR ya se quedó una vez colgado por no hacerlo). Mira cada 5 min con `gh pr view 973 --json state,mergeStateStatus` y escribe avance; si vuelve a `DIRTY` porque otro PR entró antes, repite 1-3. Tope: 90 min o dos vueltas; si se pasa, déjalo en cola y dilo en «Necesita de ti».
5. Al quedar `MERGED`: mueve sus cards (p9q0 (cerrar sesión con vista propia), zy1d (iCloud recién vaciado), 4lld (una cuenta en la nube copia al iCloud privado), atde («Volver a tu iCloud» atascado más de 6 min), f8pd (índice de la revisión por vistas 2.3)) de `blocked` a `in qa` con `tablero mover <id> --a "in qa"` y un `tablero comentar` que diga que ya está en 2.3. Añade al cuerpo del PR un bloque «Desbloqueo del 14-nov» con qué se resolvió y cómo se probó.

## Simulador

Tienes permiso para un **segundo simulador en la Max** (tope 2) si el primero lo usa otra sesión, o para el **iPhone 14 por Device MCP**. En la Mini, uno.

## Qué NO hay que tocar

- Nada fuera de los ficheros de este PR salvo lo mínimo para que compile y pase el gate con lo nuevo de 2.3.
- Ninguna funcionalidad nueva ni mejora adyacente: solo resolver y verificar.
- CloudKit Production, el gateway o el conector de producción, y los otros PR abiertos.

## Cómo se sabe que está bien

`/gate` en verde sobre el merge, el PR `973` en `MERGED` (o en cola con la razón dicha si se pasó el tope), y sus cards en `in qa`.

## Paso 0 — decisiones (nocturno, sin consultar; discutibles en el PR)

1. **Conflictos.** Medido al traer 2.3 (42 commits detrás, no 23): cinco ficheros, ninguno `.swift` ni `.strings`. `docs/DECISIONS.md` → la versión de 2.3 (los dos lados registraban el mismo hecho, el despliegue de `CD_systemRoleRaw`; 2.3 lo redacta más nuevo). `qa/coverage-index.json` → el texto de 2.3 con la frase del lote B delante (es lo que la rama añadía sobre la base). `docs/TICKETS.md` → contador a las filas reales del índice fusionado (1311). Las dos notas de memoria de Frank → las dos entradas, una detrás de otra.
2. **El arreglo de «Empezar» y «Cancelar la activación» ya estaba dentro de la rama del PR** (su merge es antecesor de la rama). Lo nuevo de nube que trae 2.3 es el lote 1 de bugs de entrada (lectura de la cuenta en paralelo y páginas de 1000), en otra zona de `MigrationWorkExecutor`.
3. **Unit: `YalaTests` entero** en vez de un subconjunto: el merge mueve 265 ficheros y las suites afectadas pasan de 450; es lo que corre el CI.
4. **XCUITest:** 15 casos de las áreas que el PR y 2.3 tocan a la vez: cierres por celda, pantalla de progreso de cerrar sesión, restaurar sin iCloud Drive, pasos de la vuelta y la puerta de iCloud privado.
5. **El warning de `AppBootstrapper.swift:575`** (resultado sin usar de `reconcileTransferPairs`) es de mayo y sale igual en 2.3: no es del merge y no se toca.
