---
id: advisory-ui-tests-fail-every-retry
status: qa
priority: medium
area: testing
created: 2026-10-07
updated: 2026-10-07
source: card del tablero tablero-ui-tres-tests-de-la-suite-advisory-falla-wsc6 (QA programada de 2.1, run 37485294893)
---

# Tres XCUITest de la suite advisory fallan en los tres reintentos

La suite UI del CI es advisory: el run sale verde aunque fallen. Estos tres fallan 3 de 3 reintentos en la QA
programada del 2026-10-06 (run `37485294893`, HEAD = merge del PR #372, Xcode 26.6, simulador iOS 26.5), así
que la suite deja de avisar de nada real.

Relacionados: [[edgecases-extreme-minimum-flaky-under-load]] y [[uitest-compara-fechas-sin-fijar-locale]].

## Persistentes (3/3), medido en el log del run

| Test | Dónde cae | Mensaje |
|---|---|---|
| `EdgeCasesUITests.test_extremeMinimumAmountSaves` | `XCUIApplication+Yala.swift:288` | no aparece `transaction_success_accept` tras tocar Guardar |
| `InboxConvertToGroupUITests.test_convertDraftToGroupExpense_preservesDraftDate` | `InboxConvertToGroupUITests.swift:165` | `("3 oct.") is not equal to ("Oct 3")` |
| `QuickActionsFavoritesUITests.test_saveAsFavoriteFromTransactionAppearsInList` | `XCUIApplication+Yala.swift:288` | no aparece `transaction_success_accept` tras tocar Guardar |

## Flaky 1/3 en el mismo run (anotados, NO se arreglan aquí)

- `AccountsCrudUITests.test_archivingAccount_turnsOnExcludeAndShowsNotice` — timeout al lanzar.
- `BudgetAlertsConfigUITests.test_selectingThresholdMarksItSelected`.
- `RemoteWipeNoticeRoutingUITests.test_notice_keepWaiting_leavesTheAppWhereItWas`.

## Diagnóstico (medido el 2026-10-07, iPhone 17 Pro, iOS 27.0, Xcode 27.0)

Para imitar el CI en local se corrió con `-testLanguage en -testRegion US` (el runner del CI corre en inglés) y
`TEST_RUNNER_TZ=America/Lima`, como el job.

### Inbox→grupo: falla el TEST (locale)

La app conserva la fecha: el chip dice «3 oct.», que es el día correcto del borrador. La expectativa se formateaba
con `Locale.current` del proceso del runner —inglés en el CI— mientras `launchForUITest` fija la app a `es_PE`.
En la Mac de Jürgen las dos mitades coinciden porque el simulador está en español; por eso no se veía en el gate.

**Arreglo:** el locale que se fija a la app pasa a una constante (`XCUIApplication.uiTestLocaleIdentifier`) y la
expectativa se formatea con él. La igualdad se queda entera. El mensaje del assert ya no afirma «no conservó la
fecha» (lo que sabe es que el texto no coincide). Era la única comparación con formato de todo `YalaUITests`.

Cierra [[uitest-compara-fechas-sin-fijar-locale]].

### Monto mínimo y favorito: falla el PRODUCTO

La captura del fallo enseña la app de vuelta en el Panel, con el registro YA guardado en «Últimos registros», y
encima la alerta **«¡Listo! Creaste tu primer gasto — Si solo fue de prueba, puedes eliminarlo — Conservar / Era
de prueba»**. El vídeo lo confirma: al tocar Guardar, el formulario se cierra y sale esa alerta en vez de la
pantalla de éxito.

Mecanismo:

1. La guía de primeros pasos marca «primer gasto» desde el `onAppear` del Panel (`autoDetect`), con los
   registros que el Panel tenga cargados **en ese instante**.
2. El seed de XCUITest corre al final del arranque. En un runner lento el Panel aparece antes, cuenta 0 y la
   marca se queda sin poner aunque el seed acabe dejando registros de sobra.
3. Al guardar, `NewTransactionView` miraba solo la marca: sin marca ⇒ «es tu primer gasto» ⇒ ofrece borrarlo
   como prueba. Esa alerta, presentada desde el Panel, cierra el formulario antes de la pantalla de éxito.

Para quien usa la app pasa igual cuando sus datos llegan después de abrir el Panel (iCloud restaurando, una
importación): con historial de sobra, el siguiente registro le dice «creaste tu primer gasto, si fue de prueba
puedes eliminarlo», y se pierde la pantalla de éxito. Mismo patrón en «primer presupuesto» y «primer pago
planificado» (`BudgetEditorView`, `ScheduledPaymentEditorView`). Voz e imagen son «prueba la función», no
«primer elemento», y no se tocan.

**Arreglo:** `SetupChecklistManager.markFirstCreation` decide con el recuento real del store: solo ofrece «¿era de
prueba?» si lo recién guardado es lo único de su tipo. El recuento usa el MISMO criterio que `autoDetect` (todos
los registros; presupuestos activos; todos los pagos planificados), así que lo único que cambia es la carrera. Si
el recuento falla, no se ofrece borrar (fail-closed: ofrecer borrar algo de quien tiene historial es el daño).

### Controles

| Corrida | Resultado |
|---|---|
| Unit `SetupChecklistManagerTests` con la decisión vieja (siempre ofrecer) | **rojo**: 4 issues (3 casos de la tabla + `withHistory`) |
| Unit con la decisión nueva | verde (46 tests en 2 suites, con `ActivationRestoreDiscardTests`) |
| XCUITest, carrera FORZADA (el Panel cuenta 0) + decisión vieja, 2 iteraciones | EdgeCases **2/2 rojo**, Favoritos **2/2 rojo**, mismo mensaje que el CI |
| XCUITest, carrera forzada + decisión nueva, 2 iteraciones | EdgeCases 2/2 verde, Favoritos 2/2 verde |
| XCUITest Inbox con la expectativa vieja, runner en inglés, 2 iteraciones | **2/2 rojo** (`"4 oct." != "Oct 4"`) |
| Sin forzar nada, código viejo, runner en inglés | EdgeCases rojo 2 de 3 corridas, Favoritos verde 3/3: en local la carrera es intermitente, en el CI se pierde siempre |

Cierra [[edgecases-extreme-minimum-flaky-under-load]]: su «flaky bajo carga» era esta carrera (más lenta la
máquina, más probable que el Panel aparezca antes que el seed).

### Verificación final (código de la rama, runner en inglés como el CI)

- Los tres persistentes, `-test-iterations 3` seguidas: **9/9 verde**.
- Gate: 20 suites XCUITest de las áreas tocadas, **48 de 49 verdes**, centinela limpio. El rojo,
  `TransactionsCrudUITests.test_recordSelectorsOpenAtMediumDetent`, falla igual con el producto de `2.1` (2/2) y va a
  [[record-selectors-uitest-taps-the-tags-chip-off-screen]].
- Hallazgo: el paso de UI de la QA programada se corta a los 110 min cada noche y no corre ~22 suites:
  [[nightly-ui-suite-hits-its-110-minute-cap-every-night]].

Capturas: `/Users/jur/Claude/worktrees/_capturas/2026-10-07-advisory-ui-tests-fail-every-retry/` — `antes-1.png`
(el formulario con 0,01 antes de guardar), `antes-2.png` (la alerta «¡Listo! Creaste tu primer gasto» en lugar de la
pantalla de éxito, con el registro ya guardado y historial de sobra), `despues.png` (la pantalla de éxito).

## QA en el iPhone (Jürgen)

Lo que los tests no cubren es el camino de un usuario nuevo DE VERDAD, que no debe cambiar.

**Montaje:** build de esta rama (o de `2.1` tras el merge) en un iPhone donde puedas borrar la app.

1. Borra Yala del iPhone e instálala de nuevo. Completa la bienvenida **sin** restaurar nada de iCloud y con una
   cuenta sin saldo inicial.
2. En el Panel, toca **Nuevo registro**, pon un gasto cualquiera y **Guardar**.
   - Esperado: sale la alerta **«¡Listo! Creaste tu primer gasto»** con **Conservar / Era de prueba** (igual que antes).
3. Toca **Conservar**. Crea un segundo gasto y **Guardar**.
   - Esperado: sale la **pantalla de éxito** («¡Listo!» con el check y **Aceptar / Registrar otro**), sin alerta.
4. Repite 2 con un **presupuesto** (Planificación → Presupuestos → nuevo) y con un **pago planificado**: el primero
   ofrece «¿era de prueba?» (la alerta sale en el Panel, al volver a él), el segundo no.

Si en el paso 2 NO sale la alerta, es regresión de este ticket: anótalo aquí.
