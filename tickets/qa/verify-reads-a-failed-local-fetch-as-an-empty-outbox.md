---
id: verify-reads-a-failed-local-fetch-as-an-empty-outbox
status: qa
priority: medium
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-22
source: "review adversarial de `reverse-verify-network-bucket-hides-a-definitive-server-no` (2026-09-22), dos lentes independientes"
---

# El mismo `fetch` que falla se lee como «no hay nada que subir» y, veinte líneas después, como «esto no se arregla»

## El problema, en lenguaje de usuario

Si la base de datos del teléfono no se deja leer, la app hace dos cosas contradictorias en la misma pasada: primero da
por hecho que **no tengo nada pendiente de subir** y se salta ese paso, y después trata ese mismo fallo como algo
**definitivo** que no merece esperar. La primera lectura es demasiado optimista —se salta una subida que sí hacía
falta— y la segunda demasiado pesimista.

## Por qué pasa (medido el 2026-09-22)

En `MigrationWorkExecutor.verify()`:

1. `liveOutboxRows()` hace `try context.fetch(FetchDescriptor<SyncOutbox>())` y, en el `catch`, **devuelve `[]`**. Con
   eso `live.isEmpty` es cierto y el push entero se salta por **falsa quiescencia**.
2. Unas líneas después, `CloudSyncEngine.verifyIntegrity` repite **exactamente el mismo fetch** y su `catch` devuelve
   `.skipped(reason: MerkleSkipReason.outboxFetchFailed)`.

Los dos `catch` describen el mismo fallo y sacan conclusiones opuestas. **Es anterior al 2026-09-22 y hasta ese día no
tenía consecuencia**: los dos caminos acababan en `.networkTimeout`. Desde que el segundo elige el techo corto
(`reverse-verify-network-bucket-hides-a-definitive-server-no`), la asimetría se paga.

Hay un tercero con el mismo patrón: `SyncMerkle.collectLeaves` devuelve `[]` cuando su fetch lanza, así que una tabla
ilegible se hashea como VACÍA y produce una divergencia que no es real.


## Decisión (2026-09-22 · Frank / regla robusta Jürgen)

**Ambos:** (1) un `fetch` de outbox que lanza NO se lee como vacío ni se salta el push; (2) `verify()` aborta con desenlace propio de ese fallo. Incluye el mismo patrón en `collectLeaves` (fetch→`[]` = divergencia falsa) en este mismo ticket.

## Qué habría que decidir antes de hacerlo

1. **¿Quién manda?** Si el outbox no se puede leer, lo honesto es no decidir nada con él: ni «vacío» ni «lleno».
2. **¿El `verify()` corta antes?** Un fetch que lanza podría cortar la pasada entera con un desenlace propio, en vez
   de dejar que cada paso improvise.
3. **`collectLeaves`** es aparte y tiene su propio daño (divergencia falsa). Puede ir en este ticket o en otro.

## Paso 0 — el árbol de decisiones, resuelto (2026-09-22, medido en este árbol)

**El barrido cambió el alcance.** El ticket nombraba tres sitios; el patrón «un `fetch` que lanza se lee como
vacío» aparece **~40 veces** en `Yala/Services/CloudSync/`. Lo que entra aquí es la familia que la decisión
NOMBRA —el fetch de `SyncOutbox` y los leaves del Merkle personal— y lo demás sale con ticket propio, medido,
no adivinado.

### D1 · ¿Qué devuelve `liveOutboxRows()` cuando el fetch lanza? → **`throws`**

No un `nil` ni un `Result`: `throws` obliga al compilador a que **cada** llamador conteste. Son tres funciones
homónimas en tres ficheros (`MigrationWorkExecutor:552`, `MigrationSnapshotUploader:225`,
`CloudSyncRuntime:734`) y las tres devolvían `[]`. «Unificar el tratamiento» son las tres, no una.

### D2 · ¿Dónde corta `verify()`? → **antes del push, con `.blocked(.localFailure)`**

El desenlace propio **ya existe**: `VerifyProbeMapping` manda `outbox-fetch-failed` a `.blocked(.localFailure)`
desde el 2026-09-22. Lo que faltaba era que la PRIMERA lectura dijera lo mismo que la segunda. Así la pasada
tiene una sola conclusión, y es la que `verifyIntegrity` ya daba veinte líneas después.

**El segundo `liveOutboxRows()` de `verify()` (post-push, :520) es peor que el primero** y el ticket no lo
nombraba: hoy un fetch caído ahí devuelve `.newDeltaDetected`, que **NO consume reintento**. O sea que una base
ilegible no solo se lee como «todo subido»: se lee como «vino un delta, re-corre gratis», y eso no tiene techo.
También sale por `.blocked(.localFailure)`.

### D3 · Los otros tres consumidores del mismo helper en el executor

| Sitio | Hoy, si el fetch lanza | Pasa a |
|---|---|---|
| `reverseDrainOnce()` :970 | se salta el push y puede devolver `.completed` ⇒ **la vuelta congela el backend con filas locales sin subir** | `.blocked(.localFailure)` |
| `runLeaderReconcile…` :659 | barrido vacío ⇒ marca `complete` en el servidor **con filas sin subir** | propaga el `throw` (retomable, el molde que ese bloque ya usa) |
| `runAdoptOrphanReconcile` :1340 | no sube las huérfanas y devuelve `.completed(uploaded: 0)` | `.transient` |

### D4 · `MigrationSnapshotUploader` (2 desenlaces)

`drainPushConfirm()` devolvía **`true` = página confirmada** con el fetch caído: el cursor avanzaba sin subir
nada. Pasa a `false`. `finishResidual()` devolvía `.completed`; pasa a `.transient`.

### D5 · `CloudSyncRuntime.performCycle()`

Se saltaba el push y seguía al pull como si el outbox estuviera limpio. Pasa a `.transient` — el ciclo se
reintenta, que es lo que la cadencia ya sabe hacer.

### D6 · `collectLeaves` → **`throws`, y `danglingOverrides` con él**

`collectLeaves` devolvía `[]` ⇒ la tabla se hashea como VACÍA ⇒ divergencia falsa. Sube por
`computeLocalMerkle` (`throws`) hasta `verifyIntegrity`, que lo convierte en
`.skipped(MerkleSkipReason.localMerkleFetchFailed)` → `.blocked(.localFailure)`.

**`danglingOverrides` entra con él y el ticket no lo nombraba.** Su propio docblock lo llama LOAD-BEARING: sin
los overrides el leaf emite `null` donde el servidor tiene un UUID ⇒ **divergencia falsa garantizada en
cualquier multi-device**. Es el mismo fetch, el mismo `[]` y el mismo daño: iba a quedar como el único agujero
de un fichero que se arregla entero.

### D7 · Un `reason` NUEVO, no reusar `outbox-fetch-failed`

`MerkleSkipReason.all` pasa de OCHO a NUEVE. El `rawValue` es lo único que deja distinguir en la flota «no pude
leer el outbox» de «no pude leer el corpus», y las dos tienen remedios distintos. El mapping los junta en
`.blocked(.localFailure)` porque el DESENLACE sí es el mismo.

### D8 · Cómo se hace lanzar un `fetch` en un test → **el molde `_testThrow*` del repo**

No hay ningún test en la suite que haga lanzar un `context.fetch`, y no hay doble de `ModelContext` (es una
`final class` sin protocolo). El repo ya resuelve esto con un flag de instancia consultado en el sitio del
fetch (`CloudSyncEngine._testThrowOnTokenHistoryFetch` y tres hermanos más). Se reusa ese molde en vez de
inventar uno.

Esto además **caduca una frase del propio test** (`MigrationWorkExecutorTests:692`): «los dos `fetch` de
SwiftData de `verifyIntegrity`… no se pueden montar desde el transporte, así que su lectura se fija en el
mapping». Desde este ticket sí se pueden montar, y se montan.

### D9 · Qué se queda FUERA, y con ticket

Los cuatro salen del barrido de este ticket, con sus coordenadas medidas:

1. **Grupos** (`GroupMerkleProjection.collectLeaves:195` + `collectMemberLeaves:224`) — mismo patrón, **otro
   canal**, y peor desenlace: `verifyGroupIntegrity` lo lee como divergencia y **resetea los cursores + re-baja
   el grupo entero**.
2. **El inventario incompleto** (`MigrationSnapshotUploader.makeSpec:298` → `hasMore = false` ⇒ la entidad se da
   por subida; `collectIdentityPairs:369`, `collectAdoptInventory:1536`, `buildOrphanRowInputs:1579`,
   `addReverseUploadPairs:456`).
3. **El journal ilegible** (`CloudMigrationController.readJournalSnapshot:1229` → `(.notStarted, 0)` **y limpia
   el motivo del aborto**; `MigrationPhaseStore.journaledPhase:119` → `.notStarted`, que es fase ESTABLE).
4. **El apply sin sus guards** (`SyncApplyEngine.buildPendingGuards:631` → dict parcial ⇒ un remoto pisa una
   escritura local pendiente; `existingQuarantineSeqs:490`; `EntityApplyMap.deleteMatching:1021`).

## Criterios de aceptación

- [x] Un `fetch` de `SyncOutbox` que lanza NO se lee como «outbox vacío» en el pre-check del push.
- [x] El desenlace de ese fallo es UNO, no dos lecturas contradictorias en la misma pasada.
- [x] Test que haga lanzar el fetch y mida las dos mitades.
- [x] `collectLeaves` con el mismo criterio (una tabla ilegible ya no se hashea como vacía).

## Qué se hizo (2026-09-22)

**Diez desenlaces, uno por consumidor, y ninguno es «no hay nada».**

| Dónde | Antes, con el fetch caído | Ahora |
|---|---|---|
| `verify()` pre-check | se saltaba el push entero | `.blocked(.localFailure)` |
| `verify()` post-push | `.newDeltaDetected` — re-run que NO consume reintento | `.blocked(.localFailure)` |
| `reverseDrainOnce()` | podía devolver `.completed` y la vuelta congelaba el backend | `.blocked(.localFailure)` |
| `runLeaderReconcile…` | barrido vacío y `complete` mandado igual | propaga (retomable) |
| `runAdoptOrphanReconcile` | `.completed(uploaded: 0)`, y el adopt no vuelve | `.transient` |
| `MigrationSnapshotUploader.drainPushConfirm` | `true` = página CONFIRMADA | `false` |
| `MigrationSnapshotUploader.finishResidual` | `.completed` | `.transient` |
| `CloudSyncRuntime.performCycle` | se saltaba el push y seguía al pull | `.transient` |
| `SyncMerkle.collectLeaves` | tabla ilegible = `sha256("")` = tabla vacía ⇒ `.diverged` falso | lanza → `.skipped(local-merkle-fetch-failed)` |
| `SyncMerkle.danglingOverrides` | overrides a medias ⇒ divergencia falsa en multi-device | lanza, con su propio caso |

`MerkleSkipReason` pasa de OCHO a NUEVE motivos: `local-merkle-fetch-failed` es propio y no un reuso de
`outbox-fetch-failed`, porque el desenlace de los dos es el mismo pero el `rawValue` es lo único que separa en la
flota «no pude leer la cola de subida» de «no pude leer los datos».

**Rastro nuevo en producción**, que antes no había ninguno: `CloudSyncBreadcrumb.outboxFetchFailed(step:)` con
**doce** valores de `step` —ocho en el sitio de la decisión y cuatro más en las relecturas del uploader, que van
por su helper— y `merkleLocalReadFailed(stage:)`. Las CINCO funciones que se tragaban el error —los tres `liveOutboxRows`,
`collectLeaves` y `danglingOverrides`— lo dejaban en un `print` bajo `#if DEBUG`, o sea en nada.

**Verificación.** 12 tests nuevos en 5 suites, y **13 mutantes medidos UNO A UNO**, no en tanda: cada uno
se aplica solo, se corre y se restaura desde una copia del scratchpad. Esa es la diferencia entre medir y
creerlo — la primera tanda los agrupó y **ocultó un defecto real** (ver abajo).

**Lo que la review adversarial cazó, y casi todo era mío.** Cuatro lentes independientes:

1. **El `catch` de `collectLeaves` no lo ejecutaba ningún test.** `computeLocalMerkle` llama a
   `danglingOverrides` ANTES que a cualquier `collectLeaves`, y les puse **el mismo `Bool`**: el primero
   cortaba siempre y el segundo quedaba intestable. Un mutante que le devolviera `return []` —la avería
   titular del ticket— habría pasado en verde. El argumento ya estaba escrito por mí en el otro seam («con un
   `Bool` la segunda es inalcanzable»); lo apliqué en el executor y lo olvidé aquí. **Y mi propia tanda de
   mutantes lo tapó**, porque muté los dos `catch` a la vez. Arreglado con dos seams; medido aislado, el
   mutante de `collectLeaves` ahora mata dos tests por su cuenta.
2. **Borré 737 caracteres de la SSOT de cobertura.** El `lastVerified` de `cloud-sync-runtime` no era una
   fecha: llevaba dentro la nota entera de `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data`. Mi
   script lo sobrescribió con `"2026-09-22"`. Restaurado, y verificado con un diff programático de que ninguna
   de las tres áreas perdió su cola histórica.
3. **Corregí el docblock de `migrationVerifyUnknownReason` y dejé mintiendo la línea que sí viaja a la flota**
   (`logger.notice(… networkTimeout conservador)`), que es el mismo defecto que el docblock denunciaba, una
   línea más abajo.
4. **`allReasonsAreListed` prometía cazar un motivo olvidado en `all` y no podía**: comparaba contra una lista
   escrita a mano en el test, así que un décimo `static let` olvidado pasaba verde. Ahora es un source-scan del
   fichero, con control positivo del propio escáner.
5. Cuatro aserciones que no podían fallar por separado (fuera), un matcher de error que no distinguía cinco
   ramas, dos tests sin control positivo, y un `try? ?? []` **haciendo de control de escenario** dentro de
   `CloudSyncRuntimeTests` — el antipatrón de este ticket, dentro del test.

**Y un control positivo mío falló al correrlo, que es exactamente para lo que está.** Afirmé que la pasada sana
llegaba al pull; es falso, con filas vivas `verify()` sale por `.newDeltaDetected` sin tocarlo. Premisa mía,
no código.

Detalle de método: los seams (`_testOutboxFetchThrowsFromCall`, `_testThrowOnLeafFetch`) van **dentro** del `do`,
no antes. Puestos fuera evitaban el `catch` real, y un mutante que reintrodujera `return []` ahí habría seguido
en verde — el test habría medido el seam en vez del código.

## QA de dispositivo

Nada que ver en pantalla: el cambio es cómo se lee una avería de la base local, y provocarla a mano en el
simulador no tiene guion razonable. Lo que sí es observable —el techo corto de la vuelta a iCloud ante un
`localFailure`— ya lo cubre la QA de `reverse-verify-network-bucket-hides-a-definitive-server-no`.

## Relacionado

- `reverse-verify-network-bucket-hides-a-definitive-server-no` — el que le dio consecuencia a la asimetría.
- `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last` — el hermano, por el lado del techo.
