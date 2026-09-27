---
id: apple-id-change-check-stays-off-after-a-failed-migration
status: backlog
priority: low
area: "sesiones, modo-nube"
created: 2026-09-27
updated: 2026-09-27
source: "review adversarial de `apple-id-change-boot-check-runs-before-the-migration-guard-can-see` (2026-09-26), lente de falso bloqueo"
---

# Tras una migración fallida, el cambio de Apple ID no se detecta hasta pulsar «Reintentar»

## El problema, en lenguaje de usuario

Si un paso de los datos a la nube terminó en fallo y la persona no ha vuelto a Almacenamiento, Yala no le ofrece cerrar
la sesión privada aunque cambie de Apple ID. No se pierde nada: se queda en el teléfono una copia que es de otra cuenta.

## Por qué pasa (medido el 2026-09-26)

- `failedRollback` deriva `.failed(.migration)` y el guard exige `.idle` (`AppleIDChangeCloseLogic.migrationAtRest`). La
  fase dura hasta «Reintentar» (`CloudMigrationController.resetAfterRollback`).
- Era el criterio del controller antes del ticket de origen; hasta entonces el arranque lo saltaba porque el controller
  aún no existía.
- Antes del cutover el teléfono está intacto (`MigrationWorkExecutor`), así que probablemente se podría ofrecer. Pero
  el terminal puede llevar efectos pendientes (`.rollback`) que un resume ejecuta.

## Qué hay que decidir (Jürgen)

¿Se ofrece el cierre con una migración fallida y sin efectos pendientes? Hasta decidirlo, no se ofrece.

## Nota (2026-09-27): la decisión ya gobierna dos lectores

Desde `private-sign-out-proceeds-with-a-migration-in-flight`, el cierre de la sesión privada usa el MISMO predicado
(`CloudSignOutFlowLogic.migrationBlockReason` sobre `migrationAtRest`). Con `failedRollback`, hoy tampoco se puede cerrar la
sesión privada hasta pulsar «Reintentar»: el aviso lo dice. Si se decide ofrecer el cierre tras un fallo sin efectos
pendientes, el término entra en `migrationAtRest` y se abren los dos a la vez; el test
`migracionFallida_tambienPara` de `PrivateSignOutMigrationGuardTests` es el que tiene que cambiar.
