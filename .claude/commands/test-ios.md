---
description: Ejecuta Unit Tests (NetoTests) y resume fallos
allowed-tools: Bash(cd:*), Bash(xcodebuild:*), Bash(grep:*), Bash(head:*), Bash(timeout:*)
---

Corre Unit Tests del target NetoTests.

DISPOSITIVO ESTÁNDAR: iPhone 17 Pro (NO usar otros para evitar demoras)

OPCIONES DE EJECUCIÓN:
- Normal: Ejecuta todos los tests
- Rápido: Solo tests modificados recientemente (si el usuario lo pide)

COMANDO:
!`cd /Users/jur/Desktop/Neto && xcodebuild -scheme Neto -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled YES -maximum-concurrent-test-simulator-destinations 2 test -only-testing:NetoTests 2>&1 | grep -E "(Test Suite|Executed|fail|error:|warning:|BUILD SUCCEEDED|BUILD FAILED|\*\*)" | head -80`

TIMEOUT:
- Si después de 3 minutos no hay output, informar al usuario que los tests están tardando
- Sugerir: "¿Quieres cancelar y verificar si el simulador está funcionando?"

Si falla:
1) Resume la causa raíz.
2) Lista el test que falló con nombre completo (TestClass/testMethod).
3) Propón el cambio mínimo para que pase.

Si pasa:
- Muestra resumen: "N tests ejecutados, todos pasaron"
