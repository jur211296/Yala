# Sin red, salir de un grupo no debe decir «Tu sesión caducó»

## Contexto
Ticket: `tickets/backlog/groups-actions-read-an-offline-token-refresh-as-a-session-expiry.md` (medium).
Hermano del #188 (canal personal): el mismo patrón — renovación fallida sin red leída como sesión caducada — en acciones de Grupos (p. ej. salir de un grupo).

## NOCHE (21:00–6:00 Lima)
Sin AskUserQuestion. Aplica el mismo criterio que #188 / personal-sync: fallo de red o renovación offline ≠ sesión caducada. Si aparece decisión de producto gorda, aparca y avisa a Frank.

## Que se pide
1. Que una acción de Grupos sin red (salida, etc.) no enseñe «Tu sesión caducó» cuando solo falló la renovación/red.
2. Tests, gate, commit, tickets + docs/TICKETS.md, PR, merge a 2.1, `/cerrar-total`. Bugs/decisiones nuevas → ticket propio antes de cerrar.

## MODO AUTÓNOMO HASTA TERMINAR
Gate/commit/board/merge/cerrar-total sin preguntar. UI CI advisory (continue-on-error). No sync al Kanban del panel.

## Que NO
marketing/; no tocar previous-person-cloud-session-survives-fresh-start-and-reinstall (espera decisión Jürgen).

## Como se sabe que esta bien
Sin red, la acción de Grupos no se confunde con sesión caducada; board + TICKETS.md al día; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión de producto o acceso de Jürgen;
  (2) abriste el PR o preview/artifact listo;
  (3) terminaste y vas a /cerrar-total — resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo sin siguiente paso claro — una vez, no en bucle.
NO: test rojo a reclasificar, build a reintentar, CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (sesión nocturna, 03:45 Lima): las recomendaciones se dan por buenas. Se discuten en el PR.
> Hechos medidos en `ea583e8b0`, leyendo el código (sin ejecutar). El inventario por consumidor va al ticket.

**Lo medido que las sostiene.** `GroupsMembershipClient.call` pide el token ANTES que el attest y, sin token, lanza
`.sessionExpired` sin hacer la petición. Las 8 construcciones de producción usan el `tokenProvider` por defecto
(`CloudAuthService.shared.accessToken()`), que da `nil` por cualquier fallo. El SDK solo borra la sesión guardada ante
cuatro códigos terminales y la borra antes de lanzar (`SupabaseSessionRenewalContractTests`). Nadie lee el `status` de
`.transient` salvo `GroupLeaveErrorLogic`, que solo distingue el 401.

**D1 · Token nulo en `call`** → `.transient(status: -1)` si el SDK conserva la sesión (`canRenewSession`, leído DESPUÉS de
pedir el token); `.sessionExpired` solo si la borró.
Por qué: es el criterio de `GroupsSyncClient.sdkRemovedTheSession` (2026-09-15) y del canal personal (2026-09-16).
Alternativas descartadas: `hasSession`, que lleva el seam `-uitest-fake-cloud-session`; y clasificar el error del SDK,
que re-deriva su taxonomía en la app.

**D2 · Cómo llega el testigo al cliente** → parámetro `canRenewSession: @MainActor () -> Bool` con default
`{ CloudAuthService.shared.canRenewSession }`. Las 8 construcciones de producción no se tocan. Un source-scan fija el
default, y el test de token nulo que ya existe inyecta `{ false }`.
Por qué: el token por defecto ya sale de ese singleton, así que testigo y token vienen del mismo sitio; es el molde de
`GroupsSyncClient`. Alternativa descartada: default `{ false }` con las 8 construcciones pasándolo (molde del canal
personal), que toca 8 ficheros de UI para ganar lo que ya da el scan del default.

**D3 · Qué `status` lleva** → `-1`.
Por qué: la renovación que no llega es una petición HTTP al servidor de auth que falló, y `-1` ya dice «sin respuesta HTTP».
Con la racha de App Attest terminal, salir de un grupo no puede culpar al teléfono de un fallo de red (solo el 401 lo
hace). Alternativa descartada: un status centinela nuevo, que ningún consumidor distingue.

**D4 · El reintento corto de `callWithRetry`** — *RETIRADA tras la review (ver «Revisión»)* → entra, y cada intento vuelve a pedir el token. Los one-shots
(`create_group`, `create_group_invite`) no reintentan, como siempre.
Por qué: la red puede volver entre intentos, y sin petición no hay ambigüedad «quizá se aplicó». Coste aceptado: salir de
un grupo sin red tarda ~4 s más en avisar, lo mismo que hoy con el token vigente.

**D5 · La puerta del servicio** (`GroupBackendMembershipService.ensureEligible`, que lee `hasSession`) → sin cambio.
Por qué: sin sesión guardada la sesión sí caducó. Bajo el seam de sesión fingida el cliente lee `canRenewSession`, que
vale `false`, así que los XCUITest siguen viendo `.sessionExpired`.

**D6 · Salir de un grupo** (Ajustes del grupo, tarjeta del grupo rechazado, «Transferir y salir») → sin cambio de código:
`GroupLeaveErrorLogic` ya lleva `.transient` a «No pudimos completar tu salida del grupo. Vuelve a intentarlo en un momento.»

**D7 · Aceptar una invitación** → sin cambio de código: `.transient` deja de abrir la hoja de inicio de sesión; la pantalla
de unión espera y a los 20 s dice «Está tardando un poco más de lo normal», y el reconciler reintenta al volver a la app.
Por qué: la hoja no arregla nada sin red. Su cinturón, con la sesión guardada, se cierra solo y vuelve a intentar la unión
(leído, no ejecutado). Es el precedente del 401 de App Attest (decisión de Jürgen, 2026-09-15). La caducidad silenciosa a
los 7 días ya tiene ticket (`groups-join-intent-expires-silently-after-transient-failures`): se le añade esta población.

**D8 · El resto de consumidores** → sin cambio de código. Crear el enlace de invitación dice lo mismo en los dos casos
(«Revisa tu conexión…»). El consentimiento, «Salir de todos mis grupos», el borrado de cuenta y la corrección del nombre
ya tratan igual los dos errores. `revokeInvite` no tiene llamadores.

**D9 · Crear grupo, aprobar y expulsar enseñan el error crudo** («Error de Yala.GroupsRPCError N») → ticket nuevo, sin
implementar. Con este cambio el número pasa de 2 a 1 cuando no hay red.
Por qué: es otro defecto (el copy), anterior a este; solo existía como residual escrito en `groups-leave-rpc-error-10`.

**D10 · Verificación** → unit en las dos direcciones sobre el cliente (sin petición, cuántas veces pide el token, testigo
leído tras el token, one-shot sin reintento), de punta a punta en salir de un grupo (`GroupService.leaveGroup` + el copy) y
en la invitación (lo que se encola en el router). Mutantes: rama revertida, predicado invertido, testigo leído antes del
token, `status` 401 y el default del init. Review adversarial con tres lentes (lógica, lo que ve la persona, tests),
por `Agent`: el encargo no pide un workflow.

**D11 · Docs que dan el bug por vivo** → se corrigen en el PR: la regla de `.claude/rules/swiftdata-cloudkit.md`, los
docblocks de `GroupsRPCError`, `call`, `canRenewSession`, `GroupLeaveErrorLogic.Kind.sessionExpired`,
`GroupBackendAcceptErrorLogic.sessionRequired` y `L10n`. `docs/ESTADO.md` no se toca desde el worktree (ADR-008).

**D12 · Device-QA** → aplica y no es simulable (sesión real de Supabase con el token caducado y sin red). Guion en el
ticket, que distingue builds: la build vieja dice «Tu sesión caducó». El ticket queda en `qa`.

**D13 · Entrega** → rama y PR a `2.1`, gate, merge y `/cerrar-total`, como pide el encargo. Sin ADR: la regla ya vive en
`.claude/rules/swiftdata-cloudkit.md`.

### Revisión tras la review adversarial (tres lentes, 2026-09-17)

> Resuelta en autónomo. Tres lentes (lógica y contrato, lo que ve la persona, tests) con refutación por hallazgo; lo que
> sobrevive está medido en el código de la app y en supabase-swift 2.50.0, sin ejecutar.

**D4 se retira: el token que no se renueva sale sin el reintento corto**, en todos los RPC.
Por qué: la renovación ya es una petición al servidor de auth que el SDK reintenta dos veces (`RetryRequestInterceptor`, con
POST añadido en `Auth/Internal/APIClient`). Reintentarla en el cliente triplicaba la espera: unos 7 s sin red en vez de
~1 s, y hasta ~9 min en vez de ~3 con una red que no responde. Mi «~4 s, lo mismo que con el token vigente» era falso, y
el reintento además tapaba el mutante del orden del testigo. Sin red esperar no sube nada (el mismo criterio que
`signout-pending-copy-says-wait-seconds-when-offline`). Se implementa con un error privado que solo viaja de `call` a
`callWithRetry`. Con esto, ninguna superficie espera más que antes del cambio.

**D10 se endurece.** El test del orden del testigo cuenta tokens y esperas; un test fija que el token nulo no toca la racha
de App Attest (ni la suma ni la borra); `AttestWiringTests` fija que las 8 construcciones de producción heredan el testigo
vivo, además de la firma del init; y la suite de punta a punta restaura el contexto de `GroupService`.

**D11 se amplía.** La regla de área nombra `GroupsMembershipClient.call` entre los sitios que deciden; y el docblock de
`GroupsAccountAssociation.associate` y el punto 6 de «Migrar a la nube» dejan de dar el token nulo como la vía al cinturón
de `GroupsSignInView` (hoy es el 401 del gateway). Los docblocks de `.sessionExpired` dicen «la sesión no sirve», no «ya no
existe»: el 401 con la sesión guardada también cae ahí.

**D14 · El 401 que no es de App Attest, sin refresh forzado en las acciones** → ticket
`groups-actions-do-not-retry-a-401-with-a-forced-token-refresh` (low). Con el reloj atrasado más de 30 s, salir de un grupo
dice «Tu sesión caducó» con red y sesión buenas, y aceptar una invitación entra en el bucle del cinturón. Anterior al cambio.

**D15 · La unión que falló sin red no se reintenta al volver la red**, mientras «Está tardando…» promete que el grupo
aparecerá «apenas esté listo» → ticket `groups-join-is-not-retried-when-the-network-returns` (low, decisión de Jürgen).
Antes, para esta población, el bucle de la hoja de inicio de sesión hacía de reintento continuo; quitarlo es el arreglo.

**D16 · El reconciler puede borrar una invitación con su unión en vuelo** (miembro rechazado que vuelve a pedir entrada) →
ticket `groups-join-reconcile-can-clear-an-invite-while-its-join-is-in-flight` (low). Anterior al cambio.

**Refutado por las lentes:** que la sesión borrada se lea pasajera (el SDK la borra antes de lanzar y la puerta del servicio
corta antes); que la hoja de inicio de sesión diera una salida que se pierde (con la sesión guardada se cerraba sola); que
algún XCUITest con la sesión fingida cambie (bajo ese seam el testigo vale `false`); y que `-1` confunda a algún consumidor
(solo `GroupLeaveErrorLogic` lee el `status`, y solo distingue el 401).

