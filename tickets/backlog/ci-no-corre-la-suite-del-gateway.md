---
id: ci-no-corre-la-suite-del-gateway
status: backlog
priority: medium
area: platform
created: 2026-09-04
source: medido al abrir el PR #63 (rejoin-tap-renotifies-admins), 2026-09-04
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
- La suite del gateway tarda **~4 minutos** offline (253 tests) y ~4 min más con red.

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
