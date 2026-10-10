---
id: welcome-adopt-stalled-session-is-kept-when-settings-reuses-it
status: backlog
priority: low
area: "modo-nube, sesiones, adopt, bienvenida"
created: 2026-09-24
updated: 2026-10-08
source: "review adversarial de `settings-adopt-stalled-before-the-claim-keeps-the-session` (2026-09-24), lente de tiempos"
---

# Si la bienvenida se queda esperando a iCloud y luego activas la nube desde Almacenamiento, la sesión de la bienvenida no se cierra

## El problema, en lenguaje de usuario

Entro en mi cuenta de la nube desde la bienvenida y la activación se queda esperando a iCloud antes de empezar. La sesión se
queda abierta a propósito, para que «Retomar» vuelva a intentarlo. Si en vez de eso acabo en Almacenamiento y toco «Activar la
nube en este dispositivo», la app reusa esa sesión como si fuera la de Grupos. Si la activación vuelve a pararse antes de
empezar, esa sesión no se cierra, y en el arranque siguiente la app puede registrarla como mi cuenta de Grupos.

## Por qué pasa (leído el 2026-09-24; no ejecutado)

La bienvenida (`startAdoptWithExistingSession`) retira la marca `AdoptSessionOwnership` cuando no llega al claim y conserva la
sesión. En Ajustes, con sesión usable, el plan es `.reuseLiveSession`, que entra en `continueToClaim` con
`sessionOpenedByThisAttempt: false`. Desde `settings-adopt-stalled-before-the-claim-keeps-the-session` esa rama cierra solo la
sesión que abrió el propio intento, así que esta no la toca.

## Qué habría que medir y decidir

1. Medir si el flujo deja salir de la bienvenida con esa sesión viva y llegar a Almacenamiento. Si no se puede, el ticket se
   descarta.
2. Si se puede, decidir si Ajustes debe tratar como suya una sesión que abrió un adopt de la bienvenida sin terminar.

## Medido en 2.1 (triage 2026-10-08)

- **El paso 1 del ticket, medido: sí se llega.** `onAdoptStarted` (`ContentView.swift`, ~2956) marca `hasCompletedOnboarding` ANTES de conducir el adopt, así que un kill con la bienvenida parada aterriza en MainTab con la tarjeta de Almacenamiento.
- `CloudMigrationController.continueToClaim`, rama adopt: tras `withdrawAdoptSessionOwnershipIfNotStarted()` sigue cerrando con `closeSessionIfOpened(openedSession)`, y `.reuseLiveSession` entra con `false`: la sesión de la bienvenida no se cierra.
- Daño acotado: la sesión es de la cuenta que la persona eligió, así que lo que Grupos registraría al arrancar es su propia cuenta.
- **Decisión (paso 2):** A) Ajustes cierra también una sesión viva sin marca de adopt que no sea la de la asociación de Grupos vigente; B) dejarlo así y documentarlo. **Recomendada: A**, con prioridad `low`.

Triage 2026-10-08: abierto · low → low · alcanzable con un kill tras onAdoptStarted, pero la sesión que queda es la de la cuenta que la persona eligió.
