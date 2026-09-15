---
id: invite-link-creation-blames-the-connection-for-any-rpc-failure
status: backlog
priority: low
area: "groups, invitaciones, copy"
created: 2026-09-15
updated: 2026-09-15
source: "review adversarial de `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` (2026-09-15)"
---

# Crear un enlace de invitación culpa a la conexión ante cualquier fallo del servidor

## El problema, en lenguaje de usuario

Quiero invitar a alguien a mi grupo. Toco para crear el enlace y Yala me dice que no pudo y que revise mi conexión. Mi
conexión está bien: lo que falló fue otra cosa.

## Lo medido (leído en el código, sin ejecutar)

- En un grupo del canal backend, `GroupDetailViewModel` enseña `L10n.Groups.Errors.inviteFailed` para CUALQUIER error
  de `create_group_invite`: su `catch` es genérico. `GroupMembersView` hace lo mismo en la otra superficie que acuña
  enlace.
- El docblock de `GroupInviteLinkCreationLogic` da ese texto por correcto porque el fallo que llega al `catch` sería «la
  red de verdad». Pero a ese `catch` también llegan un 5xx, un 502 `yala_unavailable`, un `.decoding` y un 401 por App
  Attest ausente (`.transient(status: 401)` desde el 2026-09-15; antes, `.sessionExpired`).
- `create_group_invite` no reintenta ningún transitorio (`neverRetryTransient`), así que el aviso sale al primer
  fallo.
- Sin medir: el texto exacto de `groups.errors.inviteFailed` en todos los idiomas, y cuántos fallos de este RPC no son
  de red.

## Lo que hay que decidir

1. Clasificar el error del RPC, con el molde de `GroupLeaveErrorLogic`: la red pide revisar la conexión, lo pasajero
   del servidor pide volver en un rato, y la sesión caducada pide volver a entrar.
2. Dejarlo.

## Relación con otros tickets

- `invite-link-five-causes-one-message` — el mismo problema al otro lado, al unirse con el enlace.
- `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` — de donde sale.
