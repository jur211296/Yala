---
id: no-hay-seed-con-miembro-rechazado
status: done
priority: low
area: "groups, testing, seeds"
created: 2026-09-08
updated: 2026-11-05
source: barrido de QA en simulador del 2026-09-08 (hallazgo de camino)
---

# El banner de «solicitud rechazada» no se puede ver, y el cliente ya sabe pintarlo

## Qué pasa

`DevSeedGroups` solo siembra miembros en `.pendingApproval`; **ningún perfil escribe
`status = .rejected`**. Como el estado solo llega por un pull real del backend, el
`PendingApprovalBanner(.rejected)` —que el cliente **ya tiene cableado**
(`GroupDetailView:138` y `:648-685`)— no se puede ver en simulador.

## Por qué importa

`guest-decline-has-no-screen` está catalogado como «solo puede hacerse en la app publicada». Es
verdad **solo para la mitad del rechazo**: la mitad de la sala de espera (el pendiente ve grupo y
roster y ningún gasto) sí se reproduce hoy con `grupos-pendiente`. La otra mitad no necesita
servidor para **pintarse**, solo para **llegar**: con un perfil de seed que escriba el estado, la
pantalla es verificable sin dos cuentas.

Lo que seguiría siendo device es que el rechazo **llegue** de verdad por el canal, no cómo se ve.

## Qué haría falta

Un perfil `grupos-rechazado` que siembre al usuario propio con `status = .rejected` en un grupo,
para poder ver el banner y comprobar que su botón quita el grupo de **este** teléfono.

## Cómo se sabe que está bien

Con ese perfil, el tab Grupos muestra la tarjeta, el detalle trae el banner de rechazo con su copy,
y su botón deja la lista sin ese grupo.

## Medido en 2.1 (triage 2026-10-08)

- El banner sigue cableado en `GroupDetailView` (`PendingApprovalBanner(state: .rejected, onLeave: { discardRejectedGroup() })`), y en `Yala/Seed/DevSeedGroups.swift` el único `rejected` es el `rejectedReason` del outbox, no el estado de un miembro. No existe ningún perfil `grupos-rechazado`.

Triage 2026-10-08: abierto · low → low · `DevSeedGroups` sigue sin ningún perfil que escriba `status = .rejected`; `GroupDetailView` sigue cableando `PendingApprovalBanner(state: .rejected)`.

## Resuelto (2026-11-05, lote T4)

- Perfil nuevo `grupos-rechazado` (`DevSeedGroups.createAsRejectedMember`): un grupo de Ana con mi solicitud `rejected`, sin `isCurrentUser`. Se lanza con `-uitest-icloud-identity`.
- El botón del aviso lleva `group_rejected_leave`.
- **Medido al probarlo: tocar la tarjeta ya no abre el detalle**, ofrece «¿Salir del grupo?» (`GroupsContainerView`, `onRejectedTap`). Esa salida pasa por `leave_group` del servidor, así que en el simulador solo se comprueba que aparece y que el detalle no se abre (`#test_rejectedProfile_cardOffersToLeave_withoutOpeningTheDetail`).
- El aviso del detalle (al que se llega por enlace o notificación) y su botón, que borra en local, se prueban por enlace `seeded-first` (`#test_rejectedProfile_detailShowsTheNotice_andItsButtonRemovesTheGroup`): el botón cierra el detalle y el grupo desaparece.
- Que el rechazo LLEGUE por el canal, y la salida por servidor desde la tarjeta, siguen siendo de aparato.
