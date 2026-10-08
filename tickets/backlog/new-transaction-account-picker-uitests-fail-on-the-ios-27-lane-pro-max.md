---
id: new-transaction-account-picker-uitests-fail-on-the-ios-27-lane-pro-max
status: backlog
priority: medium
area: "qa, xcuitest, transactions"
created: 2026-10-02
updated: 2026-10-08
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
