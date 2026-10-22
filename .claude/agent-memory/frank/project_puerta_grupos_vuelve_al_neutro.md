---
name: puerta-grupos-vuelve-al-neutro
description: La mitad 2 de «Vengo por un grupo» se cerró el 11-sep (PR #139) consumiendo el verbo del paso 9; la entrada por INVITACIÓN queda fuera con razón medida y falta el device-QA, que NO es simulable
metadata:
  type: project
---

**`groups-entry-on-a-mirrored-store-still-blocks-the-owner` está en `qa/` desde el 2026-09-11, PR #139.**
La puerta de «Vengo por un grupo → Crear mi primer grupo» dejó de bloquear al dueño de los datos: vuelve al
neutro y sigue.

**Why:** el ticket llevaba `blocked` desde el 10-sep esperando el verbo del paso 9. Las tres razones del
bloqueo se re-midieron una por una y las tres cayeron — pero **solo por la puerta del coordinador**: llamar
a `armSignOutWipe()` a mano sigue prohibido, y ése fue el error de la pasada anterior.

**How to apply:**

- **La decisión de producto que estaba «pendiente de Jürgen» ya estaba escrita**: la matriz del ADR, fila B,
  dice «vuelta al neutro (borra local, iCloud intacto, **relanza**) y sigue». Se aceptó el relanzamiento y
  está registrado en el Paso 0 del encargo. No volver a abrirlo.
- **La entrada por INVITACIÓN queda fuera, y no por comodidad:** su embudo (`GroupBackendInviteEntryHandler.drive`)
  lo llama también el reconciler en el trigger `.boot`, o sea **sin pantalla**, y el intent muere en el wipe
  (`AppRouter.resetAll` → `PendingJoinStore.clearAll()`). Hacen falta un `RouterIntent` nuevo y una
  superficie durable. Ticket propio, `high`: `groups-invite-on-a-mirrored-store-crosses-data`.
- **Lo que falta es el device-QA y NO es simulable** (sin cuenta de iCloud no hay espejo). Cinco recorridos
  en el ticket; el que más caro sale si falla es el 2: tras la vuelta al neutro, «Restaurar desde iCloud»
  tiene que traer todo el histórico.
- **La rama del 10-sep (`encargo/2026-09-10-…`, sin PR) queda superada** — su código no se reusó, se
  reescribió sobre el verbo del paso 9. De ella se rescataron dos tickets que nunca llegaron a `2.1`
  (`forcesync-returns-ok-without-touching-the-network`, `icloud-export-error-latch-never-clears`) y dos
  memorias de método. Se puede borrar.
- Cuatro tickets más salen de esta sesión: `invite-recovery-relaunches-for-a-mirror-it-never-uses` ·
  `sign-out-wipe-abort-loops-the-groups-gate` · `superseding-intent-can-strand-the-sign-out-coordinator`.

Relacionado: [[el-testigo-global-miente-en-el-host-de-test]], [[paso9-un-verbo-por-sesion]].
