---
description: Analiza STATE y ROADMAP para proponer automáticamente el siguiente incremento de trabajo.
---

Analiza el estado del proyecto y propone el siguiente trabajo de forma concisa.

## PASO 1: RESUMEN RÁPIDO

Lee estos archivos en paralelo:
- STATE.md (secciones: Recent Progress, Session Continuity, Next Steps)
- Los últimos 5 commits con `git log --oneline -5`
- Si existe, el último archivo en .claude/sessions/ (ordenado por fecha)

Presenta un resumen compacto:

```
## Resumen

**Última sesión:** [fecha] - [qué se hizo, de Session Continuity o último log]
**Últimos commits:**
- [hash] [mensaje]
- [hash] [mensaje]
- [hash] [mensaje]

**Fase actual:** [fase del ROADMAP]
**Documento de trabajo:** [si hay uno activo, ej: REFINAMIENTO-8.3-8.4.md]
```

## PASO 2: OPCIONES DISPONIBLES

Identifica las opciones de trabajo disponibles según:
- Next Steps en STATE.md
- Items pendientes en documento de trabajo activo (si existe)
- Siguiente fase del ROADMAP si la actual está completa

Presenta máximo 5 opciones numeradas:

```
## Siguiente trabajo

1. [código/nombre] - [descripción breve de 1 línea]
2. [código/nombre] - [descripción breve de 1 línea]
3. [código/nombre] - [descripción breve de 1 línea]

¿Cuál eliges? (1/2/3/otro)
```

## PASO 3: PLANIFICACIÓN (después de elegir)

Cuando el usuario elija una opción:

1. Investiga brevemente el item elegido (lee archivos relevantes si es necesario)

2. Pregunta:
   ```
   ¿Necesitas que planifiquemos este trabajo?
   - Sí: Divido en incrementos pequeños antes de empezar
   - No: Empezamos directo con /session-start
   ```

3. Si el usuario dice "sí" a planificar:
   - Analiza el alcance del trabajo
   - Propón división en incrementos commiteables (máximo 1-2 líneas cada uno)
   - Ejemplo:
     ```
     ## Plan para [item elegido]

     1. [Incremento 1] - [qué se logra]
     2. [Incremento 2] - [qué se logra]
     3. [Incremento 3] - [qué se logra]

     ¿Listo para empezar? Ejecuto /session-start
     ```

4. Si el usuario dice "no" o cuando el plan esté listo:
   - Pregunta: "¿Ejecuto /session-start para comenzar?"

## PASO 4: INICIO DE SESIÓN

Si el usuario confirma, ejecuta automáticamente el flujo de /session-start con:
- El objetivo ya definido (el item elegido)
- El plan de incrementos (si se definió)
- Sin volver a preguntar qué va a trabajar (ya lo sabemos)

---

REGLAS:
- Ser CONCISO - máximo 20 líneas por sección
- NO generar texto innecesario (nada de "Contexto", "Requisitos", "Definition of Done" detallados)
- Priorizar items según: bugs > UX crítico > features > polish
- Si hay un documento de trabajo activo (REFINAMIENTO, PLAN, etc.), usarlo como fuente principal
