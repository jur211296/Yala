---
description: Conversión de divisas — los tres escalones de tasas, la caché del TC actual y la marca de aproximado. Se carga al tocar el converter, las tasas o los calculadores que agregan importes.
paths:
  - "Yala/Services/CurrencyConverter.swift"
  - "Yala/Services/ExchangeRateService.swift"
  - "Yala/Services/CurrencyChangeService.swift"
  - "Yala/Utils/CurrencyUtils.swift"
  - "Yala/Utils/CurrencyFormattingHelper.swift"
  - "Yala/App/Logic/ExchangeRate*.swift"
  - "Yala/App/Logic/Calculators/CashFlowCalculator.swift"
  - "Yala/App/Logic/Calculators/HeroBucketsCalculator.swift"
  - "Yala/App/Logic/Calculators/LiveBalanceCalculator.swift"
---
# Divisas · tasas · la marca de aproximado

## La forma del bug que se repite en este módulo

**Una fuente peor que TAPA una mejor, y presenta el resultado como bueno.** Ha aparecido tres veces
con la misma silueta y distinta puerta, así que conviene reconocerla antes que memorizar sus casos:

1. `fx-partial-rate-rows-silent-1to1` (2026-09-03) — la fila de tasas del día existía pero no traía
   la divisa pedida; el converter cortaba por EXISTENCIA de fila y devolvía el monto **crudo**.
   La tasa estaba disponible dos escalones más abajo: **la fila parcial era estrictamente peor que
   no tener fila.**
2. `fx-presentation-still-shows-1to1` (2026-09-06) — lo mismo en la ruta del **TC actual**, que
   aquel fix no tocó: su caché se sembraba con `needing: []` ⇒ una fila parcial entraba entera y
   `performConversion` salía por su `guard`. Medido: **1000 JPY → 1000 PEN**.
3. El mismo día, al arreglar (2) — sembrar la caché con la tabla estática ENTERA cuando no hay fila
   de hoy hacía **vacua** la comprobación de cobertura (la tabla cubre todas las divisas), y el
   escalón de la fila real anterior no se alcanzaba nunca. Medido: `convertWithLatestRate` daba
   24,79 mientras `convert(_:on:)` daba **40** con la fila de ayer, en el mismo instante.

⇒ **Al tocar la resolución de tasas, la pregunta no es «¿devuelve un número?» sino «¿hay una fuente
mejor que este camino se está saltando?»**. Y la comprobación que lo zanja son **las dos rutas sobre
los mismos datos**: si `convert(_:on:)` y `convertWithLatestRate` no coinciden, una está eligiendo
peor (pinneado en `CurrencyConverterLatestRateQualityTests.bothRoutesAgree`).

## La caché del TC actual

- Se siembra **solo con la fila de hoy**, nunca completada con escalones inferiores: no sabe qué
  divisas le van a pedir después, y rellenar «por si acaso» es lo que mató el carry-forward.
- Guarda **el origen POR DIVISA** (`CachedRates.origins`), no una calidad del conjunto. La calidad de
  una conversión es la **peor de sus dos divisas** (`RateQuality.worse`): decir `.exact` porque una
  de ellas lo era es la verdad a medias que este enum existe para impedir.
- Lo que falta se resuelve **nombrándolo** (`needing: [from, to]`) y se **funde** en la caché. Sin la
  fusión, un día sin fila de tasas paga dos fetches y hasta 30 decodes JSON **por importe
  convertido**, y hay llamadores que convierten dentro de un bucle anidado (pagos × ocurrencias).
- La fusión se **descarta** si la caché fue invalidada mientras se resolvía: escribir ahí resucitaría
  la entrada previa al refresco y la dejaría viva hasta medianoche.
- **Todo escritor de tasas tiene que postear `.yalaExchangeRatesUpdated`.** `forceRefreshRates` no lo
  hacía y dejaba al converter sirviendo lo que sembró antes —y declarándolo aproximado— con la fila
  buena ya en disco.

## Una tasa inservible es una tasa AUSENTE

Un `0` guardado (o negativo, o no finito) pasaba la comprobación de presencia, nunca contaba como
faltante, y `performConversion` acababa devolviendo el monto **crudo** con calidad `.exact` — el bug
de arriba por otra puerta. En el destino era peor: devolvía **0**, que parece un dato real.

⇒ las tres preguntas —cobertura de la caché, `missing()` del escalonado y el guard de la conversión—
tienen que ser **la misma**: `CurrencyConverter.isUsableRate`. Al añadir un camino que lea tasas,
fíltralo por ahí o los escalones no podrán rescatar la divisa.

**Lo mismo con un importe ya convertido (2026-10-11).** Un `amountInPreferredCurrency == 0` con
`amount != 0` no es un importe: es una conversión que no se escribió. Sumado tal cual, un gasto de
grupo con la pata de préstamo así salía con el importe del grupo entero y sin «≈» (aportaba 0 al
importe y 0 a la duda). `GroupBridgeStatsAdjustment` reconvierte esa pata —y la guardada con otra
divisa preferida— con `CashFlowCalculator.reconverted`, la segunda rama de `resolvedAmount`: si
necesitas reconvertir un nativo, llama ahí, no copies la conversión. **Una fila suelta con ese cero
sigue contando 0** en `resolvedAmount` (ticket `resolved-amount-trusts-a-zero-converted-amount`).

## Reabrir una fila para que el reparador la recalcule NO es neutro

`isExchangeRateProvisional = true` parece una marca inocente —«que la mire otro»— y no lo es:
`TransactionItem.recalculatePreferredCurrency` **sobrescribe `amountInPreferredCurrency`** con lo que
dé la conversión de HOY, sea cual sea su calidad. Solo el flag distingue exacto de degradado; el monto
se pisa igual.

⇒ **reabrir solo es seguro si el monto guardado ya estaba mal.** Antes de mandar una fila a la cola,
pregunta cuál de sus columnas miente:

| lo que está mal | qué hacer |
|---|---|
| el monto convertido (la conversión falló y se guardó el crudo) | reabrir: recalcular solo puede mejorarlo |
| **solo la tasa** (hubo conversión real y se plantó un `1.0` al lado) | **corregir la tasa en el sitio**, deduciéndola de los montos ya guardados |

Las dos poblaciones caen bajo el mismo criterio de `ExchangeRateRepairLogic.needsRepair`
(`exchangeRate == 1.0` + divisa ajena) y **se distinguen por el cociente**
`amountInPreferredCurrency / amount`: si vale 1, el monto tampoco se convirtió; si no, ése ES el
número que hay que escribir en `exchangeRate` (`rateFromStoredAmounts`).

Tratarlas igual destruye datos buenos, y no en teoría: si la tasa de la fecha de la fila ya no está en
disco, `resolveRates` baja los escalones hasta la **tabla estática**, que es un snapshot congelado
(`ars: 1050.0` en `CurrencyUtils`, a un orden de magnitud del valor de 2025). El monto correcto se va,
y hay camino a que la pérdida sea **permanente**: el pase siguiente ya no cambia nada,
`allFetchesSucceeded` sella la huella futile de `FXRepairQueueLogic` y la cola deja de reintentarlo.

**Y decide QUÉ se emite al canal nube, que es la mitad menos evidente.** Las cuatro columnas de dinero
están en el grupo de coherencia `money` y `DeltaEmitter` expande cualquiera de ellas al grupo entero
con un HLC fresco. Reabrir emite la fila con la tasa envenenada **todavía puesta**: bajo LWW por
unidad, ese barrido le gana a un dispositivo par que ya la hubiera reparado y **difunde el veneno**.
Si vas a tocar una fila envenenada, **corrígela antes de guardar** — lo que viaja es el estado final,
no la intención.

**Un one-shot de reparación se sella solo cuando ha podido mirar.** El flag en `UserDefaults` se marca
aunque el barrido no encontrara nada, y eso está bien **si había corpus**: sobre un store vacío es un
sellado prematuro que deja el daño sin cura para siempre. Y `isImportQuiescent` no basta para saberlo
—vale `true` ANTES de que empiece ningún import (`lastImportDate == nil`), como documenta
`BootSaveGateLogic`—: la quiescencia y la presencia del corpus son preguntas distintas y hacen falta
las dos.

## La marca de aproximado en un total

**El importe agregado casi nunca pasa por el converter.** Cuando la divisa de destino es la preferida
—el caso normal— se suma el `amountInPreferredCurrency` que ya está en disco, convertido el día que
se creó la transacción. Así que «este total es aproximado» se sabe por dos vías y **hacen falta las
dos**:

| rama | fuente de la señal |
|---|---|
| importe guardado | `tx.isExchangeRateProvisional` |
| conversión en vivo | la `RateQuality` que devuelve `convertChecked…` |

- **La señal va separada por lado (ingreso / gasto)**, no una sola por período: el hero de Tendencias
  pinta uno de tres números según la métrica y el del Panel en modo Solo Gastos pinta solo el gasto.
  Con una señal común, un gasto mal convertido le ponía «≈» al total de INGRESOS.
- **La marca es del número que se pinta.** Antes de pasar un `isEstimate:`, comprueba qué agrega ese
  número concreto: marcar de más erosiona la marca igual que no ponerla.
- **El glifo es `≈` y no lleva copy nuevo**: lo antepone `CurrencyFormattingHelper` y lo conduce
  `AmountText.isEstimate`, que ya existía y ya lo usaban los saldos de Grupos. No inventes un rótulo
  paralelo ni una key localizada.
- **La etiqueta de accesibilidad también.** Si el número lleva «≈» en pantalla y su
  `accessibilityLabel` se formatea sin `isEstimate:`, VoiceOver lo lee como exacto: la marca es
  información, y dejarla solo en el glifo la esconde de quien no lo ve.
- **El denominador de la proporción es el número que se MUESTRA.** Cuando ese número es una resta
  —un saldo, un neto— NO uses la suma de magnitudes que lo formó: el contrato de
  `ApproximateMarkThreshold` lo dice («o su valor absoluto cuando el número es una resta») y el
  2026-09-09 se incumplió en `WidgetDataCache.periodBalanceIsApproximate`, que dividía entre
  `Σ|monto|` de todo el histórico. Efecto medido: 400 dudosos sobre un saldo de 500 son el 80 % y
  marcan; sobre una facturación de 300.000 son el 0,13 % y no ⇒ **la marca se perdía justo en quien
  más historial tiene**. El numerador es el caso contrario y no se confunden: ése suma magnitudes
  siempre, porque los errores de dos conversiones distintas no se cancelan. Y el test tiene que
  DISCRIMINAR: dos importes iguales dan el mismo veredicto con las dos reglas.
- **Cuando el importe no sale de UNA fila, su marca tampoco.** Un gasto de grupo bridgeado se
  sintetiza como `pata real + Σ patas de préstamo` (`GroupBridgeStatsAdjustment`), y las de préstamo
  están **suprimidas del recorrido**: su `isExchangeRateProvisional` no lo lee nadie. La magnitud
  dudosa la sirve `approximateMagnitude(_:magnitude:)`, y devuelve **`Σ|patas provisionales|`, no el
  neto marcado** — que es el contrato del numerador, escrito con esta misma pareja. Marcar el neto
  falla en las dos direcciones y las dos están medidas (2026-09-09): con mi parte pequeña
  (1.000 de 10.000, 9.000 prestados dudosos sobre un mes de 26.000) se queda en 3,8 % y **no marca**
  un mes con un tercio de aritmética dudosa; con mi parte grande (9.700 de 10.000, 300 dudosos sobre
  10.300) da 94 % y **marca el mes entero por 300** — en el límite, dos céntimos. Regla corta: **el
  numerador cuenta la incertidumbre que ENTRÓ, el denominador el número que SALE.**
- **`LiveBalanceCalculator` marca con un OR por DIVISA y eso es deliberado** — decisión de Jürgen del
  2026-09-08 (`approximate-mark-ors-over-whole-period`): su unidad ya es la divisa, no la
  transacción, y una divisa entera sin tasa sí es una ausencia que merece la marca. Consecuencia
  aceptada: 30 USD olvidados con la tasa caducada marcan un saldo de 42.000 €. Alimenta el saldo del
  panorama, la hoja «¿Cuánto tienes hoy?» y el KPI de Balance de Distribución. **Una review
  adversarial lo levantará como bug** —pasó el 2026-09-09, dos lentes a la vez—; está escrito en el
  docblock de la hoja para que se zanje leyendo.
- `isEstimate` en los saldos de **Grupos** significa otra cosa —«hubo conversión», no «la tasa era
  mala»— y es una decisión de producto anterior. Es un superconjunto de la nueva, así que no miente;
  no la unifiques sin decisión del owner.

## Al tocar esto, mide

Un verde no prueba nada aquí: hasta el 2026-09-03 **53 pruebas tocaban FX y ninguna podía ponerse
roja** por el bug de la fila parcial, porque ningún fixture omitía una divisa. Antes de dar por bueno
un cambio, **muta y exige rojo** — y el fixture tiene que poder construir la fila incompleta, la fila
de ayer y la tasa cero, o la suite es ciega al único modo en que este módulo falla.
