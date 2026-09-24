---
id: settings-adopt-stalled-before-the-claim-keeps-the-session
status: backlog
priority: low
area: "modo-nube, sesiones, adopt"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `adopt-exit-keeps-the-session-it-opened` (2026-09-24), lente de tiempos"
---

# Si activar la nube en este dispositivo se queda esperando a iCloud antes de empezar, la sesión que acabas de abrir se queda

## El problema, en lenguaje de usuario

En Almacenamiento toco «Activar la nube en este dispositivo», elijo Apple o Google y entro. Si justo entonces iCloud sigue
descargando datos, la activación no llega a empezar y la tarjeta vuelve a «Activar la nube en este dispositivo», pero la
sesión con la que acabo de entrar se queda abierta. En el siguiente arranque la app puede registrarla como mi cuenta de
Grupos, aunque no pedí eso.

## Por qué pasa (leído el 2026-09-24; no ejecutado)

`CloudMigrationController.continueToClaim`, rama del adopt: si `submit(.signInSucceeded)` vence su espera de quiescencia
(hasta 120 s), el journal se queda en `authenticating` y la llamada vuelve sin claim. «Migrar» trata ese caso como una
parada y cierra la sesión que abrió (`closeSessionIfOpened` tras el `guard migrationAttempt != nil`); el adopt no. Desde
`adopt-exit-keeps-the-session-it-opened` la marca de la sesión del adopt se retira ahí a propósito
(`withdrawAdoptSessionOwnershipIfNotStarted`): en la bienvenida, ese mismo caso lo retoma su «Retomar» con la sesión viva.
Ya existía antes de ese ticket.

## Qué habría que decidir

Alinear el adopt de Ajustes con «Migrar» (cerrar la sesión abierta si la llamada no llegó al claim, solo en Ajustes, que no
tiene un «Retomar» que la reuse) y decir algo en la tarjeta, o dejarlo así.
