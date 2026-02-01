---
description: Captura el contexto mental actual para retomarlo después de /compact o /clear
allowed-tools: Bash(date:*), Write, Read
---

Guarda un snapshot del contexto actual antes de perderlo por compactación o clear.

## PROPÓSITO

Cuando llevas tiempo trabajando y has acumulado contexto valioso que no quieres perder:
- Decisiones tomadas que no están en código
- Entendimiento de problemas complejos
- Estado mental de una investigación
- Hipótesis o direcciones descartadas

Este comando captura todo eso de forma estructurada.

## EJECUCIÓN

### PASO 1: Generar timestamp y ruta
```bash
SNAPSHOT_FILE=".claude/sessions/SNAPSHOT-$(date +%Y-%m-%d-%H%M%S).md"
```

### PASO 2: Analizar conversación actual

Revisar la conversación y extraer:

1. **Objetivo de la sesión**: ¿Qué estábamos tratando de lograr?
2. **Progreso**: ¿Qué se completó y qué falta?
3. **Decisiones clave**: Decisiones tomadas y su razonamiento
4. **Descubrimientos**: Cosas que aprendimos sobre el código/sistema
5. **Problemas encontrados**: Issues que surgieron y cómo se resolvieron (o no)
6. **Hipótesis descartadas**: Caminos que probamos y no funcionaron
7. **Contexto técnico**: Archivos relevantes, funciones clave, estado del código
8. **Siguiente paso**: Exactamente qué hacer al retomar

### PASO 3: Escribir snapshot

```markdown
# Context Snapshot
**Fecha:** [timestamp]
**Sesión relacionada:** [si hay log de sesión activo]

## Objetivo
[Qué estábamos haciendo]

## Progreso
- [x] [Completado 1]
- [x] [Completado 2]
- [ ] [Pendiente 1]
- [ ] [Pendiente 2]

## Decisiones tomadas
1. **[Decisión]**: [Razonamiento]
2. **[Decisión]**: [Razonamiento]

## Descubrimientos
- [Algo que aprendimos sobre el sistema]
- [Comportamiento inesperado encontrado]

## Problemas y soluciones
| Problema | Estado | Solución/Nota |
|----------|--------|---------------|
| [Prob 1] | Resuelto | [Cómo] |
| [Prob 2] | Pendiente | [Hipótesis] |

## Caminos descartados
- **[Enfoque X]**: No funcionó porque [razón]
- **[Enfoque Y]**: Descartado por [razón]

## Archivos clave
- `path/to/file1.swift` - [Por qué es relevante]
- `path/to/file2.swift` - [Por qué es relevante]

## Estado técnico
[Descripción del estado actual del código/sistema]

## Siguiente paso exacto
Al retomar esta sesión:
1. [Primer paso concreto]
2. [Segundo paso]

## Notas adicionales
[Cualquier cosa que ayude a retomar]
```

### PASO 4: Guardar y confirmar

1. Escribir archivo en la ruta generada
2. Confirmar al usuario:
```
✓ Snapshot guardado: [ruta]

Contenido capturado:
- Objetivo: [resumen corto]
- Progreso: [N] items completados, [M] pendientes
- [X] decisiones documentadas
- [Y] problemas registrados

Para retomar después de /clear:
1. Lee el snapshot: cat [ruta]
2. O simplemente di: "Retoma desde SNAPSHOT-[timestamp]"
```

## CUÁNDO USAR
- Antes de /compact si el contexto es complejo
- Antes de /clear si hay trabajo en progreso
- Al pausar una investigación larga
- Cuando el contexto tiene valor que no está en commits/docs

## REGLAS
- Ser CONCISO pero COMPLETO
- Capturar el "por qué" no solo el "qué"
- Incluir suficiente contexto para que una nueva sesión entienda
- No duplicar info que ya está en commits o STATE.md
