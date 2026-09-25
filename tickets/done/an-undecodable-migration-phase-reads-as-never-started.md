---
id: an-undecodable-migration-phase-reads-as-never-started
status: done
priority: medium
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-25
source: "residual de `an-unreadable-migration-journal-reads-as-never-started` (2026-09-22)"
---

# Si la fase guardada de la migración no se entiende, la app sigue creyendo que nunca empezó

## El problema, en lenguaje de usuario

La app apunta en qué paso va el cambio de tus datos a la nube. Desde el 2026-09-22, si esa anotación **no se deja leer**,
la app lo dice y no hace nada con ella. Pero hay un segundo caso que sigue igual: la anotación **se lee**, pero lo que pone
no se entiende (por ejemplo, la escribió una versión más nueva de Yala y el teléfono volvió a una más vieja). Ahí la app
sigue concluyendo que el cambio **nunca empezó**, con los mismos permisos que antes del arreglo.

## Por qué pasa (medido el 2026-09-22 en la rama del ticket padre)

`MigrationState.readPhase()` devuelve `(.notStarted, decodeFailed: true)` cuando `phaseData` existe y no decodifica. Los dos
lectores —`MigrationPhaseStore.phaseRead(fetch:)` y `MigrationJournalRead.read(fetch:)` del controller— toman esa fase
tal cual. El primero deja un breadcrumb ruidoso (`migrationPhaseDecodeFailed`); el segundo, ni eso.

`notStarted` es fase ESTABLE, así que es el mismo desenlace que el ticket padre cerró para el `fetch` que lanza, por otro
camino.

## Por qué quedó fuera

El ticket padre era el `catch` del `fetch`. Este camino tiene una red que el otro no tenía: `MigrationStateJournalTests`
congela un fixture JSON por cada case del enum (APPEND-ONLY), así que renombrar o borrar un case rompe el test antes de
publicar. Lo que no cubre es el DOWNGRADE: un build con un case nuevo escribe un blob que un build anterior no entiende.

## Qué habría que decidir

1. ¿`decodeFailed` es `.unreadable`? Probablemente sí en los dos lectores, y el tipo ya existe (`JournaledPhaseRead`).
2. El runner también usa `readPhase()`: ver qué hace él con `decodeFailed` antes de cambiar solo los lectores.
3. Efectos pendientes que no decodifican (`readPendingEffects` devuelve `[]`): la misma pregunta, un nivel más abajo.

## Criterios de aceptación

- [x] Un `phaseData` presente que no decodifica no se presenta como `notStarted` en ninguno de los dos lectores.
  `MigrationPhaseStore.phaseRead` y `MigrationJournalRead.read` devuelven `.unreadable`
  (`MigrationJournalUndecodableTests`, los dos con su control).
- [x] Test con un blob que no decodifica + control positivo. Blobs con la forma real de un downgrade (JSON válido con un
  case que este build no conoce), para la fase, los pendientes y los pendientes del origen; y en el runner, seis entradas ×
  cinco campos con el control legible por entrada y un pendiente conocido sembrado (`MigrationRunnerTests` §17).

## Resolución (2026-09-25)

**En lenguaje de usuario:** si una versión anterior de Yala se encuentra el paso de la nube anotado de una forma que no
entiende, ya no concluye que el cambio nunca empezó: no mueve nada, deja la anotación como estaba y lo dice en
Almacenamiento. Al actualizar Yala, la versión que la escribió sigue donde lo dejó.

**Lo que se midió antes de decidir:** el runner no solo leía `notStarted`. En cada entrada **reseteaba la fila** a
`notStarted` sin pendientes (la «normalización» M1), así que arreglar solo los lectores habría sido cosmético: el primer
`resume()` del arranque dejaba la fila en `notStarted` de verdad, y borraba de paso una migración o una vuelta en vuelo
con sus pendientes (`.persistICloudMode`, `.reverseRollback`).

**Qué cambió:**
1. Un solo testigo, `MigrationState.isJournalUndecodable`: fase, pendientes o pendientes del origen presentes que no
   decodifican, y los dos raw cuyo relleno concede con un valor desconocido (`forwardClaimIntentRaw` → `.adoptIfExisting`,
   `reverseOriginRaw` → `.done`; su `nil` sigue siendo legítimo). Los dos raw los añadió la review.
2. Los dos lectores devuelven `.unreadable` con él. Los consumidores ya sabían qué hacer con esa lectura (ticket padre).
3. El runner para en `runGuarded`, antes de cualquier entrada, y no escribe la fila. La normalización se retira.
4. El rastro `migrationPhaseDecodeFailed` («fallback notStarted», ya falso) pasa a `migrationJournalUndecodable(reader:)`.

**Tests que fijaban el reset como contrato:** tres en `MigrationRunnerTests` exigían la fila normalizada; ahora exigen la
fila intacta.

**Verificación:** 9 mutantes (los dos lectores, la parada del runner, cada término del testigo, `nil` como desconocido
y el reset de vuelta), todos muertos. Review adversarial de tres lentes sin hallazgos altos; cazó los dos raw y que la
columna de la fase de la matriz pasaba sola sin un pendiente sembrado. Los dos, arreglados aquí.

**Queda fuera, con ticket:**
- La tarjeta dice «cierra y vuelve a abrir», y en un downgrade lo que cura es actualizar
  (`journal-unreadable-card-says-reopen-when-a-downgrade-needs-an-update`, low).
- El push del cierre de sesión sincroniza sin pasar por el candado de fase (`sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate`, medium).
- Un `storageMode` desconocido se lee `.icloud` (`storage-mode-unknown-raw-reads-as-icloud`, low).
- El adopt de la bienvenida no comprueba el journal ilegible (`adopt-with-existing-session-skips-the-unreadable-journal-guard`, low).
- Con el journal ilegible, en `.icloud` se suspenden los BGTasks (widget en segundo plano) y el remap hasta actualizar:
  se pierde frescura, no datos. Asumido, sin ticket.

**Device-QA:** no hace falta. El caso se monta en unit con la fila real (SwiftData on-disk en el runner) y la pantalla
`.journalUnreadable` ya la cubre `StorageJournalUnreadableUITests`.
