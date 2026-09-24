---
id: adopt-exit-keeps-the-session-it-opened
status: backlog
priority: medium
area: "modo-nube, sesiones, adopt"
created: 2026-09-23
updated: 2026-09-23
source: "review adversarial de `adopt-effect-retries-forever-with-no-ceiling` (2026-09-23), lentes de consumidores y de relojes"
---

# Si cancelas o se rinde la entrada en tu cuenta de la nube, la sesión se queda abierta

## El problema, en lenguaje de usuario

Empiezo a activar la nube en este teléfono con mi cuenta y lo cancelo, o la app se rinde por su techo. La sesión de esa
cuenta sigue puesta. En el siguiente arranque la app puede registrarla como mi cuenta de Grupos sin que yo lo pidiera.

## Por qué pasa (leído el 2026-09-23; no ejecutado)

`CloudMigrationController.cancelMigration` cierra la sesión con `closeSessionIfOpened` solo si hay `migrationAttempt`, y
ese campo solo se rellena con `consentPath == .migration` («Migrar»). Los dos caminos del adopt lo ponen a `nil`
(`continueToClaim` y `startAdoptWithExistingSession`). Pasa igual en el claim del adopt (#221) y en su efecto (`adopt-effect-retries-forever-with-no-ceiling`).
En el Welcome, `onAdoptStarted` además marca `hasPrivateSession`, y `GroupsAssociationRegistrar.syncFromLiveSessionIfNeeded`
registra esa cuenta en el arranque siguiente.

## Qué habría que decidir

¿La salida del adopt (cancelar o techo) cierra la sesión que abrió? Ojo: la reentrada por la marca
(`AdoptClaimScope.offersReentry`) funciona sin sesión, así que cerrarla no quita la salida hacia delante.

## Relacionado

- `migrate-attempt-session-survives-a-relaunch-mid-attempt`, `adopt-effect-retries-forever-with-no-ceiling`.

## Decisión (Jürgen 2026-09-23)

**A:** sí — al cancelar o al rendirse el techo, cerrar la sesión que abrió el adopt (alineado con Migrar / `closeSessionIfOpened`). La reentrada por la marca sigue disponible.
