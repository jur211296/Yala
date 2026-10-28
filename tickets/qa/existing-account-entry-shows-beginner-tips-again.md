---
id: existing-account-entry-shows-beginner-tips-again
status: qa
priority: low
area: onboarding, tips
created: 2026-10-19
updated: 2026-10-28
source: QA guiado 2026-10-19 (TestFlight 18), card «Quien entra por «Ya tengo una cuenta» vuelve a ver todos los tips de principiante»
---

# Quien entra por «Ya tengo una cuenta» vuelve a ver todos los tips de principiante

## Qué pasaba

Tras reinstalar o cerrar sesión, quien volvía con sus datos veía otra vez las guías de cada pestaña y los tours de
principiante: su estado es local y los borrados lo reinician.

## Hecho (2026-10-22) — decisión de Jürgen: «si llega con datos»

La entrada por «Ya tengo una cuenta» (restaurar desde iCloud con datos o adoptar una cuenta de la nube,
`completeOnboardingAsRestoreSkip`) apunta la hora; el arranque, cada vuelta a primer plano, cada guía al aparecer y el
tour de Ajustes preguntan si ya llegó algún movimiento de ANTES de esa hora y, si llegó, dan por vistas las guías y los
tours (`ReturningUserBeginnerTips`). El primer gasto que apunte la persona en una cuenta vacía no cuenta. Pasados 7 días
sin datos, se deja de preguntar. Tests: `ReturningUserBeginnerTipsTests`.

## Hecho (2026-10-28) — también «Primeros pasos» (card ds09, sesión S12k)

En el 2.º iPhone de Jürgen salió «Primeros pasos» con 1 de 7 tras volver por «Ya tengo una cuenta», con el 1.º en 7 de 7:
el PR #598 cubría las guías y los tours, no la tarjeta. Ahora, en el mismo momento en que los tips se dan por vistos
(llegó algún movimiento de antes de la entrada), la tarjeta se retira (`SetupChecklistManager.dismissCompleted`), y la
propia tarjeta pregunta al aparecer y cada vez que cambia su progreso: los datos que llegan marcan solos el primer paso,
que es justo cuando ya se puede decidir. Mismo criterio que fijó Jürgen el 22-oct. Tests: `ReturningUserBeginnerTipsTests`.

## Device-QA (iPhone de QA)

1. Con datos en iCloud: borra la app, reinstala, Welcome › «Ya tengo una cuenta» › restaurar desde iCloud.
2. Cuando aparezcan tus movimientos, recorre Panel, Registros y Estadísticas, y abre Ajustes: no sale ninguna guía
   («GUÍA») ni el tour de Ajustes, y en el Panel no queda la tarjeta «Primeros pasos» (puede asomar un instante mientras
   llegan los datos; en cuanto marca el primer paso, se va).
3. Control: instalación nueva › «Es mi primera vez»: las guías sí salen.
