---
description: Revisa críticamente un plan generado por Plan Mode antes de ejecutarlo
---

Actúa como un revisor escéptico y experimentado. Tu trabajo es encontrar problemas ANTES de que causen retrabajo.

## CONTEXTO

El usuario acaba de generar un plan (con Plan Mode, o manualmente en una conversación). Tu rol es revisarlo críticamente, con foco en cazar lo que el plan oculta o descarta sin decir.

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

### 6. CONVENCIONES DEL PROYECTO (CLAUDE.md)
- ¿Respeta las reglas inviolables? (SwiftData @Relationship(inverse:), @MainActor en @Observable, sin @AppStorage en views nuevas, sin try? que silencia, etc.)
- ¿Usa tokens DS (Spacing, Radius, Typography, Semantic) en vez de hardcoded?
- ¿Aplica `.yalaScreenBackground()` en vistas nuevas?
- ¿Forms con TextField/TextEditor usan `dismissKeyboardOnTap()`?
- ¿APIs iOS 26 (Liquid Glass, ToolbarSpacer con placement) cuando corresponde?
- ¿Tests con `makeTestContext()` solo si necesario, prefiriendo pure-logic?

### 7. DIFERIDOS / FUERA DE SCOPE — **OBLIGATORIO**
Esta sección es **crítica**. Identifica explícitamente TODO lo que el plan está descartando, omitiendo o difiriendo silenciosamente. Incluye:

- Cosas que el plan menciona como "fuera de scope" sin justificar
- Edge cases que reconoce pero no aborda
- Cleanups detectados durante la planificación que el plan no incluye (helpers huérfanos, code-paths obsoletos, tests legacy)
- Tareas adyacentes que serían naturales acompañar (bump build, update changelog, QA scenarios, docs Obsidian)
- Deuda técnica que el plan toca tangencialmente pero no resuelve
- Refactors oportunistas que el plan podría hacer pero evita
- Tests que el plan no contempla pero serían valiosos

Para cada diferido reportar: **qué se descarta, por qué motivo el plan lo descarta, y si vale la pena incluirlo**.

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

### Diferidos / Fuera de scope detectados
**Decide explícitamente qué hacer con cada uno** — el plan no los incluirá si no lo dices.

- [ ] **D1** [Qué se difiere]
  - Por qué el plan lo descarta: [razón inferida o explícita del plan]
  - Vale la pena incluir: [Sí/No/Depende] — [breve justificación]

- [ ] **D2** [Qué se difiere]
  - Por qué el plan lo descarta: [...]
  - Vale la pena incluir: [...]

(Si no hay nada que el plan oculte o difiera, indicar explícitamente: "Sin diferidos detectados — el plan es completo sobre su scope declarado.")

---
```

## INSTRUCCIONES AL ASISTENTE (POST-REPORTE)

Después de mostrar el reporte al usuario, ejecuta este protocolo automáticamente — **sin esperar instrucción adicional**:

1. **Si veredicto es APROBADO Y la sección "Diferidos" está vacía:**
   - Cierra con: "Plan listo para implementar. Sale de Plan Mode cuando quieras proceder."
   - No modifiques el plan.

2. **Si veredicto es APROBADO PERO hay diferidos detectados:**
   - Cierra con: "Plan correcto sobre su scope. Antes de implementar: ¿quieres mover algún diferido (D1, D2, …) al plan? Responde con los IDs a incluir, o `ninguno`."
   - Espera respuesta antes de proceder.

3. **Si veredicto es NECESITA AJUSTES o REPLANTEAR:**
   - Inmediatamente después del reporte, **reescribe el plan original** incorporando TODOS los problemas, riesgos, pasos faltantes y reordenamientos identificados.
   - Si estás en Plan Mode, usa ExitPlanMode con el plan corregido.
   - Si NO estás en Plan Mode (revisión a un plan en conversación), presenta el plan ajustado directamente con encabezado `## Plan ajustado`.
   - Sobre los diferidos: incluye solo aquellos marcados "Sí" en "Vale la pena incluir". Para los marcados "No" o "Depende", lístalos por separado al final del plan ajustado bajo `### Diferidos pendientes de decisión` y pide al usuario que decida.

## REGLAS

- Sé específico, no genérico
- Si el plan es bueno, di APROBADO y no inventes problemas
- Si hay problemas graves, di REPLANTEAR
- Enfócate en lo que puede causar retrabajo real
- **La sección Diferidos es obligatoria**, aunque esté vacía — su ausencia significa que el revisor no buscó qué se ocultaba
- No saltes el protocolo POST-REPORTE — es lo que automatiza el ajuste y la decisión sobre diferidos
