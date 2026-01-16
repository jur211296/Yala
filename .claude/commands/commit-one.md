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
   - Listar archivos específicos para `git add`
   - Preguntar: "¿Procedo con este commit?"

6. EJECUCIÓN (solo si usuario confirma):
```bash
   git add [archivos específicos]
   git commit -m "[prefijo]: [mensaje]"
```

7. POST-COMMIT: ACTUALIZACIÓN AUTOMÁTICA DE STATE:
   Después de crear el commit exitosamente:
   
   a) Obtener hash del commit recién creado:
```bash
      COMMIT_HASH=$(git log -1 --format=%h)
      COMMIT_MSG=$(git log -1 --format=%s)
      TIMESTAMP=$(date -Iseconds)
```
   
   b) Leer .planning/STATE.md actual
   
   c) Localizar o crear la sección "## Recent Progress"
   
   d) Agregar nueva entrada:
      - Formato: `- [$TIMESTAMP] $COMMIT_HASH $COMMIT_MSG`
      - Ejemplo: `- [2025-01-16T14:30:00-05:00] a3f8b2c feat: Add category filtering`
   
   e) Mantener solo las últimas 10 entradas en Recent Progress
   
   f) Si el commit completa un item de "Next Steps", moverlo a "Completed in Current Phase"
   
   g) Escribir STATE.md actualizado
   
   h) Informar: "✓ Commit $COMMIT_HASH creado\n✓ STATE.md actualizado automáticamente"

FORMATO ESPERADO DE STATE.md:
```markdown
# Project State

## Recent Progress
- [timestamp ISO] [hash] [mensaje]
- [timestamp ISO] [hash] [mensaje]
...

## Completed in Current Phase
- [item completado]
...

## Next Steps
- [item pendiente]
...

## Parking Lot
- [idea] (Tipo: X, Prioridad: Y)
...
```

RECORDATORIO FINAL:
- TODOS los comandos git de lectura se ejecutan UNA VEZ al inicio
- Los outputs se GUARDAN y REUTILIZAN
- NUNCA ejecutar git status/diff múltiples veces
- NUNCA crear shells en background para git
- NUNCA ejecutar comandos git en paralelo
