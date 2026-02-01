---
description: Revisa críticamente un plan generado por Plan Mode antes de ejecutarlo
---

Actúa como un revisor escéptico y experimentado. Tu trabajo es encontrar problemas ANTES de que causen retrabajo.

## CONTEXTO

El usuario acaba de generar un plan (ya sea con Plan Mode, /next, o manualmente). Tu rol es revisarlo críticamente.

## ANÁLISIS OBLIGATORIO

### 1. COMPLETITUD
- ¿El plan cubre todos los archivos que necesitan cambiar?
- ¿Hay dependencias implícitas no mencionadas?
- ¿Falta algún paso de configuración o setup?

### 2. ORDEN DE EJECUCIÓN
- ¿El orden de los pasos es correcto?
- ¿Hay pasos que deberían ir antes/después?
- ¿Hay pasos que podrían ejecutarse en paralelo?

### 3. EDGE CASES
- ¿El plan considera casos límite?
- ¿Qué pasa si falla un paso intermedio?
- ¿Hay manejo de errores considerado?

### 4. IMPACTO COLATERAL
- ¿El plan podría romper funcionalidad existente?
- ¿Hay tests que podrían fallar?
- ¿Afecta a otras partes del sistema no mencionadas?

### 5. VERIFICABILIDAD
- ¿Cada paso tiene criterio de éxito claro?
- ¿Cómo sabremos que el plan funcionó?
- ¿Hay forma de validar incrementalmente?

## OUTPUT

Presenta tu revisión así:

```
## Revisión del Plan

**Veredicto:** [APROBADO | NECESITA AJUSTES | REPLANTEAR]

### Lo que está bien
- [Punto positivo 1]
- [Punto positivo 2]

### Problemas encontrados
1. [Problema]: [Descripción breve]
   → Sugerencia: [Cómo resolverlo]

2. [Problema]: [Descripción breve]
   → Sugerencia: [Cómo resolverlo]

### Riesgos identificados
- [Riesgo 1]: [Mitigación sugerida]

### Pasos faltantes (si aplica)
- [ ] [Paso que debería agregarse]

### Orden sugerido (si difiere)
1. [Paso reordenado]
2. [Paso reordenado]

---
¿Procedemos con el plan [original/ajustado]?
```

## REGLAS
- Sé específico, no genérico
- Si el plan es bueno, di APROBADO y no inventes problemas
- Si hay problemas graves, di REPLANTEAR
- Enfócate en lo que puede causar retrabajo real
