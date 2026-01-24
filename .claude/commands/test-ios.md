---
description: Ejecuta Unit Tests (YalaTests) y resume fallos
allowed-tools: Bash(cd:*), Bash(xcodebuild:*), Bash(grep:*), Bash(head:*), Bash(timeout:*)
---

Corre Unit Tests del target YalaTests.

DISPOSITIVO ESTÁNDAR: iPhone 17 Pro (NO usar otros para evitar demoras)

COMANDO (con -quiet para reducir ruido):
!`xcodebuild -scheme Yala -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet test -only-testing:YalaTests 2>&1 | grep -E "(Test Suite|Test Case|Executed|passed|failed|error:)"`

TIMEOUT:
- Si después de 3 minutos no hay output, informar al usuario que los tests están tardando
- Sugerir: "¿Quieres cancelar y verificar si el simulador está funcionando?"

Si falla:
1) Resume la causa raíz.
2) Lista el test que falló con nombre completo (TestClass/testMethod).
3) Propón el cambio mínimo para que pase.

Si pasa:
- Muestra resumen: "N tests ejecutados, todos pasaron"

NOTA: Para tests selectivos basados en archivos modificados, usa /test-smart
