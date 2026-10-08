---
id: groups-organizer-gate-unavailable-sends-to-settings-from-the-welcome
status: backlog
priority: low
area: "modo-nube, groups, onboarding"
created: 2026-09-29
updated: 2026-10-08
source: "hallazgo al cerrar `groups-invite-neutral-gate-has-no-way-out-when-the-exit-cell-cannot-wipe` (2026-09-29): el arreglo cubrió solo la rama del invitado, a propósito"
---

# «Crear mi primer grupo» dice «ciérrala desde Ajustes» en un Welcome donde no hay Ajustes

## El síntoma, en lenguaje de usuario

Toco «Crear mi primer grupo» en la bienvenida y la app me dice que el teléfono tiene una sesión abierta que hay que
cerrar desde Ajustes. Estoy en la bienvenida: no hay Ajustes a mano. La única salida es «Volver».

## Dónde está (medido el 2026-09-29)

`WelcomeGroupsGateView.neutralReturnEntryPhase()` da `.unavailable` en los mismos dos casos que la del invitado daba
antes: el cierre de sesión del teléfono no está en reposo, o la celda es `.cloudSecureSignOut`. Esa pantalla pinta
`welcome.groups.neutralUnavailableBody` («…hay que cerrar desde Ajustes antes de empezar un grupo aquí») y un solo
«Volver». El docblock de `L10n.Welcome.Groups.neutralUnavailableTitle` aún habla de «la de una visita», una celda que ya
no existe.

## Lo que se hizo en la rama del invitado, y por qué no se copió

El invitado ganó Reintentar, re-medida sola al volver el cierre a reposo, y «abre Yala otra vez» / «entra con esa
cuenta» en la celda de la nube. **El reintento automático NO se puede copiar tal cual**: al re-medir, la rama del
organizador arranca el borrado sin preguntar (`.returningToNeutral` directo si hay copia en iCloud), así que un
reintento solo sería un borrado sin gesto. Un Reintentar a mano sí es un gesto.

## Cómo se sabe que está bien

Desde cualquier estado que dé `.unavailable` al organizador, el copy dice algo verdad en el Welcome y hay una acción
que no sea solo «Volver».

## Medido en 2.1 (triage 2026-10-08)

- `WelcomeGroupsGateView.neutralReturnEntryPhase()` sigue dando `.unavailable` con el cierre de sesión fuera de reposo o con la celda `.cloudSecureSignOut`, y esa pantalla sigue pintando `welcome.groups.neutralUnavailableBody` («…hay que cerrar desde Ajustes…») con un solo «Volver».
- El docblock de `L10n.Welcome.Groups.neutralUnavailableTitle` sigue hablando de «la de una visita», una celda retirada.
- Los tres commits posteriores sobre la vista (`b925c90d2`, `517f5e18e`, `22cef3cdb`) no tocaron la rama del organizador. «Volver» deja a la persona en la bienvenida con las demás salidas: no es un callejón de la app, solo de este camino.

Triage 2026-10-08: abierto · low → low · el organizador sigue viendo «ciérrala desde Ajustes» en la bienvenida con un solo «Volver»; la bienvenida conserva las otras salidas.
