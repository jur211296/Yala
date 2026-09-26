---
description: Gateway y App Attest — qué rutas exigen el header, por qué staging no detecta que falte, y dónde vive el proveedor. Se cargan al tocar el gateway o cualquier cliente de CloudSync.
paths:
  - "gateway/src/**"
  - "gateway/test/**"
  - "gateway/wrangler.toml"
  - "Yala/Services/CloudSync/**"
  - "Yala/App/Services/AppAttestClient.swift"
  - "Yala/App/Services/ProxyClientFactory.swift"
  - "Yala/App/Logic/Attest*.swift"
  - "YalaTests/CloudSync/Attest*.swift"
---
# Gateway · App Attest · la asimetría observe/enforce

## La lección, antes que el fix

**Staging corre `ENFORCE = "observe"` y producción `ENFORCE = "enforce"`** (`gateway/wrangler.toml`, `[vars]`
vs `[env.production.vars]`). En `observe` un request SIN el header `X-Yala-Attest-Session` se **cuenta y se
deja pasar**; en `enforce` se rechaza con **401 `yala_attest_required`**. ⇒ **toda una clase de fallo —el
cliente que no manda attest— es INVISIBLE en QA y aparece solo en producción.** No es un flake ni una race:
es determinista en los dos lados, y por eso engaña. Un e2e contra staging, un device de dogfooding y la
suite entera pueden estar verdes con el canal roto.

**Corolario operativo:** un incremento que añade rutas bajo `requireUserAndAttest` NO queda verificado por
haber funcionado contra staging. La verificación tiene que ser **estructural y vivir en el repo**, porque el
único entorno que ejerce la regla es aquel al que no se puede llamar desde un test.

**Y el corolario que muerde en un incidente:** bajar `ENFORCE` a `"observe"` en producción «para probar» NO
es una herramienta de diagnóstico — apagaría App Attest para **todo** el tráfico del gateway, incluido el
proxy de IA cuyas API keys son la razón de que el gateway exista.

Costó el 401 del **2026-07-31**: con `GROUPS_BACKEND_ROLLOUT_PERCENT = 100` desplegado, crear un grupo en
TestFlight devolvía «Error de Yala.GroupsRPCError 2». `wrangler tail --env production` mostró
`POST /v1/attest/register - Ok` seguido de `[gw-err] 401 yala_attest_required` en `/groups/pull`: el device
ATESTABA bien; lo que no viajaba era el header.

## El criterio de decisión: la guard del HANDLER, nunca el cliente

Los inits de los clients declaran `attestProvider: @escaping @MainActor () async -> String? = { nil }`, y
`{ nil }` es un valor perfectamente legal ⇒ **el compilador no comprueba nada**. Nueve construcciones de
producción nacieron con el default.

Para cada construcción, la pregunta es **a qué ruta llama y qué guard usa ESE handler**:

| Guard del handler | Bajo `enforce` | Rutas |
|---|---|---|
| `requireUserAndAttest` | **401 sin header** | `/groups/rpc/:fn` · `/groups/push` · `/groups/pull` · `/groups/merkle` · `/push/register` · `/push/unregister` · `/account/delete` · `/account/siwa/revoke` · `/sync/*` · `/prefs/*` · `/attest/bind` |
| `requireUser` | pasa sin header | `/account/claim` · `/account/exists` · `/account/migration` · `/account/siwa/exchange` · `/account/entitlement` |

Las **CUATRO** definiciones de la guard estricta están DUPLICADAS a propósito y son espejos declarados:
`groups/rpc.ts`, `groups/routes.ts` (que `push/register.ts` reusa), `sync/routes.ts` y —la que esta regla
se dejó fuera hasta el 2026-08-11— **`sync/account.ts`, cuerpo byte-equivalente, que es la que sirve a
`/account/delete` y `/account/siwa/revoke`, las dos rutas más destructivas del canal**. Al tocar una, mirar
las otras: durante meses «las otras» apuntaba a 3 de 4, y la que faltaba era justo la peligrosa.

⚠️ **Y la coordenada del enforcement, que estaba mal en TRES sitios** (`AttestWiringTests.swift`,
`GroupsMembershipClient.swift`, `GroupService.swift`, corregidos en C1): en `groups/rpc.ts` el attest se
exige en el `if (enforce && !attest)` del guard, **no** en las líneas que validan el JWT de Supabase. Quien
verificara la premisa por cualquiera de esas tres puertas podía concluir que la ruta **no** exige attest.

**Cablear attest donde NO se exige puede romper el alta**: `/account/claim`, `/account/exists` y
`/account/siwa/exchange` son flujos PRE-SESIÓN, anteriores al `/attest/bind`. Por eso `CloudAccountClient`
conserva su default `{ nil }` y son sus DOS métodos destructivos (`deleteAccount`, `siwaRevoke`) los que
inyectan el proveedor — no el cliente entero.

## Reglas

- **El proveedor vivo es `AttestSessionProvider.live`** (`Yala/Services/CloudSync/AttestSessionProvider.swift`).
  Vivió anidado en `AccountDeletionService.Dependencies.liveAttest` y esa es la causa más probable de que seis
  sitios no lo encontraran: quien cablea un client de Grupos busca «attest», no «borrado de cuenta». **No lo
  vuelvas a anidar dentro de un servicio de dominio.**
- **El default `{ nil }` de los clients cuyas rutas SIEMPRE exigen attest** (`GroupsMembershipClient`,
  `GroupsSyncClient`, `GroupsMerkleClient`, `PushTokenRegistrationClient`) es **solo para tests**. No se
  invierte a `AttestSessionProvider.live` porque ~20 construcciones de la suite lo usan y llamarían al App
  Attest REAL (red) dentro de un unit test.
- **Lo que sostiene el invariante es `YalaTests/CloudSync/AttestWiringTests.swift`**, un source-scan sobre
  `Yala/`+`YalaWidgets/`+`YalaShare/` que exige `attestProvider:` en cada construcción y prohíbe el `{ nil }`
  EXPLÍCITO (que cumpliría la letra y reintroduciría el 401). Lleva un **conteo esperado por cliente**: sin
  él, un escáner roto o una clase renombrada pasarían en verde sin comprobar nada — la misma familia que
  «Executed 0 tests».
- **Un `{ nil }` que sobreviva lleva su porqué EN EL CÓDIGO**, nombrando el fichero y la línea del handler
  que lo justifica. Son **SEIS**, todos de `CloudAccountClient`, y **ninguno es un `{ nil }` literal: son
  OMISIONES del parámetro** que caen en el default del init. Importa al buscarlos —un `grep '{ nil }'` los
  pierde todos— y explica por qué el escáner los cuenta por otra vía. El sexto
  (`BornCloudSignUpService.swift`) fue el único que nació sin su porqué escrito, que es exactamente el hueco
  por el que un método que SÍ exija attest entraría sin que nadie lo viera.
- **Un método NUEVO en un client ya cableado no lo cubre el escáner.** Cuenta el `attestProvider:` del
  INIT, no los `setValue(…, forHTTPHeaderField:)` de cada método: en `GroupsMembershipClient` el header vive
  en su `call(fn:args:)` común, así que la forma de romperlo es escribir un método que NO pase por ahí, y
  eso deja los tres tests de cableado en verde. ⇒ **todo método nuevo lleva su par de transporte** (provider
  vivo ⇒ header presente, provider nil ⇒ ausente), molde `AttestHeaderTransportTests`. Los dos del consent
  de Grupos (C1, `record_groups_consent` / `groups_consent_state`) son el primer caso que lo estrena.
- **Al añadir una ruta nueva al gateway o un método nuevo a un client**, decide por la guard de su handler y
  actualiza este mapa. Si la ruta es de las estrictas, el cliente que la llame necesita el proveedor y su
  construcción tiene que entrar en el conteo del test.

## Cómo se verifica un fix de esta familia

1. **No sirve staging** (`observe` deja pasar el request roto) y **no se puede llamar a producción desde un
   test**. El pin es el source-scan.
2. **Mutación obligatoria**: quitar el cableado de un sitio tiene que dar **exit 65**, y ponerle un
   `{ nil }` explícito también. Si solo cae uno de los dos, el test comprueba la forma y no el fondo.
3. **El e2e en device contra producción lo hace el owner con un build nuevo.** Quien escribe el fix NO
   tiene forma de ejercitarlo y no debe declararlo verificado.

## Los dos 401 de la guard: sesión caducada o attest ausente (2026-09-15)

`requireUserAndAttest` responde 401 con dos códigos, y el cliente de Grupos los lee distinto:

| Código | Cuándo lo emite la guard | Qué hace el cliente de Grupos |
|---|---|---|
| `yala_attest_invalid` | el JWT de usuario no verifica | sesión caducada. Sync: reintento con refresh forzado, y `.sessionExpired` si no se rescata (`.transient` si el refresh vuelve vacío con la sesión guardada). Membresía: `.sessionExpired` directo |
| `yala_attest_required` | falta el JWT, **o** el JWT verifica y el token de attest falta o no verifica | pasajero: `.transient` con backoff, sin refresh, con `GroupsSyncBreadcrumb.groupsAttestRequired` |

- **Por qué el segundo es pasajero:** ningún cliente del canal manda una petición sin JWT, así que para ellos
  `yala_attest_required` dice «sesión buena, attest ausente». Volver a entrar no lo arregla; leído como caducada,
  paraba el loop y enseñaba «Tu sesión caducó».
- **Decide `GatewayErrorEnvelope.isAttestRequired`**, que lee `error.type` (`jsonError` escribe el mismo valor en
  `code`). En `GroupsSyncClient` va dentro de `send`, para que cuente también en la re-emisión tras un refresh;
  `GroupsMembershipClient.call` lo lanza como `.transient(status: 401)`, con su reintento corto. **El Merkle del canal
  PERSONAL sí lo distingue desde el 2026-09-22** (`reverse-verify-network-bucket-hides-a-definitive-server-no`), y no
  por gusto: ese día su 401 dejó de aplanarse y pasó a encender el aviso de «vuelve a entrar» de la vuelta a iCloud,
  así que confundirlo le pedía firmar otra vez a un teléfono cuyo problema es el attest. Con él llegó también su
  `canRenewSession`, por lo mismo. El Merkle de GRUPOS y el push token siguen sin distinguirlo: su 401 no llega a
  nada visible.
- **Al tocar cualquiera de las cuatro guards, cada código se queda en su rama**: `yala_attest_invalid` para el
  JWT, `yala_attest_required` para el attest. Fundidos, el cliente leería una sesión muerta como pasajera y
  reintentaría para siempre. En las dos guards de Grupos lo fija `gateway/test/groups.attest401.test.ts`; en
  `sync/account.ts`, `account.delete.test.ts`; en `sync/routes.ts`, `gateway/test/sync.attest401.test.ts` (2026-09-16),
  **que solo corren a mano**: el CI no
  ejecuta la suite del gateway (`ci-no-corre-la-suite-del-gateway`). Se corre con
  `npm test -- test/groups.attest401.test.ts`; el `pretest` copia los manifests, y `npx vitest` a pelo falla con
  «Cannot find module …group_capability_manifest.json».
- **El canal personal también lo lee pasajero desde el 2026-09-16** (`SyncPushClient`, `SyncPullClient`, `PrefsSyncClient`;
  ticket `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`): `yala_attest_required` es `.transient`, con
  rastro `CloudSync attestRequired edge=push|pull|merkle|prefs-push|prefs-pull` (el `merkle`, desde el 2026-09-22) y el canario `cloudSyncAttestRequired`. El resto
  de 401 sigue siendo caducada, sin el reintento con refresh forzado de Grupos
  (`personal-sync-does-not-retry-a-401-with-a-forced-token-refresh`).
- **Y ahí NO suma a la racha del teléfono, a diferencia de Grupos.** `CloudSyncRuntime.performCycle` consigue el token en
  su puerta antes de subir, así que una petición del motor llega al gateway con un token que el teléfono acuñó bien: su 401
  habla del reloj, de un build que no manda la cabecera o del servidor. La migración, la vuelta a iCloud y el adopt suben
  sin esa puerta (`MigrationWorkExecutor`, `MigrationSnapshotUploader`, con el attest pedido con `try?`): ahí el 401 sí
  puede ser un teléfono sin App Attest, y tampoco suma, como antes. Por eso el canario mezcla las dos poblaciones. En Grupos no hay puerta y el mismo 401 incluye al
  teléfono que no pudo acuñar. Contado en la racha (probado y retirado en la review del 2026-09-16) daba tres falsos
  positivos: con el reloj atrasado 24 h la puerta dejaba de borrar la racha que Grupos suma y el cierre en la nube ofrecía
  perder cambios a un teléfono que atesta; una regresión de build acababa diciendo a todo el parque «usa otro teléfono»;
  y un fallo de subida por otra cosa dejaba el aviso puesto para siempre. **Una regresión de ese tipo la cuenta el
  canario**, no el aviso. Si el aviso fijo debe cubrir a esta población es una pregunta abierta:
  `cloud-attest-notice-does-not-cover-a-gateway-rejected-token`.
- **Lo que se acepta a sabiendas, medido en la review del 2026-09-15.** Cada vuelta del loop en backoff intenta el
  attest de verdad y abre otra ventana de `AttestRefreshBackoffLogic`, que comparte con la IA y los tipos de cambio:
  cuando Apple vuelve, esos pueden recibir el error viejo hasta 60 s. Los cierres que reintentan 45 s mandan unas 23
  subidas que no aciertan si el attest no vuelve. Y una sesión revocada con el JWT aún vigente se descubre al caducar
  ese JWT, no en el refresh forzado. Antes el loop moría en la primera vuelta: nada de esto pasaba, y tampoco subía
  nada.

## El teléfono que NUNCA consigue App Attest: la racha y el veredicto terminal (2026-09-15)

Lo pasajero de arriba es cierto para quien recupera el attest en un rato, y mentira para quien no lo recupera nunca: oía
«en un rato» para siempre y no podía cerrar sesión con cambios de grupos sin subir. Decisión de Jürgen (ticket
`groups-phone-that-never-attests-is-told-to-retry-forever`): **tras 24 h y 3 rechazos sin un solo acierto**, un aviso
terminal y, en los cierres de sesión, una salida que pierde esos cambios con confirmación.

- **En Grupos, qué cuenta es la palabra del servidor, no el error local.** Un rechazo es un 401 `yala_attest_required` de
  una ruta de Grupos (push, pull o RPC); un 200 de esas rutas borra la racha. Grupos no clasifica `AppAttestError`/`DCError`:
  nadie ha medido cuáles son permanentes, y `.network` no distingue «sin red» de «sin attest». Sin red o con un 5xx no hay
  401, así que estar offline no acerca el veredicto. El motor personal no cuenta ese 401 (ver arriba) y cuenta otra cosa:
  «La racha es del TELÉFONO», más abajo. **Y un rechazo cuenta como mucho una vez por hora**: un solo gesto dispara
  ráfagas —la membresía reintenta tres veces, el cierre cada 2 s durante 45 s— y, contado por petición, el mínimo de 3 se
  cumplía en segundos.
- **La racha vive entre arranques** en `GroupsAttestStreakStore` (`UserDefaults.standard`, clave
  `groupsSync.attestRejectionStreak`), y la decisión es pura en `GroupsAttestVerdictLogic`. Describe al TELÉFONO: no está en
  `DataWipeService.removeUserPreferenceKeys` ni en `PrefSyncKey`. La escriben `GroupsSyncClient` (push y pull),
  `GroupsMembershipClient.call` y, desde el 2026-09-15, `CloudSyncRuntime.resolveAttest`, sin inyección por construcción.
  Un reloj que retrocede reinicia la racha.
- **El veredicto exige además un rechazo del ciclo que se lee** (`GroupsSyncClient.stoppedByUnavailableAttest(for:)`, molde
  del testigo del kill): una racha terminal no dice por qué falló ESTE ciclo. Lo consumen `CloudSignOutFlowLogic.classify`
  (motivo `.attestUnavailable`, que se enseña al momento y la nube no traduce) y `GroupLeaveErrorLogic.classify`.
- **La salida es una excepción ACOTADA a «nunca descarta»**: solo la ofrecen los cierres de sesión (Ajustes, la hoja del
  cambio de Apple ID y la puerta del Welcome, salvo al invitado). El desasociar pasa `lossExit: nil` y enseña el aviso sin
  salida. `exitDiscardingUnsyncedGroups` no borra nada: retoma el cierre con las FILAS que contó el aviso (por
  `clientMutationID`) como lo aceptado, y los cambios mueren con el boot-wipe de siempre. Una fila que no estaba en el aviso
  vuelve a avisar aunque la cifra no crezca: comparar por cifra se llevaba un cambio nuevo sin contarlo. En la nube, lo
  aceptado solo alcanza a los cambios de GRUPOS.
- **Tests: aísla la tienda** (`let racha = try IsolatedAttestStreak(); defer { racha.restore() }`) en todo test cuyo stub
  responda 401 `yala_attest_required`, y marca su suite `.serialized`. Sin aislar, la racha se escribe en el
  `UserDefaults.standard` del host —la app— y un día después se lee terminal en ese simulador. El helper cambia un estático,
  así que entre suites confía en `parallelizable = "NO"` de los schemes, como `PendingJoinStore.defaults`.
- **Residuales aceptados, medidos en la review del 2026-09-15.** (1) La racha viaja en la copia de iCloud y la key de
  attest no (`KeychainService`, `…ThisDeviceOnly`): un teléfono restaurado hereda la racha, y lo acotan el testigo del
  ciclo y el primer 200. (2) Con el reloj atrasado 24 h o más, el token cacheado da 401 más de un día en un teléfono que sí
  atesta (`attest-session-token-rejected-by-the-gateway-stays-cached`). (3) Si un cierre con la pérdida aceptada no llega
  a armar el borrado, las filas se quedan en `GroupSyncOutbox`, que no guarda dueño
  (`superseding-intent-can-strand-the-sign-out-coordinator`).
- **Observación**: el canario `groupsAttestTerminal` (una vez por racha) es la medición de cuántos teléfonos están así;
  `groupsSignOutAttestUnavailable` y `groupsSignOutAttestDiscarded` dicen cuántos vieron la salida y cuántos la usaron.
- **La pestaña Grupos lo dice FIJO desde el 2026-09-15, y el que avisa es el ESCRITOR** (ticket
  `groups-tab-does-not-say-this-phone-cannot-sync-groups`). Hasta ese día el veredicto solo se leía dentro de un gesto
  que podía perder algo; ahora `GroupsContainerView` pinta el aviso mientras dure, con el mismo título de esos gestos.
  Dos cosas que no se pueden tocar sin romperlo:
  - **Son CUATRO condiciones**, no el veredicto solo (`GroupsAttestTabNoticeLogic`): terminal **Y**
    `CloudSyncFlags.groupsBackendCompiledCapability` **Y** `CloudAuthService.shared.hasSession` **Y**
    `GroupsConsentState.isAccepted`. La racha es del TELÉFONO, sobrevive al cierre de sesión y desde el #175 la
    escribe también el motor personal, así que sin las tres últimas el tab anuncia una avería de Grupos a quien no
    tiene Grupos en la nube, a quien está leyendo «crea tu cuenta» o a quien todavía no ha aceptado el consent.
  - **El canal va por la capacidad COMPILADA, igual que los teardowns, y esto costó un hallazgo de la review.** El
    getter compuesto es fail-closed ante un snapshot de remote-config ausente o corrupto (`CloudSyncFlags`, sección
    «QUÉ LEE CADA CLASE DE CALL-SITE»), así que con él un teléfono restaurado desde una copia de iCloud —que hereda
    la racha y no la key de attest— se quedaba **sin aviso en su primer arranque**, mientras el cierre de sesión sí
    se lo enseñaba: el bug del ticket, vivo, en la población más probable. Un aviso sobre datos que YA existen es de
    la clase de los teardowns, no de las entradas.
  - **Las tres condiciones que no son el veredicto se leen VIVAS en el body**, no congeladas en un `@State`:
    congeladas, iniciar sesión desde el CTA de la lista no sacaba el aviso —ese sheet se cierra en sitio, sin
    `onAppear`— y una sesión que el SDK borra en caliente lo dejaba puesto, culpando al attest de una sesión
    caducada.
  - **`GroupsAttestStreakStore.didChangeNotification`**, que el store emite **solo cuando la racha cambia en disco**.
    `isTerminal()` lee `UserDefaults` y depende del reloj, así que ninguna vista se entera sola: **medido en el
    simulador el 2026-09-15**, con la racha escrita un segundo después del arranque la pestaña se quedaba muda hasta
    salir y volver — y eso es exactamente lo que pasa en producción, donde el 401 llega con el tab delante. Al añadir
    un escritor de la racha, el aviso va DENTRO de él; un rechazo que no suma no avisa, porque nada cambió.
  - **Residual aceptado: este aviso es el primer consumidor del veredicto SIN el testigo del ciclo.** Los otros tres
    (`CloudSyncRuntime`, `GroupsSyncClient`, `GroupLeaveErrorLogic`) exigen además que ESTE ciclo haya chocado con el
    attest, y no se puede exigir aquí: el tab es justo donde la persona está sin que corra nada, así que pedirlo
    dejaría el aviso mudo, que es el bug del ticket. ⇒ un teléfono restaurado con una racha heredada que hoy atesta
    bien ve el aviso hasta que un 200 la borre — y se lo cura él solo, porque el `onAppear` del tab lanza un pull y
    el 200 emite `didChangeNotification`. **Lo que NO se cura solo es el cruce de las 24 h con la app abierta en el
    tab**: la racha no cambia en disco, así que el aviso espera al siguiente gesto.

- **El canal personal lo dice fijo desde el 2026-09-15, en DOS sitios** (ticket
  `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data`). Antes su veredicto terminal solo emitía el canario y
  paraba el runtime; `SyncStatusBanner` es el de iCloud, y un ticket partió de lo contrario porque dos docblocks lo
  prometían. Decisión, copy y cableado tienen **un solo sitio** cada uno: `CloudAttestNoticeLogic`,
  `CloudAttestNoticeBanner` y `.cloudAttestVerdictWatcher`.
  - **Son TRES condiciones**: terminal **Y** `CloudSyncFlags.storageMode == .cloud` **Y**
    `CloudAuthService.shared.hasSession`. La del medio es el espejo del consent de Grupos y la que más excluye: quien
    tiene sus datos en su iCloud privado —la mayoría hoy— arrastra una racha que puede ser entera de Grupos sin mandar
    un solo movimiento personal al servidor. **Va por `storageMode`, no por `CloudRemoteFlags.cloudModeEnabled`**: el
    flag remoto es fail-closed ante un snapshot ausente, y `storageMode` es testigo directo del corpus de ESTE teléfono.
  - **La segunda superficie no es cosmética: `syncStatusSection` MENTÍA.**
    `CloudMigrationController.refreshSyncBanner` solo pone `syncNeedsSignIn` con el runtime en `.stoppedUntilSignIn`, y
    el attest terminal lo deja en `.stoppedUntilRelaunch` → caía al `else` y pintaba un check verde «Todo sincronizado» con
    el motor parado. El `else` fallaba ABIERTO: daba por bueno todo estado que nadie enumeró. La rama del attest va
    **antes** que la de `syncNeedsSignIn`, porque re-firmar no arregla un attest roto.
  - **Hereda los dos residuales del aviso de Grupos**: va sin el testigo del ciclo —exigirlo lo dejaría mudo justo en
    el caso del ticket— y el cruce de las 24 h con la app abierta espera al siguiente gesto.
  - **Sin XCUITest positivo**: verlo exige `storageMode == .cloud` y no hay seam de uitest que lo ponga (precedente en
    `SessionExitsPerCellUITests`). Lo cubren la tabla unitaria y un XCUI **negativo** sobre `.icloud` con la racha
    sembrada — el que impide decirle a todo usuario de iCloud que su teléfono no sincroniza.
  - **«Descargando tus datos…» se esconde con el veredicto terminal desde el 2026-09-17** (ticket
    `cloud-hydration-spinner-never-gives-up-without-attest`; el porqué largo, en `CloudHydrationBanner.swift`). **Se
    apoya en que el pull del MOTOR exige token y ese token borra la racha** (`resolveAttest` → `recordAcceptance`): si el
    motor llega a bajar sin pasar por su puerta, o ese token deja de borrar la racha, el banner se esconde durante una
    hidratación real. Los pulls de la migración ya bajan sin ella (`MigrationWorkExecutor.verify` y el drenaje de la
    vuelta a iCloud, con el attest en `try?`) y no tocan la racha. Tres decisiones lo sostienen:
    - lee `GroupsAttestStreakStore.isTerminal()` a secas: las otras condiciones de `CloudAttestNotice.isShowing` dicen a
      quién le es cierta la frase del aviso, no si el motor baja algo, y con ellas el spinner volvería sin sesión;
    - lo lee vivo en su tick de 1 s: con `.cloudAttestVerdictWatcher` serían dos `@State`, el del Panel y el del overlay,
      que se refrescan en momentos distintos, y el aviso podía salir con el spinner girando;
    - el sondeo termina solo por `CloudHydrationLogic.keepsWatching`, que no mira el veredicto: es otro lector sin el
      testigo del ciclo, como los dos avisos, y el primer ciclo borra una racha heredada justo antes de bajar. Lo fija
      `CloudHydrationBannerWiringTests`: el cuerpo entero del `.task`, dónde cuelga y quién escribe `visible`.

    **Residual aceptado, y es el del aviso visto desde el otro lado:** si las 24 h se cumplen con la app delante, nadie
    escribe la racha. El spinner se va en un tick y el aviso espera a su siguiente refresco, así que en ese rato no sale
    ninguno. Con el motor reintentando el hueco dura como mucho un backoff (300 s), porque el rechazo que marca
    `terminalReported` notifica. Con el motor parado por `.unavailable` dura hasta el siguiente gesto. Con el reloj hacia
    atrás justo después del cruce salen los dos hasta ese gesto.

### La racha es del TELÉFONO: la escriben los dos canales (2026-09-15)

Ticket `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`.

- **El motor personal cuenta el error de su puerta**: nunca manda una subida sin attest, y el 401 que el gateway le devuelva
  después no cuenta (ver «Los dos 401 de la guard»).
  `CloudSyncRuntime.resolveAttest` suma un rechazo cuando el error habla del attest
  (`AttestSyncGate.countsTowardAttestStreak`) y un token conseguido acaba la racha, también uno cacheado. Sin red o con el
  gateway caído el error no habla del attest: el veredicto solo se acerca con la palabra de Apple o del gateway sobre ESTE
  teléfono, y qué es permanente lo sigue decidiendo el tiempo. Dos rechazos no son culpa del teléfono y se aceptan,
  acotados por las 24 h: `DCError.serverUnavailable` y el `yala_attest_invalid` con que el gateway tapa un fallo de D1
  (`attest-gateway-reports-a-storage-failure-as-an-invalid-attestation`).
- **Una sola racha para los dos canales, a propósito.** Con dos, un cierre en la nube podía aceptar perder lo personal y
  quedarse en «en un rato» con los cambios de grupos. `GroupsAttestStreakStore` y el canario `groupsAttestTerminal`
  conservan su nombre: renombrar el canario rompe la serie.
- **La salida personal vive solo en el cierre en la nube, que es solo Ajustes.** El paso 1 traduce a
  `.personalAttestUnavailable` el `.attestUnavailable` que trae el testigo del motor
  (`CloudSyncRuntime.stoppedByUnavailableAttest(for:)`, que acepta también la parada terminal `.accountUnavailable`); el resto
  de motivos del paso 1 lo traduce `CloudSignOutFlowLogic.personalPushAllShownReason` desde el 2026-09-25 (la subida que
  no llegó, la sesión caducada, el guardado que se asienta y el motor parado; hasta ese día, todos `.permanent`). **Cada aceptación cubre solo su outbox**, y lo aceptado de lo personal
  sobrevive al aviso de grupos que sale después.
- **Retomar un cierre con la pérdida aceptada exige que el bloqueo siga siendo el attest**
  (`CloudSignOutFlowLogic.continuesAfterBlockedUpload`, en los tres sitios que suben: los pasos 1 y 2 de la nube y
  `pushGroupsForSignOut`). Si el attest volvió y la subida falla por otra cosa, un reintento subiría esos cambios: el cierre
  bloquea como siempre y retira lo aceptado. Los recuentos finales, tras soltar el canal, no pasan por ahí.
- **Tests: aísla la tienda en los del runtime que fijan `attestError`** (`IsolatedAttestStreak`). Un ciclo con token también
  la borra, y los casos que aún no aíslan están en `unit-tests-clear-the-attest-streak-of-a-device-qa-in-progress`.

## La puerta del alta: sin token no se ofrece la nube (2026-09-16)

Ticket `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest`. Es la decisión del owner del 2026-07-06 (bloquear
por adelantado), que hasta ese día vivía en `AttestSyncGate.shouldOfferCloudOnly` sin un solo llamador.

- **«Tener App Attest» es poder conseguir token, y lo define un solo sitio**: `AppAttestClient.canObtainSessionToken`, que
  vale `isSupported` o, en DEBUG, el bypass con `YALA_DEV_SHARED_SECRET`. Es la primera decisión de `performRefresh` en un
  booleano. **Si tocas esa decisión, toca las dos orillas**: un source-scan fija el cuerpo entero de la capacidad y las
  líneas de `performRefresh` y `devTokenOrThrow` que lo sostienen, en orden. `isSupported` a secas le escondería la nube a
  un simulador con `Yala Dev` y el secreto puesto, que sí sube. Con el scheme `Yala` el bypass va a producción, que no lo
  sirve (404): ahí la capacidad dice `true` y nada sube, igual que cree el cliente — solo en desarrollo.
- **En el Welcome solo gatea el ALTA**: la card «Tu cuenta en la nube» de `WelcomeAccountChoiceLogic.visibleNewOptions`, que
  comparten «Es mi primera vez», «Crear otra cuenta» y «Activar Yala completo». Sin ella queda una card, sin copy: «Es mi
  primera vez» y la activación hacen bypass a la rama privada, y «Crear otra cuenta» enseña el chooser con la privada sola.
  **No gatea** entrar con una cuenta que ya existe («Ya tengo una cuenta» y el faro).
- **Las salidas al alta de la pantalla de entrar pasan por la misma puerta** (2026-09-16, ticket
  `cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest`): «Crear mi cuenta» tras «No encontramos una cuenta» y
  «Crear cuenta con…» del mismatch solo se pintan con `WelcomeNewOptionsGate.offersCloudSignUp`, que es
  `live.contains(.cloudAccount)`. Con ella llegan también el kill del alta y el resto de términos de la card. Sin la
  puerta, «No encontramos una cuenta» ofrece «Volver» en el sitio de «Crear mi cuenta» (decisión de Jürgen: nunca la
  flecha de la esquina sola) y el mismatch se queda con «Iniciar sesión con…». **Una salida nueva al alta va dentro de ese
  `if`, alrededor del BOTÓN**: `WelcomeNewChooserWiringTests` exige cada llamada a `switchToSignUp(` dentro de un bloque
  con la condición exacta, `entryOverride = .bornCloud` solo dentro de `switchToSignUp`, y el cuerpo entero de las dos
  pantallas. La condición vive en la vista y no dentro de la función a propósito: ahí dejaría un botón muerto.
- **En Ajustes gatea la card entera** (2026-09-16, ticket `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest`):
  «Migrar a la nube» y también «Activar la nube en este dispositivo», que es entrar a una cuenta que ya existe. Lo decidió
  Jürgen porque sin token las dos acaban igual: el claim pasa sin attest —«Migrar» deja la cuenta creada— y lo que sube o
  baja después se reintenta sin fin. El término vive en `StorageRowGateLogic.offersCloudMigrationEntry` y **cierra la
  entrada, no el panel**, como el kill; la pantalla queda sin la card y sin copy nuevo. El panel es el del engaged: un
  adopt pendiente tras el claim vuelve a `notStarted` y, desde el 2026-09-23, se pinta como progreso con «Cancelar» y
  sale por su techo (`adopt-effect-retries-forever-with-no-ceiling`); hasta ese día se pintaba `.idle` y reintentaba sin
  card. **Su entrada es la
  misma expresión que la de `WelcomeNewOptionsGate.live`**: si cambias una, cambia la otra, o se pone rojo el scan de
  paridad de `StorageRowGroupsAssociationWiringTests`, que además fija el `case .idle` entero.
- **El simulador es un teléfono sin App Attest, y no se le exime.** Sin el secreto no ofrece la nube, a propósito: QA y
  producción deciden igual, que es la lección con la que abre este fichero. Un montaje manual que necesite crear una cuenta
  en la nube desde el simulador usa `Yala Dev` y pone `YALA_DEV_SHARED_SECRET` en Edit Scheme → Run → Environment
  Variables. **Desde el 2026-09-16 no hay otra forma**: «Crear mi cuenta» también pasa por la puerta. Uno que necesite la
  nube SIN App Attest la crea con el secreto por «Es mi primera vez» → «Tu cuenta en la nube», quita el secreto y relanza
  antes de empezar: el token del bypass solo vive en memoria (`AppAttestClient.cached`). **El secreto es un secret de
  Wrangler del gateway de staging**, que no se lee de vuelta: en `~/Secrets` no está (medido el 2026-09-16).
- **XCUITest**: el caso de la condición va con `-uitest-cloud-chooser` y **sin** `-uitest-fake-attest-support`, que finge
  solo la entrada de esta puerta y no toca al cliente. Los que necesitan ver la card de la nube piden los dos. En Ajustes
  basta el segundo, con `Yala Dev` (`StorageMigrationAttestUITests`). En el host de
  test la capacidad vale `false` —ningún scheme compartido pone el secreto—, **medido con un mutante** el 2026-09-16:
  quitando el seam de la puerta, los positivos caen y los negativos pasan. En un iPhone físico los negativos no aplican.
  Y afirma la ausencia de la card solo junto a una presencia que la discrimine: tras aterrizar en otra pantalla, un
  `XCTAssertFalse(… .exists)` no puede fallar.
- **El fallo caro es el contrario.** Un iPhone real dice `isSupported == true` —producción atesta—, y si dejara de decirlo la
  card del Welcome y la de Ajustes desaparecerían para todos sin un rojo. Ningún simulador lo prueba: lo miran los pasos de
  device-QA de los tickets. Cuántos teléfonos caen en la puerta no está medido: no hay canario.

## El SEGUNDO fallo del mismo día: el header estaba cableado y el token no se podía acuñar

El e2e del punto 3 se hizo, y destapó una causa distinta con el MISMO síntoma en pantalla. Precisión sobre
el §1: «el device atestaba bien» era cierto para el primer bloqueante, **no en general**. Con el cableado ya
dentro (`c267db5d`, build 7) crear un grupo seguía dando 401, porque el token no llegaba a existir.

**Medido con una sonda en device** (build Debug del scheme `Yala` — que apunta a PRODUCCIÓN, porque
`ProxyConfig.baseURL` conmuta por `DEV_BUILD`, no por Debug/Release):

    camino=ASSERT keyIdLen=44 vacio=false
    pre-generateAssertion keyIdLen=44 challengeLen=76 hashLen=32
    falló | Domain=com.apple.devicecheck.error Code=2

Todos los inputs BIEN formados y aun así `DCErrorInvalidInput`. La causa:

> **La key de App Attest muere con la INSTALACIÓN de la app (vive en el Secure Enclave, atada a la
> instancia). El string del keyId SOBREVIVE en el Keychain.** Tras reinstalar, el keyId designa una key que
> ya no existe.

Y el fallo era **permanente y silencioso** por cuatro cosas que se sumaban: `generateAssertion` fallaba con
un `DCError` **local**; el `catch` solo cubría `AppAttestError.unknownKey`, que se lanza EXCLUSIVAMENTE al
leer una respuesta del gateway ⇒ nunca re-registraba; nada borraba el keyId ⇒ cada intento releía el mismo;
y el `try?` de `AttestSessionProvider` con los logs bajo `#if DEBUG` no dejaba rastro en producción.
**Alcance: cualquier usuario que hubiera reinstalado la app se quedaba sin Grupos, sin Yala IA y sin proxy
de tipos de cambio, para siempre, viendo «Inténtalo en unos minutos».** No lo introdujo el Modo Nube: el
encendido de Grupos solo le dio una superficie visible.

### Reglas que salen de aquí

- **Una recuperación que solo escucha al SERVIDOR no se dispara nunca en local.** `unknownKey` es una señal
  de respuesta HTTP; un `DCError` no pasa por ahí. Quien escriba «recuperación: si la key no sirve, re-registra»
  tiene que cubrir las DOS procedencias. Decide `AttestKeyRecoveryLogic` (`Yala/App/Logic/`), que es el ÚNICO
  punto de decisión a propósito — separarlo en dos `catch` es justo lo que dejó el camino local descubierto.
- **El descarte va ACOTADO a `.invalidInput` y `.invalidKey`.** `DCError.h` es explícito con
  `serverUnavailable`: «try the attestation again later using the SAME key and the same value for the
  clientDataHash — retrying with the same inputs helps to preserve the risk metric for a given device». Un
  `catch` genérico quemaría una key nueva en cada fallo de red. Pinneado por
  `YalaTests/AttestKeyRecoveryLogicTests.swift`; `serverUnavailable_propaga` es la aserción que carga el peso.
- **`KeychainService.getString` devuelve `""` y NO `nil` para un ítem de cero bytes** (`String(data:encoding:)`),
  así que un `if let` pelado deja pasar un keyId vacío — que también es `InvalidInput`. Va con `!isEmpty`.
- **El canario `attestKeyDiscardedAfterAssertFailure` es la superficie de observación** de este subsistema, y
  está FUERA de `#if DEBUG` a propósito. La otra es el botón «refresh attest» de `CloudSyncDebugView`, que
  pasa `ignoringBackoff: true` para que el panel no reporte un error viejo como si fuera del intento actual.
  **No hay ningún calentador del token al launch.** Hubo uno en la firma, `AppAttestClient.ensureRegistered()`,
  cuyo docblock prometía calentarlo «tras el consent de IA / al launch si ya hay Pro»: **nunca tuvo un solo
  call-site**, así que la promesa era falsa y la consola salió muda a quien lo usó como punto de observación
  para diagnosticar el 401 del 2026-07-31 — costó una vuelta entera de diagnóstico. Borrado ese mismo día en
  vez de cablearlo, porque cablearlo no habría ahorrado latencia: `AppBootstrapper.loadExchangeRates` (paso 2
  del bootstrap, con `await` en el camino crítico) ya pide token en el primer arranque de cada día UTC ⇒ el
  caso dominante llega al primer uso de IA con el token en `cached`, y un warm-up concurrente se colgaría de
  su single-flight. Con `SESSION_TTL_SECONDS = 15 * 60`, lo único que quedaba era «relanzar el mismo día y
  tocar IA dentro de esos 15 min», y eso no paga el coste de gastar la escalera de `AttestRefreshBackoffLogic`
  en un llamador que no atiende a nadie: un warm-up que falla sube la racha y el toque REAL que llega después
  se encuentra la ventana ya consumida y recibe el error SIN intentarlo. ⇒ **si alguien vuelve a proponer un
  warm-up, la carga de la prueba es una medición, y §«Un build de Xcode NO puede validar…» dice por qué no se
  puede hacer con un build de Xcode.**

### Un build de Xcode NO puede validar un fix de attest contra producción

`verifyAttestation.ts:79` compara el AAGUID byte a byte: con `ATTEST_ENV = "production"` exige
`"appattest"+7×0x00`, y un build firmado en desarrollo manda `"appattestdevelop"` ⇒ **401
`yala_attest_invalid: AAGUID no corresponde al entorno 'production'`**, siempre, por diseño. El scheme `Yala`
en Debug tiene el bundle de producción y habla con producción, así que jamás obtendrá sesión.

⇒ **el build de Xcode es una herramienta de DIAGNÓSTICO, no de validación.** Sirve para ver el error (los
logs de `#if DEBUG` viven ahí) y para distinguir «murió antes de postear» de «llegó al servidor»: que aparezca
un `POST /v1/attest/register` donde antes no aparecía nada ES la prueba de que el lado local se arregló. Para
validar de verdad hace falta un build de distribución. Y si lo que quieres es ejercitar Grupos end-to-end sin
esperar al archive, `Yala Dev` sí completa la atestación —va a staging, que es `ATTEST_ENV = "development"` con
el bundle `.dev` y sirve los tres percents al 100—, pero es otro mundo de datos y corre en `observe`.

### Método, que costó cuatro viajes

Refutadas por el camino, todas plausibles y todas falsas: (1) «reinstalar cura la key rancia» —el Keychain
sobrevive al borrado, así que reinstalar CAUSA el estado; (2) el entitlement —ningún `.entitlements` declara
App Attest, y esa es la configuración normal y la que funcionaba; (3) la tormenta de peticiones —el segundo
device no tenía sesión de nube, sus gates de Grupos estaban OFF y no podía tormentar, y fallaba igual; (4)
caída de Apple —su status page daba App Attest operativo. **Una sonda de tres `print` dio la respuesta en una
corrida.** Cuando el error es invisible por diseño, instrumentar es más barato que razonar: es la misma
lección que la fila del `rollback()` en la Lista Negra.
