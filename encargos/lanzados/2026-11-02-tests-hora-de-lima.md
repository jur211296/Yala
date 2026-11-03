# Los tests unitarios pasan con el simulador en cualquier zona horaria, no solo en la de Lima

Cierre: **cierra-sola** → al terminar, `/cerrar-total`. Esfuerzo: medium.
Versión **2.2**. Base `origin/2.2`.
Slug: `tests-hora-de-lima` · Encargo 02 de la cola Yala (antes S35s) · al cerrar → encargo 03.

## Contexto
Hallazgo de la sesión `ci-tests-en-verde` (PR #724, 1-nov). Regla de Jürgen del 2026-10-30: todo entra en 2.2 antes del barrido QA, nada a backlog.

## Cards y criterio de hecho
- `tablero-13-tests-unitarios-salen-rojos-si-el-sim-orwz` — 13 tests unitarios salen rojos si el simulador no está en hora de Lima
  - Hecha cuando: YalaTests pasa con `TEST_RUNNER_TZ` en UTC, Etc/GMT+6 y Etc/GMT-6, además de Lima.
- `tablero-xcuitest-6-tests-de-interfaz-caen-en-ci-30pv` — XCUITest: 6 tests de interfaz caen en CI el 1 de noviembre
  - Hecha cuando: los 6 tests pasan en CI y en local, el día 1 de un mes y en un día cualquiera, sin continue-on-error ocultándolos.
- `tablero-xcuitest-el-presupuesto-de-la-tarjeta-sa-xn78` — XCUITest del presupuesto de la tarjeta al 0 % los días 1-3 (ya no aparece en `tablero listar`; según la cola quedó done con el PR #736: solo verifica que siga verde el día 1 y en un día cualquiera, y si vuelve a caer, arréglalo aquí)
  - Hecha cuando: el caso pasa con el reloj del simulador en el día 1 de un mes y en un día cualquiera.

Detalle de orwz:
- Problema: unos 13 tests (BudgetPeriodTitleLogicTests, CreditCardReminderSchedulerTests, ScheduledPaymentSummaryPlannerTests, UXAudit22Lote18DecididasTests, WeekdaySpendingCalculatorTests) fijan su calendario a America/Lima mientras el código bajo test usa `Calendar.current` o un DateFormatter del sistema. Con `TEST_RUNNER_TZ` distinto de Lima salen rojos. En producción no es bug de la app.
- Hecha cuando: YalaTests pasa con `TEST_RUNNER_TZ` en UTC, Etc/GMT+6 y Etc/GMT-6, además de Lima.

## Qué se pide
1. Verifica en el código la lista y la causa antes de tocar nada (el conteo es orientativo).
2. Por suite, decide si el test inyecta la zona al código (calendar/timeZone como parámetro) o construye sus fechas con `Calendar.current`. Prefiere no cambiar comportamiento de la app; si hace falta inyectar un parámetro, que el valor por defecto deje todo igual.
3. Corre YalaTests con las cuatro zonas y deja constancia en el PR.
4. Pasa cada card a done si no hay nada que mirar en el teléfono, o a «in qa» de Jürgen si lo hay (con `--agente` de la sesión).

## Qué NO hay que tocar
- Nada fuera de esta card. No cambies qa.yml ni la zona fija del CI.
- marketing/ ni Web/.
- No lances otras sesiones Yala. Ningún otro PR ni rama.

## También: XCUITest del presupuesto de la tarjeta al 0 % los días 1-3 (card tablero-xcuitest-el-presupuesto-de-la-tarjeta-sa-xn78)
`AccountCardPickersUITests.test_budgetOnTheCard_countsTheLineExpense` falla con «0 por ciento gastado», incluso con el binario de la base. La causa es que `DevSeedAccountLines` (perfil tarjeta-dos-lineas) fecha «Supermercado QA» y «Hotel QA» 2 y 3 días atrás, así que el día 1 caen en el mes anterior. Es el mismo patrón de dependencia del reloj que el resto de esta sesión.
Se sabe que está hecho cuando el caso pasa con el reloj del simulador en el día 1 de un mes (fecha fija o TEST_RUNNER_TZ) y en un día cualquiera.

## También: 6 tests de interfaz que caen en CI el 1-nov (card 30pv)

Run 41319488785 (HEAD 5b4898f): verde por fuera, pero con continue-on-error caen 3 veces cada uno:
- Tanda 3 · `CreditCardStatementUITests.test_cashFlow_showsTheCardPaymentInItsMonth` (:118, «El plan no se creó»).
- Tanda 3 · `UXAudit22Lote11DecididasUITests.test_needSection_explainsWhatItIsFor_andGivesAnExamplePerRow` (:111), `test_proObservations_doNotAskForATap` (:127) y `test_proObservations_withoutConsent_offerTheButtonInPlace` (:142, «La píldora Observaciones no quedó a la vista»).
- Tanda 6 · `UsageModeUITests.test_withRecords_keepEverything_bringsTheDataBack` (:94) y `test_startFresh_confirmsTwice_asksOnlyForTheMainAccount_andErasesTheRecords` (:123, «el Panel no enseñó los registros sembrados»).
- (La tanda 2, `test_budgetOnTheCard_countsTheLineExpense`, es la de xn78, arriba.)

Hipótesis: igual que xn78, dependen de la fecha (semillas que el día 1 caen en el mes anterior) o de la hora de Lima. Hay que verificarla y, si no es eso, buscar la causa real. Reprodúcelos con el simulador en el día 1 de un mes y en un día cualquiera. Quedan bien cuando pasan en ambos casos, en local y en CI.

## Cómo se sabe que está bien
- Cada card cumple su «hecha cuando»; tests verdes en las cuatro zonas y los XCUITest en el día 1 y en un día cualquiera.
- Review adversarial del diff hecha.
- PR a 2.2 con auto-merge.
## Pie fijo (lanzar-sesion)
- Proyecto Yala, repo `jur211296/Yala`. Versión **2.2**. Base `origin/2.2`; el PR va a `2.2` con auto-merge.
- Una sesión Yala a la vez: no lances otras sesiones Yala ni trabajes en paralelo con otra. Un solo PR para todo este encargo y un solo cierre.
- Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Pipeline serial de la Mini: limpiar sims muertos, DerivedData y cachés de XcodeBuildMCP de worktrees cerrados (nunca las de un worktree vivo); build con `xcodebuild -jobs 2` sin sim booteado; bootear 1 sim; tests; apagar y borrar el sim. `limpiar-mac --apply` al cerrar.
- Pasa cada card a «in qa» (o «done» si no necesita ojos de Jürgen) al abrir el PR, con `--agente` de la sesión.
- Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank (nada a backlog), y lista sus títulos en el PR y en el cierre.
- Cierre autónomo: se lanza con `--permission-mode bypassPermissions`. Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
- Al cerrar, Frank publica el digest y lanza el siguiente encargo de `~/Claude/flota/cola-yala/`.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Medido antes de decidir (YalaTests completo, mismo binario, `TEST_RUNNER_TZ`): UTC 3 rojos, Etc/GMT+6 13, Etc/GMT-6 4 → unión de 17 tests en 6 suites (las 5 de la card + `ExchangeRateServiceTests`).

1. **Por suite, inyectar o adaptar el test** → la regla: si el código ya recibe `calendar:` pero mezcla la zona del proceso por dentro, se arregla el código con el default idéntico al de hoy; si el código depende a propósito de la zona del proceso (claves de día del tracker de avisos), el test corta en la zona del proceso, como la app.
   - `PreviousPeriodHelper.previousInterval` gana `calendar:` (default `userConfiguredCalendar()`: lo que ya usaba `dateInterval`; sus cuentas no dependen de `firstWeekday`). `ComparisonPhraseLogic`/`ComparativeLabelsLogic` le pasan el calendario del usuario en SU zona (`periodCalendar(in:)`): en la app, idéntico.
   - Formatters con `calendar` y sin `timeZone` (`BudgetPeriodTitleLogic` ×2, `BudgetPeriodWheelSheet.weekOptions`, `RecurringQuickSheet` ×2): `timeZone = calendar.timeZone`. En la app el calendario es el del proceso: sin cambio visible.
   - `WeekdaySpendingCalculator.weekdayOccurrences` gana `calendar: = .current`.
   - `ScheduledPaymentSummaryPlannerTests`, `CreditCardReminderSchedulerTests`: calendario del test en `TimeZone.current` (el tracker formatea en la zona del proceso a propósito).
   - `ExchangeRateServiceTests`: la fecha se corta en UTC, la zona en que se formatea (no prueba código de la app).
2. **xn78** → ya arreglado por #736 (`seedDate` con tope en el día 1, unit tests con `now` fijo). Solo se verifica.
3. **30pv** (medido en las nocturnas: 31-oct verdes, 1-nov caen los 7, 2-nov caen solo los 2 de UsageMode):
   - `CreditCardStatementUITests.test_cashFlow…` → el asistente solo marca líneas con actividad en ≥4 meses y la semilla `tarjeta-corte` traía 3 + «ayer»; el día 1 «ayer» es el mes anterior. Semilla con 4 meses de historia.
   - 3 de `UXAudit22Lote11DecididasUITests` → la píldora «Detalle | Observaciones» exige ≥5 movimientos en el período; «Este mes» el domingo 1 no los tiene. Esos 3 casos eligen «Mes pasado» (lo que miden no depende del período).
   - 2 de `UsageModeUITests` → su control esperaba un «Bus» que la semilla `minimal` pone al azar. Fixture aditivo `-uitest-seed-today-record` (molde `-uitest-seed-future-movement`): un «Bus» hace un minuto sin salir de hoy.
4. **El reloj del día 1 en XCUITest** → no hay seam de reloj ni forma de mover el del simulador, y con `TZ` no se llega hoy (3-nov) al día 1. Se verifica: (a) hoy, día 3 (dentro de la ventana 1-3); (b) cada causa por su lógica pura con fecha fija donde existe; (c) la nocturna del 1-dic. Conservador y reversible; documentado en el PR.
5. **No se toca** `qa.yml` ni la zona del CI.
