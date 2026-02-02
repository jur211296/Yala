---
description: Compacta contexto preservando solo el plan, listo para ejecutar
---

Limpia el contexto de exploración y planificación, preservando SOLO el plan final.

## CUÁNDO USAR

```
Shift+Tab → [planificación] → [Esc] → /review-plan → /plan-ready → /session-start o /yolo
```

Úsalo cuando:
- El proceso de planificación consumió mucho contexto
- Ya tienes el plan revisado y aprobado
- Quieres empezar la ejecución con contexto limpio

## EJECUCIÓN

### PASO 1: Extraer el plan final

Identificar y guardar:
- Objetivo de la tarea
- Lista de pasos/incrementos del plan
- Archivos clave a modificar
- Decisiones importantes tomadas

### PASO 2: Crear resumen compacto

```markdown
## Plan a ejecutar

**Objetivo:** [descripción corta]

**Pasos:**
1. [paso 1]
2. [paso 2]
3. [paso 3]

**Archivos clave:**
- [archivo 1]
- [archivo 2]

**Decisiones:**
- [decisión importante 1]
- [decisión importante 2]
```

### PASO 3: Informar al usuario

```
╔═══════════════════════════════════════════════════════════════╗
║                    PLAN LISTO PARA EJECUTAR                   ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Objetivo: [objetivo]                                         ║
║  Pasos: [N]                                                   ║
║  Archivos: [M]                                                ║
║                                                               ║
║  El contexto de exploración será compactado.                  ║
║  Solo se preservará el plan resumido arriba.                  ║
║                                                               ║
║  ¿Proceder? (sí / ver plan completo / cancelar)               ║
╚═══════════════════════════════════════════════════════════════╝
```

### PASO 4: Ejecutar compact

Si el usuario confirma:

1. Ejecutar `/compact` internamente
2. Inmediatamente después, presentar el plan resumido como contexto fresco

### PASO 5: Siguiente paso

```
✓ Contexto compactado
✓ Plan preservado

Siguiente paso:
- /session-start  → Para ejecución con validaciones
- /yolo           → Para ejecución autónoma
```

## RESULTADO

Después de `/plan-ready`:
- Contexto limpio (~90% reducido)
- Plan completo disponible
- Listo para `/session-start` o `/yolo`

## FLUJO COMPLETO RECOMENDADO

```
/next
    ↓
Shift+Tab → "Planifica [tarea]"
    ↓
[Esc]
    ↓
/review-plan
    ↓
/plan-ready          ← COMPACTA AQUÍ
    ↓
/session-start o /yolo
    ↓
[ejecución con contexto limpio]
```
