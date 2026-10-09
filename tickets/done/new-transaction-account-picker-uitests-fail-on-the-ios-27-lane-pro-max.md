---
id: new-transaction-account-picker-uitests-fail-on-the-ios-27-lane-pro-max
status: done
priority: high
area: "qa, xcuitest, transactions"
created: 2026-10-02
updated: 2026-10-09
source: gate de list-column-too-narrow-for-accessibility-text-on-a-turned-pro-max (carril adaptativo)
---

# Tres XCUITest que eligen cuenta en «Nuevo registro» fallan siempre en el Pro Max del carril (iOS 27.0)

## Qué se ve

En `YalaLane-Adapt-iPhone-ProMax` (iOS 27.0), tres casos fallan **de forma estable, también aislados**:

| Caso | Mensaje |
|---|---|
| `TransactionsCrudUITests.test_createTransaction` | «No se montó AccountSelectorSheet con filas.» |
| `QuickActionsFavoritesUITests.test_saveAsFavoriteFromTransactionAppearsInList` | «No se montó AccountSelectorSheet con filas.» |
| `EdgeCasesUITests.test_extremeMinimumAmountSaves` | `Failed to tap Button (First Match)` … `identifier BEGINSWITH` |

El log de XCTest añade en los tres: **«Automation type mismatch: computed Button from legacy attributes vs PopUpButton
from modern attribute»**. Los tres entran por el FAB del Panel y eligen cuenta con
`app.buttons … identifier BEGINSWITH "account_selector_row_"`.

## No es del cambio que lo destapó

Medido el 2026-10-02 en el mismo simulador: **2.1 limpio (`7a9708657`) falla igual** en los tres, dos rondas
aisladas; la rama del PR, también dos rondas. `RemoteWipeNoticeRoutingUITests.test_notice_keepWaiting_leavesTheAppWhereItWas`
falló una vez en lote y pasó dos aislado: ése sí es inestable bajo carga, no de este grupo.

## Medido también en el iPhone 17 Pro del gate (2026-10-05)

`EdgeCasesUITests.test_extremeMinimumAmountSaves` falla igual en el `iPhone 17 Pro` de iOS 27.0 que usa el `/gate`
(`BD413F36`), con el mismo «Automation type mismatch … PopUpButton»: en lote y otra vez aislado, con el centinela en 0
(solo en el simulador). Sesión `fresh-start-drops-mirror-entries-of-another-identity-without-counting-them`, que no toca el
formulario de registro. Así que no es del Pro Max: es del runtime iOS 27.0.

## Y `test_createTransaction` también en el iPhone 17 Pro del gate (2026-10-08)

Sesión `late-icloud-wipe-stays-frozen-after-a-settled-failed-migration` (no toca el formulario de registro), simulador
`iPhone 17 Pro` iOS 27.0 `46287CFE`: «No se montó AccountSelectorSheet con filas.» en lote y dos veces aislado, centinela en
0. **El build de `2.1` sin el cambio de la sesión (`efb6ae72e`) falla igual**, aislado. El rojo del gate de esa sesión es
este ticket.

## Qué falta medir

- Si pasa en el `iPhone 17 Pro` del gate de siempre y en el runtime del CI: hoy solo está medido en el Pro Max de iOS 27.0.
- Qué elemento sale como `PopUpButton` (la fila o el chip de cuenta). Si es un `Menu`/`Picker` de SwiftUI que iOS 27
  expone con otro tipo, el arreglo es del test (`app.descendants(matching: .any)` por identificador), no del producto.

## Relacionados

[[transaction-save-helper-flake-one-per-suite]] · [[edgecases-extreme-minimum-flaky-under-load]] ·
[[list-column-too-narrow-for-accessibility-text-on-a-turned-pro-max]]

## 2026-10-05 · También en el iPhone 17 Pro del gate (iOS 27.0)

Medido en el gate de `groups-stuck-drain-on-a-healthy-phone-says-try-again-later` (árbol sobre `a7b37a5f2`, cuyo diff no toca
Panel, «Nuevo registro» ni los selectores): `EdgeCasesUITests.test_extremeMinimumAmountSaves` falla en lote y **aislado**, con
el mismo `Failed to tap Button … account_selector_row_` y el mismo «Automation type mismatch: computed Button from legacy
attributes vs PopUpButton». Así que no es del Pro Max: es del runtime iOS 27.0 (inferido de dos modelos, no de más).

## 2026-10-07 · Tercera sesión que lo ve, mismo runtime

Gate de `ai-every-call-sends-its-task-and-passes-the-bench` (árbol sobre `2890d1353`, sin cambios en Panel, «Nuevo
registro», selectores ni semilla), simulador `iPhone 17 Pro` de iOS 27.0: falla en lote (36 de 37 en verde) y otra vez
aislado, con el centinela en 0 y el mismo «Automation type mismatch … PopUpButton».

## 2026-10-08 (tarde) · otra vez en el gate, sobre `34f126415`

Sesión `wire-decoder-accepts-non-finite-money` (toca el apply del pull, no el formulario de registro), `iPhone 17 Pro`
iOS 27.0 `46287CFE`: `EdgeCasesUITests.test_extremeMinimumAmountSaves` falla en lote (con el centinela en 0) y aislado,
con el mismo `Failed to tap Button … account_selector_row_` y el «Automation type mismatch … PopUpButton». Los otros 9
casos de las tres suites del gate pasan.

## 2026-10-08 (mediodía) · los tres, bisecado contra el árbol base

Gate de `account-currency-change-leaves-scheduled-and-favorites-stale` (sobre `2ddb5d28e`), `iPhone 17 Pro` iOS 27.0
`46287CFE`, centinela en 0: fallan **los tres** (`test_extremeMinimumAmountSaves`, `test_createTransaction`,
`test_saveAsFavoriteFromTransactionAppearsInList`) con «No se montó AccountSelectorSheet con filas» / `account_selector_row_`
y el «Automation type mismatch … PopUpButton». Como ese diff toca `NewTransactionView`, se bisecó: con
`NewTransactionView.swift` y `NewTransactionViewModel.swift` devueltos a `HEAD`, los tres fallan igual. No es de esa rama.

## Otra vez en el gate de `inbox-dismiss-x-does-not-delete-the-draft-for-good` (2026-10-08)

`EdgeCasesUITests.test_extremeMinimumAmountSaves`, iPhone 17 Pro de iOS 27.0 (`46287CFE`), en lote de 10 suites (31
casos, 30 verdes), centinela en 0 (solo en el simulador), mismo «Automation type mismatch … PopUpButton». Ese cambio
no toca el formulario de registro.

Triage 2026-10-08: abierto · medium → high · lleva seis gates seguidos en rojo en iOS 27.0 con el árbol base; los tres tests siguen buscando `app.buttons` con `account_selector_row_` (`TransactionsCrudUITests.swift:61`) y la red del alta de un registro está ciega en el runtime del gate.

## 2026-10-08 (tarde) · otra vez en el gate del iPhone 17 Pro

Gate de `queued-offer-after-dismiss-flakes-on-a-cold-simulator` (el diff solo aplaza la liberación de la matriz del
shell; no toca el formulario de registro). `test_createTransaction`: «No se montó AccountSelectorSheet con filas.» en el
lote de 37 suites (126 casos, centinela en 0, 428 muestreos) y otra vez aislado sobre el mismo binario. Los otros 120
casos del lote, verdes. Mismo simulador (`46287CFE`) en el que la medición de la mañana vio fallar a 2.1 limpio.

## 2026-10-09 · otra vez en el gate, bisecado contra `4c973dd8a`

Gate de `after-session-redesign-review-widgets-siri-applepay-and-web-copy` (no toca «Nuevo registro» ni los selectores),
`iPhone 17 Pro` iOS 27.0 `46287CFE`: `test_extremeMinimumAmountSaves` y `test_createTransaction` fallan en lote con el
centinela en 0. **Un build de `2.1` sin el cambio (`4c973dd8a`) falla igual en los dos, aislado.**

## 2026-10-09 · Resuelto: el toque al chip se perdía mientras entraba el teclado (arreglo del test)

**Qué pasaba, medido** en el `iPhone 17 Pro` iOS 27.0 (`46287CFE`), con una sonda que vuelca el árbol y los marcos:
los tres tests teclean el monto y tocan el chip de cuenta acto seguido. En ese instante el teclado **sigue entrando**
(su marco estaba en y=891, fuera de la pantalla de 874) y el formulario aún no ha subido para dejarle sitio: el chip
está en y=716. XCUITest sintetiza el toque ahí; cuando llega, el formulario ya subió (chip en y=513) y el toque cae en
vacío. No corre ni el `dismissKeyboard()` de la acción del chip: el árbol del fallo trae el teclado arriba, el monto
con el foco y ninguna hoja. Un **segundo toque**, con todo quieto, abre la hoja con sus dos filas. Con una pausa
antes de tocar (la sonda que vuelca el árbol primero) pasa siempre; sin ella falla siempre.

**Lo que no era:** el aviso «Automation type mismatch … PopUpButton». Con la hoja abierta, las filas salen como
`Button` (`account_selector_row_Ahorros USD`, `…_Cuenta Principal`); el aviso lo da otro nodo al resolver la
consulta y no impide nada. Tampoco es del producto: a una persona el chip se le mueve solo mientras anima el teclado
y toca donde lo ve. Por qué solo en 27.0: el teclado tarda más en entrar que en 26.x (inferido; coherente con la regla
de `testing.md` de que 27.0 es ~2× más lento en el ciclo de UI) y `typeText` no espera a que termine.

**El arreglo** (`YalaUITests/Support/XCUIApplication+Yala.swift`): `openSelectorFirstRow(chip:rowPrefix:)` y
`chooseFirstSelectorRow(chip:rowPrefix:)`. Antes de tocar esperan a que el teclado acabe de moverse y el chip esté
quieto (`waitForSettledLayout`: dos lecturas seguidas con el mismo marco y el teclado dentro de la ventana), y buscan
la fila por identificador con `descendants(matching: .any)`. Si el chip queda fuera de la fila horizontal, la
desplazan antes (lo que pedía `record-selectors-uitest-taps-the-tags-chip-off-screen`). Las aserciones no bajan: el
chip tiene que existir y ser alcanzable, la fila tiene que montarse, y el resto de cada test sigue igual.

Lo usan las cuatro suites con el patrón `account_selector_row_`: `TransactionsCrudUITests` (`test_createTransaction`
y el bucle de `test_recordSelectorsOpenAtMediumDetent`), `QuickActionsFavoritesUITests`, `EdgeCasesUITests` y
`ChatMessagingLayoutUITests#test_draftDetails_opensSheet_withTheNewRecordAccountSelector`. En los tres flujos rojos
también la subcategoría, que va justo después en el mismo formulario.

**Verificado con mutantes** (activables por `TEST_RUNNER_…` en una build temporal, retirados): sin ninguna espera
antes del toque, `test_createTransaction` rojo; solo con `waitForSettledLayout`, verde 2 de 2, y sus lecturas la
ven trabajar (teclado con `maxY` 1118 y chip en 716, luego teclado en 816 y chip **todavía** en 716 una lectura más,
luego chip en 513). Por eso la guarda exige el chip quieto, no solo el teclado. Un tercer mutante, sin la espera de
asentamiento pero con el `waitForExistence` previo, también pasó: en iOS 27 esa llamada tarda ~1 s aunque el chip ya
exista, y ese segundo tapa la carrera por accidente. La guarda es la espera de asentamiento, no esa latencia.

**Runtime anterior:** en la Mini solo hay iOS 27.0 instalado; 26.x no se pudo medir aquí. La red de ese runtime es el
CI (Xcode 26.6).

**Verde, medido el 2026-10-09** sobre `82ab8d877` (tras el merge del PR #413), `iPhone 17 Pro` iOS 27.0 `46287CFE`, un
solo simulador, centinela «estuviste solo» en todas: las cuatro suites tocadas en lote (`TransactionsCrudUITests`,
`QuickActionsFavoritesUITests`, `EdgeCasesUITests`, `ChatMessagingLayoutUITests`) **13 de 13, dos rondas**, y los tres
casos de este ticket **aislados, dos rondas, 6 de 6**. `test_recordSelectorsOpenAtMediumDetent` incluido: ver
`record-selectors-uitest-taps-the-tags-chip-off-screen`.
