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

Las tres definiciones de la guard estricta están DUPLICADAS a propósito y son espejos declarados:
`groups/rpc.ts`, `groups/routes.ts` (que `push/register.ts` reusa) y `sync/routes.ts`. Al tocar una, mirar
las otras.

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
  que lo justifica. Hay cinco, todos de `CloudAccountClient`.
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
