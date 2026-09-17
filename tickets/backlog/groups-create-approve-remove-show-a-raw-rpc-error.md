---
id: groups-create-approve-remove-show-a-raw-rpc-error
status: backlog
priority: low
area: "groups, copy"
created: 2026-09-17
source: "inventario de consumidores de `groups-actions-read-an-offline-token-refresh-as-a-session-expiry` (2026-09-17); ya anotado como residual en `groups-leave-rpc-error-10`"
---

# Crear un grupo, aprobar o expulsar a alguien sin conexión enseña «Error de Yala.GroupsRPCError 1»

## El problema, en lenguaje de usuario

Sin conexión, toco «Crear grupo» (o apruebo una solicitud, o expulso a alguien). Yala me enseña «No se ha podido
completar la operación. (Error de Yala.GroupsRPCError 1.)». No sé qué ha pasado ni qué hacer.

## Lo medido (2026-09-17, leído en el código)

- Tres alerts pintan `error.localizedDescription` de un `GroupsRPCError`, que no conforma `LocalizedError`, así que
  Foundation fabrica el número del caso:
  - crear grupo: `GroupFormView` (`saveErrorMessage = error.localizedDescription`, en el `catch` de `saveAsync()`);
  - aprobar una solicitud: `GroupMembersView.performApprove` (`pendingErrorMessage`);
  - expulsar a un miembro: `GroupMembersView.removeMember` (`actionErrorMessage`).
- El número sale del orden del enum, fijado por `GroupsMembershipClientTests.nsErrorCode_perCase_isMeasuredNotInferred`:
  `1` es `.transient` (sin red, 5xx) y `2` es `.sessionExpired`.
- Desde el 2026-09-17 el token que no se renueva sin red llega como `.transient` y no como `.sessionExpired`
  (`groups-actions-read-an-offline-token-refresh-as-a-session-expiry`): el número pasó de 2 a 1. Los dos eran crudos.
- Salir de un grupo ya no lo tiene: `GroupLeaveErrorLogic` elige el texto (`groups-leave-rpc-error-10`, que dejó estos tres
  escritos como residual).
- Crear el enlace de invitación tampoco: sus dos superficies enseñan `groups.errors.inviteFailed` para cualquier error.

## Por dónde va

Un clasificador por acción con su copy, molde `GroupLeaveErrorLogic`: «sin conexión» y «el servidor falló» piden volver a
intentarlo; la sesión borrada pide volver a entrar; los `yala_*` de cada RPC, su propio texto. El copy nuevo es producto:
necesita a Jürgen y `BRAND-VOICE.md`.

## Relación con otros tickets

- `groups-leave-rpc-error-10` — el mismo defecto al salir de un grupo, ya arreglado; aquí vive su residual.
- `groups-actions-read-an-offline-token-refresh-as-a-session-expiry` — cambió qué número ve la persona sin red.
