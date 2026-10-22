---
id: fx-pnl-education-card
status: done
priority: medium
area: panel/finance
created: 2026-05-03
source: YalaWiki/Ideas/idea-fx-pnl-card.md
updated: 2026-09-08
qa-status: passed
qa-date: 2026-09-08
---


# Card educativa de Ganancia/Pérdida Cambiaria (FX P&L)

## Problema

> Tras el fix Live Balance ([[rvw_live-balance-multi-currency-fix]]), el usuario multi-divisa puede ver que su balance no coincide exactamente con la suma del cashflow histórico. La diferencia es ganancia/pérdida cambiaria latente (FX P&L) — información valiosa pero invisible. Las sheets informativas explican el porqué, pero no muestran la magnitud.

## Solución

Añadir card en el Panel (sección Tendencias o Para ti) que muestre:
- **FX P&L acumulado**: diferencia entre balance live y cashflow histórico acumulado, en moneda preferida.
- **Por moneda**: desglose breakdown por moneda nativa, mostrando saldo nativo, TC actual, valor en preferida, y P&L parcial.
- Mensaje cálido tipo: "Tus dólares se han **revalorizado/depreciado** un X% desde que entraron a tu cuenta."
- Visualización: chip tinta verde (ganancia) / gris (pérdida). NO usar rojo.

Indicador adicional: cuando `isExchangeRateProvisional` aplica al saldo (TC fallback porque API está caída o cuenta tiene transacciones recientes sin TC del día), mostrar etiqueta "TC estimado" en la card de balance.

## Acceptance Criteria

- [ ] Solo aparece cuando hay >1 moneda con saldo no-cero.
- [ ] Solo aparece si `|FX P&L| > umbral` (ej. >0.5% del balance) — evita ruido.
- [ ] Visualización breakdown por moneda en sheet detalle.
- [ ] Etiqueta "TC estimado" cuando aplica.
- [x] Free vs Pro: **Free** (decisión Jürgen 2026-09-06, abajo).

## Decisión Jürgen (2026-09-06)

**Free.** Elegida entre Free y Pro. Motivo, tal como se le puso delante y ratificó: es informativa y no usa IA; explica una diferencia que el
usuario multi-divisa ya ve en su saldo y no entiende. El diseño se resuelve en el `/spec` sobre el
patrón de cards del Panel, no aquí.

## Diseño

Pendiente de `/spec` (ya no de decisión). Inspiración: Wise, Revolut muestran FX P&L en transferencias. Yala lo mostraría a nivel cuenta/balance.

## Notas Técnicas

- `LiveBalanceCalculator.liveBalanceBreakdown(...)` ya retorna `nativeBalances` por moneda.
- Cashflow histórico acumulado: nueva agregación basada en `amountInPreferredCurrency`.
- FX P&L = balance live − Σ(cashflow histórico).
- Por-moneda: `(saldo_nativo × TC_actual) − Σ(cashflow_de_esa_moneda)`.

## Spec e implementación (2026-09-07, Frank)

### Lo que medí antes de diseñar

Las Notas Técnicas del ticket son **correctas**: `LiveBalanceCalculator` (27 usos),
`liveBalanceBreakdown` (4), `nativeBalances` (14) e `isExchangeRateProvisional` (32) existen todos
en `Yala/`. Control positivo: `CurrencyCode`, 651.

**Falso, y descartado:** la sección «Para ti» no existe. `PanelSectionKind`
(`Yala/App/Models/WidgetType+PanelSection.swift:15-23`) tiene siete casos y ninguno es ése.

**La premisa que sostiene la resta, confirmada:** `amountInPreferredCurrency` guarda el valor al
**TC del día de la transacción**. Lo fijan los dos únicos sitios que lo reescriben en masa
(`CurrencyChangeService.swift:60-65` y `TransactionItem.recalculatePreferredCurrency`), ambos con
`on: transaction.date`. Cambiar de moneda preferida **reexpresa** el pasado, no lo borra. Sin eso,
esta card no tendría nada que restar.

### El cálculo: FIFO por lotes

Por cada divisa extranjera con saldo vivo, se recorren sus transacciones **en orden de fecha**. Los
movimientos del mismo signo que el saldo abren lote (cantidad + TC de entrada); los contrarios
consumen lotes en orden de llegada. Lo que queda vivo al final es la posición actual, y su coste
medio es el `costBasis`. `pnl = saldo × TC_hoy − costBasis`.

**El primer diseño no era éste, y conviene que quede escrito por qué.** Promediaba
`Σ|amountInPreferredCurrency| / Σ|amount|` sobre todos los movimientos de la divisa. Es más simple
y **puede invertir el signo del número**:

- **Un gasto no es una entrada.** Comprar 1.000 USD a 3,00 y revenderlos el mismo año arrastra el
  «TC de entrada» de 100 dólares comprados a 4,00 en 2023 hasta ~3,05. Con el dólar hoy a 3,50 la
  card anuncia **ganancia a quien ha perdido**.
- **Un traspaso entre cuentas propias tampoco.** Sus dos patas entran al TC del día del traspaso,
  así que mover dinero de bolsillo empuja el P&L hacia cero: medido, **+300 → +33**.

FIFO responde a la pregunta real («¿qué pagué por los dólares que TODAVÍA tengo?») y es el criterio
de Wise y Revolut, la referencia que el propio ticket cita. Los traspasos se excluyen por
`balanceAdjustmentType`. Si los lotes vivos no cubren el saldo —un traspaso entrante desde una
cuenta que el filtro dejó fuera— la divisa se descarta entera antes que inventarle base.

### El mismo conjunto de cuentas que el saldo

`Breakdown` expone `eligibleAccountIDs` ya resuelto (contables, filtro de selección, `isExcludeMode`)
y el FX P&L recorre **ése**. El riesgo de esta feature no es la fórmula: es que los dos lados de la
resta barran conjuntos distintos, porque entonces el número sigue pareciendo plausible y está mal.

### Las dos vías de la marca de aproximado

`.claude/rules/currency-fx.md` lo exige y aquí es literal: el coste base sale de un importe
**guardado** (→ `tx.isExchangeRateProvisional`) y el valor de hoy de una conversión **viva** (→
`RateQuality`). Con sólo la segunda, una transacción sellada con la tabla estática produce un P&L
inventado y lo presenta como exacto — medido: **+38 % de ganancia salida de una tabla hardcodeada**.
La calidad se guarda **por divisa**, no una para el conjunto.

Un `amountInPreferredCurrency` a cero es un importe **ausente** (el valor por defecto del modelo), no
un coste de cero: se reconvierte con la tasa de su fecha. Tratarlo como dato daba el saldo entero
presentado como ganancia.

**Sin chip nuevo.** El glifo `≈` de `AmountText` ya dice esto y la regla prohíbe el rótulo paralelo;
el AC pedía una etiqueta «TC estimado» y se cumple con la marca que la app ya tiene. Las otras siete
superficies siguen siendo de `fx-approximate-mark-missing-on-secondary-surfaces`.

### Cuándo aparece

- Hay **al menos una divisa extranjera** con saldo no residual y base fiable.
  **Desviación del AC, deliberada:** el AC pedía «>1 moneda con saldo no-cero», pero un usuario con
  preferida PEN y todo su dinero en dólares tiene **una** divisa con saldo y es el caso donde la
  card más sirve. Lo que el AC quiere evitar es el usuario mono-divisa, y ése no tiene ninguna
  extranjera: el filtro correcto es la exposición, no el conteo.
- `|pnlTotal| > 0,5 % × baseExpuesta`, con `baseExpuesta = Σ|costBasis|`.
  **El denominador no es el balance**, aunque el AC lo propusiera: con un saldo cercano a cero o
  posiciones que se cancelan (+1.000 USD contra −3.800 PEN) el 0,5 % del balance es ~0 y la card no
  se iría nunca — justo el ruido que el umbral existe para filtrar.
- Y el número **no puede redondear a cero en pantalla**: «+0,00 €» es ruido con aspecto de dato.

### Qué ve el usuario

- **Card**: título según el signo, el P&L con su signo, y una frase sobre la divisa que **explica el
  número** —elegida por `|pnl|`, no por tamaño: con 10.000 USD planos y 1.000.000 ARS caídos,
  ordenar por exposición daba el titular «Pérdida» junto a «tus dólares valen un 0 % más»—. Cuatro
  variantes de frase, porque **un saldo negativo es una deuda** y a quien debe dólares no se le dice
  «tus dólares valen más» cuando el TC sube: para él eso es la mala noticia.
- **Hoja de detalle**: una fila por divisa con saldo nativo, TC de entrada, TC de hoy, valor actual
  en preferida y P&L parcial, más la nota que admite que el TC de entrada es un promedio de lotes.
- **Color**: `Color.incomeAmount` (#0F7A80, contraste 5,1) para la ganancia y la jerarquía normal
  del texto para la pérdida. **Nunca el rojo del DS** — perder por tipo de cambio no es un error del
  usuario— y nunca un color de la paleta como texto: ninguno llega al AA de 4,5 sobre tarjeta.

### Card suelta, y la condición vive dentro

Va en el `VStack` de `PanelView` (patrón `SetupChecklistCard`), no como `WidgetType` configurable:
por diseño aparece pocas veces y un widget que rara vez se ve ensucia el selector de secciones.

**El gate está dentro de la card, no en el callsite.** Con el `if` fuera, cruzar el umbral mientras
el usuario lee el detalle destruía la card, su `@State` y su `.sheet` —la hoja se cerraba sola en su
cara— y además leer la propiedad `@Observable` allí invalidaba `PanelView` entero, que es el body
pesado que `PanelShell` existe para no re-evaluar. La hoja recibe además un **snapshot** capturado
al abrirla, para que no mute bajo la vista de quien la está leyendo.

### Hoja nueva, no ampliar `BalanceLiveAnchorEducationSheet`

Aquella responde a otra pregunta («¿por qué mi saldo de hoy no cuadra con la curva?») y la abren dos
sitios cuyo contrato heredaríamos. Se reutiliza su vocabulario visual, no su código.

### Lo que cazó la review adversarial

Tres lentes independientes, y **todos los defectos eran míos**. Además de los dos que invertían el
signo (arriba), la marca incompleta, las filas sin `≈`, la `dominant` por exposición, el gate en el
callsite, el color sin contraste, el chip paralelo y el «+0,00».

Y uno que merece nombre propio: **mi primer arreglo heredó la forma del bug que arreglaba.** Al ver
que `amountInPreferredCurrency` podía venir sellado contra otra moneda preferida, añadí un guard que
**descartaba** esas transacciones, citando once precedentes del repo. Los precedentes
**reconvierten** en su `else` (`BalanceHelper:46`, `CashFlowCalculator:90`): me quedé con el `if` y
tiré el `else`. Y descartar no es neutro — sesga la muestra hacia las transacciones más antiguas o
llegadas de otro dispositivo, que es exactamente donde el tipo de cambio era distinto.

### Verificación

- `YalaTests/FXPnLLogicTests` (23 casos) y `YalaTests/FXPnLWiringTests` (10, source-scan).
- Suite completa: **6.404 tests en 651 suites, en verde**.
- **Control positivo por mutación, dos veces**: quitar la exclusión de traspasos mueve el P&L de
  **+300 a −100** (cambia de signo) y pone rojos dos casos; quitar `isEstimate: row.isApproximate`
  pone rojo el source-scan.
- Localización: 14 claves × 16 locales, con el contrato de alias respetado (`pt` es copia de
  `pt-BR`, no portugués europeo — se rompió al escribirlas y lo cazó `LocalizationParityTests`).

### Device-QA: pendiente y por qué

Requiere una cuenta multi-divisa con histórico real. **Ningún seed de UI test la produce** (son
PEN), así que la card no aparece en XCUITest y su cobertura de UI es cero por construcción. Queda
para el owner con datos de aparato.

### Lo que salió de camino y NO se tocó

Cuatro hallazgos reales de la review, fuera del alcance de este ticket, con ticket propio:
`panel-no-recalcula-al-llegar-tasas-nuevas`, `reparacion-de-tasas-no-avisa-al-panel`,
`hoja-del-saldo-vivo-ignora-los-filtros-de-sesion` y `widget-de-tc-no-localiza-separadores`.

## Referencias

- Spec base que habilita: [[rvw_live-balance-multi-currency-fix]]
- Anexo B del plan (filosofía coexistencia honesta): `~/.claude/plans/crea-el-spec-y-reactive-cloud.md`

migrated from YalaWiki Ideas/idea-fx-pnl-card.md @ 1934e8ad

---

## QA Visual · 2026-09-08

**Veredicto: PASS**, y con una corrección de fondo: **la premisa de que esto no se podía ver en
simulador era falsa.**

iPhone 17 Pro (iOS 26.5), `Yala Dev`, seed **`minimal`**
(`-uitest -uitest-reset -uitest-skip-onboarding -uitest-pro -uitest-seed minimal`). La card salió
en el Panel sin hacer nada especial.

### La premisa que se cae

El ticket decía: *«Ningún seed de UI test la produce (son PEN), así que la card no aparece en
XCUITest y su cobertura de UI es cero por construcción.»* **Medido: es falso.**
`DevSeedAccounts.swift:22-36` crea la cuenta principal en PEN **y una de ahorros en USD** con saldo,
y `DevSeedExchangeRates` siembra el histórico de tasas con deriva. Eso basta para que el FIFO
encuentre lotes vivos y la card se pinte. Su cobertura de UI **no** es cero por construcción: era
cero porque nadie la había mirado.

### Lo que se vio

**La card en el Panel** (`panel_fx_pnl_card`):

> **Pérdida por tipo de cambio** — ≈ S/ **-80,00**
> «Tus dólares valen hoy un 1.1% menos que cuando entraron a tu cuenta.»

- **El titular casa con el signo**: número negativo, titular «Pérdida». No hay desajuste.
- **No se pinta en rojo**, que era el requisito explícito: la card usa el tono neutro del tema y
  una flecha ↘. El verde queda reservado para la ganancia, como pedía el ticket.

**La hoja de detalle**, con la fila por divisa y sus cuatro columnas:

| Divisa | Saldo nativo | TC entrada · TC hoy | Valor hoy | P&L parcial |
|---|---|---|---|---|
| **USD** | $ 2.000,00 | «Entró a **3.70** · hoy a **3.66**» | = S/ 7.320,00 | ≈ S/ **-80,00** |

Más el total («En total ≈ S/ -80,00»), el texto educativo que explica de dónde sale el número, y dos
notas honestas: que el TC de entrada es **un promedio** de todos los movimientos en esa moneda, y
que «alguna conversión usó un tipo de cambio que no era el de hoy, así que estas cifras son
aproximadas» — que es el porqué del «≈».

### La aritmética cierra sola

```
2.000 × 3,70 = 7.400,00   ← lo que valía al entrar
2.000 × 3,66 = 7.320,00   ← «= S/ 7.320,00» en pantalla ✓
       diferencia = −80,00 ← «≈ S/ −80,00» ✓
       80 / 7.400 = 1,08 % → «1.1% menos» ✓
```

Los cuatro números de la fila son consistentes entre sí y con el titular. Y el TC de 3,66 es el
mismo que se dedujo por separado en el QA de `groups-budget` (2.584,20 − 1.230 = 1.354,20 sobre
$370 → 3,66), o sea que dos pantallas distintas están leyendo la misma tabla de tasas.

### Captura

- `qa-fx-pnl-01-hoja-detalle-por-divisa-20260908-212514.png`

### Lo que NO se vio

- **El caso de GANANCIA**, y con él el verde `#0F7A80`. Este corpus da pérdida. Para verlo hace
  falta un corpus donde la divisa se haya apreciado — probablemente `-uitest-seed pesado`, con
  10 años de deriva, o repetir hasta que el random-walk caiga del otro lado.
- El umbral del 0,5 % por debajo del cual la card **no** debe aparecer.
