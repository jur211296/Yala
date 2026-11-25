---
description: Qué frena el merge en el CI de GitHub (qa.yml) y qué solo avisa — los unit bloquean desde el 2026-10-10, la UI no. Se carga al tocar el workflow o sus scripts.
paths:
  - ".github/workflows/qa.yml"
  - "qa/scripts/ci-*.sh"
  - "qa/cuarentena.json"
  - "qa/scripts/cuarentena-test.sh"
  - "qa/checklist-confiabilidad.yaml"
  - "qa/scripts/checklist-elegir*"
  - ".claude/agents/revisor-checklist.md"
---

# CI de GitHub: qué frena el merge

El ruleset de `2.1` exige tres checks: `tests`, `coverage-index` y `gateway`. El auto-merge
(ADR-054 de casa) mergea en cuanto los tres salen verdes. Leerlo cuesta un comando:
`gh api repos/jur211296/Yala/rulesets/24270515`.

| Qué | ¿Frena el merge? | Dónde |
|---|---|---|
| Unit pure-logic y context-based | **Sí**, desde el 2026-10-10 | jobs `build` → `unit` (3 tandas) → `tests` |
| UI (XCUITest) | No: advisory y solo en la nocturna | job `ui` |
| UI de lo tocado | No corre en el CI: solo en el paso 3 de `/gate`, en local | `qa/scripts/interfaz-de-lo-tocado.py` |
| Revisor con checklist | No corre en el CI: paso 4 bis de `/gate`, en local y en observar | `qa/scripts/checklist-elegir.py` (de 2.3) |
| El aviso a Grok | No, salvo que no quede ningún canal | job `aviso` |

## Los unit van en tres jobs, y `tests` es solo su veredicto (2026-11-21)

Auditoría de tiempos del CI (`docs/auditorias/2026-11-21-ci-tiempos.md`). Un PR que compilaba tardaba
~66 min en el p50: build desde cero (~27), pure-logic (~23) y context-based (~4) en serie en un runner.

- **`build`** compila una vez y sube los productos. **Reusa el DerivedData del último build de 2.3**
  (`actions/cache`, clave = Xcode + `Package.resolved` + commit). Medido en la Max: frío 214 s; mismo
  checkout 23 s; cambio dentro de una vista 47 s; solo un test 65 s; cambio de interfaz en un fichero
  central 192 s. **La ruta tiene que ser la misma** (copiado a otra, recompila entero) y la caché de
  compilación de Xcode sola, sin el resto del DerivedData, no gana nada (218 s).
  Guarda el push a 2.3/1.0 y la nocturna; un PR solo si no encontró nada. Un fallo de caché nunca
  rompe el run (`continue-on-error`): compila desde cero.
  **Desde el 2026-11-25 la caché sí recorta** (clave `ddp-v2`): medido sobre 63 PR del 19 al 25-nov, se
  restauraba y el build tardaba igual (~29 min), porque el checkout deja todas las fechas nuevas y el
  build lo recompilaba todo. Ahora el paso «Fechas de los ficheros desde la caché»
  (`qa/scripts/ci-fechas-desde-cache.py`) da una fecha fija vieja a lo que no cambió desde el commit de la
  caché y la de ahora a lo que sí, y la caché de compilación de Xcode va apagada (con ella encendida, una
  línea cambiada recompilaba casi todo). **Nunca des a un fichero cambiado una fecha más vieja que la del
  build anterior**: el build compara «más nuevo que» y lo da por al día; medido, el binario salió con el
  código de antes y el build en verde. Por eso no valen fechas derivadas del contenido. Límite: un PR que
  cambia declaraciones del módulo de la app recompila `YalaTests` entero igual (medido, 518 s como un build
  completo); el recorte es para los cambios internos (~1 min frente a ~4-8). Lo que queda, en la card
  «el build recompila todas las pruebas unitarias».
  **Nada escribe en `.ddp` mientras se restaura**: el simulador en segundo plano valida con su propio
  DerivedData (`SIM_DERIVED`). Con `.ddp`, su `-showdestinations` resolvía paquetes en
  `.ddp/SourcePackages` a la vez que `tar` extraía ahí, y la caché salía «no encontrada» (run 44924790889).
- **`unit`** es una matriz de 3 tandas. El reparto lo hace `qa/scripts/ci-unit-tandas.sh` por los
  tiempos de `qa/ci-unit-tiempos.json`; la última tanda corre «todo menos lo de las otras», así que
  una suite nueva nunca se queda fuera. Context-based corre en la tanda 1, a la vez que las otras.
  La lista de sus 7 clases vive en ese script, en un solo sitio.
- **`tests`** (Ubuntu) junta resultados con `ci-unit-resultado.sh` y **falla cerrado**: rojo si el
  build o cualquier tanda no corrió o no salió en verde. Es el check que exige el ruleset: **no se
  renombra**, y nunca se le pone `continue-on-error`. `ci-unit-bloqueante-test.sh` lo vigila, junto con
  que `TANDAS` cuadre con la matriz.
- **Tabla de tiempos.** Cada tanda sube `unit-tiempos-N` (segundos por suite, del `.xcresult`). Cuando
  las tandas se descompensen, `python3 qa/scripts/ci-unit-tiempos.py generar <run> <run> <run>`.
- **Cambiar el número de tandas** toca la matriz, las salidas `pure_N`/`rojos_N` de `unit` y `TANDAS`
  de `tests`. Ocupan 3 de los 5 macOS de la cuenta: por eso la nocturna va de noche.

## La nocturna la lanza el vigilante a hora fija (2026-11-21)

GitHub servía el cron de `qa.yml` con 6-10 h de retraso (entre las 09:00 y las 13:47 de Lima, del
12-oct al 20-nov), y la nocturna, que dura 7,5-9 h, ocupaba los macOS en plena jornada.

- **`nocturna-vigilante.yml` despierta cada hora y en cada push a la rama de trabajo**, y la lanza en
  cuanto pasa la hora del cron de `qa.yml` (02:17 UTC = 21:17 Lima) si la del día no ha nacido
  (`PLAZO_HORAS=0`). Sin aviso: es lo normal. Avisa solo si la lanza más de 6 h tarde.
- **El cron de `qa.yml` es el respaldo**: cuando GitHub lo sirve, el job `changes` pregunta al mismo
  script si la del día ya nació (excluyendo su propio run) y, si sí, no corre nada. Si no puede
  saberlo, corre.
- **Mover la hora es cambiar ese cron**; el vigilante la lee de ahí. A las 21:17 acaba hacia las
  05:00-06:30. Al minuto exacto solo lo daría un disparador fuera del repo (launchd en la Mini):
  propuesto, no hecho.

## `coverage-index` corre dos bancos en segundo plano (2026-11-21)

`interfaz-de-lo-tocado-test.sh` (~100 s) y `sim-lock-test.sh` (~82 s) se lanzan con
`qa/scripts/bancos-en-fondo.sh lanzar` y un último paso (`if: !cancelled()`) los espera. **El sitio en
el job importa**: `sim-lock-test` cuenta procesos `xcodebuild` y va después de los bancos que crean uno
de mentira; `interfaz-de-lo-tocado-test` hace `git fetch` y va después del otro paso que lo hace. Un
banco nuevo en segundo plano tiene que pasar esas dos preguntas. `gate-ci-checks.sh` replica
`if: ${{ !cancelled() }}` (en local ya corre todo) y ninguna otra condición. `changes` y
`coverage-index` tienen tope de 10 min.

## La interfaz de lo tocado corre en el gate local, no en el CI del PR

**Decisión de Jürgen, 2026-11-17: ningún PR corre pruebas de interfaz en el CI.** El runner `xcode-27`
se paga por minuto y no hay presupuesto. La propuesta P2 de `docs/verificacion/` pedía un job del PR
en observar y luego obligatorio; se midió y se descartó. No se vuelve a proponer un job de interfaz
por PR sin un presupuesto de macOS aprobado.

- **Lo que se midió** sobre los 214 PR de 2.3 del 3 al 17-nov: 143 tocan pantallas, y en casi todos
  `qa/scripts/interfaz-de-lo-tocado.py` encuentra más clases de las que caben (mediana sin techo:
  ~495 min de interfaz). Con 40 min de techo y ~20 de build, eran ~59 min de macOS por PR, ~10 h/día.
- **Lo que queda**: el script elige las clases del paso 3 de `/gate` en la Mini o la Max (gratis),
  con techo de 30 min y la lista de lo que deja fuera. Su banco (`interfaz-de-lo-tocado-test.sh`)
  corre en `coverage-index`, que es ubuntu y no cuesta.
- **Lo que eso significa**: la interfaz no tiene red en el PR. Un PR que se cuele sin gate (o con
  el paso 3 saltado) solo se ve en la nocturna, ya dentro de `2.3`. Por eso el paso 3 del gate no
  se salta, y lo que el script deja FUERA va al informe del gate como no corrido.

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

## Cuarentena: un rescate solo vale si la prueba está en la lista

Desde el 2026-11-17 (propuesta P1 de verificación, `docs/verificacion/`). Del 10 al 17-nov, 50
rescates en 47 de 338 corridas, todos de la familia `CurrencyConverter*`: un rojo rescatado
mergeaba en verde y nadie se enteraba.

- **La lista es `qa/cuarentena.json`, y el CI la lee de `origin/2.3`, nunca del PR** (paso
  «Cuarentena de pruebas inestables» de cada tanda del job `unit`). Apuntar una prueba es un PR propio a 2.3, con
  dueño, ticket, fecha de entrada y motivo; no viaja dentro del PR que la rescata.
- `ci-reintentar-rojos.sh --cuarentena` juzga cada rescate: en la lista, aviso con dueño y días;
  fuera, aviso «Rescate fuera de cuarentena» en el PR (anotación) y en el resumen del job. Los
  arranques fallidos del simulador no pasan por la lista: son infraestructura.
- **Modo observar hasta el 1-dic-2026**: el rescate fuera de lista se anota y no frena. El
  interruptor es `_meta.modo` (`observar` → `bloquear`) en el fichero de 2.3; la promoción es una
  sesión corta aparte, que decide también si un fichero ilegible debe bloquear (hoy cuenta como
  lista vacía en observar, con un error visible).
- **A los 14 días sin arreglo, la prueba se borra con su porqué** (o sale de la lista si ya está
  arreglada). El CI la lista como vencida en el resumen del job; no borra nada solo.
- Banco: `cuarentena-test.sh` (valida la lista del árbol y el lector) y
  `ci-reintentar-rojos-test.sh`, casos 21-28. Los dos en `coverage-index`.
- Solo la LISTA se lee de 2.3; el script que la aplica sigue siendo el del PR. Leer también las
  reglas del gate de la rama base es la propuesta P4.
- **Vale también para la UI de la nocturna (2026-11-25).** Se apunta como `YalaUITests/Suite/test_caso()`
  (o `YalaUITests/Suite`). La prueba corre igual; si su rojo final está en la lista, el paso «Veredicto de
  la tanda» (`qa/scripts/ci-ui-veredicto.py`) no pinta la tanda y la lista aparte en el aviso, con dueño,
  ticket y días. Sin modo bloquear para la UI (es advisory); la caducidad de 14 días, igual. Banco:
  `ci-ui-veredicto-test.sh`.

## Revisor con checklist: en el gate, en observar, leído de 2.3

Desde el 2026-11-17 (propuesta P4 de `docs/verificacion/`). Paso 4 bis de `/gate`: un solo agente
`revisor-checklist` recibe el diff y los ítems de `qa/checklist-confiabilidad.yaml` que dispara, y
hace hasta tres rondas con la sesión. No corre en el CI: es local, como la interfaz de lo tocado.

- **Se leen de `origin/2.3`, nunca del PR**: la checklist, `qa/scripts/checklist-elegir.py` (el gate
  lo saca con `git show`) y las instrucciones del revisor (el selector mete el cuerpo de
  `.claude/agents/revisor-checklist.md` de 2.3 en el encargo). Un PR que cambie cualquiera de los tres
  se juzga con los de 2.3, y el informe lo avisa. Cambiar las reglas es un PR propio a 2.3.
- **Solo lógica cara**: aplica si dispara un ítem de nube, dinero, migración, fechas o formulario. Los
  de `pruebas` acompañan y no lo disparan solos. Tope de 10 ítems; no se rellena hasta 3.
- **Medido sobre los 215 PR mergeados a 2.3 del 3 al 17-nov** (con los 30 ítems de la checklist): el
  revisor habría aplicado en 72 (≈5 al día), mediana 2 ítems, máximo 6; el tope no se alcanzó nunca;
  2 ítems no dispararon (`salir-de-fase-repone-pendientes`, `syncid-cambiado-escribe-testigo`).
- **Validado** sobre el PR de categorías a un toque (#920): el revisor señaló
  `SplitCalculatorUITests` y `AccountCardPickersUITests`, las dos que ese PR rompió sin correrlas. No
  es una prueba ciega: ese PR es uno de los dos orígenes del ítem.
- **Modo observar**: no bloquea. El interruptor es la constante `MODO` del selector, en 2.3. El
  resultado va al cuerpo del PR («Revisor con checklist», con los ids) y a la línea `Verificado:`
  (`· revisor N ítems, H hallazgos, K aceptados`). `ultimo_disparo` no se escribe en el YAML: la
  revisión mensual (P5) lo cuenta de los PR.
- **Cuándo pasa a bloquear**: no antes del **15-dic-2026** ni de **30 PR con revisor**. Se cuenta con
  `git log origin/2.3 --format=%B | grep -o 'revisor [0-9]* ítems*, [0-9]* hallazgos*, [0-9]* aceptados*'`.
  Se promueve si al menos la mitad de los hallazgos acabaron aceptados (arreglados) y menos de uno de
  cada diez PR quedó «sin acuerdo». Bloquear significa: sin sello mientras quede un hallazgo sin
  acuerdo tras la ronda 3. Lo decide Jürgen, en una sesión corta que cambia `MODO` en 2.3.
- Banco: `qa/scripts/checklist-elegir-test.sh` (repo de mentira con su rama de reglas), en
  `coverage-index`.

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

Y otra vez el 2026-11-19, sin llegar a cancelar: el máximo verde iba a 74,9 de 80 (build y pure-logic casi se doblaron
desde el 26-oct). Job a 110, build a 50, pure-logic a 55, con la tabla re-medida en `qa.yml`.

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
  **Desde el 2026-11-19 se regenera con varios runs** (`ci-ui-tiempos.sh <run> <run> <run>`): cada suite pesa la
  mediana y cada caso cuenta como mucho 600 s. Con uno solo, un runner congelado (un caso de 29 min «passed») pesaba
  la suite al triple. Ese día la suite sumaba ~872 min y las tandas pasaron de 9 a 14.
- **Cada caso tiene tope de 10 min** (`-default-test-execution-time-allowance 600` en el paso de UI, 2026-11-19). El
  más lento legítimo mide ~6. Si una suite nueva necesita más, se parte el caso; no se sube el tope a ciegas.
- **Un caso cortado por el tope no lo reintenta xcodebuild** (2026-11-25): reinicia el runner y sigue, y el caso
  queda rojo aunque `-retry-tests-on-failure` esté puesto. Del 22 al 25-nov pasó en ~3 casos por noche, siempre
  distintos: la app deja de avisar que está quieta y cada toque espera 60 s. El veredicto de la tanda relanza una
  vez, solo, cada caso cortado (como mucho 3); si pasa, no pinta la tanda y sale aparte en el aviso. Si un mismo
  caso se cuelga dos noches, ya no es el runner: se mira el caso.
- **El runner de XCUITest se calienta aparte** («Calentar el runner de XCUITest», un caso corto del Panel que no
  cuenta). Calentar el simulador solo abre la app, y el primer caso de cada tanda seguía pagando el arranque del
  runner y de la accesibilidad. Si cambias el caso de calentamiento, que siga siendo corto y verde cada noche.
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
