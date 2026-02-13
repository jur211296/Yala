---
description: Busca un patrón en paralelo usando subagentes especializados
argument-hint: "[patrón a buscar]"
allowed-tools: Task, Grep, Glob, Read
---

Ejecuta una búsqueda exhaustiva en paralelo usando subagentes especializados.

## USO
```
/parallel-search [patrón]
```

Ejemplo: `/parallel-search fetchTransactions`

## EJECUCIÓN

### PASO 1: Validar entrada
- El patrón debe ser proporcionado como argumento: $ARGUMENTS
- Si no hay argumento, preguntar: "¿Qué patrón quieres buscar?"

### PASO 2: Lanzar subagentes en paralelo

Usar el Task tool para lanzar 3 subagentes SIMULTÁNEAMENTE (en una sola llamada):

**Subagente 1 - Código fuente:**
```
Buscar el patrón "$ARGUMENTS" en:
- Yala/**/*.swift (excluyendo tests)

Reportar:
- Número de archivos con coincidencias
- Lista de archivos con líneas específicas
- Contexto de uso (función, clase, struct)
```

**Subagente 2 - Tests:**
```
Buscar el patrón "$ARGUMENTS" en:
- YalaTests/**/*.swift
- YalaUITests/**/*.swift

Reportar:
- Tests que usan este patrón
- Cobertura aparente (¿hay tests específicos?)
```

**Subagente 3 - Documentación y configs:**
```
Buscar el patrón "$ARGUMENTS" en:
- **/*.md
- **/*.json
- **/*.plist
- Comentarios en código (// y /* */)

Reportar:
- Referencias en documentación
- Configuraciones relacionadas
```

### PASO 3: Consolidar resultados

Esperar a que todos los subagentes terminen y presentar:

```
╔════════════════════════════════════════════════════════════╗
║  BÚSQUEDA PARALELA: "$ARGUMENTS"                           ║
╠════════════════════════════════════════════════════════════╣
║                                                            ║
║  CÓDIGO FUENTE                                             ║
║  ─────────────                                             ║
║  Archivos: [N]                                             ║
║  - path/to/file1.swift:42 (en función X)                   ║
║  - path/to/file2.swift:87 (en clase Y)                     ║
║                                                            ║
║  TESTS                                                     ║
║  ─────                                                     ║
║  Archivos: [N]                                             ║
║  - YalaTests/SomeTests.swift:15                            ║
║  Cobertura: [Buena/Parcial/Sin tests]                      ║
║                                                            ║
║  DOCUMENTACIÓN                                             ║
║  ─────────────                                             ║
║  Referencias: [N]                                          ║
║  - README.md:23                                            ║
║                                                            ║
╠════════════════════════════════════════════════════════════╣
║  TOTAL: [N] archivos, [M] coincidencias                    ║
╚════════════════════════════════════════════════════════════╝
```

## REGLAS
- SIEMPRE lanzar los 3 subagentes en paralelo (una sola llamada con múltiples Task)
- Usar subagent_type: "Explore" para los subagentes
- Si el patrón es muy común (>50 resultados), agrupar por directorio
- No mostrar contenido completo de archivos, solo ubicaciones y contexto
