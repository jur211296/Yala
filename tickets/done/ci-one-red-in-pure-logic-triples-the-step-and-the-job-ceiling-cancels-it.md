---
id: ci-one-red-in-pure-logic-triples-the-step-and-the-job-ceiling-cancels-it
status: done
priority: high
area: ci
created: 2026-10-06
updated: 2026-10-06
source: encargo 2026-10-06-pr369-tests-job-times-out-in-pure-logic (PR #369 cancelado tres veces)
---

# Un solo rojo en pure-logic triplica el paso y el tope del job lo cancela: el rojo advisory acaba bloqueando el merge

## Qué se midió

El paso `Unit tests (YalaTests pure-logic)` de `.github/workflows/qa.yml` corre con
`-retry-tests-on-failure`. Con Swift Testing, `xcodebuild` no repite el test que falló: **repite la suite entera**
hasta 3 veces («Retrying tests on failure. Running tests repeatedly up to 3 times»). Medido en los logs:

| run | rama | tests ejecutados | paso pure-logic | desenlace del job |
|---|---|---|---|---|
| 37434626440 (sano) | 2.1 | 8 954 en 880 suites | 13 min | success |
| 37417460535 (×2) | #369 | 26 889 en 2 643 suites | 26 y 29 min | cancelado (el context-based murió a medias) |
| 37436494168 | #369 | 26 913 en 2 643 suites | 28 min | cancelado en pure-logic |
| 37325431444 | 2.1, 2026-10-05 | 26 511 en 2 589 suites | 30 min | cancelado |
| 37083625365 · 37088395186 | 2.1, 2026-10-03 | — | 28 y 27 min | success por poco |

26 889 = 3 × 8 963. Con el build en 13-15 min, tres vueltas de ~9 min más el arranque pasan del tope de 45 min del
job (`timeout-minutes` del job `tests`) antes de que salte el de 30 del paso. El tope del JOB cancela, y
`continue-on-error` no rescata una cancelación (está escrito en el propio `qa.yml`).

En #369 el rojo era determinista (un test que dependía del idioma del simulador, arreglado en el propio PR). En
37325431444 era el flaky conocido de `SpikeR3ContainerReleaseTests` (eje 4a/4b), que acabó pasando en la tercera
vuelta («passed after 1510 seconds») y aun así el job se canceló.

## Por qué importa

- **El paso es advisory y deja de serlo según cuánto tarde.** Un rojo rápido sale `outcome: failure`, el job termina
  verde y el aviso de rojos advisory lo cuenta. El mismo rojo con tres vueltas cancela el job: `tests` sale rojo, el
  ruleset de `2.1` lo exige y el auto-merge se queda bloqueado.
- **El diagnóstico se pierde.** El job cancelado parece un cuelgue («pure-logic se corta por tiempo»), no un test en
  rojo. El aviso tampoco ayuda: lee `cancelled`, no el test que falló. Este encargo entero salió de ahí.
- **Recurre.** Tres días distintos en cuatro (10-03, 10-05, 10-06), y el flaky de SpikeR3 sigue abierto.

## Opciones (sin decidir)

1. **Reintentar solo lo que falló**: correr una vez sin reintento y, si hay rojos, sacar sus identificadores del
   `.xcresult` (`xcresulttool get test-results tests`) y repetir solo esos con `-only-testing`. Conserva el rescate
   del flaky y cuesta segundos. Es la opción que mejor encaja con «el paso es advisory».
2. **Quitar `-retry-tests-on-failure`** del paso: un rojo es un rojo y el aviso lo cuenta. El comentario del propio
   paso dice que «-retry no converge», aunque 37325431444 sí convergió.
3. **`-test-iterations 2`**: tope de dos vueltas. Con el build de hoy queda al límite (≈ 14 + 2 × 10 + arranque).
4. Subir el tope del job: no arregla nada, solo mueve el borde.

Antes de elegir, medir si el reintento repite la suite entera también con XCTest o solo con Swift Testing: aquí
solo se midió el segundo.

## XCTest frente a Swift Testing (medido el 2026-10-06)

**El reintento repite la suite entera SOLO con Swift Testing.** Con XCTest repite únicamente el caso rojo:

- Nocturna 37346159546, paso de UI (`YalaUITests`, XCTest, mismo `-retry-tests-on-failure`): 171 líneas
  `Test Case … passed|failed` para 165 casos distintos. Los 3 que salen más de una vez son los 3 rojos, ×3 cada uno;
  ningún caso verde se repite.
- Paso pure-logic de 37325431444 (`YalaTests`, Swift Testing entero): `Test run with 26511 tests in 2589 suites`,
  tres vueltas completas, y en cada una falló un eje distinto de `SpikeR3ContainerReleaseTests` (4b y luego 1+2).

Por eso solo el paso pure-logic cambia. Context-based también es Swift Testing, pero dura 2-3 min con tope de paso de
10: su reintento puede agotar SU tope (que `continue-on-error` sí rescata), no el del job. La UI es XCTest.

## Qué se hizo: opción 1

`qa/scripts/ci-reintentar-rojos.sh` corre la selección una vez, sin `-retry-tests-on-failure`. Si sale en rojo, lee
del `.xcresult` (`xcrun xcresulttool get test-results tests`) los casos con `result: Failed` y los repite solos con
`-only-testing:YalaTests/<nodeIdentifier>`, hasta 3 vueltas en total; cada vuelta repite solo lo que sigue en rojo.
Banco: `qa/scripts/ci-reintentar-rojos-test.sh`, en el job `coverage-index`.

Medido con un paquete sonda de Swift Testing (Xcode 27) y `xcodebuild` real antes de decidir:

- `nodeIdentifier` es `Suite/test()` también para un `@Test("nombre visible")`, y sirve tal cual en `-only-testing`
  con el bundle delante.
- **Un crash no deja casos sin correr**: `xcodebuild` relanza el proceso («Restarting after unexpected exit, crash, or
  test timeout») y sigue con los de detrás; solo el que corría queda `Failed`. Repetir los rojos basta.
- **Un `-only-testing` que no casa con nada sale exit 0 con cero casos.** Por eso un rojo cuenta como rescatado solo
  si aparece `Passed` en el `.xcresult` de la repetición, nunca por el exit.
- De punta a punta con la sonda: un flaky (falla la 1.ª vez) y un determinista. Vuelta 1: 5 casos, exit 65. Vuelta 2:
  solo los 2 rojos. Vuelta 3: solo el determinista. Salida: rescatado el flaky, rojo el determinista, exit 1.

Decisiones:

- **Caída segura**: `.xcresult` que falta o no se lee, JSON sin la forma esperada, exit ≠ 0 sin ningún caso rojo (un
  fallo de lanzamiento) o más de 100 rojos (eso ya no es un flaky) ⇒ no se repite nada y el paso sale con el código de
  la primera vuelta. Nunca cae a repetir la suite entera.
- **El aviso nombra los tests**: el script publica `rojos` en `$GITHUB_OUTPUT` (ya tras la primera vuelta, por si algo
  corta la repetición, y otra vez al final), el job `tests` lo expone como `unit_pure_rojos` y el aviso lo añade a la
  línea de pure-logic. Los rescatados salen como anotación `warning` del run.
- **`-collect-test-diagnostics never`** en el paso. Medido en la Mini con el script real sobre Yala y
  `TEST_RUNNER_TZ=UTC` (4 rojos deterministas en `WidgetDataServiceIntervalTests`): la vuelta 1 (8 981 tests) tardó
  14 min 15 s y la vuelta 2, con solo los 4 rojos que corren en 0,03 s, **10 min 34 s**. La diferencia era un
  `simctl diagnose --timeout=600` que `xcodebuild` lanza tras cada corrida con un rojo. En los logs del runner
  (Xcode 26) no aparece, pero con él las tres vueltas volverían a rozar el tope; nadie sube esos diagnósticos.
- El paso sigue `continue-on-error` y con su tope de 30 min; el del job (45) no se toca.

## Probado en el CI del PR #373

| corrida | qué | paso pure-logic | tests ejecutados | job `tests` |
|---|---|---|---|---|
| 37471905924 | sana | 14 min 29 s, una vuelta | 8 981 | 34 min 24 s, success |
| 37479038308 | rojo provocado (`TEST_RUNNER_TZ: UTC`, commit revertido) | 18 min 57 s: 13 min 49 s + 2 min 25 s + 2 min 23 s | 8 981 + 4 + 4 | 39 min 53 s, success |

En la provocada, la vuelta 1 dejó 4 rojos deterministas de `WidgetDataServiceIntervalTests` y las vueltas 2 y 3
repitieron SOLO esos 4. El paso salió `outcome: failure` con una anotación `error` por test, el job terminó dentro
del tope, y el aviso de rojos advisory entregó «hay tests en rojo» con los 4 nombres en la línea de pure-logic.
Con el `-retry-tests-on-failure` de antes, esa misma corrida habría ejecutado ~26 900 tests y el job se habría
cancelado. El flaky de `SpikeR3ContainerReleaseTests` no apareció en ninguna de las dos: el rescate de un flaky está
probado con la sonda y el banco, no en el CI.

Margen que queda: con el build más lento visto hoy (17 min), un rojo determinista deja el job en ~40-42 min de 45.
Cada repetición cuesta ~2,4 min en el runner (instalar y lanzar la app), no los tests.
