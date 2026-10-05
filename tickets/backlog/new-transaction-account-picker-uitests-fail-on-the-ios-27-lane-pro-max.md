---
id: new-transaction-account-picker-uitests-fail-on-the-ios-27-lane-pro-max
status: backlog
priority: medium
area: "qa, xcuitest, transactions"
created: 2026-10-02
updated: 2026-10-05
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
