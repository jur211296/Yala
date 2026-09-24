---
id: adopt-session-close-drops-the-mark-before-the-sign-out-lands
status: backlog
priority: low
area: "modo-nube, sesiones, adopt"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `settings-adopt-stalled-before-the-claim-keeps-the-session` (2026-09-24), lente de tiempos"
---

# Si la app muere justo mientras cierra la sesión de un adopt, el arranque siguiente la registra como tu cuenta de Grupos

## El problema, en lenguaje de usuario

Cuando la activación de la nube se cancela, se rinde o no llega a empezar en Almacenamiento, la app cierra la sesión que abrió
para eso. Si la app muere en ese instante (menos de un segundo), o si el cierre de sesión falla, la sesión sobrevive. En el
arranque siguiente la app la registra como tu cuenta de Grupos, que es justo lo que el cierre quería evitar.

## Por qué pasa (leído el 2026-09-24; no ejecutado)

Los tres caminos que cierran la sesión de un adopt borran la marca `AdoptSessionOwnership` ANTES del `await signOut()`:
`closeSessionOfExitedAdopt` (`record(nil)` y luego `closeSessionIfOpened(true)`) y, desde este ticket, la rama adopt de
`continueToClaim` (`withdrawAdoptSessionOwnershipIfNotStarted` la retira antes de cerrar). Además `CloudAuthService.signOut`
borra la marca al entrar y la sesión al final, tras un `await` del servicio de derechos. Si `client.signOut(scope: .local)`
falla, solo queda un breadcrumb. En esa ventana, con la sesión viva y sin marca, `GroupsAccountAssociation` (el registrador del
arranque) ya no la reconoce como del adopt.

## Qué habría que decidir

Si merece la pena mantener la marca hasta que el cierre aterrice (borrarla después de `signOut`, y que `signOut` no la borre
antes de cerrar), a cambio de tocar `CloudAuthService.signOut`, que comparten todos los cierres. La ventana es de menos de un
segundo.
