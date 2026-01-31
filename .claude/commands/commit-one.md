---
description: Crear 1 commit atómico, pequeño y verificable
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git log:*)
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

5. PROPUESTA DE COMMIT:
   - Determinar prefijo correcto: feat:, fix:, refactor:, chore:, docs:
   - Proponer mensaje descriptivo
   - ❌ NUNCA incluir línea "Co-Authored-By: Claude..." en el mensaje
   - Listar archivos específicos para `git add`
   - Preguntar: "¿Procedo con este commit?"

6. EJECUCIÓN (solo si usuario confirma):
```bash
   git add [archivos específicos]
   git commit -m "[prefijo]: [mensaje]"
```

7. POST-COMMIT: ACTUALIZACIÓN DE DOCUMENTACIÓN

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

   c) ACTUALIZAR DOCUMENTOS DE TRABAJO CONSULTADOS:

      Revisar TODOS los documentos .md en .planning/ que se leyeron durante
      esta sesión para implementar el trabajo. Ejemplos comunes:

      - REFINAMIENTO-*.md → Marcar items completados con ✅
      - PLAN.md → Marcar pasos ejecutados
      - PHASE*-SPEC.md → Marcar subfases/items completados
      - QA-SCENARIOS.md → Agregar escenarios si aplica
      - Cualquier otro documento con checklists o items pendientes

      Para cada documento consultado:
      - Buscar el item específico que el commit completó
      - Cambiar "[ ]" a "[x]" o "Pendiente" a "✅ Completado"
      - Agregar fecha o hash del commit si el formato lo permite

   d) VERIFICACIÓN FINAL:
      - Confirmar que STATE.md refleja el progreso real
      - Confirmar que documentos de trabajo están sincronizados
      - Listar documentos actualizados al usuario

   e) INFORMAR AL USUARIO:
      ```
      ✓ Commit $COMMIT_HASH creado
      ✓ STATE.md actualizado (Recent Progress + Session Continuity)
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
