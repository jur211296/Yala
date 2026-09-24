---
id: welcome-adopt-stalled-session-is-kept-when-settings-reuses-it
status: backlog
priority: low
area: "modo-nube, sesiones, adopt, bienvenida"
created: 2026-09-24
updated: 2026-09-24
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
