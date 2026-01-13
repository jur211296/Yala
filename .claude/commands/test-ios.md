---
description: Ejecuta Unit Tests (NetoTests) y resume fallos
allowed-tools: Bash(cd:*), Bash(xcodebuild:*), Bash(grep:*), Bash(head:*)
---

Corre Unit Tests del target NetoTests.

!`cd /Users/jur/Desktop/Neto && xcodebuild -scheme Neto -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test -only-testing:NetoTests 2>&1 | grep -E "(Test Suite|fail|error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" | head -120`

Si falla:
1) Resume la causa raíz.
2) Lista el test que falló.
3) Propón el cambio mínimo para que pase.
