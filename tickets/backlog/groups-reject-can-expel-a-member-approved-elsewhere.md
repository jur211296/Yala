---
id: groups-reject-can-expel-a-member-approved-elsewhere
status: backlog
priority: low
area: "groups, backend"
created: 2026-10-16
source: "review adversarial del arreglo B1 del lote 19 de la auditoría UX 2.2 (rechazar va al servidor)"
---

# Rechazar una solicitud puede expulsar a alguien que otro ya aprobó

## El problema, en lenguaje de usuario

Ana administra «Viaje a Cusco» en el iPhone y en el iPad. En el iPhone acepta a Carla. Horas después abre el iPad, que
todavía no ha bajado el cambio, ve a Carla como pendiente y toca «Rechazar». Carla, que ya estaba dentro, sale del grupo.

## Lo medido

- Desde el lote 19, `GroupService.rejectMember` va al servidor por `remove_member`, porque no existe un RPC de rechazo.
  Hasta entonces «Rechazar» fallaba siempre en un grupo de la nube.
- `remove_member` acepta filas `active` y `pendingApproval`: a un pendiente lo deja `rejected` y a un activo `removed`
  (`supabase-groups-staging.ddl`, sección 5; golden «A rechaza» de `gateway/test/groups.goldens.test.ts`).
- El cliente comprueba antes del RPC que la fila siga pendiente EN ESTE TELÉFONO; lo que solo sabe el servidor no lo ve.
- Tras el RPC, el estado local sigue a la respuesta (`removed` si ya era miembro), y el pull lo confirma.

## Por qué es `low`

Hace falta una aprobación en otro sitio que este teléfono aún no haya bajado, y en los grupos de la nube solo
administra quien creó el grupo (no hay cambio de rol). La intención de quien rechaza es que esa persona no esté, y quien
sale así puede volver a entrar con el enlace: el re-join la deja otra vez pendiente.

## Qué haría falta

Un RPC `reject_member(p_group_id, p_member_key)` que exija `status = 'pendingApproval'` y devuelva
`yala_member_not_found` en otro caso, y que `rejectMember` lo use. Es un cambio de servidor con deploy, fuera de una
sesión de auditoría.
