---
id: creategroup-throw-after-commit-loses-owner
status: backlog
area: groups
priority: medium
created: 2026-08-29
updated: 2026-08-29
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
