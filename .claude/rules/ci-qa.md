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

- **Cuando una tanda se acerque a ~80 min de UI, primero se regenera la tabla de tiempos; si no basta,
  se añade otra tanda**, no se sube el tope. Las cifras y la simulación están en `qa.yml` («POR QUE
  OCHO», «POR QUE NUEVE»). Cambiar el número toca la matriz, las salidas `ui_N` y `UI_TANDAS` del
  aviso; `ci-ui-tandas-test.sh` falla si no cuadran.
- **El reparto pesa por MINUTOS, no por casos (2026-11-05).** Con ocho tandas iguales en casos, los
  pasos fueron de 54 a 92 min: el coste por caso va de 10 s a más de 4 min. El peso sale de
  `qa/ci-ui-tiempos.json`; se regenera con `bash qa/scripts/ci-ui-tiempos.sh <run>` desde un run con
  **todas** las tandas completas (se niega si alguna no corrió casos). Una suite que no está en la
  tabla pesa 46 s por caso: una suite que se salta entera (vídeos, medidas de carga) tiene que estar
  en la tabla, o pesa minutos que no gasta. Una tabla vieja descompensa; nunca deja una suite fuera.
- **Las tandas no compilan (2026-11-04).** El job `ui-build` compila una vez y sube
  `.ddp/Build/Products`; cada tanda lo baja y corre `test-without-building`. Antes compilaba cada
  una en frío con tope de 25 y el runner tarda de 11 a 25+ min: cuatro de ocho se quedaron sin
  tests el 4-nov. No se vuelve a compilar por tanda. `-only-testing` no recorta el build:
  `build-for-testing` compila `YalaTests` igual.
- **`max-parallel` deja un `macOS` libre para el CI de los PR**: GitHub sirve la nocturna de día.
- **El primer test de cada tanda paga el arranque del simulador** si nadie lo calienta antes
  (`ci-calentar-simulador.sh`). Un rojo que siempre cae en el primer caso de una tanda es eso, no
  el test.
- Para leer una tanda: `gh run view <run> --job <id> --log` (con `continue-on-error`,
  `--log-failed` sale vacío) y `grep "Test Suite '.*' (passed|failed)"` dice hasta dónde llegó.

## El runtime del simulador nunca pasa del SDK, y una tanda sin tests no es un verde

Del 5 al 7-nov de 2026 las nueve tandas de UI corrieron **cero tests** y el run salió verde. La
imagen `xcode-27-arm64` cambió (20261026.0314.1 → 20261104.0337.1) y trajo un runtime iOS 27.2
completo; con el Xcode 27.1 del CI, `ci-simulador.sh` lo elegía por ser «el más nuevo» y el paquete
`YalaUITests` no cargaba (`AppIntentsTesting` de 27.1 pide un símbolo que el 27.2 ya no tiene).

- **Orden de runtimes** (`ci-simulador.sh`): casa con el SDK → el más nuevo que NO pase del SDK →
  solo si no hay otro, el menos nuevo de los posteriores, con aviso. El job `ui` corre en modo
  estricto (`SIM_HASTA_SDK=si`) y falla con el motivo antes de gastar el runner. Los unit van en
  modo tolerante: un runtime posterior les funciona, y el estricto dejaría los PR sin CI el día
  que la imagen pierda el bueno. Banco: `ci-simulador-test.sh`, casos 13-17.
- **Cada tanda cuenta lo que corrió** (`ci-ui-conteo.sh`, lee el `.xcresult` y el log). Si no
  ejecutó ningún test, la tanda sale en rojo y el aviso dice «la UI no ejecutó ningún test». Es lo
  único de la UI que pone su job en rojo: **un test en rojo sigue advisory**. Banco:
  `ci-ui-conteo-test.sh`.
- **Antes de culpar a un test o al runner, compara la imagen.** El `Set up job` de cada tanda trae
  `Runner Image → Version`, y el paso «Simulador del runner» imprime la línea `Entorno:` con imagen,
  Xcode, SDK y runtime con su build. Dos runs del mismo commit con imágenes distintas no prueban
  nada del código.
- Subir el CI a Xcode 27.2 (o al que traiga el runtime nuevo) va con la release, no con un
  incidente: cambia el compilador de los unit que bloquean el merge.
