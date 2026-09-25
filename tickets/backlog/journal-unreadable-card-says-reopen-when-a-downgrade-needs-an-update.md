---
id: journal-unreadable-card-says-reopen-when-a-downgrade-needs-an-update
status: backlog
priority: low
area: "modo-nube, migración, copy"
created: 2026-09-25
updated: 2026-09-25
source: "residual de `an-undecodable-migration-phase-reads-as-never-started` (2026-09-25)"
---

# Si Yala volvió a una versión anterior, la tarjeta dice «cierra y vuelve a abrir» y eso no lo arregla

## El problema, en lenguaje de usuario

Si alguien instala una versión de Yala más vieja que la que tenía (un tester de TestFlight que elige un build anterior),
la app puede encontrarse el paso de la nube anotado de una forma que esa versión no entiende. Desde el 2026-09-25 no
hace nada con él y enseña en Almacenamiento la tarjeta de «no pudimos comprobar en qué punto están tus datos». La tarjeta
termina con «si no se arregla, cierra Yala y vuelve a abrirla», y en este caso reabrir no arregla nada: lo que lo arregla
es **actualizar Yala**.

## Por qué quedó fuera

El ticket padre decidió qué hace la app (no tocar nada, no decidir con esa anotación). Esto es copy nuevo en los 17
idiomas y una decisión de producto sobre qué se le pide a la persona, y no hacía falta para cerrar el callejón.

## Qué habría que hacer

- Distinguir las dos causas en la lectura: el `fetch` que lanza (reabrir sí puede curarlo) y la fila que no se entiende
  (`MigrationState.isJournalUndecodable`, solo lo cura actualizar). Hoy las dos son `JournaledPhaseRead.unreadable`.
- Propuesta de texto para la segunda: «Esta información la guardó una versión más nueva de Yala. Actualiza Yala para
  seguir; tus datos no se han tocado.» (Leer BRAND-VOICE antes; medir que «no se han tocado» es verdad en cada camino.)

## Población

Solo quien baja de versión. En App Store no se puede elegir un build anterior, así que es TestFlight. Por eso es `low`.

## Criterios de aceptación

- [ ] Con una fila que no se entiende, la tarjeta pide actualizar Yala, no reabrirla.
- [ ] Con un `fetch` que lanza, sigue el texto de hoy.
