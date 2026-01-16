---
description: Captura rápidamente una idea con contexto mínimo y clasificación automática.
---

Captura rápidamente una idea con contexto mínimo y clasificación automática.

PROPÓSITO:
Cuando estás trabajando en un incremento y se te ocurre algo, no quieres perder el foco pero tampoco olvidar la idea. Este comando la captura estructuradamente.

PASOS:
1. Recibe del usuario una descripción breve de la idea (una o dos frases)

2. HAZ PREGUNTAS DE CLASIFICACIÓN (máximo 3):
   - "¿Es mejora de algo que ya existe o feature completamente nueva?"
   - "¿Es técnico (refactor, optimización) o funcional (UI, UX, lógica de negocio)?"
   - "¿Tiene dependencias de otras partes del sistema?"

3. CLASIFICA LA IDEA:
   - Tipo: [Feature | Improvement | Tech Debt | Bug | Research]
   - Categoría: [UI/UX | Data Model | Business Logic | Performance | Architecture]
   - Prioridad estimada: [High | Medium | Low] basada en:
     * High: bloquea trabajo actual o tiene impacto grande
     * Medium: mejora importante pero no urgente
     * Low: nice-to-have sin impacto inmediato

4. CAPTURA EN STATE.MD:
   - Abre STATE.md sección "Parking Lot"
   - Agrega entrada con formato:
     [FECHA] [TIPO] [CATEGORÍA] [PRIORIDAD]: [Descripción]
     Contexto: [Por qué surgió esta idea]
     Dependencias: [Si tiene]

5. CONFIRMA:
   - "Idea capturada en Parking Lot. ¿Continuamos con el incremento actual?"

EJEMPLO DE CAPTURA:
```markdown
- 2025-01-16 [Feature] [UI/UX] [Medium]: Agregar filtro por rango de fechas en lista de transacciones
  Contexto: Surgió mientras implementaba filtro por categoría, los usuarios probablemente querrán ambos
  Dependencias: Ninguna, puede implementarse independientemente
```

REGLAS:
- Captura la idea en menos de 2 minutos
- NO empieces a implementarla ahora
- NO interrumpas el incremento actual
- Si el usuario insiste en que es crítica, pregunta: "¿Quieres detener el incremento actual y replanear para incluir esto?"

Este comando te permite capturar ideas sin perder momentum. La clasificación estructurada hace que después sea fácil priorizar cuando revisas el Parking Lot.
