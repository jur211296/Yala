---
id: registros-calendario-cuenta-gastos-por-signo
status: qa
priority: high
area: calculos
created: 2026-09-02
updated: 2026-09-02
---
# El calendario de Registros cuenta los gastos por el signo del importe, y no cuadra con el resumen de arriba

## Qué ve el usuario

En la pestaña **Registros**, con el modo calendario activo, hay dos cifras de gasto en pantalla a
la vez —el chip «Gastos» del resumen, arriba del todo, y el número que imprime cada celda del
calendario, justo debajo— y **no cuadran**. No hace falta cambiar de pantalla ni de filtro: están
a un golpe de vista una de otra.

Pasa siempre que un movimiento tiene el importe con el signo contrario al de su categoría, que es
lo normal en dos situaciones cotidianas:

- **Le devuelven un cobro.** Un cargo de Restaurantes que vuelve como abono (importe positivo,
  categoría de gasto). El resumen lo trata como lo que es —un reembolso: **resta** de sus gastos—
  y el calendario **lo ignora por completo**: el día no descuenta nada, y si ese abono era el
  único movimiento del día, la celda ni siquiera pinta barra.
- **Le devuelven un ingreso.** Un salario o una transferencia recibida que se revierte (importe
  negativo, categoría de ingreso). El resumen lo descuenta de los **ingresos**, que es donde
  estaba; el calendario lo **suma a los gastos de ese día**, y el usuario ve un gasto que nunca
  hizo.

El efecto para quien usa la app es que el calendario —la vista que sirve justamente para mirar
«qué día gasté de más»— **infla los días** en los que hubo una devolución, y no descuenta los
reembolsos. Y como en la misma pantalla, en modo lista, el importe de cada fila **sí** se colorea
por categoría, un mismo movimiento puede aparecer pintado como gasto en la lista y no contar como
gasto en el calendario.

**También lo lee VoiceOver.** La etiqueta de accesibilidad de cada celda anuncia esa misma cifra
equivocada, así que quien no ve la pantalla no tiene ninguna forma de detectar el desajuste.

## Evidencia medida

Todo lo de abajo está medido en el árbol de hoy (rama `2.1`, HEAD `553b91c9`).

**La regla canónica** vive en `Yala/App/Logic/TransactionClassificationLogic.swift:27-29`: la
categoría decide, y el signo del importe es fallback **solo** si `category == nil`.

**El resumen la usa.** `RecordsViewModel.calculateSummary` (`Yala/App/ViewModels/RecordsViewModel.swift:297-328`)
decide el bucket en la línea **:316** (`if TransactionClassificationLogic.isIncome(record)`) y
acumula con signo: `expense -= amount` en **:319** —un importe de signo contrario a su categoría
reduce el bucket en vez de sumar magnitud—.

**El calendario no.** `DailySpendingCalculator.compute`
(`Yala/App/Logic/Calculators/DailySpendingCalculator.swift:45-48`) sigue mirando solo el signo:

```swift
let amount = adjustment.amountInPreferredCurrency(record)
if amount < 0 {
    dayExpense += abs(amount)
}
```

Nunca consulta la categoría. Los otros tres filtros (cuenta excluida de estadísticas :41, ajustes
y transferencias :42, patas de préstamo del bridge :43) sí coinciden con los del resumen — el
único criterio que divergió es la clasificación.

**Las dos cifras salen del MISMO conjunto de datos**, en la misma vista.
`Yala/App/Views/Statistics/RecordsTabView.swift` pinta el resumen en **:43** (`heroSummary`, cuyo
chip de gasto lee `viewModel.recordsSummary.expense` en **:231**, con identificador
`records_summary_expense` en **:236**) y, unos puntos más abajo, monta el calendario en
**:58-69**, pasándole `viewModel.groupedRecords` en **:60**. Es el mismo array que recorre
`calculateSummary` en **:301**. No hay diferencia de filtro, de período ni de divisa que explique
la discrepancia: es solo la regla.

**La cifra llega a la celda y a VoiceOver por el mismo camino.**
En `Yala/App/Views/Records/Components/RecordsCalendarView.swift`, el cálculo se invoca en **:61**;
el valor por día se reparte a cada celda en **:277**; la celda lo imprime en **:302**
(`Text(CompactAmountFormatter.string(expense))`) y lo entrega **sin transformar** a la etiqueta de
accesibilidad en **:325**, que lo formatea como importe en **:368**. La condición de «hay gasto»
está en **:289** (`expense > 0 && inRange`): por eso un día cuyo único movimiento es un abono con
categoría de gasto queda sin barra y sin número.

**En la lista de la misma pantalla la regla sí es la buena.**
`RecordRowView.amountColor` (`Yala/App/Views/Records/Components/RecordRowView.swift:246-249`)
resuelve `record.category?.isIncome ?? (record.amount >= 0)` — categoría primero. Tres superficies
en una pantalla, dos reglas.

### El doc-comment miente, y se puede fechar

El comentario de `DailySpendingCalculator.swift:10-19` **promete** lo contrario de lo que hace:

> línea :12 — «Replica el criterio de `RecordsViewModel.calculateSummary` para que la suma de las
> barras cuadre con el chip "gasto" del hero»

y en :15-16 declara que trata como gasto «los montos con `amountInPreferredCurrency < 0`».

Cuando se escribió era **verdad**: el calculador nació el 2026-05-31 en `18878f74`
(«feat(records): calendario de gasto diario con barras gradiente»), y en esa fecha el resumen
también clasificaba por signo. La promesa se rompió el **2026-07-05** en **`13f2cbb0`**
(«fix(records): clasificar income/expense por categoría en el header de Registros»), que cambió
`calculateSummary` de `if amount > 0 / expense += abs(amount)` a la regla canónica con acumulación
signed — **y no tocó `DailySpendingCalculator`**. Desde entonces el comentario describe un contrato
que ya no existe, y cualquiera que lo lea concluirá que el calendario está alineado.

> **Corrección de una coordenada de partida:** el encargo atribuía la rotura a `8347a776`. Medido:
> `8347a776` es el commit hermano del mismo día para Tendencias / Estadísticas / Reportes y
> **no toca `RecordsViewModel.swift`** (`git show 8347a776 --stat`: 9 ficheros, ninguno es ese).
> El que cambió el resumen de Registros es `13f2cbb0`. Vale la pena leer su propio mensaje, porque
> describe este bug antes de que ocurriera: acotó el cambio a Registros «autocoherente» avisando de
> que tocar los totales dejando las curvas y listas por signo «introduce divergencias
> intra-pantalla». El calendario se quedó fuera de esa cuenta de superficies.

Las otras cuatro superficies de totales que localicé con `grep` ya están en la regla canónica
(`StatisticsViewModel`, `RecordsViewModel`, `TrendDataProcessor`, `ReportNotificationService`);
`DailySpendingCalculator` es la que quedó atrás.

### El fixture que lo reproduce ya está en el repo

`DevSeedTransactions.createDesyncFixtures`
(`Yala/Seed/DevSeedTransactions.swift:579-614`, siembra en **:606-609**) planta 4 movimientos en
`Date.now` —los cuatro el mismo día, por tanto **una sola celda** del calendario—:

| línea | importe | subcategoría | categoría |
|---|---|---|---|
| :606 | +600 | Salario | ingreso (normal) |
| :607 | **−100** | Salario | ingreso (**desync**) |
| :608 | −500 | Restaurantes | gasto (normal) |
| :609 | **+200** | Restaurantes | gasto (**desync**) |

Su doc-comment (**:565-577**) documenta los totales esperados por la regla canónica —«fix (por
categoría): Ingresos = 600 − 100 = 500 · Gastos = 500 − 200 = 300»— frente a los del bug por signo
—«Ingresos = 600 + 200 = 800 · Gastos = 100 + 500 = 600»—. Se activa con `-uitest-seed-desync`
(`Yala/App/UITestHooks.swift:214`), y ese seed es **aislado**: no arranca el seed aleatorio, así
que no hay nada que contamine los totales.

Aplicando a mano los dos algoritmos sobre esas 4 filas: el chip de gasto da **300** y la única
celda del calendario da **600** (100 del salario devuelto + 500 del cargo real; el abono de +200
no descuenta). *Calculado sobre el código, no ejecutado en simulador.*

## Por qué los tests no lo cazan

`YalaTests/DailySpendingCalculatorTests.swift` tiene **8 tests** (`empty_returnsZeroMax`,
`sumsExpensesPerDay`, `ignoresIncome`, `ignoresTransfersAndAdjustments`, `ignoresExcludedAccounts`,
`ignoresRecordsWithoutAccount`, `maxAcrossDays`, `incomeOnlyDay_notInResult`) y **ninguno asigna
categoría**.

Todos construyen sus transacciones con el helper `makeTx` (**:30-47**), que llama al inicializador
de `TransactionItem` **sin pasar `category:`** — y ese parámetro tiene default `nil`
(`Yala/Models/TransactionItem.swift:143`). Con `category == nil`, la regla canónica *cae al signo
por diseño*, así que **los 8 tests darían exactamente el mismo verde con el bug y con el arreglo**.
No es que fallen en cazarlo: es que están construidos de forma que no pueden. Un test verde que no
puede ponerse rojo es peor que no tener test, porque compra confianza que no existe.

El propio comentario del helper (**:29**) fija el modelo mental equivocado: «negativo = gasto,
positivo = ingreso».

Los otros dos cercos tampoco llegan:

- **El e2e discriminante existe pero mira otra pantalla.** `YalaUITests/Flows/IncomeExpenseClassificationUITests.swift`
  usa justo ese fixture desync, pero su único test (**:25**) afirma sobre `stats_kpi_income` /
  `stats_kpi_expense` —las cifras de Insights— y **nunca cambia al modo calendario** (0 apariciones
  de «calendar» en el fichero).
- **El índice de QA no nombra esta superficie.** `DailySpendingCalculator` y `RecordsCalendarView`
  aparecen **0 veces** en `qa/coverage-index.json`.

## Arreglo propuesto

1. **Clasificar por la regla canónica en `DailySpendingCalculator.compute`**: sustituir el
   `if amount < 0 { dayExpense += abs(amount) }` de :46-48 por el bucket de
   `TransactionClassificationLogic.isIncome(record)` con **acumulación signed**, en paridad literal
   con `RecordsViewModel.swift:316-320` (es decir, restar el importe al acumulador del día en vez de
   sumar su valor absoluto). El helper es lógica pura sin SwiftData, así que no arrastra dependencias
   al calculador.

2. **Corregir el doc-comment mentiroso DENTRO de este mismo arreglo** (`DailySpendingCalculator.swift:10-19`).
   Ahora mismo la promesa de :12 es falsa; tras el fix vuelve a ser cierta, y la frase de :15-16
   sobre «montos con `amountInPreferredCurrency < 0`» debe describir la regla nueva. Dejarlo para
   después es lo que produjo este ticket: el comentario sobrevivió dos meses describiendo un
   contrato roto.

3. **Un test que pueda ponerse rojo.** Añadir a `DailySpendingCalculatorTests` un caso que
   **asigne categoría** a las transacciones —el helper `makeTx` necesita un parámetro `category:`,
   hoy no lo tiene— cubriendo los dos desyncs del fixture: categoría de gasto con importe positivo
   (debe **restar** del día) y categoría de ingreso con importe negativo (**no** debe sumar al día).
   El criterio de aceptación del test es que **falle contra el código actual**: si pasa con el bug
   dentro, no sirve. Conviene mantener además un caso con `category == nil` para fijar que el
   fallback por signo sigue vivo.

4. **Actualizar `qa/coverage-index.json`** en el mismo commit, como pide la regla anti-drift del
   repo. Hoy esta superficie no figura en el índice.

### Opcional, no bloqueante

Extender `IncomeExpenseClassificationUITests` al modo calendario cerraría el hueco de punta a
punta con el fixture que ya existe, pero **requiere trabajo previo**: `RecordsCalendarView` no
tiene ningún `accessibilityIdentifier` (0 apariciones en el fichero), así que no hay forma de
afirmar sobre la cifra de una celda concreta. El botón que cambia a modo calendario sí es
alcanzable —`viewModeButton` (`RecordsTabView.swift:336-367`) expone
`.accessibilityLabel(mode.accessibilityLabel)` en :365, aunque tampoco lleva identificador—.
El unit test del punto 3 es suficiente para blindar la regla; esto es cobertura adicional.

### Residual a decidir

Con acumulación signed, el gasto neto de un día puede quedar en cero o en negativo (un día en el
que solo hubo un reembolso). El guard `if dayExpense > 0` (:50) descartaría esos días, y la
condición `expense > 0` de la celda (`RecordsCalendarView.swift:289`) haría lo mismo. *Inferido,
no medido:* con ese comportamiento la suma de todas las barras seguiría siendo mayor que el chip
del resumen cuando algún día neteara negativo, porque el resumen sí arrastra ese negativo al total.
Hay que decidir si el calendario debe representar un día neto negativo o simplemente no pintarlo —
es una decisión de producto, no un detalle de implementación, y conviene tomarla antes de escribir
el fix para que el test la fije.

---

## Resolución — 2026-09-02

**Arreglado.** `DailySpendingCalculator.compute` clasifica ahora con la regla canónica
(`TransactionClassificationLogic.isIncome`: la categoría decide, el signo solo es fallback si
`category == nil`) y acumula **signed**, en paridad literal con `RecordsViewModel.calculateSummary`.
El doc-comment se corrigió en el mismo cambio, con la fecha en que la promesa se rompió — llevaba
dos meses describiendo un contrato que ya no existía, y eso es lo que produjo el bug.

### Verificado por mutación, no por «BUILD SUCCEEDED»

Se revirtió **solo la lógica**, dejando los tests nuevos puestos, y se corrió la suite. Los tres
casos discriminantes fallaron con las cifras exactas que este ticket había predicho leyendo el
código *(la predicción decía «calculado sobre el código, no ejecutado en simulador»; ya está
ejecutado)*:

| Caso | Con la versión por signo | Esperado |
|---|---|---|
| `desyncFixtureDay_matchesHeroSummary` | **600.0** | 300 |
| `expenseCategoryWithPositiveAmount_reducesDay` | **500.0** | 300 |
| `incomeCategoryWithNegativeAmount_notCountedAsExpense` | **100.0** | `nil` |
| `nilCategory_stillFallsBackToSign` | pasa en ambos | *(correcto: fija el fallback)* |

Con el fix restaurado: **12/12 en verde** (`-only-testing:YalaTests/DailySpendingCalculatorTests`,
`-parallel-testing-enabled NO`). El helper `makeTx` ganó el parámetro `category:` — sin él la suite
no podía discriminar, que es la razón por la que los 8 casos anteriores nunca cazaron esto. La
lección quedó como regla 21 en `.claude/rules/testing.md`.

### Decisión del owner sobre el residual (2026-09-02)

**Un día cuyo gasto neto queda en cero o negativo no se pinta.** Se mantienen los dos guards
(`DailySpendingCalculator` y la condición de la celda en `RecordsCalendarView`) para no introducir
UI nueva en un ticket de clasificación. Consecuencia aceptada y anotada también en el doc-comment
del calculador: en esos días concretos la suma de barras queda por encima del chip del hero, que sí
arrastra el negativo. Si algún día se decide representarlos, es cambio de UI y ticket aparte.

### Barrido del patrón

Revisadas las ~80 apariciones de clasificación por signo en `Yala/`. Seis superficies ya usan la
regla canónica. Descartados con motivo: `BalanceTrendCalculator:39` (el signo solo preserva la
magnitud tras convertir divisa; clasifica con `category.isIncome` dos líneas después) y
`CashFlowProjectionCalculator:424,447` (filtra meses con actividad para una media, no clasifica).

**Queda uno vivo, fuera de este ticket:** `Yala/App/Views/Inbox/InboxView.swift:907` pasa
`isExpense: amount < 0` teniendo `subcategory.safeCategory` disponible dos líneas antes. Es
cosmético —la etiqueta del aviso de confirmación tras aprobar un borrador— y no se tocó.

### Qué falta (esto es lo que hay que verificar en QA)

1. **En el simulador**, con `-uitest-seed-desync`: abrir Registros en modo calendario y comprobar
   que la celda del día del fixture dice **300**, igual que el chip «Gastos» de la misma pantalla
   (antes decía 600).
2. **VoiceOver**: la etiqueta de esa celda anuncia la misma cifra corregida.
3. **Un día solo con reembolso**: comprobar que la celda no pinta barra — es el residual decidido
   arriba, no un fallo.

Sigue abierto el punto **opcional** de la propuesta: extender `IncomeExpenseClassificationUITests`
al modo calendario. Requiere trabajo previo — `RecordsCalendarView` no tiene ningún
`accessibilityIdentifier`, así que hoy no hay forma de afirmar sobre la cifra de una celda concreta.
