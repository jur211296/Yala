---
description: Ejecuta UI Tests (YalaUITests) y resume fallos
allowed-tools: Bash(cd:*), Bash(xcodebuild:*), Bash(grep:*), Bash(head:*)
---

Corre UI Tests del target YalaUITests.

!`cd /Users/work/Neto && xcodebuild -scheme Yala -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test -only-testing:YalaUITests 2>&1 | grep -E "(Test Suite|fail|error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" | head -120`

Si falla:
1) Resume la causa raíz.
2) Lista el test que falló.
3) Propón el cambio mínimo para que pase.
