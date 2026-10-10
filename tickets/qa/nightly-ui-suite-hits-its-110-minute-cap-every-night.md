---
id: nightly-ui-suite-hits-its-110-minute-cap-every-night
status: qa
priority: high
area: testing
created: 2026-10-07
updated: 2026-10-09
source: hallazgo de advisory-ui-tests-fail-every-retry (run 37485294893)
qa-status: needs-testing
qa-date: 2026-10-09
qa-notes: verificar 3 nocturnas seguidas tras el merge con las 85 suites arrancadas, cada paso de UI bajo 110 y cada job con 15 min de margen
---

# La suite UI de la QA programada se corta por tiempo todas las noches y no llega a correr un cuarto de las suites

## Qué se midió el 2026-10-07

El paso `UI tests (YalaUITests) — solo nocturna · advisory` de `qa.yml` lleva `timeout-minutes: 110`. En las seis
últimas QA programadas el paso dura lo mismo que el tope:

| Run | Inicio | Fin | Duración |
|---|---|---|---|
| 37485294893 (6-oct) | 15:46:35 | 17:36:48 | 110 min |
| 37346159546 (5-oct) | 17:37:57 | 19:28:10 | 110 min |
| 37207917034 (4-oct) | 14:26:34 | 16:16:48 | 110 min |
| 37125969899 (3-oct) | 13:51:46 | 15:40:27 | 109 min |
| 37021905092 (2-oct) | 15:24:26 | 17:14:46 | 110 min |
| 36884315519 (1-oct) | 15:49:41 | 17:31:55 | 102 min |

En el del 6-oct el log termina con `The action 'UI tests …' has timed out after 110 minutes`, y solo arrancaron
**62 de las 84 suites** de `YalaUITests/Flows/`. `TransactionsCrudUITests`, entre otras, no aparece ni una vez.
Como el paso es `continue-on-error`, el run sale verde.

⇒ La QA programada no prueba la suite entera, y lo que se queda fuera depende del orden alfabético: las suites
del final no corren nunca.

## Qué lo agrava

`-retry-tests-on-failure` repite cada caso rojo hasta 3 veces. Los tres persistentes de
`advisory-ui-tests-fail-every-retry` gastaban ~6 min por noche entre los tres. Arreglarlos ayuda, pero no
alcanza para entrar en 110 min.

## Qué haría falta (no decidido)

Medir cuánto dura la suite entera en el runner y elegir: subir el tope, partir la suite en dos pasos o dos
noches, o quitar el reintento de los casos que tardan. Cualquiera toca `qa.yml`, que el encargo que lo encontró
tenía vetado.

## Medido otra vez el 2026-10-08 (run 37644787793, QA programada del 7-oct sobre `beed3a2`)

- El paso de UI arrancó a las 16:10:33 y se cortó a las 18:00:49 («has timed out after 110 minutes»), con **179
  casos pasados y 1 rojo** (`AdvancedFiltersUITests.test_excludeModePersistsAfterApply`) de los 244 `func test` que
  hay en `YalaUITests`. Media de 35 s por caso pasado; iba por `StatisticsHeroLikePanelUITests` (orden alfabético). El
  log avanza hasta el último segundo: es lentitud, no un cuelgue.
- **Esta vez el JOB también se canceló** (`tests` cancelled, 15:33:13 → 18:04:53, 151,7 min frente al tope de 150 de
  la nocturna). Lo que lo empujó por encima fue el rojo de unit de esa misma noche
  (`upload-order-sorts-by-hlc-test-fails-in-ci`): sus vueltas 2 y 3 sumaron ~5,5 min antes del paso de UI, y la
  limpieza de procesos huérfanos tras el corte gastó otros ~3,5 min. Sin ese rojo el job habría acabado hacia los 146
  min: dentro, pero con 4 min de margen. Ese margen es el problema de este ticket: cualquier rojo de unit con
  reintentos cancela el job de la nocturna.

## Medido en 2.1 (triage 2026-10-08)

`gh run list --workflow qa.yml --event schedule --limit 10`. El paso de UI duró 110 min en las siete últimas nocturnas, del 2 al 8-oct, y 102, 100 y 85 min en las tres anteriores. La de hoy (37802106095): 16:12:20 → 18:02:34, y el job 146,7 min frente a un tope de 150. Dos de las diez acabaron `cancelled` (7-oct y 2-oct). El tope sigue en `qa.yml:485` (`timeout-minutes: 110`) con `-retry-tests-on-failure` (`:494`).

Triage 2026-10-08: abierto · medium → high · las diez últimas nocturnas siguen agotando el tope del paso de UI (la de hoy, 37802106095, 110 min y el job a 146,7 de 150), así que las suites del final del alfabeto, `TransactionsCrudUITests` incluida, no corren en ningún CI.

## Arreglado el 2026-10-09: la UI corre en tres tandas paralelas

**Qué cambia.** La suite de UI sale del job `tests` y pasa a un job `ui` con matriz de **tres tandas**, cada una en su
`macos-26` con su build, que corren a la vez cada noche. `qa/scripts/ci-ui-tandas.sh` reparte desde el árbol (por
número de `func test`), así que una suite nueva entra sola; la última tanda corre el target entero menos lo de las
otras, así que **ninguna suite puede quedarse fuera**. Banco en `coverage-index` (`ci-ui-tandas-test.sh`). El job
`tests` queda igual en la nocturna que en el PR y su tope de nocturna baja de 150 a 60; el del PR (45) no se toca.
`nocturna-vigilante.yml` no cambia de lógica: sigue un cron y un run diario, y el vigilante cuenta runs, no jobs.

**Por qué así y no otra cosa.** Medido en la nocturna 37802106095 (8-oct): 36 min antes de la UI; la UI cerró 65 de
las 85 suites (192 de 250 casos) en sus 110 min, con solo 2 reintentos. Es lentitud (~0,6 min por caso), no
reintentos: quitar el reintento no habría bastado. Subir topes daba un job en serie de ~3 h; dos noches alternas
dejaban cada suite cada 48 h.

**Medido en la rama:**

| Dispatch | Tandas | Suites arrancadas y cerradas | Paso de UI (min) | Job (min) |
|---|---|---|---|---|
| 37906397439 | 2 | 42 + 43 = 85 | 83,3 · 83,3 | 95,8 · 99,4 |
| 37917143838 | 3 | 28 + 28 + 29 = 85 | 48,1 · 69,4 · 57,2 | 60,3 · 85,1 · 71,2 |

Topes: paso de UI 110, job 150. El job `tests` de la nocturna: 28,8 y 27,0 min (tope 60). Con dos tandas cabía,
pero a 1,3x del tope y con una suite que pasó de 149 casos (11-sep) a 250 (9-oct); por eso tres. Suite entera
sumada el 9-oct: ~158 min. El aviso recibe el resultado de cada tanda (`ui_1`…`ui_3`) y lo comprobé en los dos
dispatches: una tanda en rojo sale nombrada, y una salida vacía cuenta como «no llegó a correr».

**Rojos que salieron al correr por fin la suite entera** (no los causa el reparto; ya tienen ticket):
- `ImageEntryReviewUITests` ×3 (`test_readsWithoutCountdown_andSavesInTheSameSheet`, `test_missingSubcategory_…`,
  `test_twoPhotos_…`): «Guardar» no se habilita, 3 de 3 reintentos en los dos dispatches →
  `image-entry-uitests-save-stays-off-for-a-complete-record`.
- `TransactionsCrudUITests.test_recordSelectorsOpenAtMediumDetent`: rojo en el primer dispatch (chip de etiquetas
  fuera de pantalla), verde en el segundo → `record-selectors-uitest-taps-the-tags-chip-off-screen`. Hasta hoy no
  había corrido nunca en CI.

## Qué falta para cerrarlo

Tres nocturnas seguidas tras el merge (`gh run list --workflow qa.yml --event schedule --limit 3`). En cada una:
1. los tres jobs `UI tests (tanda N)` acaban y su log trae `ci-ui-tandas: tanda N de 3` y tantas suites cerradas
   (`Test Suite '…UITests' passed|failed`) como lista la tanda (28/28/29 hoy);
2. cada paso de UI por debajo de 110 min;
3. cada job de UI y el job `tests` con al menos 15 min de margen (≤135 y ≤45).
