---
id: panel-colapsa-la-seleccion-de-cuentas-a-la-primera
status: done
priority: medium
area: panel
created: 2026-09-06
updated: 2026-09-16
source: hallazgo de la review adversarial de distribution-balance-kpi-skips-fx
qa-status: passed
qa-date: 2026-09-16
---

# Con dos o más cuentas filtradas, el Panel solo mira la primera

## Qué pasa

El filtro de cuentas es un **conjunto** (`SessionState.selectedAccountIDs`) y la barra de filtros lo
pinta con su cuenta («2 cuentas»). Estadísticas lo respeta entero
(`StatisticsViewModel.computeEligibleAccounts:517-527`). El Panel, en cambio, lo colapsa a su primer
elemento:

```swift
// PanelViewModel.swift:291
var selectedAccountID: PersistentIdentifier? { SessionState.shared.selectedAccountIDs.first }
```

y lo consume en `computeEligibleAccounts` (`:1392`) y en `displayedBalanceInDefaultCurrency`
(`:1056`). O sea: seleccionas A y B, el Panel te enseña solo A — y `.first` sobre un `Set` **no es
estable**, así que ni siquiera es "la primera que tocaste".

## Cómo se llega

No es un estado exótico. `SessionState.toggleAccountFilter` es single-select, pero **no es el único
escritor**: `RecordsFiltersView.accountChip` hace `insert` sin `removeAll` (`:183-191`) y
`commitToViewModel` lo vuelca a la misma clave global (`:677`); y `SessionState.applyBudgetFilters`
escribe el conjunto entero resuelto del presupuesto (`:743`). Tres toques desde Registros → Filtros.

## Por qué sale ahora

Al cerrar `distribution-balance-kpi-skips-fx` (KPI de Balance de Distribución == el del Panel), esta
asimetría se convirtió en la única vía conocida por la que esos dos números pueden seguir sin
cuadrar: con cuentas A=10.000 y B=5.000 seleccionadas, el Panel diría 10.000 y Distribución 15.000.
Queda documentado como límite conocido en aquel ticket y en su PR, sin corregir, porque la decisión
del owner del 2026-08-26 fue **no tocar Panel**.

## Qué hay que decidir antes de arreglarlo

Cuál de los dos comportamientos es el correcto. Si el Panel debe respetar el conjunto, el cambio no
es solo `computeEligibleAccounts`: `displayedBalanceInDefaultCurrency` pasa `selectedAccountID` a
`LiveBalanceCalculator`, que tiene su propia rama de cuenta única con fallback al total
(`LiveBalanceCalculator.swift:66-77`), y `PanelTotalAccountsLogic.accountsForTotal` decide con
`hasSelectedAccount` (`:18-25`). Son cuatro sitios que asumen «una o ninguna».

## Decisión Jürgen (2026-09-06)

**El Panel respeta el conjunto de cuentas, como Estadísticas.** Elegida entre eso y «el Panel es de
una cuenta y con varias muestra el total». Motivo, tal como se le puso delante y ratificó: la barra de filtros dice «2 cuentas» y Distribución ya
suma las dos; que el Panel enseñe una —y no se sepa cuál— es el único camino conocido por el que los
dos saldos siguen sin cuadrar tras `distribution-balance-kpi-skips-fx`. Toca los cuatro sitios que
asumen «una o ninguna» (`selectedAccountID`, `computeEligibleAccounts`,
`displayedBalanceInDefaultCurrency` → `LiveBalanceCalculator`, `PanelTotalAccountsLogic`).

## Acceptance Criteria

- [x] Con dos cuentas seleccionadas, Panel y Estadísticas muestran el mismo saldo.
- [x] El toggle `includeGroupsInPanelTotal` sigue aplicando solo al total agregado.
- [x] Unit que fije el caso de dos cuentas en los dos caminos.
- [ ] Device-QA: seleccionar dos cuentas desde Registros → Filtros y comparar Panel vs Distribución.

---

## Implementación (2026-09-07)

### Lo que se re-midió antes de tocar nada

El ticket es del 6-sep y trae coordenadas. **Ninguna de las rutas del ticket existía**: cita
`PanelViewModel.swift`, `LiveBalanceCalculator.swift` y `PanelTotalAccountsLogic.swift` sin su
carpeta real (`Yala/App/ViewModels/`, `Yala/App/Logic/Calculators/`, `Yala/App/Logic/`). Las líneas
también habían corrido: `selectedAccountID` estaba citado en `:291` y vive en `:300`;
`computeEligibleAccounts` en `:1392` → `:1412`; `displayedBalanceInDefaultCurrency` en `:1056` →
`:1064`.

**Y «los cuatro sitios» eran más de cuatro.** El grep de `selectedAccountID` devuelve consumidores
que el ticket no nombra, en tres vistas del propio Panel: `AccountsCarouselView`,
`PanelFilterControlBar` y `PanelPanoramaSection`.

### El defecto que no estaba en el ticket

`displayedBalanceInDefaultCurrency` pasaba `selectedAccountID` a `LiveBalanceCalculator`, **que no
conoce `isExcludeMode`**. Y el modo excluir sí llega al conjunto de cuentas:
`RecordsFiltersView.commitToViewModel` escribe `isExcludeMode` y el conjunto en el mismo gesto
(`:672-677`).

Consecuencia medida por lectura: con «excluir» activo y la cuenta A marcada, el saldo grande del
Panel mostraba **el saldo de A** — exactamente lo contrario de lo que pedía el filtro. Entra aquí y
no en un ticket aparte porque el AC 1 (Panel == Estadísticas) es falso mientras ese camino exista:
Estadísticas resuelve el modo y el Panel no.

### Qué cambia para quien usa la app

- Con dos cuentas filtradas, **el saldo del Panel suma las dos**. Antes enseñaba una, y cuál no era
  predecible (`Set.first` no es estable).
- Con «excluir» activo, el saldo **descuenta** las cuentas marcadas en vez de mostrarlas.
- El **carrusel marca las N tarjetas** filtradas, no una.
- El **chip de filtro dice «2 seleccionadas»** en vez del nombre de una cuenta arbitraria.
- El tap de una tarjeta del carrusel sigue siendo «filtrar por esta cuenta», y ahora es
  determinista: antes, con dos cuentas filtradas, tocar una podía limpiar el filtro entero o
  reducirlo a esa, según qué elemento devolviera `Set.first`.

### Ficheros

| Fichero | Cambio |
|---|---|
| `Yala/App/Logic/Calculators/LiveBalanceCalculator.swift` | `selectedAccountID?` → `selectedAccountIDs: Set` + `isExcludeMode`; elegibilidad por intersección / sustracción |
| `Yala/App/ViewModels/PanelViewModel.swift` | `selectedAccountIDs` nuevo; `computeEligibleAccounts` espeja Estadísticas; el saldo pasa conjunto + modo |
| `Yala/App/Views/Panel/AccountsCarouselView.swift` | `isSelected` por `contains` |
| `Yala/App/Views/Panel/Components/PanelFilterControlBar.swift` | Chip con `L10n.Filters.selectedCount` cuando hay varias |
| `Yala/App/Views/Panel/Sections/PanelPanoramaSection.swift` | `hasSelectedAccount` desde `!isEmpty` |
| `.claude/rules/session-filters.md` | Regla durable (nueva) |

`PanelTotalAccountsLogic` gana `hasAccountFilter(selectedAccountIDs:isExcludeMode:)` — ver «Lo que
cazó la review». `accountsForTotal` no cambia.

L10n: **cero claves nuevas y cero ficheros de idioma tocados**. El chip reusa
`buildAccountChips` + `FilterChipView(accountName:count:)`, que ya construyen «BCP +1».

### Lo que se preservó a propósito

Cuando la selección no resuelve a ninguna cuenta contable (la única elegida está excluida de
estadísticas), el Panel sigue cayendo **al total agregado**. Es comportamiento heredado de
`BalanceHelper.displayedBalance` y está fijado por
`liveBalance_selectedAccountIDExcluded_fallsBackToTotal`. Estadísticas, en ese mismo caso, devuelve
0. **Es una divergencia viva** y cambiarla es una decisión de producto, no de este cambio →
`saldo-con-seleccion-no-contable-diverge-entre-panel-y-estadisticas`.

En modo excluir **no hay fallback**: excluir todas da 0, no el total. Un fallback ahí convertiría
«excluir» en «mostrar el total», que es peor que el bug original.

### Tests

`LiveBalanceCalculatorTests` (+5) y `BalanceKPIParityTests` (+3). Los dos tests que fijaban el
contrato de una sola cuenta se migraron y **siguen verdes**, que es lo que prueba que el caso de una
cuenta no cambió.

- `liveBalance_twoSelectedAccounts_sumsBoth` — 10.000 + 5.000 = 15.000, y ni 10.000 ni 5.000.
- `liveBalance_twoSelectedAccounts_excludeMode_returnsTheRest`
- `liveBalance_excludeMode_allAccountsExcluded_isZeroNotTotal`
- `liveBalance_twoSelected_oneExcludedFromStats_countsOnlyTheCountable`
- `liveBalance_breakdownWithTwoAccounts_keepsNativeBuckets` — `liveBalanceBreakdown` bajo selección
  de cuenta no lo fijaba ningún test; solo se cubría vía el wrapper `Double`.
- `twoSelectedAccounts_panelMatchesDistribution` — el AC 1. Los dos caminos son asimétricos a
  propósito: el Panel recibe todas las cuentas + el conjunto, Distribución las recibe ya filtradas.
- `twoExcludedAccounts_panelMatchesDistribution`
- `includeGroupsToggle_appliesOnlyToAggregateTotal` — el AC 2.

Medido, no leído del veredicto: **6280 tests en 637 suites, 0 fallos** (`-only-testing:YalaTests`,
`-parallel-testing-enabled NO`). Los 8 nuevos se comprobaron nombrados uno a uno en el log.

### Device-QA — sin esto no hay PASS

No se declara PASS: no hay números de aparato. Escenario, con **al menos tres cuentas con saldo
distinto y no cero** (dos para filtrar, una que debe quedar fuera):

1. Registros → **Filtros** → sección Cuentas → tocar **dos** cuentas (el chip permite varias).
   Aplicar.
2. **Panel**: el saldo grande debe ser la **suma de las dos**, no el de una. El carrusel debe
   marcar **las dos tarjetas**. El chip de filtro debe decir **«2 seleccionadas»**.
3. **Estadísticas → Distribución**, métrica Balance: el KPI debe ser **el mismo número** que el
   Panel. Éste es el AC 1 y el que cierra el hueco que dejó `distribution-balance-kpi-skips-fx`.
4. Repetir con el toggle **«excluir»** activo en Registros → Filtros: el saldo del Panel debe ser
   el de **las cuentas NO marcadas**. Antes mostraba el de una de las marcadas.
5. Ajustes → toggle **«incluir grupos en el total del Panel»** OFF: con el filtro de dos cuentas
   activo el saldo **no debe cambiar** (el toggle es solo del total agregado); al **quitar** el
   filtro, sí debe recortar las cuentas «Grupos [moneda]».
6. Anotar los números exactos de los pasos 2 y 3. Si no cuadran, **no cerrar**.

---

## Lo que cazó la review adversarial (y no los tests)

Dos lentes independientes sobre el diff. **Las dos coincidieron en el mismo defecto**, que era mío y
que la suite en verde no veía.

### El defecto: excluir una cuenta hacía SUBIR el saldo

Al generalizar el filtro pasé `hasSelectedAccount: !selectedAccountIDs.isEmpty`. En modo excluir eso
es `true`, así que `PanelTotalAccountsLogic` dejaba de aplicar el toggle
`includeGroupsInPanelTotal` — y las cuentas sistema «Grupos [moneda]» volvían al agregado, porque se
crean con `excludeFromStatistics: false` y sobreviven al `subtracting`.

Con `Normal` 1000, `Grupos PEN` 500, `Otra` 200 y el toggle OFF: sin filtro el Panel decía 1200;
**al excluir `Otra` (200) decía 1500**. Excluir una cuenta con saldo positivo subía el total 300.

Antes del cambio esta combinación no era observable —en modo excluir el saldo era el de la cuenta
excluida, roto de otra forma—, así que el camino es **nuevo y lo introduje yo**.

Causa de fondo: copié la regla `!isEmpty` en dos sitios en vez de nombrarla una vez. El arreglo la
pone en `PanelTotalAccountsLogic.hasAccountFilter`, que es donde ya vive la lógica del total, y sus
dos consumidores —el saldo y el conteo del panorama— la leen de ahí.

**Mi test nuevo no lo detectaba** (probaba `accountsForTotal` aislado, sin distinguir modo). El que
lo fija, `excludeMode_isAggregate_soGroupsToggleStillApplies`, se verificó **con un mutante**:
revertido el fix, falla con `balance → 1500.0` esperando 1000. Un test que no falla sin el arreglo no
protege nada.

### Otros dos que introduje, y su arreglo

- **El tap del carrusel en modo excluir invertía el filtro.** Tocar una tarjeta atenuada («excluida»)
  la convertía en la única incluida, apagaba el modo excluir por el `didSet` de `SessionState` y
  **se llevaba por delante otros chips** (naturaleza, por ejemplo). Antes pasaba ~la mitad de las
  veces por el `.first` inestable; al hacerlo determinista lo fijé al 100 %. Ahora en modo excluir el
  tap añade o quita de la lista de excluidas, que es lo que la tarjeta dice.
- **El chip se apartó del resto de la app.** Mi versión mostraba «2 seleccionadas» mientras Registros
  decía «BCP +1» para el mismo `SessionState`, y con un ID sin resolver llegaba a decir «1
  seleccionadas» sin nombre. Sustituido por `buildAccountChips`, el helper que ya usan Registros y
  los chips de categoría y tag del propio fichero: nombre estable —filtra un `[Account]` ordenado, no
  un `Set`— y `+N`.

### Lo que la review confirmó correcto

La equivalencia del cálculo con **una** cuenta en los cuatro casos (ID válido, excluido, inexistente,
conjunto vacío); que `computeEligibleAccounts` espeja a Estadísticas línea a línea y que ambos leen
el mismo almacén; que **ningún otro caller** de `liveBalance` cambia (los 5 de producción no pasan
filtro); y que la X del chip limpia el conjunto entero, no solo el primero.

### Lo que salió de camino y NO se tocó

Tres hallazgos preexistentes, con ticket propio:

- `panel-lee-el-filtro-de-cuentas-en-singular-fuera-del-saldo` — el subtítulo «en N cuentas» cuenta
  todas mientras el saldo filtra, y el prefill del formulario propone una cuenta arbitraria (en modo
  excluir, la excluida).
- `saldo-con-seleccion-no-contable-diverge-entre-panel-y-estadisticas` — con una cuenta excluida de
  estadísticas filtrada, el saldo grande muestra el total, los widgets 0 y el KPI 0: la pantalla se
  contradice. Incluye el ID fantasma que deja `EntityDeletionService` al borrar una cuenta.
- `filtro-de-cuentas-se-colapsa-al-navegar-a-registros` — `buildRecordsContext` colapsa cuentas,
  categorías y needs con `.first` al saltar de Estadísticas a Registros.

## QA Visual · 2026-09-16 — PASS

Simulador iPhone 17 Pro (iOS 26.5), sobre `2.1` @ `bebd57a57`, `Yala Dev`, seed `realista` + `-uitest-seed-group-bridge-fx JPY`. Cuentas del montaje: Ahorros
USD, Cuenta Principal, Grupos (JPY, de sistema, ≈ S/ 900) y QA FX Grupo (≈ S/ -1,050). Total ≈ S/ 69,780.45.

| Paso | Qué se vio |
|---|---|
| Filtro con **dos** cuentas incluidas (Ahorros USD y Cuenta Principal) | Panel «Tienes S/ 69,930.45» (= total − 900 + 1,050), carrusel con las dos marcadas, chip «Ahorros USD +1» |
| Distribución, mismo filtro | «Saldo de cuentas S/ 69,930.45», igual que el Panel |
| Toggle de grupos OFF, con el filtro | Sin cambio: Grupos ya estaba fuera |
| Toggle OFF, sin filtro | ≈ S/ 68,880.45 en 3 cuentas (−900) |
| **Excluir** esas dos + toggle OFF | ≈ S/ -1,050.00 |

La selección de dos cuentas ya no se queda en la primera: el Panel y Distribución suman las dos.

Capturas: [Panel](../../qa/evidencia-barrido-20260916/13-panel-dos-cuentas-suma-y-carrusel.jpg) · [Distribución](../../qa/evidencia-barrido-20260916/14-distribucion-saldo-cuentas-igual-panel.jpg) · [excluir](../../qa/evidencia-barrido-20260916/15-panel-excluir-dos-cuentas-toggle-off.jpg).

Visto de paso: con el filtro puesto, el panorama dice «en 4 cuentas». Ya tiene ticket:
`panel-lee-el-filtro-de-cuentas-en-singular-fuera-del-saldo`.
