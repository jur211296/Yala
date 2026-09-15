---
id: groups-tab-does-not-say-this-phone-cannot-sync-groups
status: backlog
priority: low
area: "groups, attest, copy"
created: 2026-09-15
updated: 2026-09-15
source: "decisión de Jürgen en `groups-phone-that-never-attests-is-told-to-retry-forever` (2026-09-15): el aviso fijo, a ticket propio"
---

# Un teléfono sin App Attest no se entera de que sus cambios de grupos no llegan hasta que intenta salir

## El problema, en lenguaje de usuario

Edito gastos de un grupo desde este teléfono. Nadie del grupo los ve, y la app no me dice nada. Solo me entero cuando
intento cerrar sesión, desasociar la cuenta de grupos o salir del grupo: ahí me dice que este teléfono no puede
sincronizar mis grupos.

## Lo medido (2026-09-15)

- Desde `groups-phone-that-never-attests-is-told-to-retry-forever` el teléfono tiene un veredicto terminal
  (`GroupsAttestStreakStore.isTerminal`: 24 h y 3 rechazos sin un solo acierto). Lo leen los cierres de sesión, el
  desasociar y salir de un grupo. Ninguna pantalla lo enseña sin que la persona haga uno de esos gestos.
- El canal personal tampoco tiene aviso fijo: su veredicto terminal solo emite el canario
  `cloudSyncBlockedByAttestUnavailable` (`CloudSyncRuntime.performCycle`). El ticket de origen daba por hecho un banner
  que no existe.
- El canario `groupsAttestTerminal` cuenta cuántos teléfonos llegan al veredicto: con ese número se puede decidir si
  merece pantalla.

## Lo que hay que decidir (Jürgen)

1. Un aviso fijo en la pestaña Grupos mientras el veredicto sea terminal: «Este teléfono no puede sincronizar tus
   grupos», y qué puede hacer la persona.
2. Esperar al canario `groupsAttestTerminal` y decidir con el número.
3. Dejarlo: el aviso ya sale en los gestos que pueden perder algo.

## Relación con otros tickets

- `groups-phone-that-never-attests-is-told-to-retry-forever` — de donde sale.
- `groups-join-intent-expires-silently-after-transient-failures` — otro silencio de la misma población: la invitación
  que caduca.
