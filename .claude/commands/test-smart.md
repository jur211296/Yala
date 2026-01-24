---
description: Ejecuta solo tests relevantes para los cambios actuales
allowed-tools: Bash(git:*), Bash(xcodebuild:*), Bash(grep:*), Bash(find:*), Read, Glob
---

Ejecuta solo los tests relevantes para los archivos modificados.

PASOS:

1. DETECTAR ARCHIVOS MODIFICADOS:
   ```bash
   git diff --name-only HEAD
   ```
   Si no hay cambios staged, usa: `git diff --name-only`

2. MAPEAR ARCHIVOS A TESTS:
   Para cada archivo .swift modificado, busca tests relacionados:

   | Archivo modificado | Test relevante |
   |-------------------|----------------|
   | *Filter*.swift | FilterServiceTests |
   | *Calculator*.swift | CalculatorTests |
   | *Trend*.swift | TrendProcessingTests, TrendGroupingTests |
   | *Tag*.swift | TagTests |
   | *Category*.swift | (buscar en tests) |
   | *Transaction*.swift | (buscar en tests) |
   | *Account*.swift | (buscar en tests) |

3. SI NO HAY MAPEO CLARO:
   - Busca en YalaTests/ archivos que importen o mencionen las clases modificadas
   - Usa: `grep -l "NombreClase" YalaTests/*.swift`

4. EJECUTAR TESTS SELECTIVOS:
   ```bash
   xcodebuild -scheme Yala \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -quiet \
     test -only-testing:YalaTests/[TestClass] \
     2>&1 | grep -E "(Test Suite|Test Case|Executed|passed|failed|error:)"
   ```

5. REPORTAR:
   - "Archivos modificados: [lista]"
   - "Tests ejecutados: [lista de test classes]"
   - "Resultado: N tests, todos pasaron" o detalles de fallos

CASOS ESPECIALES:
- Si modificaste archivos de UI (Views/): Informar que no hay tests de UI automatizados
- Si modificaste DesignTokens.swift: No requiere tests
- Si no hay tests relacionados: Informar y sugerir /test-ios para correr todo

EJEMPLO:
```
Cambios detectados:
- Yala/Models/Tag.swift
- Yala/Services/FilterService.swift

Tests relevantes identificados:
- TagTests (6 tests)
- FilterServiceTests (8 tests)

Ejecutando tests selectivos...
✓ 14 tests ejecutados, todos pasaron
```
