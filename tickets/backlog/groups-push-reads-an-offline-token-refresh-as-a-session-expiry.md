---
id: groups-push-reads-an-offline-token-refresh-as-a-session-expiry
status: backlog
priority: medium
area: "modo-nube, groups, sesión"
created: 2026-09-15
source: "medición del encargo `cloud-signout-collapses-a-groups-session-expiry-into-permanent` (2026-09-15), confirmada por una lente adversarial"
---

# «Tu sesión caducó» también le sale a quien solo está sin conexión

## El problema, en lenguaje de usuario

Anoto un gasto de grupo sin conexión. La app se queda más de una hora en segundo plano. Sigo sin red, abro Yala
y toco «Cerrar sesión». La app me dice **«Tu sesión caducó. Vuelve a iniciar sesión e inténtalo de nuevo.»** Mi
sesión está bien: lo que falla es la conexión. Y si le hago caso, sin red tampoco puedo volver a entrar.

## Lo medido (leído en la app y en el SDK, sin ejecutar)

- supabase-swift 2.50.0 da el token por caducado 30 s antes de tiempo (`Types.swift:143-145`,
  `Constants.swift:12`), y entonces `session()` intenta renovarlo (`Internal/SessionManager.swift`).
- Sin red, la renovación lanza el error de red y **no** borra la sesión. Solo la borran cuatro respuestas del
  servidor: `session_not_found`, `session_expired`, `refresh_token_not_found` y `refresh_token_already_used`
  (`Internal/APIClient.swift:43-48`). O sea que `CloudAuthService.hasSession` sigue en `true`.
- `CloudAuthService.accessToken()` convierte **cualquier** error en `nil` (`CloudAuthService.swift:233-241`).
- `GroupsSyncClient.pushPending` pide el token antes de nada y, sin él, devuelve `.sessionExpired(pending:)` sin
  hacer ninguna petición (`GroupsSyncClient.swift:1448-1450`). Su reintento del 401 no llega a correr. El pull
  hace lo mismo (`:1800`).
- `CloudSignOutFlowLogic.classify` lo convierte en `.sessionExpired`, y el aviso sale con
  `groups.errors.sessionExpired`.
- No hay nada delante que mire la red: el ciclo de grupos no consulta ningún monitor.

## A quién le llega

- **Cerrar sesión en la nube**, desde `cloud-signout-collapses-a-groups-session-expiry-into-permanent`
  (2026-09-15). Antes decía «revisa tu conexión», que para este caso era lo cierto.
- **Cerrar sesión en el «equipo» y en solo grupos**, desde el paso 9: van por `pushGroupsForSignOut`, que
  propaga el motivo.
- **El desasociar** de Almacenamiento (`detachBlockedSession`), **la puerta de Grupos del Welcome** y **la hoja del
  cambio de Apple ID**, que leen el mismo motivo.
- **Sin medir:** ante `.sessionExpired` la cadencia de grupos para con `.stopUntilSignIn`
  (`GroupsSyncClient.swift:398`) y solo re-arranca en el próximo `startIfEligible`. Si ese arranque no llega al
  volver la red, los cambios se quedan sin subir hasta relanzar.

## Lo que hay que decidir (Jürgen)

1. **Separar «sin red» de «sesión caducada» donde se sabe.** Con la sesión guardada (`hasSession == true`), un
   token que no llega es un fallo pasajero; «tu sesión caducó» solo cuando el SDK la borró. Arregla a la vez las
   cuatro celdas, el desasociar y el Welcome, y cambia la cadencia.
2. **Dejar el clasificador y suavizar el texto** para que no afirme la causa.
3. **Dejarlo**, sabiendo que exige estar sin red y con el token caducado a la vez.

Recomendación: la 1. El cliente es el único sitio donde se distinguen los dos casos, y el SDK ya los separa.

## Criterios de aceptación (si se elige la 1)

- [ ] Con la sesión guardada y la renovación fallida, el push de grupos no devuelve `.sessionExpired` (test).
- [ ] Con la sesión borrada por el SDK, sí (test en la dirección contraria).
- [ ] La cadencia vuelve a subir sola al recuperar la red, sin relanzar la app.

## Cómo reproducirlo (device)

1. Yala Dev, cuenta en la nube con un grupo.
2. Pon el modo avión y crea un gasto de grupo.
3. Deja la app en segundo plano hasta que pase la hora `exp` de Ajustes → «¿Dónde viven tus datos?» →
   «Modo Nube · Auth».
4. Sin quitar el modo avión, Ajustes → «Cerrar sesión» → confirma en la hoja.
5. Hoy sale «Tu sesión caducó…». Con la opción 1 debería salir «Los últimos cambios de tus grupos no llegaron al
   servidor…».

## Relación con otros tickets

- `cloud-signout-collapses-a-groups-session-expiry-into-permanent` — la decisión que lleva el caso a la nube.
- `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door` — el mismo aviso cuando la sesión sí caducó.
- `groups-outbox-rows-without-a-live-session-have-no-exit` — quien no puede volver a entrar de ninguna forma. Su
  síntoma ya narraba este caso («anoté gastos de grupo sin conexión y mi sesión caducó»).
