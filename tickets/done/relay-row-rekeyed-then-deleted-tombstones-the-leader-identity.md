---
id: relay-row-rekeyed-then-deleted-tombstones-the-leader-identity
status: done
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-25
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

- [x] Decidido si merece la pena: sí (decisión de Frank, noche del 2026-09-25): un borrado no debe reaparecer ni tumbar la
      activación.
- [x] El borrado de una fila re-identificada en la ventana del relevo sube con la identidad que el backend conoce, en la
      verificación, en el drain del cutover y en el reconcile de `done` tras el relanzamiento.
- [x] Canario de contrato en rojo → verde: sin el arreglo caen 9 casos.

## Resolución (2026-09-25)

**Para el usuario:** si borras un movimiento justo mientras la nube se está activando y otro teléfono acaba de mandar a
iCloud sus datos viejos, el borrado llega a la nube: el movimiento ya no reaparece en tus otros teléfonos, y la
verificación de la activación no se queda comparando algo que no cuadra.

**Qué se hizo:**
- La idea del ticket (leer el record del objeto borrado en los metadatos del espejo) se descartó: depende de que el drain
  llegue antes de que el espejo exporte el borrado, segundos con red. El vínculo que no caduca es la fila por su `Z_PK`
  (el cambio de identidad es un update del mismo objeto), con el identificador del store.
- `RelayIdentityLedger`: registro JSON `store/entidad/Z_PK → syncID`, sembrado por `assignIdentity` para los seis tipos
  acuñados, fusionando. Lo leen los dos motores (el de la migración y el del runtime).
- El drain emite el tombstone de la identidad preservada Y, si el registro dice que la fila tuvo otra (sin testigo la
  preservada; con testigo, de su tipo y con coordenadas la del registro; ninguna fila viva la lleva), también el de esa.
  Las dos porque desde un teléfono no se sabe cuál conoce el backend (en el líder desplazado es al revés), y `apply_delta`
  guarda como borrada una identidad desconocida (medido en producción).
- Leer el testigo o la fila que lo decide y fallar aborta la vuelta entera del drain (`false`), no solo su transacción.
- El registro se retira por marca (el cierre del reconcile de `done`), no por fase; sin marca si esa restauración toleró
  metadatos ilegibles; el `.rollback` lo borra. Canario `cloudRelayTombstoneTranslated`.

**Verificación:** 13 casos nuevos en `MigrationWorkExecutorTests`, 19 mutantes muertos, review adversarial con tres
lentes (pérdida de datos, ciclo de vida, tests) que cazó cinco cosas y cambió el diseño (de traducir a emitir las dos;
abortar el drain; retirar por marca; store en la clave). Gate: Yala y Yala Dev sin warnings nuevos, 7887 unit en 754
suites. Sin device-QA: el daño queda cubierto por el contrato unitario; qué valor gana CloudKit sigue sin medirse sin dos
teléfonos, como en #243.

**Tickets nuevos:** `displaced-leader-after-the-cutover-restores-its-own-identity-over-the-relays` (medium) y
`relay-identity-ledger-missing-after-an-update-mid-migration` (low).
