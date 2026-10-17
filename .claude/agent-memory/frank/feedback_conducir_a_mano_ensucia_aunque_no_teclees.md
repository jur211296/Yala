---
name: conducir-a-mano-ensucia-aunque-no-teclees
description: Tras capturas a mano (content_size, axe tap/swipe, -AppleLanguages) dos XCUITest del formulario cayeron con «no dejó de moverse»; simctl erase y verdes ×2
metadata:
  type: feedback
---

El 2026-10-17 conduje el simulador a mano para las capturas (16 idiomas con `-AppleLanguages`, `simctl ui
content_size` a XXXL y AX5 y vuelta a `large`, `axe tap`/`swipe`), **sin teclear nada**, y en el gate cayeron
`EdgeCasesUITests.test_extremeMinimumAmountSaves` y `FirstExpensePracticeAlertUITests` con «new_transaction_account_chip
no dejó de moverse». `HardwareKeyboardLastSeen` no estaba puesto, así que la regla de `testing.md` (`type_text`/`axe type`)
no lo explicaba. Tras `simctl erase` + boot: verdes dos corridas seguidas, centinela limpio. Causa sin aislar.

**Why:** la regla del teclado hace pensar que solo teclear ensucia; aquí bastó lo demás.

**How to apply:** si conduces el simulador a mano antes del gate, por lo que sea, `erase` antes de los XCUITest; o
mejor, saca las capturas DESPUÉS del gate. Relacionado: [[conducir-simulador-con-axe]],
[[una-tanda-de-capturas-cuesta-diez-gigas]].
