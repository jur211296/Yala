---
name: el-ci-se-verifica-en-local
description: Un cambio al workflow del CI se prueba ANTES de pushear — el script del paso se extrae del YAML y se corre con matriz de escenarios; actionlint con control negativo zanja las dudas de schema
metadata:
  type: feedback
---

**Un cambio a `.github/workflows/` no se verifica esperando al CI: se verifica en local, y sale más
barato.** Tres gestos, los tres medidos el 2026-09-07 en el ticket del timeout del CI.

**Why:** el bucle «pushear y mirar qué pasa» cuesta ~90 min por intento en este repo, y encima
prueba *una* rama del comportamiento — justo la que se dio ese día. La lógica interesante de un
workflow (a quién avisa, cuándo calla) tiene media docena de combinaciones y ninguna se elige a
voluntad desde un push.

**How to apply:**

1. **El `run:` de un paso es bash y se puede ejecutar.** Extráelo del YAML con un parser, no a ojo
   (`ruby -ryaml -e '...steps.find{...}["run"]'`), y córrelo con las variables del paso puestas a
   mano. Así probé los **8 escenarios** del aviso a Grok —PR verde con UI saltada, PR con unit en
   rojo, PR con el build caído, nocturna verde, nocturna con UI roja, nocturna cancelada— en
   segundos. Truco para leer el resultado sin enviar nada: deja `WEBHOOK_URL` vacío; la rama que
   avisa muere con `::error ... Faltan GROK_WEBHOOK_*` y la que calla sale con su `::notice` y
   exit 0. Eso es un discriminador limpio de qué rama tomó.
2. **Un paso que decide (`if:`, outputs) se corre con el entorno del evento.** El job `changes` de
   Yala decide si la suite corre; ejecutarlo con `GITHUB_EVENT_NAME=schedule` y `GITHUB_OUTPUT`
   apuntando a un fichero temporal confirmó en un segundo que un `schedule` cae en su rama
   fail-closed y devuelve `run_tests=true`. Razonarlo habría bastado *casi* siempre, que es el
   problema.
3. **`actionlint` para lo que la documentación no contesta — con control negativo.** La doc de
   GitHub no dice si `timeout-minutes` admite `${{ }}`; actionlint sí, y lo dice en el mensaje de
   error («expecting a single `${{...}}` expression **or float number literal**»). Pero un linter
   que acepta todo no prueba nada: **antes de creerte el verde, dale de comer algo inválido**
   (texto plano, una expresión de tipo string, una clave mal escrita) y comprueba que protesta por
   los tres. `brew install actionlint`; valida expresiones, contextos disponibles y shellcheck del
   `run:`.

**Y lo que NO se puede verificar así, para no venderlo como probado:** que el valor de un
`timeout-minutes` sea el correcto sólo se observa provocando el cuelgue, que cuesta el tope entero.
Ahí el schema y la semántica de `&&`/`||` es lo que hay; dilo como inferido.

**El corolario que casi me muerde:** cuando el cambio ES al CI, el PR es su propia prueba y eso es
un argumento para ir por PR aunque `CLAUDE.md` permita commitear directo a `2.1` un diff que cae
entero en `.github/`. Si commiteas directo, el workflow nuevo corre por primera vez ya mergeado.

Ver [[mis-mediciones-fallan-por-el-filtro]] (el control negativo es la misma familia) y
[[gate-paso3-no-detecta-cero-casos]].

## El comentario que escribí para justificar mi propio diseño era una inferencia falsa

Al poner los topes de paso escribí en el YAML el porqué: «cuando el JOB agota su tope, el runner lo
mata y el paso final de aviso puede no llegar a ejecutarse **ni con `if: always()`**». Sonaba a
mecanismo de plataforma y lo escribí con tono de hecho. Es **falso**: el servidor re-evalúa las
condiciones de los pasos pendientes y los `always()` sí corren, con una ventana de 5 min.

Lo cazó una verificación contra `actions/runner` que había lanzado *en paralelo*, no yo releyendo.
El diseño se sostenía —los topes de paso siguen siendo lo correcto—, pero **por una razón distinta
de la que dejé escrita**: lo que `continue-on-error` rescata es el `Failed` de un timeout de paso, y
no rescata la cancelación de un timeout de job (`ApplyContinueOnError` abre con
`if (Result != TaskResult.Failed) return;`).

⇒ **la justificación que escribo en un comentario es tan verificable como la premisa de un ticket, y
envejece peor: queda ahí como documentación para el siguiente.** Cuando el porqué de una decisión
apoya en «así se comporta la plataforma», eso es una afirmación que hay que medir o marcar como
inferida — sobre todo cuando es *mi* diseño el que se beneficia de que sea cierta, que es cuando
menos ganas tengo de comprobarla.


## Y la herramienta puede no estar mirando el fichero: actionlint NO linta `.github/actions/`

**2026-09-09.** Saqué el envío de los avisos a una composite action y `actionlint` dio `rc=0` a la
primera. El YAML estaba **roto** (un `description:` sin comillas con un `: ` dentro). `actionlint
-verbose` lo dice: `Linting 3 files`, los tres de `workflows/`. **El verde era sobre cero
ficheros** — la familia exacta del «SUCCEEDED con cero tests».

**How to apply:**

- Control negativo **de la herramienta, no solo del código**: mete un error en el fichero que crees
  que está lintando y comprueba que lo canta. Si no lo canta, no lo está mirando.
- Cuenta los ficheros que dice mirar. Y ojo con el grep que usas para contarlos: el mío
  (`grep -c "^verbose: Linting \."`) dio 3 cuando eran 4, porque actionlint entremezcla las líneas
  y algunas salen como `verbose: verbose: Linting …`. Dos filtros mal en la misma sesión.
- La red que sí funciona para un `action.yml`: cargarlo con `yaml.safe_load` —eso **es** la
  comprobación de sintaxis— y pasar sus `run:` por `shellcheck -e SC2154`. Cazó el YAML roto al
  primer intento.
- Lo que actionlint **sí** cubre: valida los `with:` de un `uses: ./.github/actions/<x>` contra los
  `inputs:` declarados. Cubre la interfaz, no el cuerpo.

**Y `!` dentro de comillas dobles en zsh se come el grep.** `grep -n "if: \${{ !cancelled"` no
encontró una línea que estaba ahí. Comillas simples, o `grep -n 'cancelled()'`. Familia de
[[zsh-no-divide-variables]].

## Un job «cortado por tiempo» se diagnostica contando tests, no buscando el cuelgue

**2026-10-06, PR #369.** El encargo decía «pure-logic se cuelga en CI». No había cuelgue: el log decía
`Test run with 26 889 tests` contra los 8 963 de un run sano. Con Swift Testing,
`-retry-tests-on-failure` repite la suite **entera** hasta tres veces, así que un solo rojo determinista
triplicaba el paso y el tope del job lo cancelaba. Tres greps lo zanjaron: el conteo, el `✘ … recorded an
issue at`, y los tiempos por paso de la API comparados con 8 runs sanos.

**How to apply:**

- Ante un corte por tiempo, lo primero es `grep "Test run with"` en el log del job y compararlo con un run
  sano. Un múltiplo exacto es el reintento, no un cuelgue.
- Un rojo que solo sale en CI y no en el gate: el runner arranca en **inglés**. Se reproduce con
  `-testLanguage en -testRegion US`, y el control es correr el test ORIGINAL así y verlo caer en la misma
  línea que el CI.
- Las tandas de mutantes, otra vez sin `-collect-test-diagnostics never`: tercera vez (ver
  [[mutantes-sin-diagnose-y-con-copia]]). Cada mutante cazado costó 600 s de `simctl diagnose`.
