---
id: la-nocturna-de-ui-no-ha-disparado-ni-una-vez
status: done
priority: medium
area: ci
created: 2026-09-08
updated: 2026-09-08
source: medido al verificar en producción el cierre de `el-job-de-tests-del-ci-no-tiene-timeout`
---

# La nocturna de UI está configurada y verificada, pero el `cron` no ha disparado ni una vez

## Qué se midió (2026-09-08, 09:44 UTC)

`el-job-de-tests-del-ci-no-tiene-timeout` mudó la suite de UI a una corrida nocturna
(`cron: '17 8 * * *'`, commit `6a9df989`, en `2.1` desde el 2026-09-08 00:05 UTC). La primera
ventana posible era **hoy a las 08:17 UTC**, con el workflow ya 8 h en la rama por defecto.

**No disparó.** Y no es que fallara: es que no existe.

```
gh run list --workflow qa.yml --limit 100 --json event --jq '[.[].event]|group_by(.)|map({ev:.[0],n:length})'
→ [{"ev":"pull_request","n":48},{"ev":"push","n":51},{"ev":"workflow_dispatch","n":1}]
```

**Cero runs con `event: schedule`** en la ventana de 100 runs (que llega hasta el 2026-09-06).

## Qué se midió el 2026-09-08 (sesión de diagnóstico)

### La premisa del ticket se sostiene, con una corrección de fecha

El ticket databa la llegada del `cron` a `2.1` en «el 2026-09-08 00:05 UTC». Esa es la fecha del
**commit** `6a9df989` (2026-09-07T19:05-05:00 = 00:05 UTC). Lo que importa es cuándo llegó a la
rama por defecto, y llegó **por el merge del PR #93**, cuyo commit es `0f92a91d`:

```
gh api 'repos/jur211296/Yala/actions/runs?event=push&per_page=100' → 0f92a91d creado 2026-09-08T00:23:59Z
```

Diecinueve minutos más tarde, y da igual: la ventana de las 08:17 UTC seguía estando **7 h 53 min
después**. Hubo ventana, y no disparó.

### Cinco causas más, descartadas y medidas

Además de las cuatro del ticket:

| Causa candidata | Medición | Veredicto |
|---|---|---|
| Es un fork (los forks no ejecutan `schedule`) | `gh repo view --json isFork` → `false` | descartada |
| Actions restringido en el repo | `actions/permissions` → `enabled: true`, `allowed_actions: all` | descartada |
| Apagado que la API no refleja | `gh workflow enable qa.yml` (idempotente) → sigue `active` | descartada |
| `concurrency` canceló el run | no hay bloque `concurrency` en el fichero | descartada |
| Colisión con un run en vuelo a esa hora | hueco vacío entre 08:08:38 y 08:50:36 UTC | descartada |

Y una distinción que el silencio no deja ver pero la API sí: **el run no se canceló, no llegó a
crearse.** Un run cancelado aparecería en la lista con `conclusion: cancelled` y su `event`. El
filtro por evento da cero absoluto:

```
gh api 'repos/jur211296/Yala/actions/runs?event=schedule&per_page=100' --jq .total_count
→ 0    (en TODO el repositorio, cualquier workflow, desde siempre)
```

### Lo que de verdad se perdió, en números

El ticket decía que sin la nocturna «deja de haber cobertura de UI, en silencio». Cuánta:

```
runs de QA por día, y cuántos llevaban la suite de UI dentro (>55 min de reloj; la UI son ~67)
  2026-09-05   runs QA:  52   con UI: 31
  2026-09-06   runs QA:  39   con UI: 27
  2026-09-07   runs QA:  39   con UI: 24
  2026-09-08   runs QA:  31   con UI:  1   ← el día de la mudanza
```

Esa **una** del día 8 es el `workflow_dispatch` manual de verificación. Corridas **automáticas** de
UI desde la mudanza: **cero**. Se pasó de 24-31 al día a ninguna, que es exactamente el modo de
fallo que el YAML avisaba que había que vigilar, ocurriendo desde el primer día.

Conviene separar dos preguntas que el silencio confunde, porque la mitigación de cada una es
distinta:

- **¿Corrió la UI?** La contestan `schedule` **y** `workflow_dispatch`: los dos ponen
  `UI_TOCABA=true` y ejecutan la suite entera. Para *cobertura*, un dispatch manual cuenta.
- **¿Funciona el reloj?** La contesta **solo** `schedule`. Para eso un dispatch manual no prueba
  nada — y leerlo como prueba es el error que ya se cometió una vez con el run de 89,7 min.

Al preguntar «¿hubo corrida de UI en las últimas 26 h?» hay que filtrar por evento o la respuesta
es siempre que sí: **59 runs de QA en esa ventana, de los que solo 1 ejecutó la UI.**

### La sonda: contestar hoy en vez de en dos días

Con `qa.yml` la pregunta «¿dispara el `schedule` en este repo?» cuesta dos días, porque su ventana
es una al día. Se añadió `.github/workflows/cron-canary.yml` (commit `d4195157`, directo a `2.1`
porque el `schedule` solo corre desde la rama por defecto): un workflow de Linux que dura segundos,
con `cron: '*/5 * * * *'`. Misma pregunta, una ventana cada cinco minutos. Es temporal y el propio
fichero dice cuándo se retira.

## Lo que ya está descartado, medido

Las cuatro causas habituales no son:

| Causa candidata | Medición | Veredicto |
|---|---|---|
| El workflow no está en la rama por defecto | `default_branch` = `2.1`; el commit está en `origin/2.1` | descartada |
| El workflow está deshabilitado | `gh api .../actions/workflows` → `state: active` | descartada |
| Apagado por inactividad (repo público, 60 días) | `pushed_at` = hoy; el estado sería `disabled_inactivity`, no `active` | descartada |
| El `cron` es inválido | `17 8 * * *`, cinco campos; actionlint 1.7.12 en verde sobre el fichero | descartada |

Queda la explicación aburrida y probable: **GitHub retrasa y a veces omite la ventana**, sobre todo
la primera tras añadir un `schedule`. Está documentado ("the `schedule` event can be delayed during
periods of high load"). El minuto 17 ya se eligió para esquivar la congestión de la hora en punto.

**Una sola ventana perdida no prueba que esté roto.** Por eso esto es un ticket y no una alarma.

## Que la nocturna FUNCIONA ya está probado — no es lo que se duda aquí

El `workflow_dispatch` corre exactamente lo mismo que la nocturna, y corrió:

| run | evento | rama | duración | resultado |
|---|---|---|---|---|
| `34173188063` | `workflow_dispatch` | `2.1` | **89,7 min** | success |

Es decir: el contenido de la nocturna está verificado de punta a punta, con la UI dentro y sobre la
rama correcta. Lo que no está verificado es **que el reloj la despierte sola**.

La distinción importa porque es justo el modo de fallo que el YAML avisa que hay que vigilar: una
corrida programada que desaparece sin que nadie la toque no rompe nada, no pone nada en rojo y no
avisa. Simplemente deja de haber cobertura de UI, en silencio, y nadie se entera hasta que un bug de
UI llega a producción.

### El veredicto de la sonda: el reloj no sirve ventanas en este repositorio

Del **10:02 al 10:39 UTC**, 37 minutos, con el canario `active` en la rama por defecto y su cron
`*/5`: **siete ventanas, cero runs.** 36 muestras a razón de una por minuto, todas en cero, y cero
runs con `event: schedule` en todo el repositorio.

**Y el canario no está roto, que es la otra explicación posible y había que descartarla.** Lanzado a
mano (run `34216568502`) corre y termina en verde en segundos. Es decir: el workflow es válido, es
ejecutable, GitHub lo reconoce y está donde tiene que estar. Lo único que no ocurre es que el reloj
lo despierte — que es exactamente el síntoma de `qa.yml`, reproducido en un segundo workflow
independiente y en minutos en vez de en días.

Sin este control positivo la medición no valdría nada: un canario que nunca dispara **porque está
mal escrito** produce el mismo cero que uno al que GitHub no sirve, y habría acabado documentando
un error mío como un fallo de la plataforma.

**Lo que esta muestra NO distingue,** y conviene decirlo: «el `schedule` no dispara» y «el
`schedule` se retrasa más de 37 minutos» dan el mismo cero. La documentación de GitHub admite
retrasos bajo carga y los repositorios públicos gratuitos no tienen prioridad. Pero la conclusión
operativa es la misma en los dos casos y es la que importa: **no se puede colgar la cobertura diaria
de UI de este mecanismo.** Un reloj que puede no sonar, o sonar tardísimo, sin avisar de ninguna de
las dos cosas, no es un reloj sobre el que se construye.

Por eso el vigilante no espera a que el diagnóstico se cierre del todo: la cobertura no puede
quedarse esperando a que GitHub se explique.

## La mitigación: el vigilante (`nocturna-vigilante.yml`, commit `6bddb614`)

El diagnóstico del cron puede tardar días. La ausencia de cobertura, no: hoy es cero. Así que la
mitigación no espera al veredicto, y además no depende de él — vale igual si el cron acaba
disparando (puede omitir ventanas, y a los 60 días de inactividad GitHub lo apaga solo) que si no.

Comprueba que la suite de UI corrió sobre `2.1` en las últimas 26 h y, si no, **la lanza él** y
avisa a Grok. Corre en Linux y dura segundos.

**Dos relojes que fallan de forma distinta**, que es todo el diseño:

- `schedule` (11:43 UTC, 3 h 26 min tras la ventana de la nocturna) — es el mismo mecanismo que
  vigila, así que por sí solo no vale de nada.
- `push` a `2.1` — no depende del cron. Cubre lo que de verdad importa: que todo commit que entra
  en la rama por defecto acabe teniendo una corrida completa de UI.

Punto ciego medido y aceptado: 8 de los últimos 30 días no tuvieron ningún commit en `2.1`, con
rachas de hasta 3 seguidos. En esos días el reloj de push no suena — pero tampoco hay código nuevo
que probar, así que lo que se pierde es vigilancia del entorno, no cobertura del código.

### Verificado de punta a punta, no deducido

El camino que lanza la nocturna solo se recorre el día que algo va mal, y un mecanismo de
emergencia que únicamente se ejercita durante la emergencia no está probado. Por eso la ventana es
un parámetro del `workflow_dispatch`. Con `horas: 1`, run `34214276978`:

```
Ventana: desde 2026-09-08T09:13:23Z (hace 1 h) hasta ahora.
  event=schedule → 0 run(s) dentro de la ventana
  event=workflow_dispatch → 0 run(s) dentro de la ventana
##[warning]La nocturna no ha corrido. Se lanza desde aqui.
Dispatch enviado.
Buscando un run de qa.yml creado despues de 2026-09-08T10:13:24Z.
##[notice]El run existe. La suite de UI corre ahora.
##[warning]Grok recibio el aviso (HTTP 200): la nocturna no habia corrido y se ha lanzado sola.
```

Los cuatro eslabones, cada uno medido: detecta la ausencia, dispara, **comprueba que el run nació**
y entrega el aviso. Y el camino normal también, en el run `34214190128` del push que lo introdujo:
con la ventana por defecto vio `workflow_dispatch → 1` (el dispatch de las 00:24) y no lanzó nada.

Una cosa que se daba por sabida y ahora está medida: **el `GITHUB_TOKEN` sí puede disparar un
`workflow_dispatch`.** GitHub no crea runs a partir de eventos disparados con ese token —es la
regla anti-cascada— y `workflow_dispatch` es la excepción documentada. Aquí está comprobada en
producción, que es distinto de haberla leído.

### Efecto inmediato

Ese disparo de prueba dejó la nocturna corriendo (run `34214288413`, suite completa de UI). La
cobertura de UI de hoy pasó de cero automáticas a una real.

## Cómo se cierra

`gh workflow enable qa.yml` ya se corrió (idempotente): el workflow seguía `active`, así que no
había apagado que la API no estuviera reflejando.

Lo que queda por mirar, y **ya no bloquea la cobertura**, porque el vigilante la garantiza:

```bash
# ¿ha servido GitHub alguna ventana programada, en cualquier workflow?
gh api 'repos/jur211296/Yala/actions/runs?event=schedule&per_page=100' --jq .total_count
```

- **Deja de ser cero** → el cron sí sirve ventanas; lo de hoy fue retraso. El vigilante se queda
  igual: su trabajo es que una ventana perdida no pase inadvertida, no sustituir al cron.
- **Sigue en cero mañana** → el `schedule` no sirve en este repositorio, y entonces el `schedule`
  del propio vigilante tampoco vale: quien sostiene la cobertura es su disparador de `push`. Eso
  deja descubiertos los días sin commits (8 de los últimos 30), y **ahí sí hay una decisión tuya**:
  montar un reloj que no dependa de GitHub —un `launchd` en la Mini que haga `gh workflow run
  qa.yml`— o aceptar que la cobertura de UI vaya atada al ritmo de trabajo y no al calendario.

**Lo que NO hay que volver a hacer:** leer un `workflow_dispatch` en verde como prueba de que el
reloj funciona. Corre el mismo contenido, y por eso no distingue nada.

## Distinto de

- `el-job-de-tests-del-ci-no-tiene-timeout` (done) — puso los topes y mudó la UI. Los topes están
  verificados en producción; esto es el cabo que aquel no podía comprobar porque el cron aún no había
  tenido ninguna ventana.
- `ci-warns-but-does-not-block` — va del `continue-on-error`, no del disparo.

## Acceptance Criteria

- [x] Queda medido si el `schedule` dispara solo, sobre al menos dos ventanas. → **Siete ventanas
      del canario `*/5` en 37 min, cero runs**, más la ventana perdida de `qa.yml` con 7 h 53 min
      de margen. Cero `event: schedule` en todo el repositorio, nunca. Con control positivo: el
      canario lanzado a mano corre en verde, así que lo que falla es el reloj y no el workflow.
- [x] Si no dispara, la suite completa de UI vuelve a tener una corrida diaria efectiva por algún
      medio, y queda escrito cuál. → **`nocturna-vigilante.yml`**, verificado de punta a punta en
      producción (detecta la ausencia, lanza, comprueba que el run nació, avisa). El medio es
      doble a propósito: su `schedule` y, sobre todo, su disparador de `push` sobre la rama por
      defecto, que no depende del cron. Punto ciego medido y escrito: los días sin commits.
