---
id: personal-sign-out-reads-an-unfinished-drain-as-nothing-pending
status: backlog
priority: medium
area: "modo-nube, sync"
created: 2026-09-26
updated: 2026-09-26
source: "`groups-drain-failure-reads-as-nothing-pending` (2026-09-26), al buscar todas las instancias del patrón"
---

# Cerrar sesión en la nube puede llevarse un cambio personal que no llegó a capturarse

## El problema, en lenguaje de usuario

Casi nunca pasa. Si justo al cerrar sesión la app no consigue capturar tu último cambio (un fallo al leer o guardar,
o el reloj del teléfono muy desajustado), el cierre puede creer que no queda nada por subir y borrar el teléfono con
ese cambio dentro.

## Por qué pasa (leído el 2026-09-26; inferido, no ejecutado)

- El push-all del cierre personal (`CloudMigrationController.pushAllForSignOut`) decide con
  `CloudSignOutFlowLogic.pushAllVerdict(livePendingCount:…)`: outbox vivo a 0 ⇒ `.drained`.
- El drain del ciclo (`CloudSyncRuntime.performCycle`, paso 1) descarta lo que devuelve `CloudSyncEngine.drainOnce`. Con
  una vuelta que aborta hace `rollback()`: el cambio no está en el outbox y el recuento da 0.
- Con el corte por deriva del reloj, `drainOnce` devuelve `true` a propósito (ver su docblock), así que ni leyéndolo
  bastaría para este llamador, que borra.
- La rama con el candado cerrado sí lo cubre (`hasUncapturedPersonalChanges` en `pushAllVerdictWithoutEngine`); la rama
  con motor no.

Es el gemelo personal de `groups-drain-failure-reads-as-nothing-pending`, que en Grupos se cerró con una captura previa
que devuelve si terminó y una re-captura tras el ciclo que vacía el outbox.

## Por dónde va

Tras un `.drained` del bucle, preguntar `runtime.hasUncapturedPersonalChanges(context:)` (lectura del History sin
escribir, ya existe) antes de dar el outbox por vacío; `true` o `nil` ⇒ bloquear sin descartar, con el motivo que ya
use el push-all para el guardado que se asienta.

## Criterios de aceptación

- [ ] Con un drain que aborta o se corta por el reloj, el cierre en la nube no sale `.drained` con el outbox a 0.
- [ ] Sin nada pendiente, el cierre no cambia (ni esperas ni red nuevas).
