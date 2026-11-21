---
name: capturas-por-xcuitest-ensucian-el-app-group
description: Correr XCUITest que guardan registros antes de la suite unitaria deja lastUsedAccountID en el App Group del simulador y pone rojos SharedStateIsolationTests y ActivationRestoreDiscardTests
metadata:
  type: feedback
---

El 20-nov-2026, tras ocho corridas de capturas por XCUITest (guardaban registros), la suite unitaria entera dio 2 rojos:
`SharedStateIsolationTests.scopeLastUsedAccount_entraSinUltimaCuenta` y el «borrado sin reset… REABRE las puertas del
seed» de `ActivationRestoreDiscardTests`. Aislados pasaban; en el CI (simulador limpio) también. Causa:
`NewTransactionViewModel.save` escribe `lastUsedAccountID` en el App Group REAL del simulador y el conserje de tests lo
devuelve a como estaba al empezar (ya sucio).

**Why:** costó una suite entera (7 min) y casi un ticket falso.

**How to apply:** si tras correr XCUITest que guardan registros salen esos dos rojos, borra la clave antes de culpar al
cambio: `xcrun simctl spawn <udid> defaults delete <AppGroup>/Library/Preferences/group.com.jurgenschmidt.yala.dev
lastUsedAccountID` (ruta con `simctl get_app_container <udid> com.jurgenschmidt.yala.dev groups`) y repite. Mejor aún:
corre la suite unitaria ANTES de las capturas. Relacionado: [[ui-tras-yalatests-entero-reinicia-el-simulador]].
