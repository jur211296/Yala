---
id: follower-waits-forever-on-a-lease-with-a-null-heartbeat
status: backlog
priority: very-low
area: "modo-nube, migración, backend"
created: 2026-09-23
source: "review adversarial de `adopt-follower-waits-for-the-leader-with-no-ceiling` (2026-09-23), lente de relojes"
---

# Un teléfono que espera a otro puede esperar para siempre si la reserva del servidor no tiene latido

## El problema, en lenguaje de usuario

Esperando a que otro teléfono termine de activar la nube, la espera no llega nunca a su plazo de 72 h. Solo sale con
«Dejar de esperar».

## Por qué pasa (inferido el 2026-09-23; no medido en producción)

Desde `adopt-follower-waits-for-the-leader-with-no-ceiling`, cada `claiming_in_progress` borra los relojes del seguidor
(`MigrationRunner.noteLeaderAlive`): prueba que el líder latió en la última hora. El SQL de `claim_account`
(`qa/cloud/g15_01_account_kind.sql`, comentario junto a la comprobación de los 60 min) avisa de que una fila con
`migration_in_progress` y el latido `NULL` no caduca nunca. Con una fila así el servidor contesta `claiming_in_progress`
siempre. Hoy el INSERT y la promoción rellenan los dos campos, así que haría falta una fila escrita por otro camino.

## Qué habría que hacer

1. Medir en producción si existe alguna fila con `migration_in_progress = true` y el latido `NULL`.
2. Si existe, decidir si el servidor la trata como caducada.

## Criterios de aceptación

- [ ] La consulta está hecha y el resultado escrito aquí.
