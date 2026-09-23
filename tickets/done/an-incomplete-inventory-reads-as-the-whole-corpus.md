---
id: an-incomplete-inventory-reads-as-the-whole-corpus
status: done
priority: high
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-23
source: "barrido del patrón durante `verify-reads-a-failed-local-fetch-as-an-empty-outbox` (2026-09-22)"
---

# Si al subir tus datos una tabla no se deja leer, la app da esa tabla por subida y sigue

## El problema, en lenguaje de usuario

Al pasar los datos a la nube —o al entrar en una cuenta que ya existe— la app recorre tus tablas y sube lo que
falta. Si una de esas lecturas falla, no lo dice ni lo reintenta: **cuenta esa tabla como si no tuviera nada**,
la da por subida y pasa a la siguiente. Los movimientos de esa tabla se quedan fuera de la nube, y como cada
paso es de una sola pasada, no vuelve a intentarlo nunca.

## Por qué pasa (medido el 2026-09-22 en este árbol)

Es la familia «un inventario incompleto se lee como el corpus entero». `verify-reads-a-failed-local-fetch-as-an-empty-outbox`
cerró el fetch de `SyncOutbox` en los tres sitios donde vivía; estos son sus vecinos, y los dejó fuera porque el
dato que leen es otro.

| Sitio | Qué devuelve el `catch` | Qué decide con eso |
|---|---|---|
| `MigrationSnapshotUploader.makeSpec:298` | `([], nil, false)` | `hasMore = false` ⇒ **el snapshot de esa entidad se da por subido** |
| `MigrationWorkExecutor.collectIdentityPairs:369` | `[]` | `CKIdentityCapture` sobre 0 pares; el breadcrumb reporta `captured: 0` como si no hubiera nada |
| `MigrationWorkExecutor.addPairs:475` | salta la entidad | mismo efecto, por entidad |
| `MigrationWorkExecutor.collectAdoptInventory:1536` | salta la entidad | ver abajo |
| `MigrationWorkExecutor.buildOrphanRowInputs:1579` | salta la entidad | las huérfanas de esa tabla no se suben |
| `MigrationWorkExecutor.addReverseUploadPairs:456` | salta la entidad | la muestra del techo de la vuelta cuenta MENOS filas vivas ⇒ «avance» falso |

El de `collectAdoptInventory` tiene dos daños distintos y conviene decirlos por separado:

1. **Desactiva el guard anti-fusión.** `:1307-1312` aborta con `.abortedEmptyBackend` si el backend está vacío y
   el plan tiene algo que subir; un inventario que se saltó filas puede dar `uploadCount == 0` y **apagar
   justo el guard que existe para no fusionar dos corpus**.
2. **Cierra el adopt en falso.** `:1324` hace `guard !plan.orphans.isEmpty else { return .completed(uploaded: 0) }`:
   sin huérfanas, el adopt se declara completo y **no vuelve a pasar por ahí**.

**Y un cuarto, que apaga un canario en vez de decidir mal** (lo cazó una lente de la review del 2026-09-22 y no
estaba en ningún ticket): `CloudSyncEngine.rehydrateOutboxFromMirror:2571-2580` sale con un `return` mudo si su
fetch lanza. No es «lee vacío», pero **silencia `cloudSyncOutboxMirrorDivergence`**, que por su propio docblock es
«el modo de fallo que ni el Merkle ve». Un fetch que falla apaga justo el canario que existe para verlo.

El de `addReverseUploadPairs` ya tiene ticket propio para su mitad
(`reverse-upload-sample-reads-unreadable-rows-as-drained`); se nombra aquí para que al arreglar la familia no se
haga dos veces ni se olvide.

## Qué habría que decidir antes de hacerlo

1. **¿Un inventario parcial corta o reintenta?** El snapshot tiene `.transient` y el adopt también; el
   `collectIdentityPairs` no tiene desenlace ninguno (su caller no puede fallar). Hay que elegir qué hace cada uno.
2. **¿Se unifica el helper?** Son seis funciones con la misma forma (`addX<M>` sobre 16 entidades, `catch` mudo).
   Un solo seam para las seis abarata el test, pero acopla seis caminos con desenlaces distintos.
3. `makeSpec` es el más grave y el más barato: su `false` es un `hasMore`, y cambiarlo a `true` con un desenlace
   de corte no toca a nadie más.

## Criterios de aceptación

- [x] Un `fetch` que lanza en el barrido del snapshot NO deja la entidad marcada como subida.
- [x] Un inventario incompleto del adopt no apaga el guard anti-fusión ni cierra el adopt con `uploaded: 0`.
- [x] Rastro en producción de la avería (hoy es un `print` de `#if DEBUG` en los seis).
- [x] Tests con el fetch lanzando + control positivo por cada desenlace tocado.

## Relacionado

- `verify-reads-a-failed-local-fetch-as-an-empty-outbox` — el mismo patrón sobre el fetch de `SyncOutbox`, cerrado.
- `reverse-upload-sample-reads-unreadable-rows-as-drained` — la mitad del muestreo de la vuelta.

## Nota del 2026-09-22 (`snapshot-upload-has-no-ceiling-and-no-way-out`)

La fila de `MigrationSnapshotUploader.makeSpec` tiene desde ese ticket un desenlace listo para usar:
`SnapshotStepOutcome.blocked(.localFailure)`, que elige el techo CORTO de la subida (15 min acumulados) y sale a la
tarjeta de fallo con el texto «este dispositivo no pudo preparar tus datos». Antes, cortar ahí habría dejado la barra
al 55 % para siempre; ahora cortar es seguro. Lo que sigue abierto es que el `catch` de `makeSpec` todavía no corta:
salta la tabla.

## Paso 0 (2026-09-23, cola A nocturna — decisiones auto-contestadas)

Medido en este árbol antes de decidir. Las coordenadas del ticket ya no casan (el fichero creció): se citan por nombre.

- **Premisa corregida.** «`collectIdentityPairs` no tiene desenlace (su caller no puede fallar)» es FALSA:
  `assignIdentity()` es `async throws` y `MigrationRunner.driveIdentity` ya convierte cualquier `throw` en
  `.localFailure` con el techo CORTO. Así que la decisión 1 del ticket se contesta sola para ese sitio.
- **D1 · ¿Corta o reintenta?** Cada sitio usa el desenlace que su camino YA tiene para «avería local», sin inventar
  vocabulario:
  - Snapshot (`makeSpec`): el paginador LANZA, `nextPage` LANZA, `uploadPage` → `.blocked(.localFailure)` (techo
    corto de 15 min y la tarjeta «este dispositivo no pudo preparar tus datos», lista desde
    `snapshot-upload-has-no-ceiling-and-no-way-out`). El cursor no avanza. Antes, con TODAS las tablas restantes
    ilegibles, `nextPage` devolvía `nil` y la pasada cerraba con `.completed`.
  - Identidad (`collectIdentityPairs` + `addPairs`): LANZAN → `assignIdentity` lanza → `.localFailure` del runner.
  - Adopt (`collectAdoptInventory` en el plan preliminar y en el definitivo, y `buildOrphanRowInputs`): LANZAN →
    `runAdoptOrphanReconcile` → `.transient`, que `runAdoptFlow` ya convierte en `adoptRetry` retomable. Es el mismo
    trato que la red en ese camino. El guard anti-fusión y el «sin huérfanas → completed» ya no ven un inventario
    parcial.
  - Vuelta (`addReverseUploadPairs`): caso NUEVO `ReverseUploadStatus.unreadable`. El runner no cierra la vuelta ni
    cuenta la observación como avance (una muestra parcial baja la cifra y reseteaba el reloj del techo); sigue
    esperando y, si la avería persiste, el techo que elija `reverseUploadBlocker` —el largo, salvo que CloudKit tenga un
    error vigente— la saca al origen en modo nube, con los datos a salvo en el backend. La pantalla conserva la cifra
    de la última observación buena, con el motivo de la actual.
- **D2 · ¿Un helper para los seis?** Para la LECTURA sí (`MigrationWorkExecutor.fetchInventory`: fetch, rastro y error
  propio); para el desenlace no, cada llamador conserva el suyo. El seam es de instancia y lanza un `CocoaError` dentro
  del `do` real: en el uploader un `Set<String>` de clases; en el ejecutor un closure `(paso, entidad)`, porque el adopt
  lee su inventario dos veces con el mismo paso y con un conjunto la segunda lectura era inalcanzable (corregido a mitad
  de implementación, al escribir su test).
- **D3 · Rastro.** Breadcrumb nuevo `CloudSyncBreadcrumb.migrationInventoryReadFailed(step:entity:)`, uno por sitio
  (`snapshot`, `identity-capture`, `adopt-inventory`, `adopt-orphan-inputs`, `reverse-sample`, `reverse-live-rows`).
- **D4 · Gemelos medidos en la familia.**
  - `collectLiveByEntityName`/`addLiveRows` (canario de metadata huérfana de la vuelta): con el fetch fallido dejaba
    la key con un `Set` vacío, así que TODA la metadata de esa entidad contaba como huérfana (canario inflado). Ahora
    omite la key (el contrato ya dice que una key ausente se ignora) y deja rastro.
  - `CloudSyncEngine.rehydrateOutboxFromMirror`: el `return` se queda (re-insertar sin saber qué hay duplicaría
    filas); se añade `outboxFetchFailed(step: "rehydrate-mirror")`, que es lo que faltaba. Reintento: el siguiente
    arranque.
- **Fuera, a ticket propio:** el `try?` del marcador en `runAdoptFlow` (una lectura fallida sale como «marker absent»)
  y el `rehydrateOutboxFromMirror` de Grupos, que tampoco deja rastro → `two-silent-local-reads-leave-a-false-or-no-trace`.
  Y la vuelta con la base ilegible espera el techo LARGO: no hay motivo «avería local» en su vocabulario, y dárselo es
  producto (texto de la salida) → `reverse-upload-unreadable-sample-waits-the-long-ceiling`.
- **Asumido:** `reverse-upload-sample-reads-unreadable-rows-as-drained` conserva su mitad de las filas `failed`, que
  pide medir en device; aquí solo se cierra el fetch que lanza.

## Resultado (2026-09-23)

**Para quien usa la app:** si al pasar tus datos a la nube, al entrar en una cuenta que ya existe o al volver a iCloud
el teléfono no consigue leer una de tus tablas, la app ya no la da por hecha: se para con el motivo «este dispositivo»
(la ida), lo reintenta (el adopt) o sigue esperando sin darse por terminada (la vuelta). Antes seguía como si esa tabla
estuviera vacía y cerraba el paso sin sus datos.

- Los seis inventarios del ticket, más el **backfill de identidades** que corre antes de dos de ellos
  (`SyncIdentityService.backfillIdentities`, gemelo que cazó la review: tragaba su error y el adopt podía cerrarse con
  las filas sin identidad contadas como `needsIdentity`, no como huérfanas).
- Rastro en producción: `migrationInventoryReadFailed(step:entity:)`, `migrationIdentityBackfillFailed(errorType:)` y
  `outboxFetchFailed(step: "rehydrate-mirror")`. Ningún test los fija: el `Logger` no tiene sink.
- Mutantes: 19 en la primera tanda y 6 en la segunda (backfill, motivo de la pantalla, mínimo inventado, dry-run).
- Review de tres lentes. Sin defectos altos en el fix. Corregido por ella: el backfill (arriba), el motivo congelado de
  la pantalla en la muestra ilegible, la primera observación ilegible sin test, y nueve docblocks o frases que decían de
  más («no toca el reloj», «no llegaban nunca», la key «SIEMPRE» presente…).
- Tickets nuevos: `adopt-effect-retries-forever-with-no-ceiling` (el adopt, por red o ahora por avería local, se
  reintenta sin techo ni tarjeta), `reverse-upload-unreadable-sample-waits-the-long-ceiling` (plazo y texto de la vuelta
  con la base ilegible: producto) y `two-silent-local-reads-leave-a-false-or-no-trace` (cinco lecturas que solo fallan
  en el rastro).
- Sin device-QA: una base local ilegible no se provoca en un iPhone.
