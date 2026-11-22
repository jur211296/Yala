---
id: 2026-11-21-nube-congelamiento-yala-ios-a
status: done
priority: high
area: "cloud-sync"
created: 2026-11-21
updated: 2026-11-21
source: "Sentry YALA-IOS-A, YALA-IOS-13, YALA-IOS-14/15/16 (2.3 (5), iPhone personal); decisión 145 de la auditoría de decisiones contra 2.3"
---

# Tras guardar con la nube activa, la app ya no se recalcula dos veces (resto de YALA-IOS-A)

## Qué se midió antes de tocar nada

- **Sentry (21-nov, 22:00 Lima).** YALA-IOS-A y YALA-IOS-13 figuran resueltos, sin eventos desde el 20-nov 06:45 Lima. La
  parte de YALA-IOS-13 (pase de refs colgadas) ya estaba arreglada en 2.3. Pero en la MISMA apertura del último evento de A
  (2.3 (5), iPhone personal, `app_start_time` 10:45 UTC) saltaron YALA-IOS-14, 15 y 16, esta vez con pila propia, 1-3 s
  después de `push → /sync/pull`: el recálculo del Panel (`calculateTrendData`), la proyección del Flujo de caja
  (`FlujoProyeccionInteligente.detectar`) y la foto de los widgets (`WidgetDataCache.buildCashFlowByDay`). YALA-IOS-17 es el
  cuelgue de prueba de Sentry (build dev), no cuenta.
- **El código.** El servidor devuelve en el pull lo que el teléfono acaba de subir (`server_seq > since`, sin filtro de
  origen). El apply lo reescribe (idéntico) y lo cuenta como página aplicada; el runtime avisa
  (`fanOutRemoteChangesApplied`) y, desde el 13-nov, `RemoteChangesFanOut` sube `dataVersion` en el acto: todas las
  pantallas montadas (Panel, Informes, widgets…) recalculaban otra vez. Pasaba en el primer ciclo tras CADA guardado.

## Qué se hizo

- `pullAndApplyOnce` escribe `CloudSyncEngine.lastPullChangedLocalData`: cuenta una fila nueva, una borrada, una parte
  aplicada cuyo HLC remoto difiere del que `SyncUnitClock` tenía (o sin reloj local), una cuarentena, una ref colgada
  resuelta o un reconciliador que guardó. El eco de lo propio —cada parte con el mismo HLC que dejó el drain— no cuenta.
  El eco se sigue aplicando igual: el camino de los datos no cambia.
- `CloudSyncRuntime.performCycle` avisa solo con `pagesApplied > 0` **y** ese testigo.
- Regla nueva en `.claude/rules/swiftdata-cloudkit.md` (al final).

## Medido (simulador iPhone 17 Pro, iOS 27.2, en la Max)

`YalaTests/NubeCongelamiento/MedicionGuardadoConNubeTests` (solo con `YALA_MEDIR_CONGELAMIENTO=1`): Panel cargado, nube
activa contra un servidor falso que devuelve lo subido, un guardado y el ciclo. Latido de 5 ms en el main actor.
«Antes» = el aviso sin el testigo (2.3).

| Historial | Escenario | Recálculos | Hilo principal bloqueado (total) | Bloqueo más largo |
|---|---|---|---|---|
| 2.500 | A · ciclo tras el recálculo (lo normal) | 2 → **1** | 1,19 s → **0,82 s** | 0,52 s → 0,49 s |
| 2.500 | B · ciclo a mitad del recálculo | 2 → **1** | 1,11 s → **0,71 s** | 0,41 s → 0,40 s |
| 20.000 | A · ciclo tras el recálculo | 2 → **1** | 7,19 s → **3,92 s** | 2,90 s → 2,90 s |
| 20.000 | B · ciclo a mitad del recálculo | 2 → 2 | 6,88 s → 6,90 s | 2,9 s |
| 20.000 | C · ciclo VACÍO a mitad de un recálculo | 2 → 2 | 6,61 s → 6,57 s | 2,9 s |

## Qué NO cumple, y por qué

- **El bloque de más de 250 ms que queda es el propio recálculo del Panel tras guardar**, que existe con nube y sin ella:
  ~0,4 s con 2.500 movimientos y ~2,9 s con 20.000 en el simulador (`performCalculation`: tendencia, categorías, saldo de
  inicio del período, flujo de caja). Es la card «El recálculo entero del Panel sigue siendo un bloque de ~2,6 s con un
  historial grande».
- **Con historiales grandes (escenarios B y C), un ciclo de la nube que coincide con el hero por tramos lo corta y recarga
  el Panel entero**: `calculateHeroWidget` mira `StoreRemoteChangeCounter`, y cualquier guardado —también un ciclo vacío—
  publica `NSPersistentStoreRemoteChange`. Medido con una sonda: la petición del segundo recálculo sale de
  `calculateHeroWidget`. Card nueva; es lógica de seguridad contra leer un `@Model` borrado (card f8rj) y no se toca de
  noche sin el iPhone.
- **El ciclo en sí bloquea ~0,12 s (2.500) y ~0,49 s (20.000)** al aplicar el eco: no se midió qué parte domina.

## Tests

- `YalaTests/NubeCongelamiento/EcoDelGuardadoTests` (11): con el ciclo real y un servidor falso que devuelve lo subido como
  el gateway. Rojo sin el arreglo (el eco avisaba y `dataVersion` subía dos veces por guardado). Mutantes: sin la condición
  del aviso caen 5; «todo es eco» tumba la edición de otro aparato; «el borrado no cuenta» tumba el borrado ajeno; «sin
  reloj local es eco» tumba la fila sin `SyncUnitClock` y la regla de `isOwnEcho`. Los tres últimos casos los pidió el
  revisor con la checklist (reloj ausente, reloj ilegible con el seam, regla de `isOwnEcho`).
- Suites vecinas en verde: `CloudSyncRuntimeTests`, `SyncApplyEngineTests`, `DanglerPassBatchLookupTests`,
  `ApplyPageBatchLookupTests`, `CloudSyncWiredEntitiesTests`, `SyncQuarantineDrainTests` y el resto del área: 109 suites,
  1.713 casos. XCUITest de lo tocado: 21 clases, 115 casos, 0 fallos.

## Encontrado y no tocado

- Insertar un movimiento en una cuenta con 20.000 cuesta ~0,27 s de hilo principal en el `setter` de `account` (lista
  inversa), medido con `sample` en la medición.
- El canal de Grupos (`GroupsSyncClient.pullUntilExhausted`) avisa con cualquier delta aplicado; si su pull devuelve lo que el
  teléfono subió, tendría el mismo eco (inferido, sin medir).
