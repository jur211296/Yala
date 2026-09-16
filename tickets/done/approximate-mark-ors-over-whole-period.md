---
id: approximate-mark-ors-over-whole-period
status: done
priority: medium
area: "currency, fx, ui"
created: 2026-09-07
source: review adversarial de fx-manual-writes-seal-approximate-as-final (2026-09-07)
updated: 2026-09-16
qa-status: passed
qa-date: 2026-09-16
---

# Una sola transacción aproximada pone «≈» al número grande de todo el mes

## Qué le pasa al usuario

`HeroBucketsCalculator` acumula la marca con un **OR sobre todo el bucket del período**
(`HeroBucketsCalculator.swift:102,105`), igual que `CashFlowCalculator` por lado
(`CashFlowCalculator.swift:95`). Basta **una** transacción con la tasa aproximada para que el hero del
Panel —y su etiqueta de VoiceOver, `HeroMonthView.swift:198-205`— declare aproximado el total del mes
entero.

Desde `fx-manual-writes-seal-approximate-as-final` la población marcada es mucho mayor, así que esto
pasa de raro a frecuente para el usuario multidivisa. Tres fuentes nuevas:

- Crear una transacción mientras la fila del día aún no cubre las dos divisas (arranque sin red, o
  antes de que termine el refresco; el fallo de API se traga en silencio).
- **Editar cualquier cosa de una transacción vieja**: cambiar solo la nota de una de hace dos años,
  cuya fila es parcial, la voltea `false → true` y le pone «≈» al hero de aquel mes.
- Cambiar la divisa preferida, que recorre el histórico completo.

`FXPnLLogic` sí degrada bien —marca **por fila de divisa** (`FXPnLLogic.swift:301`)— y es el modelo a
seguir.

## Por qué importa y no es cosmético

Lo dice el propio código en `FXPnLLogic.swift:72-74`: **marcar de más erosiona la marca igual que no
ponerla**. Si el «≈» sale casi siempre, deja de significar nada y el usuario aprende a ignorarlo —
que es justo el final que `fx-presentation-still-shows-1to1` vino a evitar por el otro extremo.

Se agrava con `repair-queue-has-no-exit-for-partial-rate-rows`: mientras esa cola no tenga salida, las
transacciones marcadas no se limpian nunca y la marca se vuelve permanente.

## Lo que NO está afectado (medido)

- **Usuarios monomoneda**: `convertChecked` cortocircuita `fromCode == toCode` a `.exact`
  (`CurrencyConverter.swift:236-239`), y `contextFreeQuality` hace lo mismo antes de `setContext`. El
  problema es exclusivo de multidivisa.
- **El panorama del Panel**: su marca sale del `LiveBalanceCalculator`, no de este flag —
  pero **eso no lo deja al margen**, y esta línea decía lo contrario. Corregido el 2026-09-08:
  `LiveBalanceCalculator.swift:138` acumula su propia marca con **el mismo OR**
  (`amountsAreApproximate = amountsAreApproximate || !outcome.quality.isExact`) y la pinta en tres
  sitios de `PanelPanoramaSection` (`:133`, `:149`, `:162`) vía
  `PanelViewModel.panelTotalBalanceIsApproximate`. La diferencia real es otra, y **es la que importa
  para decidir**: itera `nativeBalances`, que ya viene **agrupado por divisa**, así que no tiene un
  importe aproximado por transacción sobre el que calcular una fracción.

## Criterio de hecho (AC)

- [ ] Decidir con Jürgen el umbral: ¿marca si CUALQUIER transacción es aproximada, si lo es una
      fracción del importe, o se marca por divisa como en `FXPnLLogic`? Es decisión de producto.
- [ ] Sea cual sea, que el hero y la comparativa usen el mismo criterio — hoy los tres calculadores no
      coinciden.
- [ ] Test que fije el criterio elegido con un caso de una sola transacción aproximada entre muchas
      exactas.


---

## Para decidir — preparado el 2026-09-08

**La pregunta, en una línea:** cuándo se gana el «≈» un total — ¿basta una transacción aproximada,
o hace falta que pese?

### Lo que medí hoy, y que mueve la decisión

Las tres coordenadas del ticket son **exactas en este árbol** (`HeroBucketsCalculator:102,105`,
`CashFlowCalculator:95`, `FXPnLLogic:301`). Pero el barrido completo encontró **cuatro**
acumuladores, no tres, y el cuarto es el que el ticket daba por no afectado
(`LiveBalanceCalculator:138`, corregido arriba). Los cuatro usan OR; en lo que difieren es en la
**fuente**, no en el operador:

| Dónde | Fuente de la marca | Granularidad |
|---|---|---|
| `HeroBucketsCalculator:102,105` | solo el flag guardado en la transacción | por transacción |
| `CashFlowCalculator:95,103` | flag **o** `!outcome.quality.isExact` | por transacción |
| `LiveBalanceCalculator:138` | solo el converter | **por divisa** |
| `FXPnLLogic:195` → `:112` | ambas | **por fila de divisa** |

Y el coste real está donde no se ve: **`ApproximateAmountMarkTests.swift` tiene 14 tests que fijan
el comportamiento actual**, y su comentario de `:115-118` documenta *a propósito* que una sola
transacción provisional debe bastar — o sea, el OR de hoy no es un descuido, es una decisión escrita
que este ticket propone revisar.

### Las opciones, con su coste medido

**(a) Dejarlo como está.** Coste cero. El «≈» sigue saliendo casi siempre para el usuario
multidivisa, y se erosiona hasta significar nada — que es lo que el propio código advierte en
`FXPnLLogic.swift:72-74`.

**(b) Umbral por importe**: marcar solo si la parte aproximada pesa lo suficiente sobre el total.
- **Coste: 4 ficheros de lógica y reescribir ~5 tests. Las vistas no se tocan.** `Buckets` y
  `CashFlowSummary` pueden acumular un importe aproximado paralelo y **derivar dentro del struct** el
  mismo `Bool` que ya exponen: la firma pública no cambia, así que `PanelViewModel`, `HeroMonthView`
  y los tests de wiring (que hacen *grep literal* sobre el fuente de las vistas) sobreviven intactos.
- **Su parte incómoda, y es de producto:** `LiveBalanceCalculator` no tiene importe aproximado por
  transacción, solo saldos por divisa, así que ahí el umbral se mide sobre otra cosa. Y para el
  «disponible» hay que elegir denominador.

**(c) Por divisa, como `FXPnLLogic`.** **Es el más caro y el que menos resuelve.** `HeroBuckets` no
agrupa por divisa en absoluto: suma `amountInPreferredCurrency` en escalares (`:70-76`), así que
introducir filas por divisa cambia su tipo de retorno y arrastra `PeriodSummary`, `HeroMonthView` y
los tests de wiring. Y sobre todo: **en el hero no hay dónde enseñar el desglose.** `FXPnLLogic`
puede marcar por divisa porque su desglose ya *es* el producto y hay un sheet que lo pinta
(`FXPnLDetailSheet:131`); el hero es **un número solo** en moneda preferida, y marcar «≈ por divisa»
un número agregado no le dice nada a nadie.

### Mi recomendación: **(b)**, y con estos dos valores ya elegidos

Porque es la única que ataca el síntoma real —que la marca se dispara por ruido— sin pedir UI nueva,
y porque el coste cae entero en lógica y tests, no en producto.

Dos parámetros que la vuelven concreta, propuestos para que solo haya que decir sí o no:

1. **Umbral: 5 % del importe del bucket.** Por debajo, el error posible es menor que el redondeo que
   el usuario ya ve; por encima, la marca informa de algo. Es un número redondo y explicable.
2. **Denominador: la magnitud del propio lado que se marca** (gasto sobre gasto, ingreso sobre
   ingreso), no el neto. El neto puede acercarse a cero y disparar el umbral con céntimos.
3. **`LiveBalanceCalculator` se queda con su OR por divisa** — su unidad ya es la divisa, y una
   divisa entera sin tasa sí es una ausencia que merece la marca.

### Si eliges (b), el AC es

- [ ] `HeroBucketsCalculator` y `CashFlowCalculator` acumulan importe aproximado y derivan el `Bool`
      por umbral; la firma pública de `Buckets` y `CashFlowSummary` no cambia.
- [ ] El umbral vive en **un solo sitio** con nombre, no repetido en cada calculador.
- [ ] Test con **una** transacción aproximada pequeña entre muchas exactas ⇒ **no** marca; y el
      gemelo con una aproximada que pesa ⇒ **sí** marca.
- [ ] Los ~5 tests de `ApproximateAmountMarkTests` que fijan «una basta» se reescriben al criterio
      nuevo, y su comentario `:115-118` se actualiza: hoy documenta lo contrario.
- [ ] `ApproximateMarkWiringTests` sigue verde sin tocarlo (si se rompe, es que cambió una firma que
      no debía cambiar).

### Si eliges (a), el AC es

- [ ] Se anota en el ticket que la marca amplia es deliberada, y se cierra como `discarded` — para
      que la próxima review no lo vuelva a levantar.

### Decisión de Jürgen

**(b) Umbral del 5 % sobre el propio lado.** Contestada el 2026-09-08 e implementada en el mismo PR.

- El criterio vive en **un solo sitio con nombre**: `ApproximateMarkThreshold` (`fraction = 0.05`).
  Un `0.05` suelto en un calculador sería un bug de duplicación.
- **Denominador: la magnitud del propio lado** (gasto sobre gasto, ingreso sobre ingreso), no el
  neto, que puede acercarse a cero y disparar el umbral con céntimos.
- `HeroBucketsCalculator` y `CashFlowCalculator` acumulan el importe aproximado **exactamente igual
  que su total** —con `abs()` el primero, con signo el segundo— y derivan el `Bool` en el `return`.
  La firma pública de `Buckets` y `CashFlowSummary` no cambia, así que las vistas y los tests de
  wiring no se tocan.
- **`LiveBalanceCalculator` conserva su OR**, y no es un olvido: su unidad ya es la divisa, no la
  transacción, y una divisa entera sin tasa sí es una ausencia que merece la marca.

**Lo que descubrió el control positivo, y conviene no perder:** con el criterio nuevo **ningún test
existente cambió de color** — los 14 usan importes iguales, donde una de seis pesa un 16,7 % y sigue
marcando. O sea que la batería que había **no distinguía** el criterio viejo del nuevo. El test que
sí lo demuestra es `cashFlow_oneTinyProvisionalAmongMany_doesNotMark` (5 de 1.005 = 0,5 %),
verificado con el mutante: recompilado el código anterior, ese test se pone **rojo**.

**(c) queda descartada con el motivo medido:** marcar por divisa es lo más caro y lo que menos
resuelve. `FXPnLLogic` puede hacerlo porque su desglose por divisa **es** el producto y hay un sheet
que lo pinta; el hero es un número solo en moneda preferida y no hay dónde enseñar el desglose.


---

## Lo que la review adversarial cambió, antes de mergear (2026-09-08)

**La primera implementación tenía una regresión y tres fallos de diseño.** Ninguno lo habría cazado
el gate: la suite entera estaba verde cuando se lanzó la review.

### 1 · El «Disponible» perdía la marca justo cuando más falta (regresión, ALTA)

Con umbrales por lado y el neto compuesto como `income || expense`, un ingreso de 1.000.000 con
49.000 aproximados (4,9 %, no marca) frente a un gasto exacto de 999.000 dejaba un «Disponible» de
**1.000 sin «≈», con una incertidumbre 49 veces mayor que el número**. Con el OR anterior sí salía
marcado: era una regresión introducida por este mismo cambio.

**Arreglo:** el neto tiene su propio cociente — incertidumbre de los dos lados **sumada** contra el
número que se pinta. Afecta a `CashFlowSummary.amountsAreApproximate`, `Buckets.periodNetApproximate`
(nuevo), `PanelHeroPeriodData.amountsAreApproximate` y `InsightsCalculator.PeriodSummary`, que tenía
el mismo OR alimentando el balance de Tendencias.

### 2 y 3 · El numerador con signo se cancelaba (ALTA)

Un gasto de 200 aproximado y su reembolso de 200 **también aproximado** dejaban numerador 0 ⇒ no
marcaba. Y si el reembolso hubiera sido exacto, sí: **la respuesta dependía de a cuál de las dos le
tocó el flag**. Peor de fondo: los errores de dos conversiones distintas **no se cancelan** — 1.000
aprox y 900 aprox no dejan 100 de incertidumbre, dejan 1.900.

**Arreglo:** numerador y denominador pasan a `Σ|contribución|`, magnitudes sumadas y nunca netos. Es
literalmente lo que `FXPnLLogic` ya había decidido con su `exposedBase = Σ|costBasis|` — y el
fichero nuevo lo citaba como motivación mientras hacía lo contrario.

### 4 y 5 · Los dos bordes

- **Sin suelo en el numerador**, una cancelación que dejaba `1e-15` marcaba y la misma cancelación
  exacta no: dos respuestas para el mismo caso según los decimales. Ahora el suelo es simétrico y
  vale **0,01**, alineado con `FXPnLLogic.nearZero` en vez de inventar un segundo suelo.
- **El borde inclusivo no lo era.** `0.15 / 3.0` da 0,049999999999999996 y `0.05 * 3.0` da
  0,15000000000000002: un 5 % exacto se caía por un ulp **por los dos caminos**. Se resolvió con
  tolerancia relativa.

### Lo que esto enseña sobre la batería que había

Los 14 tests originales usaban importes iguales, donde una de seis pesa un 16,7 %. **Ninguno cambió
de color** al pasar del OR al umbral ⇒ no distinguían un criterio del otro. Y ninguno cubría
reembolsos, ni el neto, ni `adjustment`. Los seis nuevos salen de ahí, y los dos que demuestran el
cambio están verificados con mutante: recompilado el código anterior, se ponen rojos.

### Dos hallazgos que NO se arreglan aquí, con ticket propio

- [[dos-criterios-de-aproximado-en-la-misma-pantalla]] — el panorama del Panel conserva su OR por
  divisa (es la decisión), así que el glifo «≈» significa dos cosas en la misma pantalla.
- [[bridge-de-grupos-pierde-la-marca-de-sus-patas]] — preexistente, pero ahora que el importe entra
  en un cociente, una atribución mal hecha **desplaza el umbral** en vez de solo perderse.

---

## Device-QA hecho · 2026-09-09 — PASS

Simulador iPhone 17 Pro (`9D0F6D32`), iOS 26.5, `Yala Dev`, con
`-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista -uitest-seed-foreign-account JPY`.

**El umbral se ve funcionando, y el par que lo demuestra es el mismo fixture leído con dos filtros
distintos** — o sea que no hace falta montar nada más para verificar esta decisión:

| filtro | parte aproximada / total del lado | «≈» |
|---|---|---|
| **Todo el tiempo** | 750 sobre 206.725 = **0,36 %** | **no** |
| **Este mes** | 750 sobre 4.673 = **16,0 %** | **sí** |

Son **las mismas transacciones** en los dos casos. Con el OR anterior el filtro «Todo el tiempo»
habría marcado igual —basta una fila provisional en el bucket—, así que la ausencia de marca ahí es
exactamente la erosión que la decisión (b) vino a evitar, vista en pantalla.

Capturas: `qa/evidencia-fx-20260909/01-panel-este-mes-CON-arg.png` (marca) y el snapshot de «Todo el
tiempo» del mismo lanzamiento (sin marca).

**La otra mitad de la decisión también se vio**: `LiveBalanceCalculator` conserva su OR, y por eso
el panorama dice **«Tienes ≈ S/ 79.011,40 en 3 cuentas»** con «Todo el tiempo» mientras los tres
números grandes de esa misma pantalla no llevan marca. Es lo que decidiste el 2026-09-08 —«su unidad
ya es la divisa, no la transacción»— y lo que [[dos-criterios-de-aproximado-en-la-misma-pantalla]]
registra como coste asumido. **Conviene saber que se ve así de junto**: dos criterios de «≈», en la
misma pantalla, a la vez.

**No se verificó** el borde inclusivo del 5 % ni el suelo de 0,01: son bordes de coma flotante y su
sitio son los tests, que ya los cubren.

## QA Visual · 2026-09-16 — PASS (re-verificado)

Simulador iPhone 17 Pro (iOS 26.5), sobre `2.1` @ `bebd57a57`, `Yala Dev`, seed `realista` + `-uitest-seed-foreign-account JPY`. Repite el PASS del
2026-09-09 con las cifras de hoy:

| Filtro | Disponible · Ingresos · Gastos | «≈» |
|---|---|---|
| Todo el tiempo | S/ 62,477.80 · 266,971.80 · 204,494.00 | **no**: la parte aproximada no llega al 5 % |
| Este mes | ≈ S/ 7,270.40 · ≈ 12,856.40 · ≈ 5,586.00 | **sí** |

Mismas transacciones con dos filtros: la marca sale solo donde pesa, y Estadísticas dice lo mismo que
el Panel. El panorama («Tienes ≈ S/ 70,680.45…») conserva su criterio propio, como se decidió el
2026-09-08.

Capturas: [Todo el tiempo](../../qa/evidencia-barrido-20260916/06-fx-panel-todo-el-tiempo-sin-marca-panorama-con.jpg) · [Este mes](../../qa/evidencia-barrido-20260916/07-fx-panel-este-mes-con-marca-CON-arg.jpg).
