---
description: Crear 1 commit atómico, pequeño y verificable
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git log:*), Bash(xcodebuild:*), Bash(grep:*), Bash(wc:*), Grep, Glob, Read, Write, Edit, Agent
---

OPTIMIZACIÓN CRÍTICA - EJECUTAR COMANDOS GIT UNA SOLA VEZ:
```bash
# PASO 0: Ejecutar estos comandos UNA SOLA VEZ al inicio
# Guardar outputs en variables para reutilización
GIT_STATUS=$(git status --porcelain 2>&1)
GIT_DIFF_STAT=$(git diff --stat 2>&1)
GIT_DIFF_NAMES=$(git diff --name-only 2>&1)
GIT_DIFF_FULL=$(git diff 2>&1)
GIT_LOG=$(git log --oneline -10 2>&1)

# USAR estos outputs guardados para TODO el análisis posterior
# NUNCA volver a ejecutar estos comandos durante el proceso
```

REGLAS ABSOLUTAS:
- ❌ PROHIBIDO ejecutar git status más de una vez
- ❌ PROHIBIDO ejecutar git diff más de una vez
- ❌ PROHIBIDO crear múltiples shells en background
- ❌ PROHIBIDO ejecutar comandos git en paralelo
- ✅ USAR los outputs guardados arriba para todo el análisis

PASOS OBLIGATORIOS (usando outputs ya guardados):

1. LIMPIEZA DE COMMITS WIP (usar $GIT_LOG guardado):
   - Revisar si hay commits con prefijo "wip:"
   - Si los hay y están relacionados con el trabajo actual, preguntar:
     "Detecté N commits wip: previos. ¿Quieres combinarlos en este commit final?"
   - Si el usuario confirma: ejecutar `git reset --soft HEAD~N`
   - Después del reset, ACTUALIZAR las variables:
```bash
     GIT_STATUS=$(git status --porcelain 2>&1)
     GIT_DIFF_STAT=$(git diff --stat 2>&1)
     GIT_DIFF_NAMES=$(git diff --name-only 2>&1)
```

2. ANÁLISIS DE CAMBIOS (usar variables guardadas, NO ejecutar comandos nuevos):
   - Contar archivos: usar $GIT_DIFF_NAMES
   - Contar líneas: usar $GIT_DIFF_STAT
   - Ver contenido: usar $GIT_DIFF_FULL
   - Ver estado: usar $GIT_STATUS

3. VALIDACIÓN DE ALCANCE (usar variables guardadas):

   Contar archivos y líneas desde las variables guardadas:
   - Archivos modificados: contar líneas en $GIT_DIFF_NAMES
   - Líneas totales: parsear $GIT_DIFF_STAT

   Aplicar estas reglas:

   SI archivos > 5 O líneas totales > 300:
   - ALERTA: "Este cambio parece grande para un commit atómico"
   - Analiza si realmente es un solo tema o son múltiples temas
   - Pregunta: "¿Esto debería dividirse en múltiples commits?"

   SI archivos > 10 O líneas > 500:
   - ALERTA FUERTE: "Este cambio es demasiado grande"
   - Muestra breakdown por archivo (usar $GIT_DIFF_STAT)
   - REQUIERE que el usuario confirme explícitamente o divida el cambio

   SI detectas cambios en archivos no relacionados temáticamente:
   - Ejemplo: cambios en Model + cambios en Views + cambios en Tests
   - Sugiere división por capas: "Model changes", "View updates", "Test additions"

   Si el usuario confirma que es un solo commit grande válido, procede
   Si el usuario acepta dividir, guíalo: "Empecemos con los cambios de [capa 1]"

4. IDENTIFICACIÓN DE TEMA (usar variables guardadas):
   - Revisar $GIT_DIFF_NAMES y $GIT_DIFF_FULL para entender qué cambió
   - Determinar si es un tema único atómico
   - Si son múltiples temas, alertar y pedir división
   - Determinar prefijo: feat:, fix:, refactor:, test:, chore:, docs:

5. SWIFT AUDIT AUTOMÁTICO (antes de tests):
   - Ejecutar /swift-audit sobre los archivos .swift modificados (de $GIT_DIFF_NAMES)
   - Si hay issues CRÍTICOS: mostrarlos y BLOQUEAR el commit hasta que se resuelvan
   - Si hay warnings menores: mostrarlos como nota informativa, no bloquean
   - Si está LIMPIO: continuar al paso 6

6. TEST GATE (después de audit, antes de commit):

   SKIP si: prefijo es docs: o chore: y no hay archivos .swift modificados.

   ### 6A. EJECUTAR TESTS RELEVANTES

   Mapear archivos .swift modificados a tests existentes:
   - Para cada archivo en $GIT_DIFF_NAMES que sea .swift (excluir Views/):
     - Buscar test suite correspondiente en YalaTests/: `grep -rl "NombreClase" YalaTests/`
     - También buscar por convención: `NombreClaseTests.swift`

   Ejecutar tests relevantes encontrados:
   ```bash
   xcodebuild -scheme Yala \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -quiet \
     test -only-testing:YalaTests/[TestClass] \
     2>&1 | grep -E "(Test Suite|Test Case|Executed|passed|failed|error:)"
   ```

   - Si FALLAN: BLOQUEAR commit. Mostrar fallos y pedir que se corrijan.
   - Si PASAN: crear flag `touch .claude/sessions/tests-passed` y continuar.
   - Si no hay tests relevantes: crear flag igualmente y registrarlo para 6B.

   ### 6B. DETECTAR GAPS DE COBERTURA

   Según el prefijo del commit:

   **fix: → Test de regresión OBLIGATORIO**

   1. Analizar el diff para entender QUÉ bug se corrigió
   2. Buscar si ya existe un test que cubra ese escenario exacto
   3. Si NO existe:
      - Generar test de regresión mínimo que:
        a) Reproduce el escenario que causaba el bug
        b) Verifica que ahora funciona correctamente
      - Nombrar: `test_[método]_[escenarioBug]_[resultadoCorrecto]()`
      - Mostrar al usuario:
        ```
        ⚠️ Bug fix sin test de regresión detectado.

        Test propuesto:
        [código del test]

        ¿Incluir en este commit? (s/n/editar)
        ```
      - Si acepta: escribir el test, añadir al staging
   4. Si ya existe un test que lo cubra: informar "✓ Regresión cubierta por [TestName]"

   **feat: → Cobertura de funcionalidad nueva**

   1. Del diff, extraer funciones/métodos públicos o internal NUEVOS (no modificados)
      - Buscar líneas añadidas con `func ` que no sean `private`
      - Excluir: funciones de Views (body, makeX), overrides de setUp/tearDown
   2. Para cada función nueva, verificar si tiene test correspondiente
   3. Si hay funciones sin test:
      - Generar tests básicos: happy path + 1-2 edge cases por función
      - Seguir convención: `test_[método]_[escenario]_[resultado]()`
      - Seguir patrón Given/When/Then del proyecto
      - Mostrar al usuario:
        ```
        ⚠️ [N] funciones nuevas sin tests:
        - func calculateBudgetSpent() → 0 tests
        - func filterByNature() → 0 tests

        Tests propuestos: [N] tests para [N] funciones
        [código de los tests]

        ¿Incluir en este commit? (s/n/editar)
        ```
      - Si acepta: escribir tests, añadir al staging
   4. Si todas las funciones nuevas tienen tests: "✓ Cobertura OK"

   **refactor: → Solo verificar que tests existentes pasan**
   - Ya cubierto por 6A. No generar tests nuevos.
   - Si tests fallan por el refactor, BLOQUEAR.

   **test: → Verificar que los tests nuevos compilan y pasan**
   - Ejecutar los tests nuevos/modificados.
   - Si fallan: BLOQUEAR.

   ### 6C. REGLAS DE GENERACIÓN DE TESTS

   Al generar tests, seguir ESTRICTAMENTE estas reglas del proyecto:
   - NUNCA usar makeTestContext() ni ModelContainer in-memory (crash CloudKit)
   - Crear objetos @Model SIN insertar en contexto — properties y persistentModelID funcionan
   - Usar MockCurrencyConverter para tests que necesiten conversión de divisas
   - Estructura: Given/When/Then con // comentarios
   - Naming: test_método_escenario_resultado
   - Ubicar en YalaTests/ con nombre [Clase]Tests.swift
   - Si ya existe archivo de tests para esa clase, AGREGAR al existente (no crear nuevo)

   ### 6D. REPORTE TEST GATE

   Mostrar resumen compacto:
   ```
   ## Test Gate
   Tests ejecutados: [N] tests en [M] suites — ✓ todos pasan
   Cobertura: [estado según prefijo]
   - [✓ Regresión cubierta / ⚠️ Test de regresión añadido / ✓ Cobertura OK / ⚠️ N tests añadidos]
   Tests nuevos: [N] (si se generaron)
   ```

7. PROPUESTA DE COMMIT:
   - Proponer mensaje descriptivo con prefijo correcto
   - ❌ NUNCA incluir línea "Co-Authored-By: Claude..." en el mensaje
   - Listar archivos específicos para `git add` (incluyendo tests nuevos si se generaron en paso 6)
   - Si se generaron tests, el mensaje de commit debe reflejarlos:
     - fix: → "fix: [descripción] + regression test"
     - feat: → "feat: [descripción] + [N] tests"
     - O si son muchos tests, sugerir commit separado: test: → primero, luego feat:/fix:
   - Preguntar: "¿Procedo con este commit?"

8. EJECUCIÓN (solo si usuario confirma):
```bash
   git add [archivos específicos]
   git commit -m "[prefijo]: [mensaje]"
   rm -f .claude/sessions/tests-passed
```
   Nota: el flag tests-passed se limpia después de cada commit para forzar
   que /test-smart se ejecute de nuevo antes del siguiente commit.

9. POST-COMMIT: ACTUALIZACIÓN DE DOCUMENTACIÓN

   PRINCIPIO: Todo trabajo debe dejar rastro para futuras sesiones.

   Después de crear el commit exitosamente:

   a) Obtener datos del commit:
```bash
      COMMIT_HASH=$(git log -1 --format=%h)
      COMMIT_MSG=$(git log -1 --format=%s)
      TODAY=$(date +%Y-%m-%d)
```

   b) ACTUALIZAR STATE.md:

      En "## Recent Progress":
      - Agregar: `- [$TODAY] $COMMIT_HASH $COMMIT_MSG`
      - Mantener solo las últimas 10 entradas

      En "## Completed in Current Phase":
      - Si el commit completa un item de "Next Steps", moverlo aquí
      - Ser ESPECÍFICO: no solo "Bug fix" sino "Bug 7.6: Contador archivados corregido"

      En "## Session Continuity":
      - Actualizar "Last session:" con fecha actual
      - Actualizar "Stopped at:" con descripción del último trabajo
      - Actualizar "Next step:" con el siguiente item lógico

   c) ACTUALIZAR CLAUDE.md (si se añadieron tests):
      - Actualizar conteo total de tests en "### Test Suites (N suites, N tests)"
      - Si se creó suite nueva, añadirla a la lista
      - Si se añadieron tests a suite existente, actualizar el conteo

   d) ACTUALIZAR DOCUMENTOS DE TRABAJO CONSULTADOS:

      Revisar TODOS los documentos .md en el vault Obsidian (~/Library/Mobile Documents/iCloud~md~obsidian/Documents/YalaWiki/) que se leyeron durante
      esta sesión para implementar el trabajo. Ejemplos comunes:

      - REFINAMIENTO-*.md → Marcar items completados con ✅
      - PLAN.md → Marcar pasos ejecutados
      - PHASE*-SPEC.md → Marcar subfases/items completados
      - QA-SCENARIOS.md → Agregar escenarios si aplica (OBLIGATORIO para feat: y fix: significativos)
      - Cualquier otro documento con checklists o items pendientes

      Para cada documento consultado:
      - Buscar el item específico que el commit completó
      - Cambiar "[ ]" a "[x]" o "Pendiente" a "✅ Completado"
      - Agregar fecha o hash del commit si el formato lo permite

   e) VERIFICACIÓN FINAL:
      - Confirmar que STATE.md refleja el progreso real
      - Confirmar que documentos de trabajo están sincronizados
      - Listar documentos actualizados al usuario

   f) INFORMAR AL USUARIO:
      ```
      ✓ Commit $COMMIT_HASH creado
      ✓ STATE.md actualizado (Recent Progress + Session Continuity)
      ✓ CLAUDE.md actualizado (test count: N → M)  ← solo si cambió
      ✓ Documentos actualizados: [lista de archivos .md modificados]
      ```

FORMATO ESPERADO DE STATE.md:
```markdown
# Project State

## Recent Progress
<!-- Últimos 10 commits con formato: -->
- [YYYY-MM-DD] hash mensaje
- [YYYY-MM-DD] hash mensaje

## Completed in Current Phase
<!-- Items específicos completados, no solo commits: -->
- **Feature/Bug X**: Descripción detallada de qué se logró
- **Item Y del documento Z**: Completado (hash)

## Next Steps
<!-- Items pendientes con referencias a documentos fuente: -->
- [ ] Item pendiente (ver DOCUMENTO.md #sección)

## Session Continuity
<!-- Para retomar trabajo en próxima sesión: -->
Last session: YYYY-MM-DD
Stopped at: Descripción específica del último trabajo
Next step: Siguiente item lógico a trabajar
Resume context:
- Punto importante 1
- Punto importante 2
```

RECORDATORIO FINAL:
- TODOS los comandos git de lectura se ejecutan UNA VEZ al inicio
- Los outputs se GUARDAN y REUTILIZAN
- NUNCA ejecutar git status/diff múltiples veces
- NUNCA crear shells en background para git
- NUNCA ejecutar comandos git en paralelo
- Test Gate es OBLIGATORIO para fix: y feat: — no se puede skipear
