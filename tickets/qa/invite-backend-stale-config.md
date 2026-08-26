---
id: invite-backend-stale-config
status: qa
priority: high
area: "groups, sync, backend, invites, remote-config"
created: 2026-07-31
updated: 2026-08-26
source: YalaWiki/Bugs/qa_invite-backend-mudo-config-stale.md
---


> [!bug] Corrida real (2026-07-31, dos iPhones contra PRODUCCIÓN, con `GROUPS_BACKEND_ROLLOUT_PERCENT` ya en 100): el invitado toca el enlace de invitación, **Yala se abre y no ocurre NADA** — ni pestaña Grupos, ni pantalla de unirse, ni mensaje. Hermano de [[qa_groups-aprobacion-no-retira-banner]] (mismo subsistema y mismo día, causa distinta).

# Validar en TestFlight: el enlace de invitación funciona aunque el device tenga la configuración vieja

## Qué veía el usuario

Le mandaban un enlace para unirse a un grupo, lo tocaba, y Yala se abría **en la pantalla de siempre, como si no hubiera pasado nada**. Ni un aviso, ni un error. Sin forma de saber si el problema era el enlace, la app o él mismo — así que lo lógico era pedir otro enlace, que tampoco iba a funcionar.

No era mala suerte ni lentitud: pasaba **siempre**, a cualquiera cuyo teléfono todavía no se hubiera enterado de que Grupos ya estaba disponible. Y como el teléfono solo se entera **cada 6 horas como máximo**, cualquier invitado podía quedarse horas así.

## Qué cambia ahora

El enlace se reconoce **por su forma**, no por lo que el teléfono crea recordar. Al tocarlo, Yala guarda tu solicitud en el teléfono y le pregunta al servidor si Grupos ya está disponible:

- Si lo está → sigue con el flujo normal de unirse.
- Si de verdad está apagado → **te lo dice**: «No pudimos abrir esta invitación ahora. Guardamos tu solicitud: vuelve a intentarlo en un momento.» Y como la solicitud queda guardada (7 días), en cuanto se enciende te une **sin que tengas que pedir otro enlace**.

Los enlaces de los grupos que no se han migrado siguen funcionando exactamente igual que antes.

## Implementación

**Fecha:** 2026-07-31 · **Commit:** `4671fd0e` · **Rama:** 2.0.5

### La causa real, que NO era la que parecía

El reporte inicial asumía que el enlace se «tragaba en silencio»: que `extractShareURL` devolvía `nil` y el código se limitaba a escribir un log. **Leyendo el código, es falso, y la diferencia cambia el fix.**

`extractShareURL` **acepta** un enlace del canal nuevo. El parámetro `s` de un enlace backend es el base64URL de `https://yala-app.pe/invite?g=..&t=..` — la forma mínima self-referential que el AASA exige que exista —, así que al decodificarlo `URL(string:)` no falla, y el guard host/path que viene después valida el **URL exterior**, no el decodificado. ⇒ devuelve una URL que no es de CloudKit **en vez de `nil`**, y por tanto el enlace **nunca llega** al `guard let shareURL else` que avisa al usuario.

Consecuencia: el invite del canal nuevo no se perdía, **se colaba al canal viejo disfrazado**. Con la app abierta, `fetchShareMetadata` le pedía a CloudKit metadata de `yala-app.pe`. Con la app cerrada, quedaba **persistido en `PendingInviteStore`** y se re-emitía en cada foreground. Cero UI en ambos caminos.

Cualquier fix apoyado en «si `extractShareURL` devuelve `nil`, entonces…» no se habría disparado jamás.

### Por qué el flag OFF no era un caso raro

`CloudSyncFlags.groupsBackendEnabled` es `compilado && CloudRemoteFlags.groupsBackendEnabled`, el snapshot del remote-config se refresca **como mucho cada 6 h** (`RemoteFlagDecisionLogic.refreshMinInterval`) y en producción `absentDefault` es `false` (fail-closed). Con el percent ya al 100, **todo invitado cuyo teléfono guardó la config antes del flip perdía la invitación durante horas.**

### Decisiones técnicas, y su porqué

**1. Se enruta por la FORMA del enlace; el flag decide QUÉ hacer, no SI se mira.** El parser backend corre sin gate y **antes** que el de CKShare. Es el invariante del fix: con el orden invertido, el enlace del canal nuevo satisface el parser viejo y vuelve el silencio.

**2. Intent durable, no «refrescar y reintentar» a secas.** Clasificado antes de escribirlo, como manda `.claude/rules/swiftdata-cloudkit.md` §24: un universal link tapeado es una **intención** (si la app la pierde, Apple no la re-entrega), no un evento con cola detrás ⇒ intent persistente. Y no hubo que construirlo: `PendingJoinStore` ya es ese molde y `GroupJoinReconcileLogic.decideBackend` ya tenía la rama `.skipFlagOff`, que **conserva** el intent (TTL 7 días) y lo reintenta en sus cuatro triggers. El agujero era solo que con el flag OFF nada lo persistía.

**3. `refreshIfDue(force: true)`, no `false`.** Sin `force`, `refreshIfDue` es un **no-op en el caso exacto del bug** («fetcheé hace menos de 6 h»). Es una acción de usuario con intención explícita, no un poll, así que no se toca `refreshMinInterval` para nadie más. El spam queda acotado por el guard `inFlight` del cliente y porque la rama solo se alcanza con enlace backend **y** flag OFF.

**4. El aviso va por `.showGroupSyncError`, NUNCA por `.showInviteError`.** El título del segundo está hardcodeado a `groups.invite.linkInvalidTitle` («Enlace no válido»), que aquí sería **falso** — el enlace es perfecto, lo apagado es el canal — y empujaría al invitado a pedir un enlace nuevo que tampoco funcionaría. Mismo criterio que ya aplica `handleJoinError`, que reserva `showInviteError` para el `invalidInvite` de verdad.

**5. El beta unlock se movió al helper de persistencia.** El reconciler completa el join vía `drive`, que no lo toca; sin esto el invitado entraría al grupo y seguiría detrás del gate de beta.

### Archivos

| Archivo | Qué cambió |
|---|---|
| `Yala/App/Logic/GroupInviteChannelRoutingLogic.swift` **(nuevo)** | La decisión, pura: `route(isBackendLink:flagEnabled:didRefreshFlags:)` → `.backend` / `.ckShare` / `.refreshFlagsThenRetry` / `.backendUnavailable`. `isBackendLink == false` → `.ckShare` siempre, con el flag como esté (canal viejo intacto). El docblock lleva el porqué completo del hallazgo |
| `Yala/App/AppBootstrapper.swift` | `handleInviteLink` partido en tres: el enrutado (consume la lógica pura), `enterBackendInvite` (canal nuevo, sin cambios de comportamiento) y `processCKShareInviteLink` (canal viejo, extraído tal cual). Nuevo helper `persistBackendInviteIntent` = beta unlock + intent + canario, que ahora tiene tres llamadores |
| `Yala/App/Logic/GroupBackendInviteEntryLogic.swift` | Advertencia en `routesToBackend`: su docblock describe la premisa **refutada** y la función no tiene —ni tuvo— call-site de producción. Ver «Deuda» abajo |
| `YalaTests/GroupInviteChannelRoutingLogicTests.swift` **(nuevo)** | 8 de tabla + 4 de source-scan. Ver abajo |
| 16 × `Localizable.strings` | `groups.invite.channelUnavailable`. Traducida a mano en los 12 locales que el script marca (`add-l10n-key.sh` + Python; **nunca** `perl -CSD` inline: mojibake que la paridad no caza) |
| `qa/coverage-index.json` | Área `groups-backend-g4-invites`: coverage + globs + `lastVerified` |
| `.claude/rules/swiftdata-cloudkit.md` | Regla durable (ver abajo) |

### Verificación

- Builds `Yala` ×2 y `Yala Dev`: exit 0, con los 3 warnings de línea base (`ContentView:1333`, `AccountEntitlementService:72` ×2).
- **107 tests en 9 suites, exit 0** — conteo comprobado contra la línea `Test run with N tests in M suites`, filtros `-only-testing` en array de zsh.
- **5 mutantes, los 5 en exit 65**, cada uno cazado por su propio test: (1) `.refreshFlagsThenRetry` → `.ckShare` (revertir el fix), (2) quitar el guard de `isBackendLink`, (3) re-inlinear `extractShareURL` en el enrutado, (4) re-gatear el parser por el flag, (5) `force: true` → `false`.
- `bash qa/validate-coverage.sh` → `RESULT: OK`.

**Por qué hay un source-scan además de la tabla.** El bug no era una decisión mal calculada: era **quién se pregunta primero**. Con el orden invertido, `route` puede ser perfecta y sus 8 tests verdes, porque nunca se la llama con `isBackendLink: true`. `GroupInviteChannelRoutingWiringTests` (molde `AttestWiringTests`) lee el fuente y exige: el parser backend está en el cuerpo del enrutado y `extractShareURL` **no**; el parser no está detrás del flag; el enrutado consume la lógica pura; el refresh lleva `force: true`. Se acota a la **función** y no al fichero a propósito, para que reordenar helpers privados no dé rojo espurio.

## Regla durable

En `.claude/rules/swiftdata-cloudkit.md`: **un gate de feature no puede decidir SI se parsea la entrada, solo QUÉ hacer con ella — y «byte-idéntico al camino viejo» es una afirmación que hay que MEDIR, no declarar.** Quien escriba esa frase debe comprobar qué hace el camino viejo **con la entrada del canal nuevo**, no solo con la del suyo. Corolario reutilizable: **recibir un payload del canal nuevo es evidencia de que el canal está encendido** — es la señal más fresca que tiene el device, más que su propio snapshot; sirve para invalidar el cache, no para tirarla.

## Deuda que deja abierta

`GroupBackendInviteEntryLogic.routesToBackend` codifica la premisa que este fix refutó y **nunca tuvo un call-site de producción** — solo cuatro tests verdes «demostrando» algo que el producto no hacía. Es la misma familia que el `AppAttestClient.ensureRegistered()` de `.claude/rules/gateway-attest.md`, que costó una vuelta entera de diagnóstico. Lleva la advertencia en el docblock; **borrarla, junto con los tests que solo la ejercitan, queda para un commit aparte** (hay un chip de sesión con el detalle) porque eliminar tests verdes no entraba en el alcance aprobado de este fix.

## 2026-08-17 — re-medición contra 2.0.5

Árbol: `jur211296/Yala` rama `2.0.5`, HEAD `012cabe0`. **No se ejecutó QA hoy.** `status` / `qa-status` se dejan (`needs-testing`: mixto).

**Premisa FALSE / obsoleta (D) — solo caso 3:** «enlace CKShare de un grupo NO migrado → camino de siempre, intacto». Bajo Fase 3 ese camino **no une**. Evidencia: `GroupInviteChannelRoutingLogic.route` (si `isBackendLink == false` → `.ckShare`; el docblock del helper aún afirma el camino viejo intacto) y `AppBootstrapper.handleInviteLink` case `.ckShare` (error + canary `ckShareChannelRemoved`; no persiste intent). `SplitSyncManager` / acceptShare → **404**. Commit del fix original `4671fd0e` existe; no se revirtió el enrutado por forma.

**Sigue TRUE (no tocar):** parser backend **antes** y sin gate; `refreshIfDue(force: true)`; aviso de canal apagado por `.showGroupSyncError` + `groups.invite.channelUnavailable`.

**REMAINS (C) — owner / TestFlight, no Xcode ni staging:**

- (1) enlace backend con config ya fresca → se une normal.
- (2) enlace backend con config vieja (snapshot < 6 h) → se une igual, sin mensaje de error (refresh forzado).
- (4) cold launch + enlace backend → se une tras el arranque.

No correr el caso 3 como «CKShare intacto». No cerrar el ticket. Joan revisa el nombre.

migrated from YalaWiki Bugs/qa_invite-backend-mudo-config-stale.md @ 1934e8ad
