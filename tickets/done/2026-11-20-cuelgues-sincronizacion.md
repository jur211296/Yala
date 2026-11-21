---
id: 2026-11-20-cuelgues-sincronizacion
status: done
priority: high
area: "cloud-sync"
created: 2026-11-20
updated: 2026-11-20
source: "Sentry YALA-IOS-13 y YALA-IOS-A en 2.3 (4) y 2.3 (5), TestFlight"
---

# La app se congela al aplicar cambios de la nube (YALA-IOS-13) y unos segundos tras guardar (YALA-IOS-A)

## Qué se midió

- **YALA-IOS-13** (iPhone 14, 19-nov 21:47 Lima, 2.3 (4)): App Hang Fully Blocked en mitad de la primera bajada tras
  «Activar la nube» (`/account/claim` y 15 `GET /sync/pull` seguidos). Pila: `CloudSyncRuntime.performCycle →
  pullAndApplyOnce → reresolveDanglingRefs → reresolveDangler → findTransactionItem → fetchFirstOrThrow`. No es el apply
  de página (arreglado el 13-nov, YALA-IOS-J): es el **pase final de refs colgadas**, que buscaba dos filas sueltas por
  dangler, sin índice, en el hilo principal. El estado del teléfono no se pudo leer: el store del iPhone 14 ya se había
  vaciado (0 movimientos al copiarlo el 20-nov).
- **YALA-IOS-A** (iPhone personal, 19-nov 10:25 y 10:35, 20-nov 06:45 Lima; 2.3 (4) y 2.3 (5)): App Hang **Non Fully
  Blocked**, pila del hilo principal ya libre (`YalaApp.$main`, sin código propio). Los tres eventos caen 2-5 s después
  de un `POST /sync/push` seguido de `/sync/pull`, `/prefs/pull` y `/groups/pull`: el ciclo de la nube que dispara
  guardar un movimiento, con la pestaña de Informes delante. Sin dSYM útil ni pila propia, la causa se acota por la
  línea de tiempo, no se prueba.

## Qué se hizo

- `EntityApplyMap.prepareDanglerLookups`: el pase lee por lote antes del bucle (filas origen por `IN`, destinos de tablas
  grandes por `IN`, cuentas, categorías y subcategorías enteras), con la misma caché `ApplyPageLookups` de la página.
  `loadRows` sale de `prepareLookups` para que las dos lean igual.
- `DanglerRelationshipBatch`: las refs de movimientos (categoría, subcategoría, cuenta) se asignan en bloque desde la
  lista inversa. Medido: asignar una a una cuesta ~3 ms cuando la categoría tiene 3.200 movimientos; con la caché sola el
  pase seguía en 1 s.
- Medición (simulador, 800 danglers sobre 4.000 movimientos): **3,47 s → 1,06 s (lote) → 0,23 s (lote + bloque)**.
- Tests: `YalaTests/CuelguesSincronizacion/DanglerPassBatchLookupTests` (rojo sin el arreglo: 600 búsquedas sueltas y
  3,47 s; mutante sin el bloque: rojo). Suites vecinas del apply en verde.
- Regla: corolario en `swiftdata-cloudkit.md`, regla «El apply de una página busca por LOTE».

## Qué quedó fuera (card aparte)

YALA-IOS-A puede tener más de una pieza. El pase de danglers corre en cada ciclo, también tras guardar, así que su
arreglo alcanza a ese ciclo; pero el ciclo hace más en el hilo principal: el servidor devuelve en el pull lo que el
propio teléfono acaba de subir (`gateway/src/sync/routes.ts`, `server_seq=gt.since`, sin filtro de origen), el motor lo
vuelve a aplicar entero y, con una página aplicada, avisa a toda la app (`fanOutRemoteChangesApplied` →
`dataVersion`), que recalcula todas las pantallas por segunda vez. Y luego corre el ciclo de Grupos. Medir y decidir eso
va en la card «Tras guardar con la nube activa, la app se recalcula dos veces».
