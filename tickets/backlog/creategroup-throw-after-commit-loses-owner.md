---
id: creategroup-throw-after-commit-loses-owner
status: backlog
area: groups
priority: medium
created: 2026-08-29
updated: 2026-10-08
source: docs/aprendizajes-tecnicos.md
---

# Un throw del RPC tras el commit deja al creador sin ser owner

## Qué pasa

`GroupBackendMembershipService.createGroup` es server-first: llama al RPC y solo **después**
hace `context.insert`. Si el RPC lanza *después* de que el servidor ya commiteara —un timeout,
un 5xx de vuelta— el pull sí trae la fila del grupo, pero `createGroup` no la toca: se queda
con `isOwner == false` hasta que el usuario reintente. Ve su propio grupo como si fuera de otro.

## Estado

**Preexistente**, no lo introdujo el fix que lo documentó: el camino que lanzaba tampoco lo
escribía antes. Verificado vivo el 2026-08-29.

## Por qué no se cerró en su momento

Textual del residual: cerrarlo «exigiría distinguir "lo creó" de "lo rechazó" desde un error
de transporte». Esa es la parte difícil, y es de diseño.

## De dónde sale

Residual medido y no cerrado en [docs/aprendizajes-tecnicos.md#un-gate-por-zona-calculado-sobre-filas-vivas-es-la-herramienta-equivocada-para-un-tombstone-por](../../docs/aprendizajes-tecnicos.md#un-gate-por-zona-calculado-sobre-filas-vivas-es-la-herramienta-equivocada-para-un-tombstone-por).

## Medido en 2.1 (triage 2026-10-08)

- `GroupBackendMembershipService.swift:103`: el RPC va primero (`:139`) y `isOwner = true` solo se escribe dentro del `saveUnderOutboxAuthor` posterior (`:165`). Si el RPC lanza tras el commit del servidor, no se escribe nada.
- El pull no lo repara: `isOwner` es local y `owner_user_id` no está en el manifiesto (`GroupService.swift:838-846`). La única reparación existente es `reconcileServerSideOwnership` (`GroupService.swift:815`), y solo corre tras un `yala_owner_cannot_leave`, es decir, si la persona intenta salir del grupo.

Triage 2026-10-08: abierto · medium → medium · `createGroup` sigue materializando solo tras un RPC con éxito (`GroupBackendMembershipService.swift:103-165`) y el pull no trae `isOwner`; ningún commit lo toca desde el 08-03.
