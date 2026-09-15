# Un 401 por App Attest ausente deja de leerse como «Tu sesión caducó»

## Contexto
Ticket: `tickets/backlog/groups-sync-reads-a-missing-attest-401-as-a-session-expiry.md` (medium).
Sale de la medición de `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` (PR #171 ya en 2.1).
Misma familia: el canal de grupos llama «caducada» a una sesión que no lo está.

## Decisión Jürgen (2026-09-15) — YA TOMADA, no repreguntar
Tratar `yala_attest_required` como **pasajero**: leer el `code` del envelope del 401; no enseñar «Tu sesión caducó» ni parar el loop (`stopUntilSignIn`). Dejar rastro en logs. Opción 1 del ticket.

## Que se pide
Implementar esa decisión en el cliente de sync de grupos (y revisar si `GroupsMembershipClient` tiene el mismo 401→sessionExpired). Tests que fijen el caso. Gate, commit, actualizar board (`tickets/` + `docs/TICKETS.md`), PR, merge a 2.1, `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Solo parar ante decisión/acceso real que no esté ya decidida arriba.

## Día / AskUserQuestion (6:00–21:00 Lima)
Esta sesión es DIURNA. Si aparece una decisión de producto o de acceso nueva (no cubierta por la decisión de arriba), usa AskUserQuestion — Jürgen está disponible. No inventes decisiones grandes.

## Que NO hay que tocar
marketing/. No reabrir el copy offline ni el wake-on-foreground (tickets hermanos con su propia decisión; no mezclar en este PR salvo fix mínimo colateral).

## Como se sabe que esta bien
Un 401 con `yala_attest_required` ya no produce copy/loop de sesión caducada; se trata como fallo pasajero con log; tests verdes; ticket cerrado en board + índice; PR mergeado a 2.1; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando:
(1) necesitas decisión de producto/acceso de Jürgen;
(2) abriste el PR o dejaste preview/artifact listo;
(3) terminaste y vas a /cerrar-total — resumen corto en lenguaje de usuario;
(4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, sesión lanzada desde encargo): son recomendaciones de Frank y se dan por buenas;
> se discuten en el PR. Ninguna es una decisión de producto nueva —todas aplican la de Jürgen del 2026-09-15,
> «`yala_attest_required` es pasajero»—, así que no hubo AskUserQuestion.

**Hechos medidos antes de decidir.**

- Las cuatro guards (`groups/routes.ts`, `groups/rpc.ts`, `sync/routes.ts`, `sync/account.ts`) responden 401 con dos
  códigos: `yala_attest_invalid` si el JWT no vale, y `yala_attest_required` si falta el JWT o si el JWT vale y el
  token de attest falta o no verifica. `jsonError` escribe el mismo valor en `type` y en `code`.
- Estos clientes nunca mandan una petición sin JWT (`guard` sobre el token). Para ellos `yala_attest_required`
  significa siempre «sesión buena, attest ausente».
- `/groups/rpc/:fn` no reenvía ningún 401 de PostgREST: sus fallos salen como 400 `yala_rpc_error` o 502. Todo 401
  de esa ruta sale de la guard.
- El canal personal pregunta por el attest antes de subir (`CloudSyncRuntime.performCycle`, paso 2,
  `resolveAttest`), y sin él no manda la petición. El de Grupos no pregunta: manda sin cabecera.

**D1 · Qué campo del envelope se lee** → `error.type`, con `GatewayErrorEnvelope.isAttestRequired` junto a sus dos
hermanos.
Por qué: `type` es el discriminante declarado del gateway (`errors.ts`) y el que ya leen `isGroupsChannelDisabled` e
`isAccountReverting`; en este 401 `code` vale lo mismo. Alternativa descartada: `code`, la letra de la decisión. Se
puede sobreescribir (`yala_rpc_error` lo hace) y partiría en dos la lectura del envelope. El test del gateway fija
que en este 401 los dos coinciden.

**D2 · Qué salida de la guard pasa a pasajera** → solo `yala_attest_required`. `yala_attest_invalid` sigue siendo
sesión caducada, con su reintento del JWT.
Por qué: el primero dice que el JWT vale; el segundo, que no. Alternativa descartada: todo `yala_attest_*`, que leería
pasajera una sesión muerta y la dejaría reintentando para siempre sin pedir volver a entrar.

**D3 · El reintento del 401** → `yala_attest_required` no fuerza el refresh del JWT ni re-emite. Se clasifica dentro
de `send`, así que también cuenta en la re-emisión que sigue a un `yala_attest_invalid`.
Por qué: un JWT nuevo no trae el attest. Alternativa descartada: reintentar el attest una vez; la decisión es
«pasajero», con el backoff que ya existe.

**D4 · Push y pull del canal de sync** → cambian los dos: rastro en el log y `.transient`.
Por qué: son los que paran el loop y dan el motivo del cierre de sesión.

**D5 · `GroupsMembershipClient`** → cambia también: rastro en el log y `.transient(status: 401)`.
Por qué: tiene el mismo 401 → `.sessionExpired`, y la decisión prohíbe enseñar «Tu sesión caducó». Medido por
consumidor:

- Salir de un grupo: de «Tu sesión caducó» a «No pudimos completar tu salida del grupo. Vuelve a intentarlo en un
  momento.»
  (`GroupLeaveErrorLogic` → `.retryLater`).
- Aceptar una invitación: deja de abrir el inicio de sesión de Grupos, que no arreglaba nada; conserva la invitación y
  el reconciler reintenta (`GroupBackendAcceptErrorLogic` → `.transient`).
- Salida en lote, transferir la propiedad, consentimiento y borrado de cuenta: sin cambio, ya trataban igual los dos.
- Crear grupo, aprobar y expulsar pintan el `localizedDescription` crudo: cambia el número del discriminante (2 → 1)
  en un mensaje que ya era crudo. Crear invitación enseña su copy fijo.
- Los RPC reintentables hacen 3 peticiones (1 s y 3 s); `create_group` y `create_group_invite` no reintentan. No hay
  ambigüedad «quizá se aplicó»: la guard rechaza antes de llamar al RPC.

Alternativa descartada: dejarlo a un ticket, como el del token nulo
(`groups-actions-read-an-offline-token-refresh-as-a-session-expiry`). Aquel se separó por los RPC de un solo intento,
y ese riesgo no existe con un 401 de la guard.

**D6 · `GroupsMerkleClient` y `PushTokenRegistrationClient`** → no se tocan.
Por qué: su 401 no llega a nada visible. El único lector del Merkle colapsa todo lo que no sea snapshot en `.skipped`,
y `PushTokenRegistrar` trata igual `.sessionExpired` y `.transient`.

**D7 · Canal personal** → fuera; se anota en `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`.
Por qué: son el mismo cliente y las mismas líneas que aquel ticket. Corregido tras la review: pedir el attest antes de
subir no lo evita del todo, porque `resolveAttest` solo mira la caché local.

**D8 · Rastro en logs** → `GroupsSyncBreadcrumb.groupsAttestRequired(edge:)`, `notice` fuera de `#if DEBUG` como el
resto de breadcrumbs, sin PII. `edge` = `push`, `pull` o `rpc:<fn>`.
Por qué: la decisión pide logs. Alternativa descartada: una métrica; el gateway ya registra en servidor cada
`[gw-err] 401 yala_attest_required`.

**D9 · Tests, en las dos direcciones.**

- Sync: push y pull con `yala_attest_required` → `.transient` sin refresh; con `yala_attest_invalid` →
  `.sessionExpired`; JWT caducado y después attest ausente → `.transient` en la re-emisión; el loop entra en backoff
  en vez de parar; el motivo que enseña el cierre de sesión.
- Membresía: `.transient(status: 401)` con reintento; lo que ve la persona al salir y al aceptar; `yala_attest_invalid`
  sigue caducada; el literal del wire.
- Gateway (vitest offline, fichero nuevo): en push, pull, merkle y rpc, JWT inválido → `yala_attest_invalid`; JWT
  válido sin attest, o con uno que no verifica → `yala_attest_required`; y `code == type`. Es la premisa de D1 y D2, y
  hoy solo la fija `sync/account.ts`.

**D10 · Mutantes** → quitar la rama en push, en pull y en membresía; ensanchar el predicado a `yala_attest_*`; un
typo en el literal. Los cinco tienen que caer.

**D11 · Lo que caduca con el cambio** → los docblocks de `BlockReason.sessionExpired`, `AttestSessionProvider.live`,
`GroupsRPCError.sessionExpired` y `PushOutcome.sessionExpired`; el ticket
`cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`, que ponía el attest de ejemplo; una línea en
`signout-pending-copy-says-wait-seconds-when-offline`, porque el attest también cae en ese aviso; la relación en
`groups-actions-read-an-offline-token-refresh-as-a-session-expiry`; y la regla durable en
`.claude/rules/gateway-attest.md`.

**D12 · Dónde queda el ticket** → `qa`, con guion de device-QA para Jürgen.
Por qué: el caso solo existe con `ENFORCE = "enforce"`. Un build de Xcode del scheme `Yala` lo produce siempre, porque
su attest no verifica en producción, pero hace falta iniciar sesión con una cuenta real.
