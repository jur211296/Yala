---
description: Ejecuta solo tests relevantes para los cambios actuales
allowed-tools: Bash(git:*), Bash(xcodebuild:*), Bash(grep:*), Bash(find:*), Bash(touch:*), Bash(rm:*), Read, Glob, Grep
---

Ejecuta solo los tests relevantes para los archivos modificados.

PASOS:

1. DETECTAR ARCHIVOS MODIFICADOS (staged + unstaged + untracked):
```bash
MODIFIED=$(comm -23 \
  <(sort -u <(git diff --name-only HEAD 2>/dev/null; git diff --name-only 2>/dev/null; git diff --name-only --cached 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)) \
  <(echo ""))
MODIFIED_SWIFT=$(echo "$MODIFIED" | grep '\.swift$' | grep -v 'Tests/' | grep -v 'Views/' || true)
```

   Si no hay archivos .swift modificados (excluyendo Views/ y Tests/): informar "No hay cambios testeables" y terminar.

2. MAPEO DINÁMICO A TESTS:

   Para CADA archivo .swift modificado:

   a) Extraer nombre de clase/struct principal del archivo (sin extensión, sin path)
   b) Buscar test suites que referencien esa clase:
   ```bash
   grep -rl "NombreClase" YalaTests/ --include="*.swift" 2>/dev/null
   ```
   c) También buscar por convención: `YalaTests/NombreClaseTests.swift`
   d) Buscar dependencias transitivas (clases que USAN la clase modificada):
   ```bash
   grep -rl "NombreClase" Yala/ --include="*.swift" 2>/dev/null | grep -v Views/
   ```
      Para cada dependiente encontrado, buscar SUS tests también.
      LÍMITE: máximo 1 nivel de transitividad (no recursivo).

   Consolidar lista única de test suites a ejecutar.

3. EJECUTAR TESTS:

   Si hay test suites identificadas:
   ```bash
   xcodebuild -scheme Yala \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -quiet \
     test -only-testing:YalaTests/[TestClass1] \
     -only-testing:YalaTests/[TestClass2] \
     2>&1 | grep -E "(Test Suite|Test Case|Executed|passed|failed|error:)"
   ```

   Si NO hay test suites para algún archivo modificado, registrarlo como gap.

4. MARCAR RESULTADO:

   Si TODOS los tests pasan:
   ```bash
   touch .claude/sessions/tests-passed
   ```

   Si algún test FALLA:
   ```bash
   rm -f .claude/sessions/tests-passed
   ```

5. REPORTAR:

```
## Test Smart

Archivos modificados: [lista de .swift sin Views/]
Tests ejecutados: [N] tests en [M] suites
Resultado: ✓ todos pasan | ✗ N fallos

[Si hay fallos: detalle de cada test fallido]

Gaps de cobertura:
- [archivo.swift] → sin tests encontrados
- [archivo2.swift] → sin tests encontrados
[O: "Sin gaps — todos los archivos tienen tests"]
```

REGLAS:
- Archivos en Views/ se excluyen del mapeo (no hay tests de UI)
- Archivos en Tests/ modificados se ejecutan directamente
- DesignTokens.swift, L10n.swift, Assets no requieren tests
- Si el mapeo dinámico no encuentra nada, buscar con nombre parcial (ej: "Budget" en archivo → BudgetEditorViewModelTests)
- Si no hay NINGÚN test relevante, informar claramente
