---
toca: .claude/rules/swiftdata-cloudkit.md, Yala/App/ContentView.swift, Yala/App/Logic/ReturnToICloudSheetLogic.swift, Yala/App/Logic/ReverseICloudPriorDataLogic.swift, Yala/App/Logic/WelcomePrivateICloudGateLogic.swift, Yala/App/UITestHooks.swift, Yala/App/Views/Profile/ProfileView.swift, Yala/App/Views/Settings/PendingICloudWipeSheet.swift, Yala/App/Views/Settings/ReturnToICloudSheet.swift, Yala/App/Views/Settings/StorageSettingsView.swift, Yala/App/Views/Shared/LateICloudMirrorNoticeView.swift, Yala/Utils/L10n.swift, YalaTests/CloudSync/ActivationLateNoticeKeepsGroupsTests.swift, YalaTests/CloudSync/ActivationRestoreDiscardTests.swift, YalaTests/CloudSync/LateICloudWipeLeftHalfwayTests.swift, YalaTests/CloudSync/MigrationIdentityGateWiringTests.swift, YalaTests/CloudSync/PendingICloudWipeCloudTests.swift, YalaTests/CloudSync/ReverseICloudPriorDataTests.swift, YalaTests/CloudSync/WelcomeLateNoticeKeepsJoinedGroupsTests.swift, YalaTests/ReturnToICloudSheetLogicTests.swift, YalaTests/UXAudit22Lote20NubeTests.swift, YalaUITests/Flows/PendingICloudWipeMigrationUITests.swift, YalaUITests/Flows/ReverseICloudPriorDataUITests.swift, YalaUITests/Support/XCUIApplication+Yala.swift, Yala/Resources/
esfuerzo: high
cierre: cierra-sola
pruebas-ui: si
depende: Yala/desbloquear-pr-nube-cifrado-y-fotos
---

# Desbloquear el PR «Nube 2.3: volver a tu iCloud y activar con un borrado pendiente»: traer 2.3, resolver el conflicto y dejarlo mergeado

Rama base: 2.3.

## Contexto

Lo encola la conciliación de PR abiertos de 2.3 del 14-nov (`docs/qa/conciliacion-prs-2-3/` en 2.3). Este PR terminó su sesión en modo cola: quedó en cola de auto-merge y el merge de otro PR lo dejó en conflicto, así que lleva días sin entrar. Su código **no está** en 2.3 (medido: ningún commit suyo en 2.3 y casi ninguna de sus líneas) y **nada mergeado lo reemplaza**. Su card dice «done» o «in qa», pero la conciliación la pasó a `blocked` porque el trabajo no está en la rama.

PR: https://github.com/jur211296/Yala/pull/910 — «Nube 2.3: volver a tu iCloud y activar con un borrado pendiente». Rama: `encargo/2026-11-11-lote-2-3-nube-volver-a-icloud`.

Cómo está el conflicto: Medido: el código se mezcla solo (2.3 tocó ContentView, ProfileView, StorageSettingsView, L10n y UITestHooks en otras zonas). Chocan los 16 `Localizable.strings` de forma SEMÁNTICA: el PR de los dos nombres fijos («En tu iCloud» / «En tu cuenta de Yala», decisión 51, #928) renombró las mismas claves que este PR reescribe o borra; en `es` son 5 hunks. Además `.claude/rules/swiftdata-cloudkit.md` (2 hunks), `docs/DECISIONS.md` (2) y `qa/coverage-index.json` (1).

## Qué se pide

1. `git fetch origin` y trabaja **sobre la rama del PR** (`encargo/2026-11-11-lote-2-3-nube-volver-a-icloud`), no sobre una rama nueva: trae `origin/2.3` con un merge (no rebase: la rama ya está publicada) y resuelve los conflictos.
2. Los textos nuevos de este PR usan el vocabulario anterior a la decisión 51 («Si activas la nube…», «Volver a la nube con ella»): reescríbelos con los dos nombres fijos en los 16 idiomas (regla en `.claude/rules/l10n.md`; test `DosNombresDeSitioTests`). El PR «Cambiar de cuenta» (#916) va detrás y choca con este en un hunk trivial de `StorageSettingsView.swift`.
   Pasa `/gate` entero (build ×2, unit, XCUITest de las áreas tocadas, validación del índice). Sin gate no hay commit.
3. Push a la misma rama. No abras PR nuevo: el PR ya existe y ya tiene el auto-merge activado (compruébalo con `gh pr view 910 --json state,mergeable,autoMergeRequest`; si no lo tiene, `gh pr merge 910 --auto --merge`).
4. **Espera a que tu PR quede `MERGED`** antes de cerrar (excepción a la regla de no esperar el CI, a propósito: este PR ya se quedó una vez colgado por no hacerlo). Mira cada 5 min con `gh pr view 910 --json state,mergeStateStatus` y escribe avance; si vuelve a `DIRTY` porque otro PR entró antes, repite 1-3. Tope: 90 min o dos vueltas; si se pasa, déjalo en cola y dilo en «Necesita de ti».
5. Al quedar `MERGED`: mueve sus cards (anfw (2.3 · Nube: volver a iCloud y «Activar sin borrar», en una hoja)) de `blocked` a `in qa` con `tablero mover <id> --a "in qa"` y un `tablero comentar` que diga que ya está en 2.3. Añade al cuerpo del PR un bloque «Desbloqueo del 14-nov» con qué se resolvió y cómo se probó.

## Simulador

Tienes permiso para un **segundo simulador en la Max** (tope 2) si el primero lo usa otra sesión, o para el **iPhone 14 por Device MCP**. En la Mini, uno.

## Qué NO hay que tocar

- Nada fuera de los ficheros de este PR salvo lo mínimo para que compile y pase el gate con lo nuevo de 2.3.
- Ninguna funcionalidad nueva ni mejora adyacente: solo resolver y verificar.
- CloudKit Production, el gateway o el conector de producción, y los otros PR abiertos.

## Cómo se sabe que está bien

`/gate` en verde sobre el merge, el PR `910` en `MERGED` (o en cola con la razón dicha si se pasó el tope), y sus cards en `in qa`.
