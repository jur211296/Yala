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
