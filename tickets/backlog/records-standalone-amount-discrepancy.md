---
id: records-standalone-amount-discrepancy
status: backlog
priority: medium
area: calculos
created: 2026-04-30
updated: 2026-09-02
source: YalaWiki/Backlog/p20-13_records-standalone-discrepancy.md
---

# Los totales de ingresos y gastos no cuadran entre pantallas para el mismo período

## Qué ve el usuario

Con el filtro global «Este mes» y sin filtros adicionales, el usuario abre cuatro sitios de la app
y lee cuatro pares de cifras distintos para el mismo mes. Caso reportado el 2026-04-30:

| Dónde mira | Ingresos | Gastos |
|---|---|---|
| Hero del Panel (chip/KPI) | 11356 | 7542 |
| Widget Flujo de caja | 11356 | 7063 |
| Resumen de Insights | 11356 | 7063 |
| **Registros** (pestaña de Estadísticas y pantalla propia desde «Más») | **11596** (+240) | **7303** (+240) |

La pista central es que Registros sube **+240 en los dos lados a la vez**. Eso no es una compra
que aparece de más en un sitio (eso movería un solo lado): es un movimiento que una pantalla
cuenta como ingreso y otra como gasto. Con un movimiento de 240 clasificado al revés, el ingreso
sube 240 de un lado y el gasto sube 240 del otro — exactamente lo reportado.

El desajuste del hero (+479 en gastos) lo cubrió p20-12, ya cerrado. Este ticket es el resto.

**No es «la pantalla de Registros»**: la cifra sale de `RecordsViewModel.calculateSummary()`, que
alimenta el mismo cabecero en la pestaña «Registros» de Estadísticas y en la pantalla suelta.
Cualquier sitio que muestre ese cabecero enseña la misma cifra.

## Estado a 2026-09-02

Medido en el árbol de hoy (HEAD `553b91c9`, rama `2.1`), no leído de la sesión anterior:

- **Registros (fase 1, 2026-07-05) — HECHO.** `RecordsViewModel.calculateSummary()` usa hoy el
  helper canónico (`Yala/App/ViewModels/RecordsViewModel.swift:316`, dentro de la función que
  empieza en `:297`) y acumula con signo (`:316-320`).
- **Tendencias, Estadísticas y Reportes (fase 2, 2026-07-05, commit `8347a776`) — HECHO
  TAMBIÉN.** Lo comprobé fichero por fichero; ver §«Corrección al parte de la fase 1» abajo.
- **Sigue vivo**: dos residuales declarados (§Residuales), la convención para movimientos sin
  categoría (§Las cuatro respuestas) y el calendario de Registros, que ya tiene ticket propio →
  `tickets/backlog/registros-calendario-cuenta-gastos-por-signo.md`.

El ticket se queda **en backlog** por esos cuatro frentes, no por la fase 2.

## Causa raíz

Dos formas de decidir si un movimiento es ingreso o gasto conviven en el código:

- **Por categoría** — manda `category.isIncome`.
- **Por el signo del importe** — manda que `amount` sea positivo o negativo.

Mientras signo y categoría concuerdan (el caso normal) las dos dan lo mismo. Cuando **no**
concuerdan —y hay maneras cotidianas de que no concuerden, ver §Cómo se desincronizan— cada
pantalla contesta lo suyo y el usuario ve cifras que no cuadran.

### La regla canónica ya existe en el código

`Yala/App/Logic/TransactionClassificationLogic.swift:27-29`:
```swift
static func isIncome(_ tx: TransactionItem) -> Bool {
    tx.category?.isIncome ?? (tx.amountInPreferredCurrency >= 0)
}
```
La categoría decide; el signo es el fallback **solo** cuando no hay categoría. No es «ambos
pesan igual» ni «el signo gana»: es un `??`, precedencia estricta. La misma regla, escrita a mano
antes de que existiera el helper, vive en `TransactionDetailSheetLogic.swift:37-40`,
`RecordRowView.swift:246-248`, `RecentRecordsWidget.swift:213`, `GlobalSearchView.swift:408` y
`BalanceHelper.swift:61`.

El flujo normal de creación la respeta: al elegir subcategoría, el tipo (y con él el signo) se
deriva de la categoría (`NewTransactionViewModel.swift:362-366`), y el importe final se firma
desde ese tipo (`:602`, con `TransactionFormModels.swift:49`). Las transferencias tampoco son la
causa: sus dos patas llevan `balanceAdjustmentType = adjustmentTypeTransfer`
(`NewTransactionViewModel.swift:733,748,765,781`) y quedan excluidas por igual en todos los
calculadores. Igual el ajuste de saldo inicial (`InitialBalanceService.swift:125,163`), que sí
puede tener signo contrario a su categoría («Ajuste de saldo» vive bajo «Otros», `isIncome:false`,
con importe positivo o negativo según `:141`) pero está excluido por el mismo guard.

### Cómo se desincronizan signo y categoría

**Importar un CSV/XLSX en modo «solo categorías existentes».** El signo sale del archivo
(`TransactionCSVImportService.swift:468`, y el mismo patrón repetido en `:706` y `:1326`) y la
categoría se busca **solo por nombre**, sin comprobar que su `isIncome` case con ese signo
(`:498-505`, `:731-734`, `:1353-1356`). Los dos viajan por separado en el borrador (`:539`,
`:757`, `:1379`) y se materializan juntos sin reconciliar (`:188`, `:1104`, `:1495`, `:1652`).
En modo «crear categorías nuevas» pasa igual: `CategoryImportHelper.fetchOrCreateCategory`
(`CategoryImportHelper.swift:36`) reutiliza cualquier categoría homónima sin mirar `isIncome`, y
el comentario de `:45-47` lo declara intencional (para que «Otros» sirva a transferencias). El
efecto colateral alcanza a categorías normales homónimas, no solo a «Otros».

**Cambiar la subcategoría de varios movimientos a la vez.** `RecordsViewModel.bulkUpdateSubcategory`
(`:533-551`) reasigna `subcategory` y `category` (`:540-541`) y **nunca toca el importe**. Si el
usuario selecciona gastos y los reasigna a una subcategoría de ingreso, quedan con el signo
contrario a su categoría. Su gemela `bulkUpdateAmount` (`:666-696`) hace lo inverso: conserva el
signo previo (`:679`) y no toca la categoría. En todo el código de edición masiva no hay ningún
punto que valide la coherencia signo↔categoría después de editar.

## Alcance: dónde se clasifica ingreso/gasto

> **Este mapeo NO es exhaustivo, aunque una versión anterior de este ticket dijo que sí.** El
> barrido del 2026-07-01 se presentó como «mapeo exhaustivo de todo el codebase» y se le escapó
> `Yala/App/Logic/Calculators/DailySpendingCalculator.swift`, que clasifica por signo puro
> (`:46-47`: `if amount < 0 { dayExpense += abs(amount) }`) y alimenta el calendario de Registros
> vía `RecordsCalendarView.swift:61`. No es un fichero nuevo: existe desde el 2026-05-31 (commit
> `18878f74`), **un mes antes** del barrido, y no aparece en ninguna fila de la tabla. Su propio
> comentario de cabecera (`:12-17`) dice que replica `RecordsViewModel.calculateSummary` — lo cual
> dejó de ser cierto el 2026-07-05, cuando ese resumen pasó a clasificar por categoría, y el
> comentario nunca se corrigió. Tampoco figura en los `codeGlobs` del área
> `income-expense-classification-parity` de `qa/coverage-index.json` (`:1288` y siguientes), así
> que el ratchet no lo cubría.
>
> Segundo despiste medido, cosmético: `InboxView.swift:907` pasa `isExpense: amount < 0` al aviso
> de confirmación teniendo la categoría a mano dos líneas antes (`:905-906`); solo pinta un color
> (`InboxApproveSuccessView.swift:43`), pero tampoco está en la tabla.
>
> **Moraleja operativa: no des la tabla por cerrada.** Antes de reusarla, rehaz el barrido —
> `grep -rn --include='*.swift' "isIncome" Yala` da hoy 319 aciertos en 83 ficheros — y busca
> aparte las clasificaciones por signo, que no contienen la palabra `isIncome` y por eso se
> escapan del grep obvio.

Todas las coordenadas de esta tabla las medí en el árbol de hoy.

| Dónde | Cómo clasifica | Qué pantalla |
|---|---|---|
| `TransactionClassificationLogic.swift:27-29` | **Canónica**: categoría, y signo solo si no hay categoría | Helper compartido |
| `RecordsViewModel.swift:316` (función desde `:297`) | Canónica (helper) + acumulación con signo `:316-320` | Cabecero de Registros — pestaña de Estadísticas y pantalla suelta |
| `TrendDataProcessor.swift:97` (total), `:185` (curva ingresos), `:199` (curva gastos) | Canónica (helper) | Pestaña Tendencias y widget de tendencia del Panel (`PanelViewModel.swift:1177`, `:2675`, `:2687`; `TrendsTabView.swift:1668`, `:1711`) |
| `StatisticsViewModel.swift:544,551` (totales), `:574,578` (lista de recientes), `:670,679` (curva por cuenta) | Canónica (helper) | Estadísticas |
| `ReportNotificationService.swift:310` (totales y aviso de «hubo actividad», `:312,315`) | Canónica (helper) | Reportes automáticos por notificación |
| `TransactionDetailSheetLogic.swift:37-40`; `RecordRowView.swift:246-248`; `RecentRecordsWidget.swift:213`; `GlobalSearchView.swift:408`; `BalanceHelper.swift:61` | Canónica, escrita a mano (5 copias) | Detalle de un movimiento, color de la fila, widget de últimos registros, búsqueda global, saldos |
| `HeroBucketsCalculator.swift:73-74,77` | Categoría con `== true` (sin categoría ⇒ **gasto**), magnitud absoluta | Hero del Panel |
| `CashFlowCalculator.swift:55` (guard), `:82,89` | Categoría; **excluye** los que no tienen categoría | Widget Flujo de caja (`PanelViewModel.swift:1864-1872`, previo en `:1893`) |
| `InsightsCalculator.swift:512,624,689` | Categoría, excluye sin categoría | Resumen de Insights, presupuestos en riesgo, distribución por Necesidad |
| `SankeyFlowCalculator.swift:68,79` | Categoría, excluye sin categoría | Diagrama Sankey (Distribución) |
| `TopSpendingCategoriesCalculator.swift:43`; `TopSubcategoriesCalculator.swift:52`; `TagSpendingCalculator.swift:40`; `WeekdaySpendingCalculator.swift:62` | Categoría, excluye sin categoría | Gráficos de Categorías / Subcategorías / Etiquetas / gasto por día de la semana |
| `PanelViewModel.swift:1045` y `:3042` (gasto por cuenta), `:1678` (naturaleza), `:2301` (presupuestos) | Categoría con `== false`, excluye sin categoría | Panel |
| `PanelViewModel.swift:1916` | Categoría con `!= true` (sin categoría ⇒ **pasa como gasto**) | Modo solo-gastos |
| `BudgetsViewModel.swift:608` | Categoría, excluye sin categoría | Presupuestos (y `BudgetAlertService`, que delega aquí) |
| `FilterService.swift:255,257` (filtro de tipo) y `:268,270` (chips de naturaleza) | Categoría; sin categoría **no pasa ninguno de los dos** | Filtro de Registros y de Categorías/Reporte/Sankey |
| `WidgetDataCache.swift:532-533` | Categoría con `?? false` (sin categoría ⇒ gasto) | Widgets de pantalla de inicio |
| `PivotTableCalculator.swift:185` (dimensión «Tipo») | Categoría, fallback al signo con `>` sobre `tx.amount` | Tabla dinámica del Informe |
| `PivotTableCalculator.swift:195,202,225` (dimensiones «Categoría», «Subcategoría», «Cuenta») | Categoría con `?? false` — **fallback distinto, en el mismo fichero** | Mismo Informe |
| `FinancialScoreCalculator.swift:500`; `ScheduledPaymentsViewModel.swift:552` | Categoría con `?? false` | Salud financiera, pagos programados |
| **`DailySpendingCalculator.swift:46-47`** | **Signo puro — único superviviente medido** | **Calendario de Registros** (`RecordsCalendarView.swift:61`) → ticket propio |
| `RecordsViewModel.swift:736` (dentro de `:731-743`) | Categoría | Detecta si la selección es de ingresos, de gastos o mixta antes de una edición masiva |

`FinancialScoreCalculator` y `ScheduledPaymentsViewModel` clasifican además por
`ScheduledPayment.transactionType` (un enum de texto propio de los pagos programados) en otros
sitios: es otra fuente de verdad, sobre otro modelo, y no entra en esta comparación.

### Corrección al parte de la fase 1

El parte de la fase 1 decía que `TrendDataProcessor` y `ReportNotificationService` «se
revirtieron» y quedaban para una fase 2. **Eso ya no describe el árbol.** La fase 2 se hizo el
**2026-07-05**, commit `8347a776` («fix(stats): clasificar income/expense por categoría en
Tendencias, Estadísticas y Reportes»), y hoy:

- `TrendDataProcessor.swift:97` clasifica con el helper para el total, y `:185`/`:199` para la
  curva de ingresos y la de gastos — total y curva juntos, que era justo la objeción que frenó la
  fase 1.
- `StatisticsViewModel.swift:544,551` (totales), `:574,578` (lista de recientes) y `:670,679`
  (curva por cuenta) usan el helper.
- `ReportNotificationService.swift:310` clasifica con el helper, y el aviso de «hubo actividad»
  (`:312,315`) cuelga de la misma decisión, no de un chequeo aparte.

Consta en `qa/coverage-index.json` (área `income-expense-classification-parity`,
`lastVerified: 2026-07-11`) una verificación en dispositivo de la fase 2 sobre TestFlight 2.0.5
b2 — curva de gasto negativa con un reembolso real importado por CSV, coherencia entre
Tendencias, Estadísticas y Registros, y el aviso de actividad.

Lo que **no** consta y sigue sin hacerse: comprobar si el caso concreto del reporte (+240) se ve
también en Tendencias en los datos de esa persona. No hay consulta ejecutada ni telemetría; la
causa raíz explica el mecanismo, identificar los movimientos exactos requiere mirar sus datos.

## Las cuatro respuestas para un movimiento sin categoría

Esto **nunca se unificó**, y es la forma exacta del síntoma original repetida un piso más abajo:
un solo movimiento, cuatro pantallas, cuatro respuestas. La fase 1 eligió el fallback al signo
para el helper y lo dejó documentado, pero **solo lo aplicó a sus cuatro consumidores**; el resto
del código siguió con lo suyo.

Caso concreto para leer la lista: un movimiento **sin categoría**, sin `balanceAdjustmentType`,
en una cuenta que sí cuenta para estadísticas, importe **+100**, dentro del período.

**1. Es un ingreso de 100.** `TransactionClassificationLogic.swift:28` cae al signo y `+100 >= 0`.
Lo aplican el cabecero de Registros (`RecordsViewModel.swift:316`), los totales y las curvas de
Tendencias (`TrendDataProcessor.swift:97,185`), Estadísticas
(`StatisticsViewModel.swift:544,574,670`) y los reportes automáticos
(`ReportNotificationService.swift:310`). La fila lo pinta como ingreso
(`RecordRowView.swift:247`), igual el detalle (`TransactionDetailSheetLogic.swift:39`), el widget
de últimos registros (`RecentRecordsWidget.swift:213`), la búsqueda global
(`GlobalSearchView.swift:408`) y la dimensión «Tipo» del Informe (`PivotTableCalculator.swift:185`).

**2. Es un gasto de 100.** El hero del Panel lo suma a gastos: `HeroBucketsCalculator.swift:74`
usa `== true`, que sin categoría da `false`, y `:77` acumula la magnitud. Las dimensiones
«Categoría», «Subcategoría» y «Cuenta» del **mismo Informe** hacen lo mismo con `?? false`
(`PivotTableCalculator.swift:195,202,225`), igual que los widgets de pantalla de inicio
(`WidgetDataCache.swift:533`), la salud financiera (`FinancialScoreCalculator.swift:500`) y los
pagos programados (`ScheduledPaymentsViewModel.swift:552`). En modo solo-gastos también pasa como
gasto (`PanelViewModel.swift:1916`, `!= true`).

**3. No existe.** El widget Flujo de caja lo descarta con un guard antes de mirar nada
(`CashFlowCalculator.swift:55`). Igual Insights (`InsightsCalculator.swift:512,624,689`), el
Sankey (`SankeyFlowCalculator.swift:68`), el gasto por día de la semana
(`WeekdaySpendingCalculator.swift:62`), los gráficos de categorías, subcategorías y etiquetas
(`TopSpendingCategoriesCalculator.swift:43`, `TopSubcategoriesCalculator.swift:52`,
`TagSpendingCalculator.swift:40`), los presupuestos (`BudgetsViewModel.swift:608`,
`PanelViewModel.swift:2301`) y el gasto por cuenta (`PanelViewModel.swift:1045,3042`).

**4. Desaparece de la lista.** Si el usuario toca el chip «Ingresos» o el chip «Gastos» para
filtrar, el movimiento no pasa ninguno de los dos (`FilterService.swift:268,270`; lo mismo el
filtro de tipo en `:255,257`). Es decir: existe en la lista sin filtro, y se esfuma en cuanto se
filtra por naturaleza — sin que ningún filtro diga que lo está escondiendo.

Dos matices medidos, por si alguien los toma por una quinta respuesta y no lo son:

- El calendario (`DailySpendingCalculator.swift:46`) clasifica por signo puro, así que para este
  huérfano positivo coincide con la respuesta 1 (no lo cuenta como gasto). Su divergencia es
  otra: la de un movimiento **con** categoría cuyo importe la contradice. Va en su propio ticket.
- La respuesta 1 no es una sola implementación. El helper mira `amountInPreferredCurrency` con
  `>= 0`; `PivotTableCalculator.swift:185` mira `tx.amount` con `> 0`; `RecordRowView.swift:247` y
  `BalanceHelper.swift:61` miran `tx.amount` con `>= 0`. Para un importe exactamente 0 el helper
  dice ingreso y el Informe dice gasto.

Decidir **una** convención (fallback al signo, o excluir) y aplicarla en todos los sitios es lo
que cierra este frente. Mientras no se decida, cualquier pantalla nueva elegirá la suya.

## Residuales abiertos

Los dos que declaró la fase 1 **siguen vivos**, verificados hoy:

**1. El formulario de edición prefilla el tipo con `||` en vez de la regla canónica.**
`Yala/App/Views/Transactions/NewTransactionView.swift:1497`:
```swift
if tx.subcategory?.safeCategory.isIncome == true || tx.amount > 0 {
```
Con un `||`, un movimiento de categoría de gasto pero importe positivo prefilla **Ingreso** — la
dirección contraria a «la categoría manda». No afecta a ningún total: es solo el estado inicial
del formulario, pero al abrir para editar un movimiento ya descuadrado el usuario ve un tipo que
no es el de su categoría. (La coordenada de este residual había derivado: el ticket citaba
`:1387`.)

**2. El mismo Informe usa dos fallbacks distintos.** `PivotTableCalculator.swift:185` cae al signo
para la dimensión «Tipo»; `:195`, `:202` y `:225` dicen siempre gasto para «Categoría»,
«Subcategoría» y «Cuenta». Para un movimiento sin categoría, cambiar de dimensión en el mismo
informe lo mueve de lado. (Coordenadas anteriores del ticket: `:173` y `:183,190,213`.)

**3. Nuevo, con ticket propio: el calendario de Registros.** Clasifica por signo puro y no cuadra
con el chip de gasto que tiene justo encima, en la misma pantalla →
`tickets/backlog/registros-calendario-cuenta-gastos-por-signo.md`.

## Riesgos al cerrar lo que queda

- **Unificar la convención de «sin categoría» cambia cifras visibles.** Si se elige el fallback al
  signo, las pantallas de la respuesta 3 empezarán a contar movimientos que hoy ignoran; si se
  elige excluir, el cabecero de Registros, Tendencias, Estadísticas y los reportes automáticos
  dejarán de contar movimientos que hoy suman. Antes de decidir conviene medir cuántos movimientos
  sin categoría y sin `balanceAdjustmentType` existen de verdad.
- **El neto no se mueve, el desglose sí.** Reclasificar redistribuye entre ingreso y gasto sin
  tocar `ingresos − gastos`. Es la frase útil si el usuario pregunta por qué cambió el número.
- **Los reportes automáticos cambian retroactivamente.** Al recalcularse en el próximo envío,
  quien reciba reportes por notificación verá cifras distintas de las del mes pasado.
- **No hay test que fije la convención de «sin categoría».** `TransactionClassificationLogicTests`
  cubre el helper, pero la divergencia vive en los sitios que **no** lo usan
  (`PivotTableCalculator`, `HeroBucketsCalculator`, `WidgetDataCache`, `FilterService`), y el área
  `income-expense-classification-parity` de `qa/coverage-index.json` no los lista en sus
  `codeGlobs` — tampoco a `DailySpendingCalculator`. Cualquier fix debería ampliar esos globs, o
  el ratchet seguirá sin ver el siguiente despiste.

## Acceptance Criteria

Hechos y medidos en el árbol de hoy:

- [x] El cabecero de Registros clasifica por categoría (`RecordsViewModel.swift:316`) — fase 1,
      2026-07-05.
- [x] Tendencias, Estadísticas y los reportes automáticos clasifican por categoría, con el total y
      la curva/lista/aviso de actividad migrados juntos (`TrendDataProcessor.swift:97,185,199`;
      `StatisticsViewModel.swift:544,551,574,578,670,679`; `ReportNotificationService.swift:310`)
      — fase 2, commit `8347a776`, 2026-07-05.
- [x] Existe el helper compartido `TransactionClassificationLogic.swift:27-29` y lo consumen esos
      cuatro sitios.

Pendiente:

- [ ] Decidir **una** convención para los movimientos sin categoría —fallback al signo o
      exclusión— y aplicarla en los sitios de la §Las cuatro respuestas, no solo en los cuatro
      consumidores del helper. Anotarla en `.claude/rules/` para que la próxima pantalla no
      invente la suya.
- [ ] Alinear el residual 1: el `||` de `NewTransactionView.swift:1497` debe seguir la regla
      canónica (`??`).
- [ ] Alinear el residual 2: un solo fallback dentro de `PivotTableCalculator` (`:185` vs
      `:195,202,225`).
- [ ] Corregir el comentario de cabecera de `DailySpendingCalculator.swift:12-17`, que afirma
      replicar un criterio que `RecordsViewModel.calculateSummary` ya no usa (lo arregla el ticket
      del calendario, pero si ese se cierra sin tocarlo, queda aquí).
- [ ] Test de regresión con un conjunto fijo que incluya (a) un movimiento con signo contrario a
      su categoría y (b) un movimiento sin categoría: cabecero de Registros, total de Tendencias,
      Informe y widget Flujo de caja deben coincidir al primer decimal en al menos tres períodos
      (Este mes, Última semana, Este año).
- [ ] Test explícito de la invariante: `ingresos − gastos` no cambia al reclasificar.
- [ ] Ampliar los `codeGlobs` del área `income-expense-classification-parity` en
      `qa/coverage-index.json` para incluir los sitios que hoy quedan fuera del ratchet
      (`DailySpendingCalculator`, `PivotTableCalculator`, `HeroBucketsCalculator`,
      `WidgetDataCache`, `FilterService`).
- [ ] Comprobar si el caso concreto del reporte (+240, 2026-04-30) también se ve en Tendencias en
      los datos de esa persona — sigue sin ejecutarse.
- [ ] QA en dispositivo del frente que quede tras la decisión de convención.

migrado desde YalaWiki Backlog/p20-13_records-standalone-discrepancy.md @ 1934e8ad
