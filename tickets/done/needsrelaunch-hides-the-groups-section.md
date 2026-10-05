---
id: needsrelaunch-hides-the-groups-section
status: done
priority: medium
area: "modo-nube, settings, groups"
created: 2026-09-11
updated: 2026-10-02
source: "review adversarial de `cloud-killswitch-hides-the-only-door-to-detach-groups`, lente de estados"
---

# Con la migración esperando relanzamiento, la cuenta de grupos vuelve a quedarse sin puerta

## El problema, en lenguaje de usuario

Si mi Yala quedó esperando a que cierre y vuelva a abrir la app (tras una migración o una reversa),
Ajustes → «¿Dónde viven tus datos?» enseña solo esa tarjeta. La sección «Grupos» no está, así que
mientras no relance no puedo soltar mi cuenta de grupos. Y ese estado **no es un tránsito**: sobrevive a
todo hasta que mate la app.

## Lo medido (2026-09-11)

`StorageSettingsView.swift:171-172`:

```swift
case .needsRelaunch(let direction):
    relaunchCard(direction)
```

Nada más. El estado se deriva de `mirrorOffArmed` / `phase == .reverseMountMirror`
(`CloudMigrationController.swift:79-88`), **los dos durables**.

El caso con daño real es `.needsRelaunch(.toICloud)` —la reversa—: ahí `storageMode` ya es `.icloud` ⇒
`deviceState == .privateSession` ⇒ la sección **sí aplicaría** (`.associated` o `.associatedNeedsSignIn`,
las dos con `offersDetach == true`) y el `case` no la monta. Se llega por el camino normal:
`promoteAssociatedAccountThenCutover` (`CloudIdentityRoutingLogic.swift:206-208`) deja la asociación
escrita y la reversa devuelve el dispositivo a sesión privada con ella puesta.

`.migrating` / `.reverting` tienen el mismo hueco durante el cutover; en `.reverting` el daño es nulo
(`storageMode == .cloud` ⇒ `.sameAccountAsPersonal`, que no ofrece soltar nada de todos modos).

**El criterio para cerrarlo ya está escrito tres líneas más abajo**, justificando por qué
`.waitingForLeader` y `.failed` SÍ montan la sección (`StorageSettingsView.swift:175-178`): «salen del
journal PERSISTIDO… ocultar aquí la sección dejaría sin poder desasociar —indefinidamente—».
`.needsRelaunch` cumple esa misma descripción y no recibió el mismo trato.

## Lo que se espera

Decidir si la card de relanzamiento sigue siendo **bloqueante** —es su diseño: «cierra Yala y vuelve a
abrirla»— o si la sección de Grupos es la excepción que merece convivir con ella. Si se monta, cuidado
con no convertir una card bloqueante en una pantalla normal.

## Cierre (2026-10-02)

**La premisa no se sostiene, y por eso la sección no se monta.** Medido en `2.1` (b051d8d03): en
`.needsRelaunch(.toICloud)` el modo sigue en `.cloud`, no en `.icloud`. La arista
`reverseFreezeBackend → reverseMountMirror` solo emite `.mountMirrorAndRelaunch`, que desarma el flag del
mirror-off y no toca el modo; `.persistICloudMode` sale únicamente en el cuarteto de
`reverseUpload → icloudActive` (y en el aborto del paso 4, que va a `failedRollback`). Con `.cloud`,
`deviceState == .cloudComplete` ⇒ la sección sería `.sameAccountAsPersonal`, que no ofrece desasociar. Las
otras dos formas de llegar a la tarjeta de relanzar (`.toCloud`: cutover/adopt y `.rearmMirrorOff`) también
escriben `.cloud`.

O sea: la tarjeta de relanzar va sola y nadie se queda sin puerta. Montar la sección ahí solo añadiría «tus
grupos usan esta misma cuenta» a una tarjeta cuyo trabajo es «cierra y vuelve a abrir».

`.reverting`: mismo modo `.cloud`, daño nulo (como ya decía el ticket). `.migrating` pre-cutover sí lleva
`.icloud`, pero es tránsito salvo el adopt que se reintenta, que ya conserva la sección: no se amplía.

**Lo que queda fijado:**
- `MigrationWorkExecutorTests.needsRelaunch_keepsCloudMode_soTheGroupsSectionHasNoDoorToLose`: efectos reales
  (`.mountMirrorAndRelaunch`, `.rearmMirrorOff`) → modo → `derive` → `sectionState` en las 8 combinaciones →
  sin puerta. Si una arista llega a escribir `.icloud` antes de relanzar, salta, y entonces el `case` de la
  vista sí tiene que montar la sección.
- `MigrationJournalUnreadableTests.storageScreen_durableCases_keepTheirCardAndTheGroupsSectionWhereItIsADoor`:
  la tarjeta de relanzar sigue ahí; espera del seguidor y fallo conservan la sección.
- Comentario en el `case .needsRelaunch` de `StorageSettingsView` con el porqué.

Sin device-QA: no cambia nada visible.
