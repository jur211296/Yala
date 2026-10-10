---
id: apple-id-change-boot-check-is-lost-when-the-journal-is-unreadable-at-launch
status: backlog
priority: low
area: "sesiones, modo-nube"
created: 2026-09-27
updated: 2026-10-08
source: "review adversarial de `apple-id-change-boot-check-runs-before-the-migration-guard-can-see` (2026-09-26), lentes de orden y de falso bloqueo"
---

# Si el arranque no puede leer el estado de la migración, el cambio de Apple ID espera al arranque siguiente

## El problema, en lenguaje de usuario

En un arranque en el que Yala no puede leer todavía en qué punto está el paso de los datos a la nube (por ejemplo, un
arranque en segundo plano con el teléfono bloqueado), la comprobación del cambio de Apple ID no ofrece nada, y no lo
vuelve a intentar al abrir la app. El aviso llega en el siguiente arranque en frío.

## Por qué pasa (medido el 2026-09-26; el prewarm, inferido)

- El journal ilegible da `.journalUnreadable` y `migrationAtRest` no concede, a propósito.
- El disparo de arranque es uno por proceso y `checkForAppleIDChange` no cuelga de `handleBecameActive` (criterio del
  ticket `apple-id-change-should-close-the-private-session`: sin ida a CloudKit en cada primer plano).
- `CloudMigrationController.rekickIfParked` repinta la pantalla cuando el journal vuelve a leerse, pero no reintenta
  esta comprobación.

## Criterios de aceptación

- [ ] Si el disparo de arranque salió por el guard de migración, un primer plano posterior lo reintenta UNA vez, sin
  convertirlo en una ida a CloudKit por cada primer plano. Test del reintento y de que no se repite.

## Medido en 2.1 (triage 2026-10-08)

- `AppBootstrapper.checkForAppleIDChange` sigue saliendo por `guard migrationAtRestForAppleIDChange()` sin apuntar nada para reintentar; su doc comment lo lista como residual (3) y cita este ticket.
- Los únicos disparos siguen siendo `boot` y `identity-notification`; ninguno cuelga de `handleBecameActive`.

Triage 2026-10-08: abierto · low → low · sigue sin reintento tras un arranque con el journal ilegible, y el código lo documenta como residual; solo retrasa el aviso un arranque.
