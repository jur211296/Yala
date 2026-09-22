---
id: verify-reads-a-failed-local-fetch-as-an-empty-outbox
status: backlog
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

## Qué habría que decidir antes de hacerlo

1. **¿Quién manda?** Si el outbox no se puede leer, lo honesto es no decidir nada con él: ni «vacío» ni «lleno».
2. **¿El `verify()` corta antes?** Un fetch que lanza podría cortar la pasada entera con un desenlace propio, en vez
   de dejar que cada paso improvise.
3. **`collectLeaves`** es aparte y tiene su propio daño (divergencia falsa). Puede ir en este ticket o en otro.

## Criterios de aceptación

- [ ] Un `fetch` de `SyncOutbox` que lanza NO se lee como «outbox vacío» en el pre-check del push.
- [ ] El desenlace de ese fallo es UNO, no dos lecturas contradictorias en la misma pasada.
- [ ] Test que haga lanzar el fetch y mida las dos mitades.

## Relacionado

- `reverse-verify-network-bucket-hides-a-definitive-server-no` — el que le dio consecuencia a la asimetría.
- `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last` — el hermano, por el lado del techo.
