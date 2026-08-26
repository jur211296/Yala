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
   - Prioridad estimada: [high | medium | low] basada en:
     * high: bloquea trabajo actual o tiene impacto grande
     * medium: mejora importante pero no urgente
     * low: nice-to-have sin impacto inmediato

4. CAPTURA EN `tickets/backlog/<english-kebab-slug>.md`:
   - Slug inglés kebab-case (filename = id)
   - Frontmatter: `id`, `status: backlog`, `priority` si la clasificaste, `updated` (hoy), `source` si aplica
   - Título + descripción + contexto + dependencias
   - Una línea en `docs/ESTADO.md` si la idea bloquea el trabajo actual
   - Añadir la fila en `docs/TICKETS.md`

5. CONFIRMA:
   - "Idea capturada en tickets/backlog/<slug>.md. ¿Continuamos con el incremento actual?"

EJEMPLO DE CAPTURA:
```markdown
---
id: filter-transactions-by-date-range
status: backlog
priority: medium
updated: 2026-08-26
---
# Filter transactions by date range

Contexto: Surgió mientras implementaba filtro por categoría, los usuarios probablemente querrán ambos
Dependencias: Ninguna, puede implementarse independientemente
```

REGLAS:
- Captura la idea en menos de 2 minutos
- NO empieces a implementarla ahora
- NO interrumpas el incremento actual
- NO escribas en Obsidian ni en STATE.md
- Si el usuario insiste en que es crítica, pregunta: "¿Quieres detener el incremento actual y replanear para incluir esto?"

Este comando te permite capturar ideas sin perder momentum. La clasificación estructurada hace que después sea fácil priorizar cuando revisas `tickets/backlog/`.
