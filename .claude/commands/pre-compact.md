---
description: Prepara resumen antes de compactar manualmente (Shift+C)
---

Analiza y presenta qué se preservará/descartará antes de compactar.
**La compactación real se hace con Shift+C después de este comando.**

## PROPÓSITO

Te permite controlar QUÉ se preserva antes de ejecutar Shift+C.

## CUÁNDO USAR

Momentos ideales para compactar:
- Después de completar un milestone/tarea
- Antes de cambiar de tema/feature
- Cuando sientes que la conversación perdió foco
- Después de /session-end
- Cuando el contexto tiene >50% de ruido (exploración, errores corregidos, etc.)

## EJECUCIÓN

### PASO 1: Análisis pre-compactación

Revisar la conversación y clasificar:

**PRESERVAR (crítico):**
- Objetivo actual de la sesión
- Decisiones de arquitectura/diseño tomadas
- Estado actual del trabajo (qué está hecho, qué falta)
- Archivos clave modificados
- Errores importantes y sus soluciones

**DESCARTAR (ruido):**
- Exploraciones que no llevaron a nada
- Errores de build ya corregidos
- Múltiples intentos fallidos
- Outputs largos de comandos
- Lecturas de archivos que ya no son relevantes

### PASO 2: Verificar snapshots

Antes de compactar, verificar:
- ¿Hay contexto valioso que no está en commits ni STATE?
- Si sí: Sugerir `/context-snapshot` primero

### PASO 3: Presentar resumen pre-compact

```
## Pre-compactación

**Se preservará:**
- Objetivo: [objetivo de la sesión]
- Progreso: [resumen de lo hecho]
- Decisiones: [lista corta]
- Archivos relevantes: [lista]

**Se descartará:**
- [N] lecturas de archivos
- [M] outputs de comandos
- [P] errores ya corregidos
- Exploración de [tema X]

¿Procedo con la compactación? (sí/no/primero snapshot)
```

### PASO 4: Indicar siguiente paso

```
═══════════════════════════════════════════════════════════════
         PRESIONA Shift+C PARA COMPACTAR AHORA
═══════════════════════════════════════════════════════════════
El resumen arriba es lo que se preservará.
```

## ALTERNATIVAS

Si el usuario no quiere perder nada:
- Sugerir `/context-snapshot` primero
- O `/checkpoint` que hace commit + actualiza STATE + prepara para continuar

Si el usuario quiere borrar TODO:
- Sugerir `/clear` directamente

## REGLAS
- NUNCA compactar sin avisar qué se perderá
- SIEMPRE ofrecer snapshot si hay contexto valioso
- La compactación es para OPTIMIZAR, no para perder información
- Si hay trabajo sin commitear, advertir antes de compactar
