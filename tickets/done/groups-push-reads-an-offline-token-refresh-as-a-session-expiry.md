---
id: groups-push-reads-an-offline-token-refresh-as-a-session-expiry
status: done
priority: medium
area: "modo-nube, groups, sesión"
created: 2026-09-15
updated: 2026-09-23
source: "medición del encargo `cloud-signout-collapses-a-groups-session-expiry-into-permanent` (2026-09-15), confirmada por una lente adversarial"
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - sin red, token caducado y gasto pendiente a la vez, unos 75 min; GroupsSyncClientTests y contrato con el SDK
---

# «Tu sesión caducó» también le sale a quien solo está sin conexión

## El problema, en lenguaje de usuario

Anoto un gasto de grupo sin conexión. La app se queda más de una hora en segundo plano. Sigo sin red, abro Yala
y toco «Cerrar sesión». La app me dice **«Tu sesión caducó. Vuelve a iniciar sesión e inténtalo de nuevo.»** Mi
sesión está bien: lo que falla es la conexión. Y si le hago caso, sin red tampoco puedo volver a entrar.

## Lo medido (leído en la app y en el SDK, sin ejecutar)

> Las coordenadas son de la medición, anteriores al cambio del 2026-09-15.

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

- [x] Con la sesión guardada y la renovación fallida, el push de grupos no devuelve `.sessionExpired` (test).
- [x] Con la sesión borrada por el SDK, sí (test en la dirección contraria).
- [x] La cadencia vuelve a subir sola al recuperar la red, sin relanzar la app. En el loop propio de Grupos; en
      `.cloud` Grupos cicla dentro del runtime personal, que seguía parándose hasta
      `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-16).

## Relación con otros tickets

- `cloud-signout-collapses-a-groups-session-expiry-into-permanent` — la decisión que lleva el caso a la nube.
- `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door` — el mismo aviso cuando la sesión sí caducó.
- `groups-outbox-rows-without-a-live-session-have-no-exit` — quien no puede volver a entrar de ninguna forma. Su
  síntoma ya narraba este caso («anoté gastos de grupo sin conexión y mi sesión caducó»).

## Hecho el 2026-09-15 — opción 1

**Lo que cambia para la persona.** Sin conexión y con el token caducado, ninguna pantalla dice ya «Tu sesión caducó»
ni manda a volver a entrar:

- **Cerrar sesión con una cuenta en la nube:** al momento, «Los últimos cambios de tus grupos no llegaron al
  servidor…».
- **«Equipo», solo grupos, hoja del cambio de Apple ID y puerta de Grupos del Welcome:** tras unos 45 s de reintentos,
  el aviso de lo pasajero, «Todavía estamos terminando de guardar unos cambios…».
- **Desasociar la cuenta en Almacenamiento:** «Quedan cambios de tus grupos sin subir…».

Con la sesión borrada de verdad, las cinco siguen pidiendo volver a entrar. Y la sincronización de grupos ya no se
para: reintenta sola y sube en su siguiente intento.

**Lo que se tocó.** Las decisiones están en el Paso 0 de
`encargos/lanzados/2026-09-15-groups-push-reads-an-offline-token-refresh-as-a-session-expiry.md`.

- `GroupsSyncClient.sdkRemovedTheSession` decide las cuatro ramas sin token —el push, el pull, y el refresh forzado que
  vuelve vacío tras un 401 en cada uno—: `.sessionExpired` solo si `canRenewSession` es `false`. El ticket proponía
  `hasSession`; se usó `canRenewSession` porque `hasSession` lleva el seam `-uitest-fake-cloud-session`.
- `WelcomeGroupsGateView` gana una rama para `.transient`, con el mensaje de Ajustes y el título de la propia puerta:
  su catch-all mandaba volver a entrar.
- Al día los docblocks de `BlockReason.sessionExpired`, `canRenewSession` y `SignOutBlockedCopy`, con una regla nueva
  en `.claude/rules/swiftdata-cloudkit.md`.

**Cómo se verificó.**

- Unit: los tres criterios con tests en las dos direcciones en `GroupsSyncClientTests`, y la premisa del SDK ejecutada
  contra un `AuthClient` real (`SupabaseSessionRenewalContractTests`).
- Mutantes, todos muertos: las cuatro ramas revertidas, el predicado invertido (en rojo y sin colgar gracias al fusible
  de los tests de loop), el 401 con el mismo token consultando el predicado, y los dos de la rama del Welcome.
- Review adversarial con tres lentes (lógica, tests y lo que ve la persona). Lo que encontraron está arreglado o tiene
  ticket.

**Lo que queda, con ticket:**

- `groups-actions-read-an-offline-token-refresh-as-a-session-expiry` — salir de un grupo sin red sigue diciendo «Tu
  sesión caducó» (en `qa` desde el 2026-09-17).
- `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` — el canal personal, y con él Grupos en `.cloud`
  (en `qa` desde el 2026-09-16).
- `signout-pending-copy-says-wait-seconds-when-offline` — el texto y la espera de 45 s sin red.
- `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` — un 401 por App Attest ausente.
- `groups-loop-in-backoff-ignores-the-return-to-foreground` — volver a Yala no adelanta el reintento.

## Device-QA — NO simulable

Pide una sesión real de Supabase con el token caducado y el teléfono sin red: bajo `-uitest` no hay sesión que caduque,
y el simulador no corta la red por dispositivo.

**Montaje.** iPhone con **Yala Dev** (staging) y una cuenta con al menos un grupo. Sin movimientos personales
pendientes: en la nube bloquearían antes con el aviso genérico.

1. Ajustes → «¿Dónde viven tus datos?» → «Modo Nube · Auth». Apunta la hora `exp`.
2. Pon el **modo avión** y crea un gasto en el grupo.
3. Deja la app en segundo plano hasta que pase la hora `exp`. **No quites el modo avión.**
4. Abre Yala → Ajustes → «Cerrar sesión» → confirma en la hoja.
5. **Esperado, según la cuenta:**
   - **En la nube:** al momento, «No pudimos cerrar tu sesión» con «Los últimos cambios de tus grupos no llegaron al
     servidor…».
   - **Sesión privada con grupos, o solo grupos:** unos 45 s con «Guardando tus cambios pendientes…» y después «Un
     momento más · Todavía estamos terminando de guardar unos cambios…».
   - **En ningún caso** «Tu sesión caducó».
6. Solo sesión privada o solo grupos: quita el modo avión con la app abierta y no toques nada. El gasto sube solo en
   menos de 5 minutos (compruébalo desde otro teléfono del grupo). **En la nube también sube solo**, en menos de 5 minutos:
   tras más de una hora en segundo plano la verificación de App Attest ya caducó, y el motor personal sale pasajero en su
   puerta en vez de pararse (medido en el código el 2026-09-16). El caso en que el motor personal sí se paraba necesita esa
   verificación aún en caché, y tiene su guion en `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`.
7. **Control:** repite con la sesión borrada de verdad, con el paso 3 del guion de
   `cloud-signout-collapses-a-groups-session-expiry-into-permanent` (`delete from auth.sessions …` en staging) y **sin**
   modo avión al cerrar. Tiene que salir «Tu sesión caducó…».

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Pide estar sin red, con la sesión caducada y un gasto de grupo pendiente a la vez: unos 75 minutos. Lo cubren `GroupsSyncClientTests` y el contrato contra el SDK real.
