---
id: displaced-migration-leader-keeps-uploading-after-a-takeover
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `migration-takeover-uploads-without-a-lineage-check` (2026-09-24), lente de bypass"
---

# El teléfono que perdió el relevo de una activación vuelve y sigue subiendo sus datos a la cuenta

## El problema, en lenguaje de usuario

Empiezo a activar la nube en el teléfono A y se queda sin conexión más de una hora. Mientras tanto, otro teléfono B entra en
la misma cuenta y termina la activación él. Cuando A recupera la red, sigue subiendo sus datos donde se quedó, encima de
los de B. Si A y B no tenían los mismos datos, la cuenta acaba con una mezcla. A solo se para al final, cuando el servidor
le dice que otro dispositivo tomó el relevo, y para entonces lo suyo ya subió.

## Lo medido (2026-09-24, leído en el código por la review, sin ejecutar)

- La comprobación de linaje de `migration-takeover-uploads-without-a-lineage-check` protege a quien TOMA el relevo (B), en
  la identidad. A no vuelve a pasar por la identidad: su journal sigue en `uploadingSnapshot`.
- `MigrationRunner.driveUpload` no mira el lease. El heartbeat que recibe `other_leader`
  (`MigrationWorkExecutor.sendLeaseHeartbeatIfDue`) solo deja un rastro.
- `/sync/push` (`gateway/src/sync/routes.ts`) solo comprueba `reverse_frozen_at`, no quién lidera la migración.
- A solo sale en `cutover(.pending)` con `ForwardStepBlocker.otherDevice`. B, en su `verify()`, hace un pull y mete las filas
  de A en su store; el Merkle cuadra y B puede terminar con los dos corpus mezclados.
- Existía antes de ese ticket: no lo abre, pero tampoco lo cierra.

## Candidatas (sin medir)

- Que el `other_leader` del heartbeat corte la subida (definitivo), con un heartbeat SIN throttle al empezar cada pasada: un
  relevo exige 60 min de silencio, así que dentro de una pasada viva no puede ocurrir.
- O una guarda de lease en el servidor para `/sync/push` mientras `migration_in_progress` (el push tendría que llevar el
  `device_id`; toca el Worker).

## Criterios de aceptación

- [ ] Un teléfono que perdió el lease de la migración no sube ni una página más a la cuenta.
- [ ] Sale con el texto de «otro dispositivo tomó el relevo», sin esperar al cutover.
