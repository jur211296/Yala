---
id: ci-no-corre-la-suite-del-gateway
status: backlog
priority: medium
area: platform
created: 2026-09-04
source: medido al abrir el PR #63 (rejoin-tap-renotifies-admins), 2026-09-04
updated: 2026-09-15
---

# El CI no ejecuta ni un test del gateway — y sí gasta 100 minutos de simulador por tocar el índice

## Qué pasa

`.github/workflows/qa.yml` tiene un solo job de tests, y es la suite de **iOS**. La suite del
gateway (`gateway/`, ~330 tests con vitest) **no la corre nadie automáticamente**: ni en push, ni en
PR, ni de noche. La única vez que se ejecuta es cuando alguien la lanza a mano.

Y el filtro que decide si vale la pena arrancar el simulador está, para este caso, **exactamente al
revés de lo que conviene**:

| Fichero del diff | ¿Dispara la suite iOS? | ¿Se prueba lo que cambió? |
|---|---|---|
| `gateway/src/**.ts` | **no** (excluido a propósito) | **no** — nadie corre vitest |
| `qa/cloud/*.sql` | **no** (excluido a propósito) | no |
| `qa/coverage-index.json` | **sí** — ~100 min de runner | no hay nada que compilar |
| `encargos/*.md` | **sí** — ~100 min de runner | no hay nada que compilar |

Las dos primeras filas son deliberadas y el comentario del workflow las justifica bien (no entran en
el build de Xcode). El problema es que la exclusión se quedó a medias: **se les quitó el CI que no
les servía y no se les dio el que sí.**

## Por qué importa, con el caso que lo destapó

`rejoin-tap-renotifies-admins` (PR #63) arregló un bug vivo en producción tocando **sólo**
`gateway/src/groups/rpc.ts` y un `.sql`. Su red son tres tests nuevos en
`gateway/test/push.fanout.unit.test.ts`, verificados por mutación. **El CI de ese PR salió verde sin
ejecutar uno solo de ellos.**

⇒ Si mañana alguien endurece ese gate a `changed !== true` —que es la variante que parece más
correcta y rompe los avisos a los admins— **el CI no se entera**. El test que lo pinnea existe y
está en verde: nadie lo llama.

Es la misma familia que `ci-verde-con-la-suite-en-rojo`, un escalón más abajo: allí el CI ejecutaba
tests y no miraba el resultado; aquí directamente no los ejecuta.

## Medido el 2026-09-04 (no inferido)

- `grep -n "npm test\|vitest" .github/workflows/qa.yml` → **0 coincidencias** en un job. Las únicas
  menciones a `gateway` son las del `case` que lo **excluye** (líneas 101-106).
- La allowlist del job `changes` es
  `docs/*|tickets/*|marketing/*|Web/*|.claude/*` + `README/CLAUDE/LICENSE` + `gateway/*|qa/cloud/*`.
  **`qa/coverage-index.json` y `encargos/*` no están**, así que caen en el `*)` y disparan la suite.
- Coste de esa suite, del ticket hermano ya cerrado: **97-102 minutos** por corrida.
- **La suite offline del gateway tarda 2 segundos de reloj** (`npm test` entero, incluido el
  `sync:manifest`: 253 tests, 76 skipped, `Duration 1.47s`). Con las credenciales de staging
  cargadas sube a **231 s** (322 tests) porque habla con la red.
- ⇒ La desproporción es el argumento: **253 tests por 2 segundos de Ubuntu** frente a ~100 minutos
  de macOS que hoy se gastan por editar un JSON de índice.

## El primer coste real, cobrado el 2026-09-07 (añadido el 2026-09-08)

Ya no es un riesgo hipotético: **el hueco dejó pasar un rojo y costó un día de investigación.**

`bb90564a` (el tope de gasto del grupo) subió el `canon_version` del manifest de Grupos de `c1` a
`c2` —correctamente, y el commit lo razona— y actualizó el cliente Swift, pero **no** los dos
`expect(...canon_version).toBe("c1")` de `gateway/test/groups.goldens.test.ts`. Nadie se enteró
durante 24 h por dos motivos que se suman:

1. **El CI no corre esa suite** (este ticket).
2. La copia `gateway/group_capability_manifest.json` está en `.gitignore` y sólo se refresca en
   `pretest`; quien lanzaba los goldens con `npx vitest` seguía midiendo con la copia vieja en `c1`,
   **y el assert pasaba**. Cerrado aparte con `gateway/test/manifest.sync.test.ts`, que es offline y
   entraría en el job propuesto abajo.

El rojo apareció al investigar `goldens-de-staging-solo-pasan-a-trozos`, donde se había registrado
como «cero aserciones fallidas» — es decir, el diagnóstico del ticket que lo perseguía también salió
mal por esto.

## Por dónde seguir

1. **Un job `gateway` en `qa.yml`**: `ubuntu-latest`, `npm ci` + `npm test` en `gateway/`, disparado
   cuando el diff toca `gateway/**`. Barato (minutos de Linux, no de macOS) y cubre el hueco entero.
   **Ojo con el alcance**: la mitad de esa suite exige credenciales de staging
   (`USER_A_PASS`, `GROUPS_ENC_KEY`, `PUSH_ROLE_JWT`) y hoy sólo viven en `~/Secrets/` de la Mac. En
   CI habría que decidir: o sólo los tests offline (253, sin secretos), o meter tres secrets de
   repositorio. **Empezar por los offline** — ya cubren el gate del fan-out, que es lo que se escapó.
2. **Añadir `qa/coverage-index.json` y `encargos/*` a la allowlist**, que es de una línea y ahorra
   ~100 min por PR de documentación. Cuidado de NO meter `qa/*` entero: `qa/scripts/` y
   `qa/validate-coverage.*` sí deciden cómo se verifica el proyecto, y el propio workflow avisa por
   escrito de que meterlos sería el error.

## Lo que no se midió

Si un job de Ubuntu puede correr los tests que hablan con staging sin exponer credenciales en logs.
No se ha probado; la propuesta 1 lo esquiva empezando por los offline.

## Tercera instancia (2026-09-10): ahora el hueco cubre dos guards de PRODUCCIÓN

`wrangler-prod-onboarding-choice-percent-drift` añadió a `gateway/test/config.test.ts` un guard que
fija los TRES percents de rollout de `[env.production.vars]` leyendo el `.toml`. Se suma al que ya
existía, `test/wrangler.forceupdate.test.ts`, cuyo docblock se declara «la única red que queda»
contra desplegar un `MIN_SUPPORTED_BUILD` > 0 —que brickea cada instalación—.

⇒ **los dos ficheros del repo cuyo único trabajo es parar un deploy destructivo viven en la suite
que nadie ejecuta.** Los dos son offline, sin credenciales, y corren en menos de un segundo: caen
enteros dentro de la propuesta 1 (job de Ubuntu con los tests offline), que sigue sin hacerse.

Re-medido ese día: `grep -rn 'vitest|npm test|npm ci|npm run' .github/workflows/` da **un** acierto
y es el COMENTARIO de `qa.yml:140` que excluye `gateway/` del build de iOS. Sigue sin haber job.

## Cuarta instancia (2026-09-15): el cliente iOS depende de un código que solo fija esta suite

`groups-sync-reads-a-missing-attest-401-as-a-session-expiry` hizo que el canal de Grupos lea el código del 401:
`yala_attest_required` es pasajero y `yala_attest_invalid` es sesión caducada. Que las guards de Grupos no fundan los
dos lo fija `gateway/test/groups.attest401.test.ts`, offline y en menos de un segundo, y tampoco lo corre nadie. Si
una guard devolviera `yala_attest_required` con el JWT caducado, el cliente reintentaría para siempre sin pedir
volver a entrar, y ni el CI ni la suite de iOS lo verían.

