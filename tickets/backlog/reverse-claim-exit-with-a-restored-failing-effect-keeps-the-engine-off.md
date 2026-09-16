---
id: reverse-claim-exit-with-a-restored-failing-effect-keeps-the-engine-off
status: backlog
priority: low
area: "modo-nube, sync, migración"
created: 2026-09-16
source: "segunda pasada de review adversarial de `reverse-claim-rejection-has-no-way-out-in-the-client` (2026-09-16), lente de reposición de pendientes — hallazgo 1, aceptado como residual"
---

# Tras un «Volver a iCloud» que el servidor no concede, un teléfono con la migración a medias puede quedarse sin sincronizar hasta reabrir Yala

## El problema, en lenguaje de usuario

Toco «Volver a iCloud» con mala conexión y cierro Yala. Al abrirla, la app me dice que no pudo empezar la vuelta y que lo
intente en un rato. Sigo en la nube, pero lo que anoto no sube hasta que cierro Yala del todo y la vuelvo a abrir.

## Por qué pasa (medido en el código el 2026-09-16)

Solo le pasa a un teléfono que ya tenía un paso de migración pendiente que falla siempre. El caso conocido es un líder
desplazado: otro dispositivo le tomó el lease de la migración y su `complete` responde `other_leader` en cada intento.

1. Antes del toque, ese teléfono está en `done` con `.runLeaderReconcileFromFrozenCloudKit` pendiente. En el arranque, el
   paso 14.7 arranca el motor igual, porque `CloudSyncRuntime.canRunDomain` solo mira la fase.
2. Toca «Volver a iCloud» y el claim falla por red: la fase queda en `reverseClaimLeader`.
3. Cierra y abre Yala. El 14.7 ve una fase no estable y deja el motor en `.idle`.
4. El resume recibe un rechazo y vuelve a `done`. Desde `reverse-claim-rejection-has-no-way-out-in-the-client` la salida
   repone el pendiente que la vuelta había reemplazado, y ese pendiente vuelve a fallar.
5. `CloudMigrationController.startRuntimeIfStable` no arranca el motor con pendientes, a propósito: no arrancar sobre una
   migración a medias. `handleBecameActive` no lo saca de `.idle`. Hasta el siguiente arranque en frío no sincroniza.

## Por qué se aceptó así

- Lo repuesto es exactamente lo que el teléfono tenía antes del toque. No se añade ningún efecto nuevo.
- No reponerlo era peor, y no solo para este teléfono. El reconcile es lo único que manda `complete`, y sin él
  `migration_in_progress` se quedaba puesto en el backend para toda la cuenta, con otro dispositivo esperando al líder sin
  fin.
- Reponer solo cuando el servidor dice `migration_in_progress` reduce la población, pero ata la regla del cliente a los
  motivos del RPC y deja sin reponer un `.adoptBackendAccount` pendiente.

## Qué hay debajo

Dos gates arrancan el motor con criterios distintos: el 14.7 solo mira la fase y el controlador exige además cero
pendientes. Este ticket es la primera vez que la diferencia se nota justo después de un aviso.

## Criterios de aceptación

- [ ] Decidido qué gate manda para arrancar el motor con efectos de migración pendientes, y que los dos contesten lo mismo.
- [ ] Tras la salida del claim con un pendiente repuesto que falla, el motor está en el estado que ese criterio diga, sin
      depender de si hubo un arranque en frío en medio.

## Relacionado

- `reverse-claim-rejection-has-no-way-out-in-the-client` (D13) · `reverse-abort-rejected-leaves-a-frozen-cloud-saying-up-to-date`
  (la pantalla dice «Todo al día» en ese mismo estado) · `cloud-engine-can-start-with-a-reverse-abort-pending` (el caso
  contrario: el motor arranca con un pendiente que no debería).
