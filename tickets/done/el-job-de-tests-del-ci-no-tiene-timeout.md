---
id: el-job-de-tests-del-ci-no-tiene-timeout
status: done
priority: medium
area: ci
created: 2026-09-06
updated: 2026-09-08
source: medido esperando el CI del PR #78
---

# El job `tests` del CI puede ocupar un runner seis horas sin que nadie se entere

## Qué se midió

Esperando los checks del PR #78 (2026-09-06): el job `tests` llevaba **más de 60 minutos** con el
paso de UI tests en `in_progress`. No estaba colgado —los tres pasos anteriores (build, unit
pure-logic, unit context-based) habían pasado—, pero al buscar cuándo cortaría salió esto:

**`grep -n "timeout-minutes" .github/workflows/qa.yml` no devuelve nada.** Ni en el job ni a nivel de
workflow. Sin `timeout-minutes`, GitHub Actions aplica su default de **360 minutos**.

## Por qué importa

El paso que tarda es:

```yaml
- name: UI tests (YalaUITests) — advisory (flaky en runner frío, ver Lista Negra)
  continue-on-error: true
  run: |
    xcodebuild test-without-building -scheme "Yala Dev" \
      -only-testing:YalaUITests -parallel-testing-enabled NO -retry-tests-on-failure
```

La suite entera (~110 tests), **sin paralelismo** y **con reintentos**. Que tarde una hora larga es
esperable. El problema no es la lentitud: es que **un cuelgue real es indistinguible de esto** y
nadie se entera hasta las seis horas.

Y hay un segundo efecto, más silencioso: los tres pasos de test son `continue-on-error: true` a
propósito, así que el job **acaba en verde pase lo que pase**. O sea que el único coste visible de un
cuelgue es tiempo de runner y un PR que parece "pendiente" durante horas — justo el estado en el que
alguien acaba mergeando sin esperar, porque el check nunca cierra.

## Qué hacer

Dos cosas, y la segunda importa más que la primera:

1. Poner `timeout-minutes` al job (y quizá al paso de UI). Un valor por encima del percentil alto
   real, no a ojo: hay que medir cuánto tarda normalmente antes de elegirlo.
2. **Decidir si ese paso debe correr en cada PR.** La duración ya está medida (abajo): el CI no da
   señal dentro de una sesión de trabajo, así que la pregunta real es si la suite completa de UI
   pertenece al PR o a una corrida nocturna.

## Decisión Jürgen (2026-09-06)

**La suite de UI pasa a una corrida nocturna; el PR corre build + unit con `timeout-minutes`.**
Elegida entre eso, «todo en cada PR con tope de ~100 min» y «UI solo si el diff toca `Yala/`». Motivo, tal como se le puso delante y ratificó: el
PR debe dar señal dentro de una sesión de trabajo, y el gate local ya corre los XCUITest de las áreas
tocadas antes de cada commit. La nocturna corre sobre `2.1` y avisa si hay rojo (sin avisar en verde);
el tope del PR se elige por encima del percentil alto medido de build + unit, no a ojo.

## Duración medida (2026-09-06)

`gh run list --workflow qa.yml --limit 12`, quedándome con los runs que sí dispararon el job:

| Run | Minutos |
|---|---|
| 4 runs completos consecutivos | **77, 80, 82, 83** |
| El más lento de la muestra | **90** |

Los runs de 0 minutos son los que no disparan `tests` (diffs de solo documentación).

**~80 minutos de media.** Eso es más que cualquier sesión de trabajo razonable esperando un PR, y
explica el patrón que hay que evitar: el check no cierra, el PR parece pendiente, y se acaba
mergeando sin él. Un `timeout-minutes` alrededor de 120 dejaría margen sobre el percentil alto sin
permitir que un cuelgue ocupe seis horas.

## Distinto de

- `ci-no-corre-la-suite-del-gateway` — otro hueco de cobertura del CI.
- `ci-warns-but-does-not-block` — va del `continue-on-error`, que aquí es intencional; esto va del
  tiempo sin límite.

## Implementado (2026-09-07)

### La cifra del ticket estaba corta, y por eso se volvió a medir

Arriba quedó escrito «~80 minutos de media» sobre una muestra de **4 runs**. Con **39 runs** con la
suite ejecutada (todos los del 2026-09-06/07 que dispararon el job), leyendo los tiempos **por paso**
de la API de Actions, la mediana real del job es **89 min**, no 80. Pero el número que decide el tope
del PR no es ése: con la UI fuera, lo que hay que acotar es build + unit.

| conjunto | mediana | p90 | p95 | max |
|---|---|---|---|---|
| Job completo (con UI) | 88,9 | 96,7 | 99,5 | 101,7 |
| **Job en un PR (build + unit, sin UI)** | **21,6** | **25,7** | **27,2** | **29,9** |
| Build for testing | 9,7 | 11,6 | 11,9 | 13,7 |
| Unit pure-logic | 8,9 | 11,2 | 13,2 | 17,0 |
| Unit context-based | 2,4 | 3,1 | 3,1 | 3,5 |
| Solo el paso de UI | 67,2 | 73,8 | 75,5 | 76,2 |

El paso de UI se lleva el **76 %** del reloj del job. Sacarlo del PR deja la espera en **~22 min**.

### Los topes, y de dónde sale cada número

| dónde | tope | sobre qué medición |
|---|---|---|
| Job en un PR | **45** | 1,5× el máximo medido de build+unit (29,9); p95 = 27,2 |
| Job en la nocturna | **150** | 1,5× el máximo medido del job completo (101,7) |
| Paso `Build for testing` | **25** | 1,8× su máximo (13,7) |
| Paso `Unit pure-logic` | **30** | 1,8× su máximo (17,0) |
| Paso `Unit context-based` | **10** | 2,9× su máximo (3,5) |
| Paso `UI tests` | **110** | 1,4× su máximo (76,2) |

Se tiró a lo holgado a propósito: un tope generoso cuesta una hora de runner, y uno ceñido corta
corridas sanas — que es como se acaba quitando el tope y volviendo al punto de partida.

**Hay tope en cada paso además de en el job, y no es redundante.** Verificado contra el código de
`actions/runner`: cuando vence el tope de un PASO el runner deja `Result = Failed`, y
`continue-on-error` **sí** rescata eso (lo pinta de verde dejando `outcome: failure`), así que el job
sigue vivo y el aviso lo cuenta. Cuando vence el tope del JOB es una **cancelación**, y
`ApplyContinueOnError` abre con `if (Result != TaskResult.Failed) return;`: no la rescata. Los pasos
con `if: always()` sí llegan a correr en ese caso —el servidor re-evalúa sus condiciones—, pero
contra una ventana de 5 min y con el job perdido. El tope de paso es el corte bueno; el del job, la
red de debajo.

### Un solo job, no dos

`timeout-minutes` admite expresión en ambos niveles (schema de SchemaStore: `oneOf: number |
expressionSyntax`; y actionlint rechaza el texto plano con «expecting a single ${{...}} expression or
float number literal»). Eso permitió que la nocturna sea **el mismo job** con el paso de UI
condicionado, en vez de un segundo job que duplicaría el build, los dos unit y las ~90 líneas del
aviso a Grok. Duplicar eso es exactamente como divergen.

La condición aparece dos veces en el fichero —el `timeout-minutes` del job y el `env.UI_TOCABA`—
porque a nivel de job **no existe el contexto `env`** (tabla de disponibilidad de contextos: allí sólo
hay `github, needs, strategy, matrix, vars, inputs`). Queda anotado en el propio YAML.

### Lo que casi rompo, y no estaba en el encargo

`steps.<id>.outcome` vale `skipped` para dos cosas opuestas: «se saltó a propósito» y «no llegó a
correr». El bloque que avisa cuando la suite no corre —escrito el 2026-09-03, después de seis runs
seguidos que no probaron nada con el aviso callado— metía la UI en ese bucle. Al saltarla en los PR,
habría gritado **«la suite NO llegó a correr» en cada PR**; y un canal que grita cuando no pasa nada
se acaba silenciando, que es el mismo final que el canal mudo que ese bloque vino a arreglar, por el
otro extremo. Se distingue ahora con `UI_TOCABA`, que dice si a la UI le tocaba correr.

### Verificado

- **actionlint 1.7.12** en verde sobre los dos workflows, cero avisos (incluido un `SC2059`
  preexistente en el bloque del aviso, arreglado de paso por caer en las líneas tocadas).
- **El script del aviso, ejecutado en 8 escenarios** extrayéndolo del YAML: PR verde con UI saltada
  **calla**; PR con unit en rojo avisa; PR con el build caído sigue avisando «no llegó a correr»
  (la protección preexistente no se rompió); nocturna verde calla; nocturna con UI roja avisa;
  nocturna cancelada avisa.
- **El job `changes` ante un `schedule`**: se ejecutó su script con `GITHUB_EVENT_NAME=schedule` y
  devuelve `run_tests=true` por su rama fail-closed. No hubo que tocarlo.
- **La rama del `schedule`**: corre siempre sobre la rama por defecto y no se puede elegir otra; aquí
  la por defecto **es `2.1`** (`gh api repos/jur211296/Yala --jq .default_branch`), que es lo que
  pedía la decisión.

### Lo que queda dicho pero no cerrado aquí

- Yala es un repo **público**, y en los públicos GitHub deshabilita solo los workflows programados
  tras **60 días sin actividad**. No va a pasar con la cadencia de hoy; queda anotado en el YAML para
  que, si la nocturna desaparece un día, se mire ahí antes que en el YAML.
- El workflow manda tres veces a `TESTING-STRATEGY.md`, que **no está en el repo** — salió de camino
  y tiene ticket propio: `ci-workflow-cites-missing-testing-strategy`.
- Los tres pasos siguen siendo `continue-on-error` a propósito. Este ticket iba del tiempo sin tope,
  no de si deben bloquear; eso es `ci-warns-but-does-not-block`.

## Verificado en producción (2026-09-08)

Los topes se eligieron con runs de **antes** del cambio, estimando cuánto duraría el job sin el paso
de UI. Un día después ya hay corridas reales del job tal como quedó, y dicen esto — 21 runs del job
`tests` en PR y push posteriores al merge, leídos de la API de Actions:

| conjunto | mediana | p90 | p95 | max | tope | margen |
|---|---|---|---|---|---|---|
| Job en un PR (real, sin UI) | 21,7 | 29,2 | 29,9 | **34,0** | 45 | 1,32× |
| Nocturna (`workflow_dispatch`, con UI) | — | — | — | **89,7** | 150 | 1,67× |

**Cero cancelaciones y cero timeouts** en las 30 corridas del periodo: ningún tope ha cortado una
corrida sana, que era el riesgo de ceñirlos. El único rojo es un build roto conocido (2,7 min).

Dos matices que conviene dejar escritos, porque el número de arriba no es el que se predijo:

- **El máximo real (34,0) supera en 4,1 min al máximo estimado (29,9)** sobre el que se eligió el 45.
  El tope aguanta, pero el margen que se buscaba era 1,5× y hoy es **1,32×**. No hay que tocar nada;
  sí conviene saber que el colchón es menor de lo que dice la tabla de arriba, y que si el build o la
  suite unit crecen otro 30 % el tope empezará a cortar corridas sanas. Ahí se sube el tope, no se
  quita.
- **La predicción de «~22 min» era buena**: la mediana real es 21,7. Lo que se quedó corto fue la
  cola, no el centro — que es lo normal al estimar un máximo a partir de cuatro decenas de runs.

**Lo que esta verificación NO cubre:** que el `cron` despierte la nocturna solo. A día de hoy hay
**cero runs con `event: schedule`** y la primera ventana (2026-09-08 08:17 UTC) pasó sin disparar.
Que el *contenido* de la nocturna funciona está probado por el `workflow_dispatch` de arriba; que el
*reloj* la lance, no. Tiene ticket propio: `la-nocturna-de-ui-no-ha-disparado-ni-una-vez`.

## Acceptance Criteria

- [x] El job `tests` tiene `timeout-minutes` explícito, elegido a partir de duraciones medidas —
      45 min en un PR y 150 en la nocturna, más un tope por paso. Sobre 39 runs, no sobre 4.
- [x] Queda escrito cuánto tarda hoy la suite en CI. Escrito el 2026-09-06 como «~80 min» sobre 4
      runs y **re-medido el 2026-09-07 sobre 39**, por paso: mediana del job **89** min, de los que
      **67 son el paso de UI**. La cifra vieja no era falsa, era del objeto equivocado — ver arriba.
- [x] Decidido si la suite completa de UI corre en cada PR o pasa a nocturno → **nocturno** (2026-09-06).
