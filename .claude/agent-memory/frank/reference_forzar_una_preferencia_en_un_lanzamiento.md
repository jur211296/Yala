---
name: reference-forzar-una-preferencia-en-un-lanzamiento
description: -<clave> valor al lanzar gana al dominio de registro de -uitest, pero CONGELA la preferencia: un test que la cambia (reset, toggle) no puede partir de ahí
metadata:
  type: reference
---

Bajo `-uitest`, `UITestEphemeralDefaults` pone varias marcas de «visto» en el dominio de REGISTRO (p. ej.
`hasSeenGroupsNotificationPrompt`), y por eso la tarjeta «Avisos del grupo» no sale nunca en el simulador. El dominio de
ARGUMENTOS manda sobre ese: lanzar con `-hasSeenGroupsNotificationPrompt NO` (en `simctl launch` o en
`launchForUITest(extraArguments:)`) la hace salir sin tocar plist ni cfprefsd. Medido el 2026-10-28 (card rj3b).

Más barato que [[reference-forzar-preferencias-en-el-simulador]] cuando la marca vive en el dominio de registro.

**Pero congela la preferencia toda la sesión (medido el 2026-11-06, `-showsProjectedFlow NO`):** al tocar el control,
`AppPreferences` escribe en disco, el cambio de `UserDefaults` le hace releer y el dominio de argumentos vuelve a ganar:
la píldora no se encendía nunca. Sirve para FOTOGRAFIAR un estado, no para un test que la cambia; ahí, normaliza el
estado desde la pantalla. Y `-uitest-reset` borra la clave del disco pero no la de memoria si `AppPreferences` ya la
leyó: el estado puede venir de la corrida anterior.

Lo volví a pisar el 2026-11-07 con `-panelSectionsOrder planificacion,tendencias` para probar «Restablecer» de
«Configurar Panel»: el reset «no hacía nada». El orden de partida se puso arrastrando en la hoja ↕ desde el XCUITest
(`PanelSectionsConfigResetUITests.movePlanningAboveTrends`).
