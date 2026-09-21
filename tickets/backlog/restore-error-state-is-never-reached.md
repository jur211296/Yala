---
id: restore-error-state-is-never-reached
status: backlog
priority: low
area: "icloud, restore, onboarding"
created: 2026-09-21
updated: 2026-09-21
source: "medido al recorrer los call-sites de `startSearch` en `abandoned-restore-no-longer-clears-the-session-window-clock`, 2026-09-21"
---

# El estado «error» de Restaurar no lo alcanza nadie

## El problema, en lenguaje de usuario

Ninguno hoy: la pantalla de error de «Restaurar desde iCloud» no se puede ver. Lo que hay es una
pantalla escrita, traducida y mantenida que **no se pinta nunca**, y un botón «Reintentar» dentro de
ella que ningún dedo puede tocar. Si algún día una búsqueda falla de verdad, lo que la persona ve es
otra cosa.

## Medido (2026-09-21)

`WelcomeRestoreView.ViewState` declara `case error` (línea 46) y el `switch` del body lo pinta
(línea 142, `errorView`), pero **`state = .error` no aparece ni una vez en el fichero**:

```
$ grep -n "state = \." Yala/App/Views/Onboarding/WelcomeRestoreView.swift
115,122,158,191,199,216,261,264,266,489,531,549,587   ← ninguno es .error
```

`state` es `@State private`, así que nadie puede asignarlo desde fuera. `errorView` (línea ~528) y
sus dos claves de copy (`L10n.Welcome.Restore.errorTitle`, `errorBody`) son código y traducciones
muertas en las 7 lenguas.

`showRefreshToolbar` (línea 83) incluye `.error` en su lista de estados que ofrecen «volver a
buscar», así que el conteo de «los cinco botones de reintentar» de esa pantalla es realmente **cuatro
alcanzables**. Lo dicen así el docblock de `ICloudRestoreSessionSignal.noteRestoreStarted` y el test
`aRetryGetsItsOwnTokenAndCanCloseItsWindow`.

## Qué hay que decidir

Dos salidas y ninguna es obvia:

- **Retirar el caso** — menos código muerto, menos copy que mantener en 7 idiomas, y el conteo de
  botones deja de mentir. Pero si mañana hace falta un estado de error, hay que reescribirlo.
- **Cablearlo** — `startSearch` no tiene hoy ningún camino de fallo distinto de `.iCloudDisabled`; el
  candidato sería un error de la búsqueda de CloudKit que hoy cae en `.notFound` o
  `.cloudUnverified`. Eso es un cambio de producto: afirma un hecho distinto sobre los datos del
  usuario, que es la misma razón por la que `.notFound`, `.cloudPaused` y `.cloudUnverified` son
  casos separados.

## Criterios de aceptación

- [ ] `WelcomeRestoreView` no tiene estados que el `switch` pinte y nadie asigne.
- [ ] Si el caso se retira, sus claves de copy se retiran también de las 7 lenguas.
- [ ] Los sitios que cuentan «los cinco botones de volver a buscar» quedan al día con el número real.
