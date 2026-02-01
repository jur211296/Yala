---
description: Guía y ejemplos para lanzar tareas en background
---

# Background Tasks en Claude Code

## Qué son

Tareas que se ejecutan en segundo plano mientras continúas trabajando en el contexto principal.

## Cómo usarlas

### Opción 1: Pedirlo directamente
```
"Lanza en background: [descripción de la tarea]"
```

### Opción 2: Ser específico sobre el output
```
"En background, analiza todos los ViewModels y guarda un reporte en /tmp/viewmodel-analysis.md"
```

### Opción 3: Múltiples tareas paralelas
```
"Lanza estos 3 análisis en paralelo en background:
1. Buscar todos los try? en el proyecto
2. Listar todas las vistas que usan @Query
3. Encontrar prints sin #if DEBUG"
```

## Ejemplos prácticos para Yala

### Análisis de código
```
"En background, usa el agente swift-reviewer para revisar
Yala/Services/TransactionService.swift y guarda el resultado
en .claude/sessions/review-transaction-service.md"
```

### Búsqueda exhaustiva
```
"En background, busca todas las instancias de force unwrap (!)
en el proyecto y genera un reporte con archivo:línea"
```

### Generación de tests
```
"En background, usa el agente test-generator para crear tests
de FilterService y guarda el resultado en YalaTests/FilterServiceTests-new.swift"
```

### Auditoría de branches
```
"En background, usa el agente branch-auditor para comparar
feature-a y bugfix-b contra main"
```

## Cómo ver el resultado

1. **Si especificaste archivo de output:**
   ```
   "Lee .claude/sessions/[archivo].md"
   ```

2. **Si no especificaste:**
   El resultado aparecerá cuando la tarea termine (notificación).

3. **Ver estado de tareas:**
   ```
   "¿Qué tareas en background tengo corriendo?"
   ```

## Tips

- **Sé específico** sobre dónde guardar el output
- **Usa agentes** para tareas especializadas (swift-reviewer, test-generator)
- **No esperes** - sigue trabajando mientras el background task corre
- **Revisa después** - los resultados se guardan en archivos

## Limitaciones

- No pueden modificar archivos críticos sin tu aprobación
- El output puede tardar dependiendo de la complejidad
- Si necesitas el resultado inmediatamente, no uses background
