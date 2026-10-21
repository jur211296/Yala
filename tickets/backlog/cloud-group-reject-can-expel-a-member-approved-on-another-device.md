---
id: cloud-group-reject-can-expel-a-member-approved-on-another-device
status: backlog
priority: low
area: "groups, modo-nube"
created: 2026-10-20
updated: 2026-10-20
source: "residual de cloud-group-reject-request-always-fails (2026-10-20)"
---

# «Rechazar» con el estado viejo podría expulsar a quien ya se aprobó desde otro aparato

## En lenguaje de usuario

Apruebo una solicitud en el iPad y, antes de que el iPhone se entere, la rechazo en el iPhone. La persona queda fuera del grupo en vez de dentro.

## Lo medido (2026-10-20)

- El rechazo de un grupo de la nube usa `remove_member`, que deja `rejected` a un pendiente y `removed` a un activo. El cliente exige la solicitud pendiente EN LOCAL antes de llamar, pero el servidor no sabe qué creía el cliente.
- En el canal backend hay un solo admin por grupo (no existe RPC de cambio de rol), así que solo pasa con el mismo admin en dos aparatos y en la ventana del pull.

## Lo que habría que decidir

Si vale un RPC `reject_member` que solo actúe sobre `pendingApproval` (migración aditiva + allowlist y aviso del gateway, en los dos entornos), o se deja.
