---
id: invite-backend-stale-config
status: qa
priority: high
area: "groups, sync, backend, invites, remote-config"
created: 2026-07-31
updated: 2026-09-02
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

> [!warning] Esta frase decía «los enlaces de los grupos que no se han migrado siguen funcionando
> exactamente igual que antes», y **hoy es falsa**. Se corrige aquí porque es la que más caro sale
> en una corrida de QA: quien la lea de arriba clasificará como fallo un comportamiento que es el
> esperado. Re-medida contra el árbol de hoy (HEAD `553b91c9`), no heredada.

Los enlaces **antiguos** —los de un grupo que nunca se migró al canal nuevo— **ya no unen a nadie**.
Quien toque uno ve una alerta: **«Enlace no válido — Este enlace ya no es válido o expiró. Pídele al
admin que regenere uno.»** No es un fallo: el transporte que servía esos enlaces se retiró en la
Fase 3, y el aviso es deliberado, porque un enlace que no hace nada es el peor final posible. El
consejo que da además es cierto: el enlace que regenere el admin será del canal nuevo, y ése sí
funciona.

**Para quien corra la QA: esa alerta con un enlace viejo es el resultado CORRECTO, no un defecto.**
Lo que sí sería un defecto es tocar el enlace y que no pase absolutamente nada.

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
| `Yala/App/Logic/GroupInviteChannelRoutingLogic.swift` **(nuevo)** | La decisión, pura: `route(isBackendLink:flagEnabled:didRefreshFlags:)` → `.backend` / `.ckShare` / `.refreshFlagsThenRetry` / `.backendUnavailable`. `isBackendLink == false` → `.ckShare` siempre, con el flag como esté. ⚠️ La coletilla «(canal viejo intacto)» que llevaba esta celda **es falsa desde la Fase 3** y se retira: `.ckShare` ya no une, informa. El comentario del propio `route` (medido en `:66-67`) sigue diciendo «mantiene el camino CKShare literalmente intacto» — **es la misma frase caducada, en el código**; queda anotada aquí, no la corrijo porque este ticket no toca `.swift` |
| `Yala/App/AppBootstrapper.swift` | `handleInviteLink` partido en el enrutado (consume la lógica pura) + `enterBackendInvite` (canal nuevo). Nuevo helper `persistBackendInviteIntent` = beta unlock + intent + canario, con tres llamadores. ⚠️ La celda listaba además un `processCKShareInviteLink` (canal viejo, extraído tal cual): **ya no existe** — `grep -rn processCKShareInviteLink` sobre el árbol de hoy da **cero** resultados, la Fase 3 se lo llevó y en su lugar hay una rama `case .ckShare` que informa |
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

`GroupBackendInviteEntryLogic.routesToBackend` codifica la premisa que este fix refutó y **nunca tuvo un call-site de producción** — solo cuatro tests verdes «demostrando» algo que el producto no hacía.

**Sigue viva, re-medida el 2026-09-02 contra HEAD `553b91c9`.** `grep -rn routesToBackend --include="*.swift" .`: el único resultado bajo `Yala/` es su propia definición, en `GroupBackendInviteEntryLogic.swift:77` (la coordenada de partida era `~:77` y cae exacta). Los cinco call-sites reales están todos en `YalaTests/` — `GroupBackendInviteEntryLogicTests.swift:68,72,73` y `GroupBackendInviteParserTests.swift:115,127`. (Otros dos aciertos del grep son ruido: `GroupInviteChannelRoutingLogicTests.swift:30` y `GroupBatchStepZoneTests.swift:175` son **nombres de test** que contienen la palabra, no llamadas.) El docblock de la función ya lleva la advertencia. **Limpieza aparte, no de esta QA.** Es la misma familia que el `AppAttestClient.ensureRegistered()` de `.claude/rules/gateway-attest.md`, que costó una vuelta entera de diagnóstico. Lleva la advertencia en el docblock; **borrarla, junto con los tests que solo la ejercitan, queda para un commit aparte** (hay un chip de sesión con el detalle) porque eliminar tests verdes no entraba en el alcance aprobado de este fix.

## 2026-08-17 — re-medición contra 2.0.5

Árbol: `jur211296/Yala` rama `2.0.5`, HEAD `012cabe0`. **No se ejecutó QA hoy.** `status` / `qa-status` se dejan (`needs-testing`: mixto).

**Premisa FALSE / obsoleta (D) — solo caso 3:** «enlace CKShare de un grupo NO migrado → camino de siempre, intacto». Bajo Fase 3 ese camino **no une**. Evidencia: `GroupInviteChannelRoutingLogic.route` (si `isBackendLink == false` → `.ckShare`; el docblock del helper aún afirma el camino viejo intacto) y `AppBootstrapper.handleInviteLink` case `.ckShare` (error + canary `ckShareChannelRemoved`; no persiste intent). `SplitSyncManager` / acceptShare → **404**. Commit del fix original `4671fd0e` existe; no se revirtió el enrutado por forma.

**Sigue TRUE (no tocar):** parser backend **antes** y sin gate; `refreshIfDue(force: true)`; aviso de canal apagado por `.showGroupSyncError` + `groups.invite.channelUnavailable`.

**REMAINS (C) — owner / TestFlight, no Xcode ni staging:**

- (1) enlace backend con config ya fresca → se une normal.
- (2) **reescrito el 2026-09-02, ver abajo.**
- (4) cold launch + enlace backend → se une tras el arranque. ⚠️ Le aplica el mismo agujero que a (2):
  el arranque en frío es justamente donde vive. Lo que hay que esperar es que el invitado **vea
  primero la alerta** y entre al grupo más tarde, cuando la reconciliación retome la solicitud
  guardada. Que esa segunda mitad ocurra **no está medido** — es lo que este ticket afirma
  (intent con TTL de 7 días, cuatro disparadores), no lo que nadie haya visto pasar.

No correr el caso 3 como «CKShare intacto». No cerrar el ticket. Joan revisa el nombre.

### Criterio (2), reescrito — 2026-09-02

**Antes decía:** «enlace backend con config vieja (snapshot < 6 h) → se une igual, sin mensaje de
error (refresh forzado)». **Ese criterio hace fallar la QA por el motivo equivocado**: da por hecho
que el refresco forzado siempre corre, y hay un caso muy común en el que no corre.

**El agujero.** El `force` salta el intervalo mínimo de 6 h, pero **no salta un refresco que ya está
en marcha**. Medido en `Yala/Services/CloudSync/CloudRemoteConfig.swift`: `guard !inFlight` está en
la **línea 255** y el `guard force || shouldRefresh(...)` en la **257** — el que devuelve primero es
el de arriba, así que con otro refresco en vuelo el forzado se va sin tocar la red. Y en un arranque
en frío siempre hay uno en vuelo: el propio arranque lo lanza (`AppBootstrapper.swift:297-298`).

**Qué ve el usuario cuando eso pasa:** acaba de instalar Yala, abre el enlace y en lugar de entrar
al grupo le sale **«No pudimos abrir esta invitación ahora. Guardamos tu solicitud: vuelve a
intentarlo en un momento.»** — un mensaje cuya causa es falsa, porque Grupos puede estar encendido
para él; lo único que pasó es que la app no llegó a preguntarlo.

**Criterio nuevo, para quien corra la QA:**

- Con la app **ya abierta y asentada** (sin refresco de arranque en vuelo): enlace backend con
  snapshot viejo → **se une, sin mensaje de error**. Esto es lo que el criterio original describía
  y sigue siendo lo exigible.
- En **arranque en frío**, o con el enlace tapeado en los primeros segundos: ver la alerta de
  «no pudimos abrir esta invitación ahora» **NO es un hallazgo nuevo** — es este defecto, ya
  levantado. No abras otro ticket, no lo persigas: anótalo contra
  **`tickets/qa/invite-refresh-forzado-es-noop-si-hay-otro-en-vuelo.md`**, que lleva la cadena
  completa con coordenadas.
- Lo que **sí** hay que comprobar en ese caso: que la solicitud quedó guardada y el invitado acaba
  entrando sin pedir otro enlace. Si tampoco ocurre eso, **eso sí es un hallazgo nuevo**.

### Actualización 2026-09-05 — el agujero está cerrado, y eso INVIERTE el criterio

El defecto que describe todo el bloque de arriba ya está arreglado en `2.1`
(`tickets/qa/invite-refresh-forzado-es-noop-si-hay-otro-en-vuelo.md`, movido de `backlog` a `qa`):
un `force` que llega con otro refresco en vuelo ahora **espera** a ese refresco en vez de rendirse.

⇒ **Con un build que lleve ese fix, ver la alerta en arranque en frío ya NO es «este defecto, ya
levantado»: es un FALLO.** Lo que hay que exigir en el caso (4) es lo que el criterio original
pedía —**se une, sin mensaje de error**— también con el enlace tapeado en los primeros segundos.

Sigue en pie la única razón legítima para ver la alerta ahí: que el servidor de verdad no conteste
(el fetch esperado falla Y el reintento propio del `force` también). En ese caso el mensaje dice la
verdad, y la comprobación de siempre —que la solicitud quedó guardada y el invitado acaba entrando—
mantiene su valor.

**Ojo con qué build corres.** Si la tanda se ejecuta sobre TestFlight **12** (CPV 12), ese build es
ANTERIOR al fix y le aplica el criterio viejo. El criterio nuevo empieza en el primer build que
incluya el commit de ese ticket.

## 2026-09-02 — receta de QA que SÍ sale en simulador

Hasta hoy este ticket mandaba todo a TestFlight, y eso dejaba sin cubrir las dos alertas, que son
lo que más fácil se malinterpreta. **Los dos casos de abajo se reproducen en el simulador**, sin
device, sin staging y sin tocar el rollout.

Escrita leyendo el código en HEAD `553b91c9`. **No la ejecuté** — no me toca correr builds. Lo que
sigue está MEDIDO en el fuente; el resultado en pantalla es lo que ese fuente produce, INFERIDO.

### Montaje

1. **Yala Dev, lanzado a mano desde Xcode o desde el simulador. Sin `-uitest`.** No es un detalle:
   bajo ese argumento el canal se lee **siempre encendido** y el toggle de abajo **no hace nada**.
   Medido: `CloudRemoteConfig.decide` corta en `isRunningTests || isUITestHost` (`CloudRemoteConfig.swift:186`)
   antes de mirar la key de debug (`:188`); `isUITestHost` es literalmente `arguments.contains("-uitest")`
   (`:174-180`), y el `absentDefault` de un build DEV es `true` (`:120-126`). Correr esto desde un
   XCUITest da verde por el motivo equivocado.
2. **Ajustes → Almacenamiento → fila «Modo Nube · Auth»** (subtítulo «Panel DEBUG (solo Yala Dev)»).
   La fila está bajo `#if DEV_BUILD` en `StorageSettingsView.swift:66-67`; hay una gemela en la
   pantalla de iCloud, sirve igual.
3. Dentro del panel, en la tarjeta de remote-config, activar **«Simular remote OFF (kill-switch)»**
   (`CloudSyncDebugView.swift:888`). Escribe `cloudSync.debug.remoteFlagsForceOff` y con eso el canal
   de Grupos se lee apagado sin tocar red ni staging. **Acuérdate de apagarlo al terminar**: queda
   guardado y se lleva a la siguiente sesión.

### ⚠️ El enlace exige el parámetro `s`, o no llega ni al handler

Un enlace sin `s` **se descarta antes de que nadie lo mire**: no hay alerta, no hay log de invitación,
no pasa nada — y es facilísimo confundir eso con el bug original de «la app se abre y no ocurre nada».

**Corrijo la pista con la que llegué a esto:** el que exige `s` **no** es `extractBackendInvite`. Ese
parser acepta `g`+`t` en el nivel de arriba y ni mira `s` (`InviteLinkService.swift:146-147`); solo lo
usa como plan B. Quien lo exige es el portero de antes, **`InviteLinkService.isInviteLink`**
(`:221-228`), y lo hace en `:223` comprobando **únicamente que el parámetro exista** — su valor le da
igual. Ese portero está en los dos caminos de entrada: `AppBootstrapper.swift:1888` (deep link) y
`YalaAppDelegate.swift:95` (universal link).

Consecuencia práctica: `s=x` basta para pasar. No hace falta fabricar un base64 válido.

### Caso A — canal apagado (la alerta de «guardamos tu solicitud»)

Con el toggle **activado**:

```
xcrun simctl openurl booted "yaladev://invite?g=demo&t=demo&s=x"
```

Esperado: alerta **«No pudimos abrir esta invitación ahora. Guardamos tu solicitud: vuelve a
intentarlo en un momento.»**, y la solicitud guardada en el teléfono. El título **no** debe ser
«Enlace no válido» — si lo fuera, sería un fallo real: mandaría al invitado a pedir un enlace nuevo
que tampoco le serviría.

Recorrido medido: el enlace parsea, el flag se lee apagado ⇒ `route` da `.refreshFlagsThenRetry`
(`GroupInviteChannelRoutingLogic.swift:70`), se guarda la solicitud y se fuerza el refresco
(`AppBootstrapper.swift:2007-2010`), se reentra (`:2011`), el flag **sigue** apagado —el toggle gana
sobre lo que diga la red— ⇒ `.backendUnavailable`, canario `backendChannelOff` (`:2020`) y la alerta
(`:2026-2027`).

> [!warning] Esta receta produce **la misma alerta** que el defecto de arranque en frío del criterio
> (2), pero por otra causa. **No sirve para probar aquel bug**: aquí el canal está apagado de verdad
> —lo apagaste tú—, allí está encendido y la app no llegó a preguntarlo. No des por reproducido
> `invite-refresh-forzado-es-noop-si-hay-otro-en-vuelo` con esto.

### Caso B — enlace antiguo (la alerta de «enlace no válido»)

El toggle **da igual** aquí; este camino no mira el flag.

```
xcrun simctl openurl booted "yaladev://invite?s=aHR0cHM6Ly93d3cuaWNsb3VkLmNvbS9zaGFyZS8wYWJjREVGZ2hpSktMbW5vUFFSc3R1"
```

Ese `s` es un enlace de compartir de iCloud en base64url: no lleva grupo ni token dentro, así que el
parser del canal nuevo lo rechaza y el enlace cae al camino antiguo.

Esperado: alerta **«Enlace no válido — Este enlace ya no es válido o expiró. Pídele al admin que
regenere uno.»** y el canario `ckShareChannelRemoved` (`AppBootstrapper.swift:1987`). **Eso es lo
correcto**, ver el aviso del principio del ticket. El fallo aquí sería el silencio.

(Si haces la prueba con el build de producción en vez de Yala Dev, el esquema es `yala://` en lugar
de `yaladev://` — medido en `URL_SCHEME` del pbxproj. Pero el toggle del caso A no existe fuera de
Yala Dev, así que el caso A solo sale en Dev.)

### Lo que esta receta NO cierra

Todo lo que exige **unirse de verdad** a un grupo — es decir, los casos (1), (4) y la mitad
«asentada» del (2). El simulador no puede darlos: el toggle solo sabe **apagar** el canal, nunca
encenderlo, y un grupo y un token reales no salen de aquí. **Siguen siendo de TestFlight y del
owner.** La receta cubre las dos alertas y la persistencia de la solicitud; no cubre el join.

Tampoco cierra el defecto del arranque en frío, por lo dicho en el aviso del caso A.

migrated from YalaWiki Bugs/qa_invite-backend-mudo-config-stale.md @ 1934e8ad
