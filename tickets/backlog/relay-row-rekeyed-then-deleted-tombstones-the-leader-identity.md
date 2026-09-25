---
id: relay-row-rekeyed-then-deleted-tombstones-the-leader-identity
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `displaced-leader-late-identity-export-can-rekey-the-relief-corpus` (2026-09-24), lentes del duplicado y de los consumidores"
---

# Un movimiento que iCloud re-identificó y luego se borra vuelve a aparecer tras activar la nube

## El problema, en lenguaje de usuario

Activas la nube en el segundo teléfono mientras el primero, sin red, se queda atrás. El primero vuelve y manda a iCloud
sus datos viejos. Si justo entonces borras uno de esos movimientos en el segundo, el borrado no llega a la nube: el
movimiento reaparece en tus otros teléfonos, y la activación puede fallar y tener que repetirse.

## Lo medido y lo inferido (2026-09-24)

- **Medido en código**: `MigrationWorkExecutor.restoreRelayIdentities` devuelve su identidad a las filas VIVAS que el
  espejo re-identificó. Una fila borrada antes de la siguiente restauración ya no está: el drain emite el tombstone con
  la identidad guardada al borrar (`tombstone[\.syncID]`, `.preserveValueOnDeletion`), que es la del líder y el backend
  no conoce. La del relevo sigue viva en el backend.
- **Inferido**: el Merkle de la verificación diverge en cada pasada (local sin la fila, backend con ella) hasta agotar los
  reintentos de MISMATCH y salir a `failedRollback`; el reintento pasa y la fila vuelve con el pull, la misma
  resurrección que `row-deleted-during-the-relief-wait-comes-back-after-the-relief`. Tras el cutover (espejo vivo hasta
  el relanzamiento) solo resucita.
- **Idea sin medir**: traducir ese tombstone por el record del objeto borrado (los metadatos del espejo lo conservan hasta
  exportar el borrado) a la identidad del testigo huérfano. Depende de un tiempo que nadie ha medido.
- Ventanas: el hueco entre pasadas del runner, y sobre todo del cutover al relanzamiento, que puede durar horas.

## Criterios de aceptación

- [ ] Decidido si merece la pena: el daño es un borrado que hay que repetir y, a veces, una activación que se reintenta.
