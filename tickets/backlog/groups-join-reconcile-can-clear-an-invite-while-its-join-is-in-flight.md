---
id: groups-join-reconcile-can-clear-an-invite-while-its-join-is-in-flight
status: backlog
priority: low
area: "groups, invitaciones"
created: 2026-09-17
source: "review adversarial de `groups-actions-read-an-offline-token-refresh-as-a-session-expiry` (lente de lógica), 2026-09-17; anterior a ese cambio"
---

# Si me rechazaron de un grupo y vuelvo a pedir entrada, la invitación puede perderse mientras se envía

## El problema, en lenguaje de usuario

Un admin me rechazó de un grupo. Me manda un enlace nuevo, lo toco desde WhatsApp y Yala se abre. La petición no llega a
salir bien (la red falla en ese momento) y Yala no vuelve a intentarlo nunca: la invitación ha desaparecido del teléfono.

## Lo medido (2026-09-17, leído en el código, sin ejecutar)

- `GroupBackendInviteEntryHandler.attemptJoin` gasta el tap (`consumeInviteTapArm`) ANTES de esperar a `join_group`. Si
  la unión falla por algo pasajero, lo re-arma y conserva la invitación para que el reconciler la reintente.
- `GroupJoinReconciler.reconcile` no tiene guarda de reentrada, y el paso a `.active` lo lanza (`ContentView`,
  `trigger: .foreground`). Abrir Yala desde un enlace es justo un paso a `.active`.
- Con un miembro local en estado terminal (`rejected`, `left` o `removed`, `GroupJoinReconcileLogic.isTerminal`) y el tap
  ya gastado, `decideBackend` devuelve `.correctAndClear`, y el reconciler borra la invitación (`PendingJoinStore.clear`).
- ⇒ si esa pasada cae entre el gasto del tap y la respuesta de `join_group`, y la unión falla por algo pasajero, el tap se
  re-arma sobre una invitación que ya no existe. Nada vuelve a intentarlo.
- Con la unión en éxito no se pierde nada visible: el servidor ya tiene la solicitud y el pull trae el miembro.
- La ventana es la duración de `join_group`, con el reintento corto de los fallos de red (hasta ~4 s más). No es nueva:
  existía antes del 2026-09-17 con el token vigente.
- Sin medir: si en un teléfono real el `.active` llega antes o después de que el enlace lance la unión.

## Por dónde va

Que el reconciler no decida sobre una zona con la unión en vuelo (una marca en memoria que `attemptJoin` pone y quita), o
gastar el tap después de la respuesta, conservando «a lo sumo un `join_group` por tap». Precedente del tap:
`rejected-member-cold-tap-does-nothing`.

## Relación con otros tickets

- `rejected-member-cold-tap-does-nothing` — de donde salen el tap armado y la re-solicitud del miembro rechazado.
- `groups-join-is-not-retried-when-the-network-returns` — la cadencia del reintento.
