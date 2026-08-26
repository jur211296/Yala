---
description: Lee un item del Backlog en tickets/, analiza el codebase, y escribe un plan detallado en el mismo archivo.
---

Desarrolla a profundidad el spec de un feature del Backlog.

## PASO 1: IDENTIFICAR EL ARCHIVO

Si el usuario pasa un nombre como argumento (ej: `/spec widget-balance`), buscar el archivo en `tickets/` (las seis carpetas de estado):

```
tickets/*/*widget-balance*
```

Índice: `docs/TICKETS.md`.

Si no pasa argumento, listar los archivos en `tickets/backlog/` y `tickets/in-progress/` y preguntar cuál quiere desarrollar.

Ignorar `.gitkeep` y `README.md`.

## PASO 2: LEER Y ANALIZAR

1. Leer el archivo completo del ticket
2. Entender: problema, solución propuesta, acceptance criteria
3. Analizar el codebase relevante:
   - Buscar archivos, ViewModels, Services, Models involucrados
   - Leer los que sean necesarios para entender el contexto
   - Identificar dependencias y posibles conflictos

## PASO 3: ESCRIBIR EL PLAN EN EL MISMO ARCHIVO

Dejar `status` igual a la carpeta. Agregar estas secciones AL FINAL del archivo (preservar todo el contenido original):

```markdown
---

## Analisis tecnico

### Archivos involucrados
| Archivo | Cambio | Impacto |
|---------|--------|---------|
| path/to/file.swift | Crear / Modificar | Alto / Medio / Bajo |

### Modelo de datos
[Cambios en modelos SwiftData si aplica]

### Dependencias
[Services, ViewModels, o features que se ven afectados]

## Plan de implementacion

### Incrementos (orden de ejecucion)
1. **[nombre]** — [descripcion breve]
   - Archivos: `path/to/file.swift`
   - Tests: [que testear]

2. **[nombre]** — [descripcion breve]
   - Archivos: `path/to/file.swift`
   - Tests: [que testear]

### Riesgos
- [riesgo identificado y mitigacion]

### Estimacion
- Incrementos: [N]
- Complejidad: baja / media / alta
```

## PASO 4: CONFIRMAR

Mostrar resumen al usuario:
```
Spec listo: [nombre del feature]
Incrementos: [N]
Complejidad: [baja/media/alta]
Archivos principales: [lista corta]

El plan esta en tickets/<status>/[archivo].md
Siguiente paso: Plan Mode para implementar
```

## REGLAS
- NO implementar nada, solo planificar
- Ser concreto: nombres de archivos reales, no genericos
- Respetar patrones existentes (leer CLAUDE.md si necesitas referencia)
- El archivo se escribe en `tickets/` de este repo — no en Obsidian
