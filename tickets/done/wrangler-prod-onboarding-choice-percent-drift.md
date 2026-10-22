---
id: wrangler-prod-onboarding-choice-percent-drift
status: done
priority: high
area: "gateway, cloud"
created: 2026-09-09
updated: 2026-09-10
source: "medido el 2026-09-09: curl al /config de producción vs gateway/wrangler.toml"
---

# El repo dice que la elección nube del onboarding está apagada en producción, y producción la sirve al 100 %: el próximo deploy la apaga

## Qué pasa

Jürgen subió la elección born-cloud a producción en un PR que después se borró. El gateway de
producción la sirve; el repo no lo sabe.

Medido el 2026-09-09:

```
curl https://yala-gateway-production.misty-surf-6866.workers.dev/config
{"v":1,"flags":{"cloudModeRolloutPercent":100,"cloudOnboardingChoiceRolloutPercent":100,
 "groupsBackendRolloutPercent":100,"secondarySessionRolloutPercent":0},"forceUpdate":{"minSupportedBuild":0}}
```

```
gateway/wrangler.toml:130   CLOUD_MODE_ROLLOUT_PERCENT = "100"            # [env.production.vars]
gateway/wrangler.toml:132   CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT = "0"  # ← producción sirve 100
gateway/wrangler.toml:51-52 (staging: 100 / 100)
```

`wrangler deploy --env production` desde el repo escribe las `vars` del `.toml` ⇒ **el siguiente deploy
del gateway, por cualquier otro motivo, apaga la card «Tu cuenta en la nube» del Welcome** en todo el
parque, sin que nadie lo haya decidido.

## Por qué importa

Es el hermano de `storage-row-gate-comment-says-rollout-zero` (allí era un comentario del cliente el
que describía prod al revés; aquí es el fichero que **se despliega**). Y los tickets y docs que citan
«percent 0 en producción» para la elección nube (`WelcomeAccountChoiceLogic.swift` cabecera,
`CloudRemoteConfig.swift` cabecera, varios tickets) describen un estado que ya no es.

## Lo que hay que hacer

- [x] `gateway/wrangler.toml:132` → `"100"`, con el comentario de fecha como ya tiene `:125-129` para
      `CLOUD_MODE`.
- [x] Corregir los comentarios del cliente que afirman «0 en producción» para la elección.
- [x] Un test del gateway (`gateway/test/config.test.ts`) que fije los percents de producción
      leyendo el `.toml` — los TRES vivos, por la decisión de abajo.
- [x] Antes de mergear: `curl` al `/config` de prod otra vez y anotar el valor en el PR.

## Fuera de alcance

Decidir el rollout. Este ticket alinea el repo con lo que Jürgen ya decidió y desplegó.

## Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)

Preguntadas una a una antes de soltar la cola autónoma. **Mandan sobre cualquier interpretación del ADR
o de este ticket**; si algo de arriba las contradice, ganan éstas.

- **El test fija solo los TRES percents vivos**: `cloudModeRolloutPercent`,
  `cloudOnboardingChoiceRolloutPercent` y `groupsBackendRolloutPercent`.
  `secondarySessionRolloutPercent` se deja **fuera** a propósito: el ticket 12 retira M1 entera y no
  queremos tocar este test dos veces. Coste aceptado: durante los pasos 1-11 nadie vigila ese percent.
- **El test NO toca la red.** Parsea `gateway/wrangler.toml` y compara contra los valores esperados.
  Determinista y sin credenciales en CI. Queda sabido que así no se detecta un cambio hecho a mano
  desde el dashboard de Cloudflare.
- **Staging no se toca.** `SECONDARY_SESSION_ROLLOUT_PERCENT = "100"` en `[env.staging.vars]`
  (línea 56 al 2026-09-09) **se queda como está**: es objeto del ticket 12, no de éste.
- **Sí se despliega tras mergear**: `wrangler deploy --env production` y `curl` de confirmación al
  `/config`, para dejar repo y producción idénticos y comprobados. El valor medido antes y después va
  anotado en el PR.

---

## Cierre (2026-09-10)

**Para el usuario no cambia nada hoy, y ése es justo el objetivo**: la card «Tu cuenta en la nube»
del Welcome ya estaba viva en producción y sigue igual. Lo que cambia es que el repo ya no puede
apagarla sin querer.

### Lo medido

- `/config` de producción, **antes** de tocar nada (2026-09-10 00:27 -05, HTTP 200):
  `cloudOnboardingChoiceRolloutPercent: 100`. La premisa del ticket se confirmó.
- `gateway/wrangler.toml:132` decía `"0"` ⇒ el siguiente `deploy` la apagaba. Ya dice `"100"`.

### Dos correcciones a este ticket

1. **No existe `[env.staging.vars]`.** Las líneas 51-56 son el `[vars]` **top-level**, que ES
   staging (el worker se llama `yala-gateway-staging` y es el env por defecto). La decisión «staging
   no se toca» se cumplió igual: ese bloque quedó intacto.
2. **El deploy NO es `wrangler deploy --env production` a pelo.** El propio `.toml:113-114` manda
   usar `npm run deploy:production`, y está medido por qué: su `predeploy` corre `sync:manifest`,
   que copia los dos `*_capability_manifest.json` a `gateway/` — ficheros **ignorados por git** que
   `src/sync/manifest.ts` y `src/groups/manifest.ts` importan. Sin esa copia el bundle no resuelve
   sus imports.

### Los comentarios del cliente eran MÁS de los tres nombrados

Nueve sitios, no tres, y uno de ellos no salía en el grep del ticket porque no usa ninguna de las
dos cadenas: `CloudRemoteConfig.swift:19` afirmaba que «el server sirve los tres percents en 0»,
cuando los tres vivos están al 100 desde julio (dos) y septiembre (el de la elección).

Corregidos: `CloudRemoteConfig` · `WelcomeAccountChoiceLogic` (×2, incluido un «prod DARK hoy» que
caducó con D-R1 en julio) · `CloudBackendConfig` · `CloudSyncFlags` · `WelcomeFlowContainer` ·
`WelcomeNewChooserView` · `WelcomeSecondaryNoticeView` · `WelcomeMirrorRelaunchLogic` ·
`WelcomeAccountChoiceLogicTests` (docblock + nombre del `@Test`) · `SecondarySessionGateUITests`.

**No se tocaron** los que hablan del percent de la sesión secundaria, que sigue en 0 de verdad
(`CloudSyncFlags:273`, `CloudRemoteConfigTests:190`, `CloudSyncDebugView:1001`), ni los nueve
«identity capture … no-op en producción», que siguen siendo ciertos (`identityCaptureEnabled` es
`false` compilado).

### El test, y lo que NO cubre

`config.test.ts` fija los tres percents vivos leyendo el `.toml` por secciones, con control positivo
(`ENFORCE` difiere entre staging y prod) y control negativo (una key ausente da `undefined`).
Verificado con tres mutantes: prod a `"0"` → rojo · línea borrada → rojo · staging a `"0"` → verde.

Límite conocido y aceptado: fija el REPO, no el gateway. Un cambio a mano desde el dashboard de
Cloudflare no lo ve. La contraprueba es el `curl`, que va en el PR.

### Lo que se llevó por delante

- `ci-no-corre-la-suite-del-gateway` — **tercera instancia**: los DOS ficheros cuyo único trabajo es
  parar un deploy destructivo viven en la suite que ningún workflow ejecuta.
- `gateway-typecheck-roto-y-fuera-del-ci` — re-medido: 5 errores, no 3, y su plan presupone un job
  del gateway que no existe.
- `sync-runtime-safety-note-assumes-every-prod-device-is-icloud` — **nuevo**: con la card born-cloud
  viva, «TODOS los devices en producción son `.icloud`» ya puede ser falso, y ese argumento sostiene
  tener el motor de sync encendido.

### Riesgo temporal conocido, sin ticket a propósito

`welcome-private-card-promises-icloud-in-visit` (descartado el 2026-09-09) decía «deja de ser LOW en
cuanto el percent suba de 0» — y el percent ya está en 100. **No se reabre**: su descarte no se
apoyaba en el percent sino en la retirada de M1 (ADR «Sesiones — dos ejes»). La ventana en que la
card promete iCloud a una visita está abierta hasta que el ticket 12 retire M1.

