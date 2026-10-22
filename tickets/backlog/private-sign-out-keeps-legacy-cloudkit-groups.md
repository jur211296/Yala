---
id: private-sign-out-keeps-legacy-cloudkit-groups
status: backlog
priority: very-low
area: "groups, settings"
created: 2026-09-11
updated: 2026-10-08
source: "paso 9 del rediseño de sesiones (`session-exits-one-verb-per-session`), decisión D10 del Paso 0"
---

# Cerrar una sesión privada sin cuenta de grupos conserva los grupos de la era CloudKit

El cierre privado sin sesión en la nube (celda C) borra el store de grupos solo si guarda filas del canal
backend (`CloudSessionSignOut.hasBackendGroupRows`): esas se pueden volver a bajar. Las de la era CloudKit
que nunca migraron (`isBackendGroup == false`, `movedToBackendAt == nil`) no tienen de dónde volver desde que
la Fase 3 retiró el transporte, y se quedan en el dispositivo tras el cierre.

## La decisión que falta (Jürgen)

¿Se borran igual («cerrar sesión borra lo local», ADR §5) aunque no se puedan recuperar, o se conservan?
Hoy la población es teórica: producción tuvo un fresh start el 2026-09-10.

## Medido en 2.1 (triage 2026-10-08)

- `CloudSessionSignOut.hasBackendGroupRows` sigue con el mismo predicado: un `SplitGroup` con `isBackendGroup == false` y `movedToBackendAt == nil` no dispara el borrado del store de grupos.
- En 2.1 solo el seed de desarrollo crea `SplitGroup` a mano; ningún camino de producción crea grupos de la era CloudKit, así que solo los tendría una instalación antigua que nunca migró.
- Decisión que falta: **A.** borrarlos igual (ADR §5); **B.** conservarlos, como hoy, y escribirlo. Recomendada **B**: no tienen de dónde volver y borrar lo irrecuperable por coherencia no compensa con una población teórica. Con B solo queda escribir la decisión: por eso `very-low`.

Triage 2026-10-08: abierto · low → very-low · sigue igual, pero la población es teórica y la opción recomendada (conservar) no cambia código: falta escribir la decisión.
