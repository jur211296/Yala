---
description: Build iOS (scheme Yala) filtrando errores y warnings
allowed-tools: Bash(cd:*), Bash(xcodebuild:*), Bash(grep:*), Bash(head:*)
---

Ejecuta build del proyecto y muestra solo errores, warnings y estado.

PASOS:

0. HEALTH CHECK PREVIO:
   - Ejecuta: swift build --dry-run 2>&1 | grep -E "error"
   - Si hay errores de sintaxis, detén el proceso y repórtalos inmediatamente
   - Solo continúa con la compilación completa si este check pasa

1. BUILD COMPLETO:
!`xcodebuild -scheme Yala -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" | head -20`

Si aparece BUILD FAILED o errores:
1) Resume la causa raíz en 3 a 6 líneas.
2) Indica el archivo o módulo más probable.
3) Propón el cambio mínimo para que el build pase.
