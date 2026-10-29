---
description: Qué frena el merge en el CI de GitHub (qa.yml) y qué solo avisa — los unit bloquean desde el 2026-10-10, la UI no. Se carga al tocar el workflow o sus scripts.
paths:
  - ".github/workflows/qa.yml"
  - "qa/scripts/ci-*.sh"
---

# CI de GitHub: qué frena el merge

El ruleset de `2.1` exige tres checks: `tests`, `coverage-index` y `gateway`. El auto-merge
(ADR-054 de casa) mergea en cuanto los tres salen verdes. Leerlo cuesta un comando:
`gh api repos/jur211296/Yala/rulesets/24270515`.

| Qué | ¿Frena el merge? | Dónde |
|---|---|---|
| Unit pure-logic y context-based | **Sí**, desde el 2026-10-10 | job `tests` |
| UI (XCUITest) | No: advisory y solo en la nocturna | job `ui` |
| El aviso a Grok | No, salvo que no quede ningún canal | job `aviso` |

## La regla: un unit en rojo pone `tests` en rojo

- **Nunca `continue-on-error` en un paso de unit.** GitHub pinta de verde un paso así aunque
  `xcodebuild` salga con 65, y el PR entra en cola con el rojo dentro. Pasó: `UploadOrderTests` y
  `PrivateSessionMarkTests` entraron en `2.1` en rojo (3 y 7 de octubre). El banco
  `qa/scripts/ci-unit-bloqueante-test.sh`, en `coverage-index`, falla si vuelve.
- **Un flaky se cubre con reintento acotado, nunca con advisory.** Los dos pasos usan
  `ci-reintentar-rojos.sh`: repite solo los casos rojos, hasta 3 vueltas, y en un PR verde no cuesta
  nada. El flaky lleva su ticket (hoy `spike-r3-eje-4b-flaky-en-suite-completa`).
- **Un arranque fallido del simulador no es un test (2026-10-26).** Si una vuelta no corre ningún
  test real, el script relanza la selección entera dentro de sus 3 vueltas; un caso cuyo
  identificador lleva espacios («Yala encountered an error») es el texto de un error y no se repite
  nunca. Antes lo repetía dos veces como `-only-testing`, con 0 tests y el paso en rojo (run
  38969099625). Banco: `ci-reintentar-rojos-test.sh`, casos 14-20.
- **Nunca `-retry-tests-on-failure` en un paso de unit.** Con Swift Testing repite la selección
  entera, no el caso: un rojo triplica el paso y el tope del job lo cancela.
- **Context-based corre aunque pure-logic salga en rojo** (`if: !cancelled() && build ok`). Si se
  saltara, el aviso leería ese `skipped` como «la suite no llegó a correr».

Volver a poner un paso de unit en advisory es una decisión de Jürgen, no un arreglo. Ticket del
cambio: `ci-warns-but-does-not-block`.

## El tope del job cancela, y una cancelación también frena

Un job `tests` que agota su tope sale `cancelled`, y un check requerido cancelado también bloquea
el merge. **El tope sigue al trabajo, no al revés**: cuando el job verde se acerca a él, se sube
con la tabla de `qa.yml` («TOPES DE TIEMPO») re-medida, y se sube con él cualquier tope de paso
que tenga el mismo margen. Relanzar a mano no es la salida —la cola de auto-merge no espera a
nadie— y quitar el tope tampoco: sin él, un cuelgue real tarda seis horas en verse.

Pasó el 2026-10-24: el tope de 45 min canceló cinco jobs en verde en seis días (la suite pasó de
8 963 a 11 243 casos y el runner varía el doble de un run a otro). Un «context-based se cuelga»
era el tope del job cortando el último paso. **Antes de buscar el cuelgue, lee los tiempos por
paso de la API de Actions**: si el paso cancelado lleva un minuto y los anteriores se comieron el
tope, no hay cuelgue. Ticket: `ci-tests-job-ceiling-cancels-green-runs`.

Volvió a pasar el 2026-10-26 (run 40422732167, tope 60): el tope sube a 80 y los de paso de build
y pure-logic a 40 y 45, con la tabla re-medida en `qa.yml`. Esa vez había además un unit que salía
a CloudKit y esperaba a `cloudd` (47 s a 6,5 min según el runner). **Un unit no habla con la red**:
si un caso tarda decenas de segundos sin trabajo que lo explique, mira si espera a un servicio del
sistema antes de subir el tope. Ticket: `qa-2-2-se-cancela-tests-unitarios-context-based`.

## La UI se reparte en tandas, y una tanda que agota su tope no dice nada

La UI de la nocturna va en tandas paralelas (job `ui`, matriz). Una tanda que agota los 110 min de
su paso sale `failure` y el run sigue verde (advisory): **las suites que no llegó a abrir no
aparecen en ningún sitio**. Pasó del 23 al 29-oct de 2026: las tres tandas se cortaban cada noche,
~16 suites por tanda llevaban días sin correr, y la suite había pasado de 250 a 646 casos.

- **Cuando una tanda se acerque a ~80 min de UI, se añade otra**, no se sube el tope. Las cifras y
  la simulación están en `qa.yml` («POR QUE OCHO»). Cambiar el número toca la matriz, las salidas
  `ui_N` y `UI_TANDAS` del aviso; `ci-ui-tandas-test.sh` falla si no cuadran.
- **`max-parallel` deja un `macOS` libre para el CI de los PR**: GitHub sirve la nocturna de día.
- **El primer test de cada tanda paga el arranque del simulador** si nadie lo calienta antes
  (`ci-calentar-simulador.sh`). Un rojo que siempre cae en el primer caso de una tanda es eso, no
  el test.
- Para leer una tanda: `gh run view <run> --job <id> --log` (con `continue-on-error`,
  `--log-failed` sale vacío) y `grep "Test Suite '.*' (passed|failed)"` dice hasta dónde llegó.
