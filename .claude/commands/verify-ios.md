---
description: Build iOS (scheme Yala) filtrando errores y warnings
allowed-tools: Bash(xcodebuild:*), Bash(git:*), Bash(grep:*), Bash(head:*), Bash(wc:*), Bash(diff:*), Bash(cat:*)
---

Ejecuta build del proyecto y muestra solo errores y warnings relevantes.

PASOS:

1. IDENTIFICAR ARCHIVOS MODIFICADOS:
```bash
MODIFIED_FILES=$(git diff --name-only HEAD 2>/dev/null; git diff --name-only 2>/dev/null; git diff --name-only --cached 2>/dev/null)
MODIFIED_SWIFT=$(echo "$MODIFIED_FILES" | grep '\.swift$' | sort -u)
```

2. BUILD COMPLETO (con timeout de 5 minutos):
```bash
timeout 300 xcodebuild -scheme Yala \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" > /tmp/yala-build-output.txt 2>&1
cat /tmp/yala-build-output.txt
```

3. ANALIZAR RESULTADO:

   SI BUILD SUCCEEDED:
   - Filtrar warnings que pertenezcan a archivos en $MODIFIED_SWIFT
   - Ignorar warnings de archivos no modificados (preexistentes del proyecto)
   - Reportar:
     ```
     ✓ Build OK
     Warnings en tus cambios: [N] (o "ninguno")
     [lista de warnings solo de archivos modificados, si hay]
     ```

   SI BUILD FAILED:
   - Mostrar TODOS los errores (no solo de archivos modificados)
   - Resumir causa raíz en 3-6 líneas
   - Indicar archivo y línea más probable
   - Proponer cambio mínimo para que el build pase

   SI TIMEOUT:
   - Informar: "Build excedió 5 minutos. Posible: simulador no arrancado, proyecto corrupto, o Xcode indexando."
   - Sugerir: "Intenta abrir Xcode y compilar manualmente, o ejecuta `xcrun simctl boot 'iPhone 17 Pro'`"

REGLAS:
- NO ejecutar health checks previos (swift build --dry-run no aplica a .xcodeproj)
- Warnings de dependencias externas o archivos no modificados se IGNORAN
- Si hay 0 warnings en archivos modificados, es ✓ limpio aunque haya warnings preexistentes
