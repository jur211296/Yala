---
description: Texto exacto para usar en Plan Mode después de elegir una tarea
argument-hint: "[descripción de la tarea]"
---

## USO

Después de `/next` y elegir la tarea, entra a Plan Mode (Shift+Tab) y usa este prompt:

---

## PROMPT PARA PLAN MODE

Copia y pega esto (reemplazando [TAREA]):

```
Necesito implementar: [TAREA]

ANTES de escribir código:
1. Explora los archivos relevantes para entender el contexto actual
2. Identifica TODOS los archivos que necesitarán cambios
3. Detecta dependencias y posibles efectos colaterales
4. Propón un plan de implementación dividido en incrementos pequeños

Para cada incremento del plan, especifica:
- Qué archivos se modifican
- Qué cambio específico se hace
- Cómo verificar que funciona

NO escribas código todavía. Solo el plan.
```

---

## EJEMPLO COMPLETO

```
Necesito implementar: Agregar filtro por rango de fechas en la lista de transacciones

ANTES de escribir código:
1. Explora los archivos relevantes para entender el contexto actual
2. Identifica TODOS los archivos que necesitarán cambios
3. Detecta dependencias y posibles efectos colaterales
4. Propón un plan de implementación dividido en incrementos pequeños

Para cada incremento del plan, especifica:
- Qué archivos se modifican
- Qué cambio específico se hace
- Cómo verificar que funciona

NO escribas código todavía. Solo el plan.
```

---

## DESPUÉS DEL PLAN

Una vez que Claude presente el plan:
1. Revísalo críticamente (o usa `/review-plan`)
2. Ajusta si es necesario
3. Sal de Plan Mode (Shift+Tab de nuevo)
4. Ejecuta `/session-start` para comenzar la implementación
