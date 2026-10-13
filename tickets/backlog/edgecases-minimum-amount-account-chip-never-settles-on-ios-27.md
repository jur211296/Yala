---
id: edgecases-minimum-amount-account-chip-never-settles-on-ios-27
status: backlog
priority: medium
area: "qa, xcuitest, transactions"
created: 2026-10-13
updated: 2026-10-13
owner: frank
deadline: 2026-10-20
source: "gate del lote 1 de la auditoría UX 2.2 (encargo 2026-10-13-auditoria-ux-2-2-lote-1-primera-vez)"
---

# `test_extremeMinimumAmountSaves` vuelve a caer en iOS 27.0: el chip de cuenta «no deja de moverse»

## Qué se ve

`EdgeCasesUITests.test_extremeMinimumAmountSaves` falla en el iPhone 17 Pro del gate (iOS 27.0, `46287CFE`):

> `EdgeCasesUITests.swift:66: XCTAssertTrue failed - new_transaction_account_chip no dejó de moverse (¿el teclado sigue entrando o saliendo?).`

La línea 66 es `app.chooseFirstSelectorRow(chip: "new_transaction_account_chip", …)`: el helper que añadió `b0c3a21dd`
(2026-10-09) para esperar a que el teclado termine de entrar antes de tocar el chip.

## No es del cambio que lo destapó

Medido el 2026-10-13 con el centinela en 0 (simulador solo para esta corrida):

- En la rama del lote 1 (que no toca el formulario de registro): rojo en lote y **rojo aislado**.
- En **`origin/2.2` limpio (`43d874cf9`)**, worktree aparte: **rojo aislado**, mismo mensaje.

## Relación con el ticket anterior

`tickets/done/new-transaction-account-picker-uitests-fail-on-the-ios-27-lane-pro-max.md` se cerró el 2026-10-09 con
ese helper. El fallo de entonces era «Automation type mismatch … PopUpButton»; el de hoy es la espera del propio
helper, que se agota. No es el mismo síntoma: el arreglo cambió el sitio donde se rompe.

## Qué mirar primero

1. Si el chip sigue animándose con el teclado ya dentro: el helper compara posiciones del marco y en iOS 27.0 el
   marco XCUI puede no estabilizarse (memoria de Frank: «El marco de celda no es el bloque»).
2. Si `TransactionsCrudUITests.test_createTransaction` y `QuickActionsFavoritesUITests` (mismo helper) caen igual.
3. Hasta que se arregle: este rojo es conocido y **no bloquea gates de ramas que no tocan el formulario de registro**,
   siempre que se re-mida en la base como aquí.

## 2026-10-13 · gate del lote 2: verde

En el gate del lote 2 (rama `encargo/2026-10-13-auditoria-ux-2-2-lote-2-apuntar-a-mano`, sobre `origin/2.2` 7000aef89,
que toca el formulario de registro) `test_extremeMinimumAmountSaves` pasó en 39,5 s dentro de una corrida de 15 suites
(39 tests, 0 fallos, centinela en 0, simulador recién borrado). Un verde no cierra el ticket: el rojo del lote 1 fue
aislado y repetido. Si el próximo gate también sale verde, mirar si el `erase` previo del simulador es lo que cambia.
