---
id: adopt-exit-keeps-the-session-it-opened
status: done
priority: medium
area: "modo-nube, sesiones, adopt"
created: 2026-09-23
updated: 2026-09-24
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

## Nota (2026-09-23, `welcome-adopt-effect-failure-has-no-reason-and-no-cancel`)

Desde ese ticket la bienvenida tiene «Cancelar la activación» durante el adopt, y al cancelar vuelve al chooser con la
sesión todavía abierta: el mismo estado que ya dejaba la flecha desde el error. Este ticket lo cubre también.

## Hecho (2026-09-24, sesión autónoma)

**Qué cambia para quien lo usa.** Si entras en tu cuenta de la nube desde la bienvenida o desde Almacenamiento y la
activación se cancela («Cancelar la activación», «Dejar de esperar») o se rinde por su techo, la sesión que se abrió para
eso se cierra. En el siguiente arranque esa cuenta ya no aparece como tu cuenta de Grupos. Si tenías sesión de Grupos
antes de empezar, se queda como estaba. Para volver a intentarlo, «Activar la nube en este dispositivo» o el «Reintentar»
de la bienvenida te piden entrar otra vez.

**Cómo.** Una marca durable con la cuenta cuya sesión abrió el adopt (`AdoptSessionOwnership`, en `UserDefaults`, sin
schema), apuntada antes de conducir y retirada si la llamada no llegó al claim. El controller la mira por nivel tras cada
pasada del runner y al arrancar, y cierra con `closeSessionIfOpened`, como «Migrar». La marca muere con cada sign-in y
sign-out, y el registrador de Grupos no asocia la sesión que describe. El diseño y lo que no se toca están en la regla
«Y la sesión que abrió el adopt» de `.claude/rules/swiftdata-cloudkit.md`.

**Verificación.** `AdoptSessionOwnershipTests` (tabla, tienda y cableado con cuerpos enteros),
`GroupsAssociationRegistrarTests.noRegistraLaSesionDeUnAdopt`, y mutantes (ver el PR). Review adversarial de dos lentes:
las dos cazaron que la marca se apuntaba tarde (un kill en la primera pasada la perdía); además, que una sesión de Grupos
firmada después con la misma cuenta heredaba la marca, que el registrador podía adelantarse al cierre en el arranque y que
el «Retomar» de la bienvenida podía reclamar sin sesión. Todo corregido. Sin device-QA: el camino no se monta a voluntad.

**Residual, que ya existía:** un adopt de Ajustes cuyo primer paso vence la espera del import deja abierta la sesión que
acaba de firmar (en «Migrar» esa parada sí cierra): `settings-adopt-stalled-before-the-claim-keeps-the-session`.
