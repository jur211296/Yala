---
id: forward-step-ceiling-wins-over-a-cancel-given-in-the-same-pass
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-23
source: "review adversarial de `adopt-follower-waits-for-the-leader-with-no-ceiling` (2026-09-23), lente de cancelar y carreras"
---

# Si confirmas «Cancelar» justo cuando vence el techo, la tarjeta dice que falló en vez de que cancelaste

## El problema, en lenguaje de usuario

Estoy en el 22 %, en el 35 %, en el 80 % o esperando a otro dispositivo, y confirmo «Cancelar la activación» (o «Dejar de
esperar») mientras la app está reintentando por detrás. Si ese reintento es justo el que agota el plazo, en vez de volver a
empezar sin aviso veo la tarjeta de fallo con «Reintentar».

## Por qué pasa (leído el 2026-09-23; no ejecutado)

`MigrationRunner.observeForwardStepStall` no mira `migrationCancelRequested` antes de decidir el techo; lo mira `drive()` en
la vuelta siguiente, cuando la fase ya es `failedRollback` y no ofrece cancelar. `observeAdoptEffectFailure` sí lo mira
primero. Es igual en los cuatro pasos (claim, identidad, `cutover(.pending)`, `waitingForLeader`). El daño es de texto:
`.rollback` es local y no toca nada.

## Arreglo propuesto

Al principio de `observeForwardStepStall`: `if migrationCancelRequested, try await journalMigrationCancel() { return true }`,
con un test por paso.

## Criterios de aceptación

- [ ] Un «sí» apuntado en una pasada que vence el techo sale como cancelación (sin tarjeta de fallo, marca `cancelled` en
      un adopt).
