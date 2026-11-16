---
toca: Yala/App/Logic/GroupsAssociationLogic.swift, Yala/App/Logic/MigrationBlockChangeAccountLogic.swift, Yala/App/Views/Settings/GroupsAssociationSection.swift, Yala/App/Views/Settings/GroupsDetachSheet.swift, Yala/App/Views/Settings/StorageMigrationBlockedView.swift, Yala/App/Views/Settings/StorageSettingsView.swift, Yala/Utils/L10n.swift, YalaTests/CloudSync/AdoptEffectCeilingLogicTests.swift, YalaTests/CloudSync/ChangeAccountG1Tests.swift, YalaTests/CloudSync/MigrationIdentityGateWiringTests.swift, YalaTests/CloudSync/MigrationJournalUnreadableTests.swift, YalaTests/CloudSync/RemoteFlagDecisionLogicTests.swift, YalaTests/GroupsLote19FixesTests.swift, YalaTests/StorageMigrationIdentityGateLogicTests.swift, YalaUITests/Flows/GroupsAssociationRowUITests.swift, YalaUITests/Flows/StorageMigrationIdentityBlockUITests.swift, Yala/Resources/
esfuerzo: high
cierre: cierra-sola
pruebas-ui: si
depende: Yala/desbloquear-pr-nube-volver-a-icloud
---

# Desbloquear el PR «Nube 2.3 · «Cambiar de cuenta» en una fila, y la hoja de soltar»: traer 2.3, resolver el conflicto y dejarlo mergeado

Rama base: 2.3.

## Contexto

Lo encola la conciliación de PR abiertos de 2.3 del 14-nov (`docs/qa/conciliacion-prs-2-3/` en 2.3). Este PR terminó su sesión en modo cola: quedó en cola de auto-merge y el merge de otro PR lo dejó en conflicto, así que lleva días sin entrar. Su código **no está** en 2.3 (medido: ningún commit suyo en 2.3 y casi ninguna de sus líneas) y **nada mergeado lo reemplaza**. Su card dice «done» o «in qa», pero la conciliación la pasó a `blocked` porque el trabajo no está en la rama.

PR: https://github.com/jur211296/Yala/pull/916 — «Nube 2.3 · «Cambiar de cuenta» en una fila, y la hoja de soltar». Rama: `encargo/2026-11-11-lote-2-3-nube-cambiar-de-cuenta`.

Cómo está el conflicto: Medido: el código no choca con 2.3; con el PR de volver a iCloud (#910), que va delante, choca un hunk trivial de `StorageSettingsView.swift` (cada uno añade una propiedad `@Environment` en el mismo sitio: quédate con las dos). En `es` hay 4 hunks de `.strings`: uno trivial y 3 semánticos, porque #928 (decisión 51) reescribió las siete claves `storage.migrate.refused*` y `storage.migrateBlock.*` con «tu cuenta de Yala» y este PR las reescribe con «Cambiar de cuenta» y el vocabulario viejo: hay que fundir las dos frases a mano en los 16 idiomas. También `qa/coverage-index.json` (1).

## Qué se pide

1. `git fetch origin` y trabaja **sobre la rama del PR** (`encargo/2026-11-11-lote-2-3-nube-cambiar-de-cuenta`), no sobre una rama nueva: trae `origin/2.3` con un merge (no rebase: la rama ya está publicada) y resuelve los conflictos.
2. Medido: si al resolver te quedas con el lado del PR, `DosNombresDeSitioTests` cae en 4 claves (`refusedFreshStart`, `otherGroupsBody`, `otherGroupsBodyEmail`, `freshStartSessionBody`) por «cuenta en la nube» y «Activar la nube». Reescríbelas con los dos nombres fijos.
   Pasa `/gate` entero (build ×2, unit, XCUITest de las áreas tocadas, validación del índice). Sin gate no hay commit.
3. Push a la misma rama. No abras PR nuevo: el PR ya existe y ya tiene el auto-merge activado (compruébalo con `gh pr view 916 --json state,mergeable,autoMergeRequest`; si no lo tiene, `gh pr merge 916 --auto --merge`).
4. **Espera a que tu PR quede `MERGED`** antes de cerrar (excepción a la regla de no esperar el CI, a propósito: este PR ya se quedó una vez colgado por no hacerlo). Mira cada 5 min con `gh pr view 916 --json state,mergeStateStatus` y escribe avance; si vuelve a `DIRTY` porque otro PR entró antes, repite 1-3. Tope: 90 min o dos vueltas; si se pasa, déjalo en cola y dilo en «Necesita de ti».
5. Al quedar `MERGED`: mueve sus cards (izvv (2.3 · Nube: «Cambiar de cuenta» sin saltarse las consecuencias)) de `blocked` a `in qa` con `tablero mover <id> --a "in qa"` y un `tablero comentar` que diga que ya está en 2.3. Añade al cuerpo del PR un bloque «Desbloqueo del 14-nov» con qué se resolvió y cómo se probó.

## Simulador

Tienes permiso para un **segundo simulador en la Max** (tope 2) si el primero lo usa otra sesión, o para el **iPhone 14 por Device MCP**. En la Mini, uno.

## Qué NO hay que tocar

- Nada fuera de los ficheros de este PR salvo lo mínimo para que compile y pase el gate con lo nuevo de 2.3.
- Ninguna funcionalidad nueva ni mejora adyacente: solo resolver y verificar.
- CloudKit Production, el gateway o el conector de producción, y los otros PR abiertos.

## Cómo se sabe que está bien

`/gate` en verde sobre el merge, el PR `916` en `MERGED` (o en cola con la razón dicha si se pasó el tope), y sus cards en `in qa`.
