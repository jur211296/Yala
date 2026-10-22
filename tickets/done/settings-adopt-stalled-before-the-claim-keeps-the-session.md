---
id: settings-adopt-stalled-before-the-claim-keeps-the-session
status: done
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

## Resuelto (2026-09-24)

**En Almacenamiento, si «Activar la nube en este dispositivo» se queda esperando a iCloud y no llega a empezar, la sesión con
la que acabas de entrar se cierra y un aviso dice qué pasó.** Con iCloud todavía trayendo datos: «No pudimos empezar a activar
la nube: iCloud sigue trayendo datos a este dispositivo. Vuelve a intentarlo en unos minutos.»; si no, el genérico de la
pantalla. La bienvenida no cambia: su «Retomar» sigue reusando la sesión.

- Medido: la rama adopt de `continueToClaim` solo la alcanza Ajustes; la bienvenida entra por `startAdoptWithExistingSession`.
  `MigrationRunner.submit` sale con `return` al vencer `awaitQuiescence()`, con el journal en `authenticating`.
- Cómo: `withdrawAdoptSessionOwnershipIfNotStarted` devuelve si paró antes del claim (el mismo predicado que retira la marca),
  y la rama adopt, con `true`, cierra con `closeSessionIfOpened(openedSession)` —solo la sesión que abrió el intento; la de
  Grupos reusada no se toca— y pone el aviso. El texto lo elige `StorageFailureCopyLogic.settingsAdoptStoppedBeforeTheClaim`
  con `isImportQuiescent` leído antes del cierre (la señal que hizo esperar al runner); no habla de la sesión porque también sale cuando no se cerró.
- Tests: cuerpos fijados (`continueToClaim`, `withdraw…`), la bienvenida sin cierre ni aviso, y el texto por señal. 13
  mutantes del camino tocado, 13 muertos. Review de dos lentes: sin bloqueantes; la señal se lee antes del cierre, el pin de la
  bienvenida exige también que no haya `signOut`, retoques de copy en es-ES, en, en-GB y nl, y dos residuales a tickets
  (`adopt-session-close-drops-the-mark-before-the-sign-out-lands`, `welcome-adopt-stalled-session-is-kept-when-settings-reuses-it`).
- Sin device-QA: el camino (import de iCloud que no asienta en 120 s justo al entrar) no se monta a voluntad.
