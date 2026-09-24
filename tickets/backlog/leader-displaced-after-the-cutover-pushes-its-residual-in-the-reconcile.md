---
id: leader-displaced-after-the-cutover-pushes-its-residual-in-the-reconcile
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `displaced-migration-leader-keeps-uploading-after-a-takeover` (2026-09-24), lente de bypass"
---

# El teléfono que pierde el relevo DESPUÉS del cutover sigue subiendo lo que escribe

## El problema, en lenguaje de usuario

Activo la nube en el teléfono A, que llega casi al final y se queda esperando a que reabra Yala. Tardo más de una hora. Otro
teléfono B entra en la cuenta y toma el relevo. Cuando reabro A, sube lo que escribí mientras tanto encima de lo que B está
subiendo, y lo vuelve a intentar cada vez que abro la app.

## Lo medido (2026-09-24, leyendo el código; sin ejecutar)

- `displaced-migration-leader-keeps-uploading-after-a-takeover` cerró la subida y la verificación: una puerta del lease antes
  de cada página. No cubre lo que va detrás del `cutover(.serverConfirmed)`.
- En `cutover(.markerWritten)` y `.mirrorOff` el runner no late (`MigrationRunner.swift`, `driveCutover`), así que el lease
  puede caducar esperando al marcador o al relanzamiento asistido.
- La copia de staging de `claim_account` (`qa/cloud/g15_01_account_kind.sql`, la rama del relevo) mira
  `migration_in_progress`, el líder y la edad del lease; NO mira `migrated_at`. Medido en el SQL del repo, no en producción.
- En `done`, `.runLeaderReconcileFromFrozenCloudKit` hace `drainOnce` y empuja el residual del outbox
  (`MigrationWorkExecutor.swift`, `runLeaderReconcileFromFrozenCloudKit`) ANTES del `complete`, que es lo único que contesta
  `other_leader`. El efecto lanza y se reintenta en cada arranque.
- Previo a ese ticket: no lo abre, pero tampoco lo cierra.

## Candidatas (sin medir)

- Servidor: que `claim_account` no dé el relevo sobre una cuenta con `migrated_at` puesto (el líder ya pasó el cutover y el
  modo local ya es `.cloud`: el relevo no tiene sentido ahí). Hay que medir el cuerpo vivo de producción primero.
- Cliente: la misma puerta del lease delante del push del reconcile.
- Latir en `markerWritten`/`mirrorOff` mientras se espera.

## Criterios de aceptación

- [ ] Un teléfono que perdió el lease después del cutover no sube nada a la cuenta.
- [ ] Sale o se recupera con un texto que diga lo que pasó.
