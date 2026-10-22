---
name: project_dangler_ilegible_no_es_rowgone
description: PR del 23-sep (dangling-ref-repair-…): una ref colgada con la fila o el destino ilegible ya no se pierde; a done sin device-QA, tres tickets nuevos de la review.
metadata:
  type: project
---

Cerrado sin device-QA (una base local ilegible no se provoca en un iPhone). La decisión que el ticket dejaba abierta
—en los appliers, ¿tirar la página o solo no pisar la ref?— se tomó de noche por la opción robusta: **tirar la página**,
tras medir que los appliers solo corren dentro de `applyPage` y `drainQuarantineOnce`, los dos con rollback.

Lo que la review dejó con ticket y por qué no entró:
- `dangling-ref-pass-overwrites-a-pending-local-edit` (low): el pase no mira el guard D-1; es otro problema, no una lectura.
- `post-pull-reconcilers-read-an-unreadable-table-as-nothing-to-repair` (low): misma familia, fuera del save del apply.
- `a-malformed-ref-leaves-a-stale-dangler` (very-low): wire que nuestro servidor no emite.

**Why:** el encargo prohibía mezclar residuales; los tres son de otro camino.
**How to apply:** si Jürgen pregunta por qué una tabla ilegible deja ahora el pull en `.transient` en vez de avanzar
degradado: es el intercambio de #216, escrito en la regla. Relacionado: [[project_apply_no_pisa_sin_salvaguardas]].
