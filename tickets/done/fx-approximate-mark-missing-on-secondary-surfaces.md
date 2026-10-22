---
id: fx-approximate-mark-missing-on-secondary-surfaces
status: done
priority: medium
area: currency
created: 2026-09-06
updated: 2026-09-16
source: review adversarial de fx-presentation-still-shows-1to1 (2026-09-06)
qa-status: passed
qa-date: 2026-09-16
qa-notes: Widget de inicio PASS en sim 2026-09-16. Asistente no replicable (LLM sin App Attest en sim y fila provisional no fabricable en device) - override Jurgen 2026-09-16
---

# La marca de aproximado llega a los cuatro totales grandes, no a los demás

## Qué le pasa al usuario

Desde `fx-presentation-still-shows-1to1` el número grande del Panel, el de Tendencias, el de
Estadísticas y el saldo del panorama avisan con «≈» cuando alguna tasa no era la del día. **Otras
pantallas pintan los MISMOS importes sin la marca**, así que el usuario ve el mismo dinero declarado
aproximado en una pantalla y exacto en la de al lado.

## Dónde, medido el 2026-09-06

| superficie | fichero:línea | de dónde sale el número |
|---|---|---|
| «¿Cuánto tienes hoy?» | `BalanceLiveAnchorEducationSheet.swift:66` | `LiveBalanceCalculator` — **la peor omisión: esa hoja existe justo porque el saldo es multimoneda** |
| KPI de Distribución | `CategoriesTabView.swift:353` | `BalanceKPICalculator`, que tira la señal |
| Registros | `RecordsTabView.swift:144` | `RecordsViewModel:315`, suma `amountInPreferredCurrency` |
| Promedio diario | `InsightsTabView.swift:546` | derivado de `cashFlow.totalExpense` |
| Flujo de caja | `CashFlowWidget.swift:350` y `:428` | **el `CashFlowSummary` que YA trae la señal** — el más barato |
| Widget de inicio | `WidgetDataCache.swift:729` | `WidgetPeriodSummary` **no tiene el campo**: no está a `false`, está ausente |
| Asistente | `FullFinancialContextBuilder.swift:404` | descarta la señal al construir su resumen |

## Por qué quedó fuera y no es un olvido

El AC del ticket original nombraba cuatro superficies y ésas están cubiertas. Llevar la señal hasta
la hoja del saldo vivo exige atravesar `TrendDataProcessor` y los dos ViewModels —es núcleo con
suite propia—, y el widget tiene decisión aparte pendiente (`fx-widget-drops-missing-currency`).

**Rastro dejado a propósito**: `LiveAnchorInfo` NO lleva la señal. Se le añadió y se retiró en la
misma sesión al medir que nadie la leía; un campo que nadie lee parece cobertura en una auditoría
posterior y no lo es. El motivo está escrito en su docblock.

## Criterio de hecho (AC)

- [x] Las superficies de la tabla llevan la marca, o queda escrito por qué una no debe llevarla.
- [x] `CashFlowWidget` primero: su summary ya trae la señal y es un `isEstimate:` de una línea.
- [x] Un source-scan que falle si una de ellas pierde el cableado, al molde de
      `ApproximateMarkWiringTests`.

## Cerrado el 2026-09-09 (PR #111)

### Lo que la tabla decía y lo que había

**Las siete superficies eran veintiuna.** La tabla nombraba un sitio por pantalla y en cada una
había más del mismo patrón, con la señal ya en la mano. Flujo de caja citaba dos y tenía cinco
importes de período más la etiqueta de VoiceOver del gráfico; Registros citaba uno y tenía tres;
Estadísticas, uno y tenía tres. Y aparecieron **dos superficies que la tabla no nombra**, las dos en
ficheros que el ticket anterior ya había tocado: los chips de ingreso/gasto bajo el hero de
Tendencias y la píldora de gasto del hero del Panel. Esta última es el caso más nítido del bug:
`periodSummary.expense` se pinta **dos veces en la misma vista** —con «≈» en el hero de Solo Gastos,
sin él en la píldora— así que el mismo número del mismo mes salía marcado o exacto según el modo.

Es otra vez el corolario que ya está escrito en `CLAUDE.md`: **que un fichero esté en la lista de
arreglados no significa que lo estén todas sus ramas.**

### Tres correcciones a la premisa del ticket, medidas

1. **El widget de inicio NO esperaba ninguna decisión.** El ticket lo aplaza citando
   `fx-widget-drops-missing-currency`, pero ese ticket habla de `ExchangeRateWidgetHelper` — el
   widget de TASAS. Son cosas distintas: el de inicio se podía cerrar hoy y se cerró.
2. **El puntero del docblock de `LiveAnchorInfo` estaba roto.** Apuntaba a
   `fx-live-anchor-sheet-and-distribution-kpi-unmarked`, que **no existe en `tickets/`**. Quedó
   corregido al revivir el campo.
3. **El diagnóstico del widget era correcto pero incompleto**: `WidgetPeriodSummary` no tiene el
   campo, y además **está duplicada en dos targets**, y su productor
   (`WidgetDataCache.buildPeriodSummary`) no es `CashFlowCalculator` sino una suma propia que no
   mira `isExchangeRateProvisional` de nadie. No había señal que cablear: había que producirla.

### Qué se hizo, por bloques

**Con la señal ya en mano** (`isEstimate:` y poco más): Flujo de caja de la app (KPI del header con
selector por métrica, neto del compacto, las cuatro barras de ingreso/gasto y la etiqueta de
VoiceOver del gráfico), los chips de Estadísticas, el promedio diario, los chips de Tendencias y la
píldora del hero del Panel.

**Propagando la señal por un carril que ya existía**: el saldo vivo. `LiveAnchorInfo` recupera
`amountsAreApproximate` —ahora con lector real— y viaja por `TrendDataProcessor`, los dos
ViewModels y `TrendChartView` hasta la hoja «¿Cuánto tienes hoy?», que era la peor omisión. Su
desglose por divisa pasó a pedir la **calidad de cada conversión** (`convertCheckedWithLatestRate`)
en vez del OR del total: heredar la marca del saldo señalaría como dudosa una divisa cuya tasa sí
era la de hoy.

**Produciendo señal donde no existía**: Registros (`calculateSummary` acumula magnitudes por lado y
las mide con `ApproximateMarkThreshold`; su tupla de tres `Double` pasa a struct) y el widget de
inicio (`buildPeriodSummary` produce las cuatro señales; el flag viaja además en
`WidgetTransaction` para que el camino de emergencia del widget no recalcule totales declarándolos
exactos sin saberlo).

**Como booleano y no como glifo**: el asistente. Su destino es el system prompt, donde los importes
son `Double` para que el modelo pueda sumar sin parsear texto; un «≈ 1234» los convertiría en
`String`. Van tres campos hermanos (`*_is_approximate`) más la regla 15 del prompt que dice qué
hacer con ellos — sin esa línea serían el campo que nadie lee, que es justo lo que este repo ya se
quitó una vez de `LiveAnchorInfo`.

### Lo que NO lleva marca, y por qué (todo escrito en el código)

- **Importes de OTRO período** — el «vs período anterior» del flujo: la señal que viaja en el
  summary describe el período actual. → `fx-previous-period-amounts-unmarked`.
- **Importes por bucket** — el tooltip del gráfico: la señal es del período entero y aplicarla a un
  día marcaría uno cuyas conversiones pudieron ser exactas. → `fx-per-bucket-approximate-signal-missing`.
- **Subconjuntos por categoría** — pies, top-categorías, buckets de necesidad: la incertidumbre
  puede estar entera en otra categoría. → `fx-category-totals-unmarked`.
- **El saldo en su divisa nativa** en el desglose de la hoja: no hubo conversión que juzgar.
- **El saldo histórico de un período cerrado**: no existe la señal en ninguna parte de la app;
  producirla pide tocar `fillBalanceBuckets`. `BalanceKPICalculator.Result.isApproximate` devuelve
  `false` ahí y su docblock dice que eso significa «no lo sé», no «es exacto». →
  `fx-historical-balance-curve-unmarked`.
- **Los widgets de pantalla de bloqueo y la leyenda del flujo grande**: sus formateadores no
  imprimen divisa, y el «≈» de este repo se antepone al SÍMBOLO. Un «≈ 3250» pelado se lee como
  parte de la cifra.

### Lo que se aprendió y no estaba escrito en ningún sitio

**El campo Codable nuevo apaga los widgets, y la red ya existía.** El snapshot del App Group se
decodifica con `JSONDecoder().decode(WidgetDataSnapshot.self, …)` —struct entera, sin versionado—,
así que una clave nueva **no opcional** dentro de `thisMonthSummary` (que tampoco es opcional) hace
`keyNotFound` sobre un payload escrito por la versión anterior: `loadSnapshot()` devuelve nil y
**todos** los widgets de la pantalla de inicio se quedan en cero hasta que el usuario abra la app.
El primer intento los declaró `Bool` a secas y **lo cazó un test que ya estaba**:
`WidgetSessionSealTests.snapshotLegacySinElCampo_decodificaComoDelDueno`, escrito para el sello de
sesión, decodifica un JSON con «la forma exacta que hay hoy en los discos». Se resolvió como el
propio fichero ya resolvía `periodBalance` y `sessionSeal` —opcional a los dos lados, leído con
`?? false`— y se añadió el caso hermano con transacciones dentro, que el original no cubría.

**El umbral no se puede importar en el widget y por eso se replica.** `ApproximateMarkThreshold` no
está en la membership exception del target `YalaWidgetsExtension` (solo tres ficheros de `Yala/` lo
están). El camino de emergencia lo replica, y esa réplica lleva su test de paridad
(`WidgetApproximateThresholdParityTests`): compara las dos implementaciones en los diez bordes que
importan y falla si el original cambia de umbral y la copia no. Sin él, el mismo mes saldría marcado
en la app y exacto en la pantalla de inicio.

**Un `accessibilityLabel` en el `Button` tapa la etiqueta que `AmountText` se pone a sí mismo.** Los
dos chips de Registros anunciaban «Ingresos» y nada más — el importe no se leía, ni antes ni después
del cambio. Se arregló ahí porque sin eso el «≈» tampoco se oía, y el barrido del resto de la app
queda en ticket propio.

### Lo que cambió la review adversarial (tres lentes, 2026-09-09)

**Un rojo real, y lo encontraron dos lentes por separado.** `periodBalanceIsApproximate` del widget
dividía entre `Σ|monto|` —la facturación bruta de todo el histórico— en vez de entre el saldo. Pero
el saldo es una **resta**, y el contrato de `ApproximateMarkThreshold` es explícito: cuando el número
es una resta, el denominador honesto es lo que el usuario ve. El propio `return` hacía lo correcto
tres campos más arriba para el neto de caja. Efecto medido: 400 dudosos sobre un saldo de 500 dan un
80 % y marcan; sobre una facturación de 300.000 dan un 0,13 % y no. **La marca se perdía justo en
quien más historial tiene.** Corregido, y con un caso nuevo que lo discrimina — el que había (−500
dudosa, −500 exacta) daba 50 % por las dos reglas y pasaba igual con el bug dentro.

**Un hallazgo refutado por una decisión escrita.** Las dos primeras lentes señalaron que
`LiveBalanceCalculator` marca con un OR crudo y no con el umbral del 5 %, y dieron el escenario: 30
USD olvidados marcando un saldo de 42.000 €. Es cierto **y es deliberado**: Jürgen lo decidió el
2026-09-08 en `approximate-mark-ors-over-whole-period` — *«su unidad ya es la divisa, no la
transacción, y una divisa entera sin tasa sí es una ausencia que merece la marca»*. No se toca. Lo
que sí faltaba es que estuviera escrito **donde se lee**: el docblock de la hoja lo dice ahora, para
que la próxima review no lo vuelva a levantar.

**Cuatro huecos en mis propios tests, todos reales:**

1. **La paridad del umbral no comparaba nada del widget.** `replicaAgreesWithTheOriginal` medía el
   original contra una tercera copia escrita en el propio test, y el source-scan solo grepeaba dos
   literales: invertir los guards o cambiar `>=` por `>` en el código real dejaba todo verde. Y no
   hay alternativa por comportamiento — `YalaTests` no compila `YalaWidgets`. Ahora el scan fija el
   **cuerpo entero normalizado**, paso a paso y con el orden de los dos guards.
2. **Dos pasarelas sin una sola aserción.** `WidgetKPI:71` es el único camino de la marca hacia
   `BalanceWidget`, `ExpenseWidget` y el neto de flujo; `PanelSmallBarRow:46`, hacia las barras del
   compacto. Borrar una línea en cualquiera apagaba el «≈» aguas abajo con la suite en verde.
3. **`RecordsViewModel.calculateSummary` era un productor nuevo cubierto solo por un scan de la
   vista.** Cruzar los acumuladores de ingreso y gasto no ponía nada en rojo. Tiene ahora suite
   propia de comportamiento, con el caso del neto pequeño entre dos lados grandes.
4. **El caso «régimen cerrado» del KPI no pasaba por el régimen cerrado**: la transacción caía fuera
   del intervalo, así que salía por la rama «sin datos», que devuelve el mismo literal. Corregido con
   su control de escenario.

Además: los conteos pasan a filtrar comentarios con el helper `codeOnly` que el repo ya tenía en
`WidgetSessionSealTests` (documentar un símbolo que un test cuenta lo ponía en rojo sin que
producción cambiara), el scan del productor del widget se acota a `buildPeriodSummary`, y el
emparejamiento del `switch` por métrica se fija `case` a `case` — con `contains` sueltos, devolver la
señal del gasto en el caso del ingreso pasaba en verde.

**Y una corrección de honestidad en un docblock mío.** `BalanceKPICalculator.Result.isApproximate`
decía que en el régimen cerrado «no hay señal que leer», presentándolo como imposibilidad técnica. Es
alcance: el ingrediente está a mano y este mismo commit hace ese cálculo para el widget. La
diferencia es que allí el bucle es una suma propia de cuatro líneas y aquí sale de
`fillBalanceBuckets`, que alimenta también la curva y tiene dos suites encima. Reescrito, y el ticket
`fx-historical-balance-curve-unmarked` lleva el dato.

**Verificación tras la review**: 4 mutantes nuevos, los 4 rojos donde debían (guards invertidos en la
réplica, `WidgetKPI` sin reenviar, acumuladores de Registros cruzados, denominador del saldo vuelto a
la facturación bruta).

### Verificación

- **Suite unitaria completa en verde: 6.540 casos en 666 suites.** El conteo se leyó de
  `Test run with`, no de un grep anclado.
- **XCUITest de las 13 áreas que casan con los ficheros tocados**: 27 casos, 0 fallos, 0 reinicios de
  runner (la comprobación que separa un rojo real de una colisión de corridas).
- **Siete mutantes en total, los siete rojos donde debían.** Tres antes de la review (hoja cableada a
  `false`, umbral replicado a 0,10, productor del widget vuelto a un OR) y cuatro después (guards
  invertidos en la réplica, `WidgetKPI` sin reenviar, acumuladores de Registros cruzados,
  denominador del saldo vuelto a la facturación bruta).

### Queda por hacer

- **Device-QA**, y **SÍ es simulable**: sirve el mismo montaje que los otros tickets de FX —una
  cuenta en divisa ausente de la fila de tasas—, así que lo bloquea
  `qa-no-puede-crear-cuenta-en-otra-divisa` (**high**) igual que a los otros cuatro.
- Lo que hay que mirar con los ojos: que el «≈» de la hoja del saldo vivo y el del número grande del
  Panel digan lo mismo a la vez, que el widget de inicio lo pinte tras reescribir el snapshot, y
  que el asistente use la salvedad **solo** cuando el flag viene en `true`.

## Deja ocho tickets

- `fx-historical-balance-curve-unmarked` (**medium**) — el saldo de un período cerrado no puede
  marcar. Lleva escrito el dato que aportó la review: en el widget sí se pudo, y por qué aquí no es
  lo mismo.
- `records-summary-mixes-preferred-currencies` (**medium**) — el resumen de Registros suma divisas
  preferidas distintas; `CashFlowCalculator` tiene el `if` que a él le falta.
- `fx-category-totals-unmarked` (low) · `fx-per-bucket-approximate-signal-missing` (low) ·
  `fx-previous-period-amounts-unmarked` (low) — los tres desgloses sin señal propia.
- `records-summary-chips-hide-their-amount-from-voiceover` (low) — el patrón de a11y, a barrer.
- `stats-per-account-branch-keeps-stale-live-anchor` (low) — preexistente, medido de camino.
- `widget-period-balance-ignores-group-bridge-adjustment` (low) — hallazgo de la review: el saldo del
  widget y su gasto no recorren el mismo conjunto de transacciones. Preexistente, y la marca lo
  hereda de forma coherente con su número, que es por lo que no se tocó de camino.

## No confundir con

- `fx-manual-writes-seal-approximate-as-final` (high) — por qué la señal **se enciende menos de lo
  que debería** en cualquier superficie.
- `fx-widget-drops-missing-currency` — el widget de TASAS omite la divisa en vez de marcarla; es otra
  decisión y **no bloqueaba** al widget de inicio, contra lo que decía este ticket.

---

## 2026-09-09 — el montaje que esperabas ya existe

El estado de partida se siembra desde un solo launch con `-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista -uitest-seed-foreign-account JPY` (ticket `qa-no-puede-crear-cuenta-en-otra-divisa`, **done**). Deja la cuenta «QA FX» con un ingreso y dos gastos fechados HOY, marcados `isExchangeRateProvisional` por el camino de producción — la fila del día existe y no trae JPY, así que la conversión es `.staticFallback`.

**Aviso para no leer un falso negativo:** con el filtro «Todo el tiempo» el fixture NO marca (750 sobre 206.725 son el 0,36 %, bajo el umbral del 5 %). **Acota el período** — con «Este mes» los tres números del Panel llevan «≈» y sin el arg ninguno.

**Queda desbloqueado ENTERO.** Tu :213 pedía exactamente «una cuenta en divisa ausente de la fila de tasas» y nada más, así que ya puedes recorrer las superficies secundarias y ver en cuáles falta la marca.

---

## Device-QA hecho · 2026-09-09 — PASS con tres hallazgos, ninguno de los cuales lo reabre

Simulador iPhone 17 Pro (`9D0F6D32`), iOS 26.5, `Yala Dev`, mismo lanzamiento que su hermano y
período «Este mes» (con «Todo el tiempo» el fixture pesa 0,36 % y no marca: no leerlo como fallo).

### Las superficies de tu tabla, una a una

| superficie | veredicto | lo que se vio |
|---|---|---|
| «¿Cuánto tienes hoy?» | **PASS** | «Tu saldo hoy **≈ S/ 79.011,40**» — la peor omisión, cerrada |
| Flujo de caja | **PASS** | Total **≈ S/ +5.327,00**; el «vs S/ 4.704,00» sin marca, como está declarado |
| Registros | **PASS** | Hero y los dos chips con «≈», **y la etiqueta de VoiceOver también** (`≈ S/ 10.000,00`) |
| Promedio diario (Resumen) | **PASS** | **≈ S/ 519,22** |
| Chips de Estadísticas | **PASS** | **≈ S/ 10.000,00** / **≈ S/ 4.673,00** |
| KPI de Distribución (hero) | **PASS** | **≈ S/ 79.011,40** en modo Balance |
| Widget de inicio | **no verificado** | exige montar el widget en la pantalla de inicio; queda para la próxima tanda |
| Asistente | **fuera del simulador** | su salida es el system prompt, y comprobar que usa la salvedad **requiere LLM real** |

El desglose por divisa de la hoja pide la calidad de **cada** conversión, como dice tu texto: PEN sin
marca (nativa), USD y JPY con ella.

### Tres hallazgos, con ticket propio

1. **[[live-anchor-breakdown-doubles-the-approximate-glyph]]** (medium) — en el desglose por divisa
   el copy ya traía un «≈» propio, así que la divisa dudosa sale **«≈ ≈ S/ 750,00 hoy»** y la buena
   «≈ S/ 111.711,40 hoy»: se distinguen sólo por *cuántas veces* aparece el símbolo. El cableado que
   añadiste aquí es correcto; lo que no llega es la señal. Está en los 16 `.lproj`.
2. **[[pie-header-total-unmarked]]** (medium) — «Análisis del gasto» pinta **S/ 4.673,00 sin marca**,
   el mismo número al céntimo que el Panel, Resumen y Registros marcan. Corrige además una premisa
   de `fx-category-totals-unmarked`, que justifica su `low` diciendo que «el total que agrega estas
   líneas sí avisa».
3. **[[weekday-bar-daily-average-unmarked]]** (medium) — hay **dos** tarjetas rotuladas «Promedio
   diario»: la de Resumen marca (≈ S/ 519,22) y la de Tendencias no (S/ 3.944,00). Tu tabla nombraba
   `InsightsTabView.swift:546`; la otra es `WeekdayBarPanelWidget.swift:36`, que además se monta
   también en el Panel.

Los tres son superficies que **la tabla no nombraba** o presentación, no regresiones de lo que este
ticket cableó — por eso el veredicto es PASS y no vuelve a `in-progress`. Y son, otra vez, el mismo
corolario del `CLAUDE.md` que tú ya habías escrito aquí: la tabla nombra un sitio por pantalla.

### Lo que queda para cerrar del todo

Verificar el **widget de inicio** con el snapshot reescrito. Es simulable (montar el widget en la
pantalla de inicio del simulador), sólo que no cabía en esta tanda.

## QA Visual · 2026-09-16 — PASS

Simulador iPhone 17 Pro (iOS 26.5), sobre `2.1` @ `bebd57a57`, `Yala Dev`. Cierra lo que el 2026-09-09 dejó abierto: **el widget de inicio**.

| Montaje | Widget «Gastos» | Panel |
|---|---|---|
| seed `realista` + `-uitest-seed-foreign-account JPY` y un gasto a mano de 1.000.000 ¥ en «QA FX» | **≈ 228,161** | ≈ S/ 228,160.67 |
| seed `realista` **sin** el arg de divisa | **203,745**, sin «≈» | sin «≈» |

El widget marca cuando el Panel marca, y con la misma cifra.

Capturas: [con marca](../../qa/evidencia-barrido-20260916/09-fx-widget-gastos-con-marca-igual-al-panel.jpg) · [sin marca](../../qa/evidencia-barrido-20260916/11-fx-widget-gastos-SIN-arg-sin-marca.jpg).

**El «$» de esas dos capturas no es un bug.** Sale solo bajo `-uitest`; lo más probable es el fallback a
USD de `WidgetDataCache.swift:350` cuando falta la divisa preferida. Con una instalación real (onboarding
en PEN y un gasto de 12) el widget dice **«PEN 12»**: [captura](../../qa/evidencia-barrido-20260916/33-widgets-sin-uitest-muestran-PEN.jpg).

**Asistente: cerrado sin verificar (override de Jürgen 2026-09-16).** Comprobar la salvedad exige el
LLM real, que el simulador no tiene (sin App Attest). En un iPhone tampoco hay guion: los seeds que
fabrican una fila con tasa provisional solo existen en simulador.
