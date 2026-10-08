---
id: stuck-groups-drain-with-another-account-and-a-cycle-reason-names-two-of-three-causes
status: backlog
priority: very-low
area: "grupos, sync, copy"
created: 2026-10-05
updated: 2026-10-08
source: "residual de `detach-with-a-stuck-groups-drain-names-only-the-first-of-two-causes` y `stuck-groups-drain-hides-held-rows-of-another-account` (2026-10-05)"
---

# Drain atascado, cambios de otra cuenta y además sin App Attest o sin sesión: el aviso nombra dos de tres causas

## El problema, en lenguaje de usuario

Tres fallos a la vez: el teléfono no consigue preparar algún cambio de grupos, hay cambios apuntados con otra cuenta, y además
el teléfono lleva más de un día sin la verificación de seguridad (o la sesión caducó). El aviso habla de la verificación (o de
la sesión) y, en el desasociar, del atasco; no de la otra cuenta. Al arreglarlo y reintentar, sale «otra cuenta». No se pierde
nada: en los cierres, «Cerrar sesión y perderlos» ya cuenta todas las filas, también las ajenas.

## Por qué pasa (medido leyendo el código el 2026-10-05)

`CloudSignOutFlowLogic.stuckCaptureVerdict` da prioridad al motivo del ciclo si abre la salida (`lossCause`), antes de mirar
las filas de otra cuenta. `DetachBlockedNotice` solo combina una causa con el atasco.

## Propuestas (decide Jürgen)

- **A.** Dejarlo: en los cierres la salida ya lo resuelve todo, y el desasociar es el único que lo enseña de una en una.
- **B.** Un texto del desasociar para las tres causas (3 textos más × 16 locales).

## Medido en 2.1 (triage 2026-10-08)

- `CloudSignOutFlowLogic.stuckCaptureVerdict` (:1025) sigue devolviendo el motivo del ciclo con `lossCause` antes de mirar las filas de otra cuenta.

Triage 2026-10-08: abierto · very-low → very-low · no se pierde nada y la propuesta A (dejarlo) sigue siendo razonable.
