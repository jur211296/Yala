---
name: cierre-de-diseno-spec-por-cards
description: Al cerrar un artifact de diseño, Jürgen quiere la versión oficial limpia y una especificación por cards (con ID estable) que el bot pueda partir sin confundirse.
metadata:
  type: feedback
---

Cerrar un diseño = quitar del artifact alternativas y mandos descartados, y dejar dentro una especificación por cards con ID
estable (dónde se ve + atajo, qué ve la persona, textos exactos, existe/nuevo, dependencias, fuera de alcance, «está bien cuando»),
más un bloque JSON. La misma spec va al repo (`docs/<tema>/SPEC.md`), generada de UNA fuente para que no diverjan.

**Why:** 9-nov: «para que el bot pueda leerlo y disgregar todo este trabajo en cards… y que no se confunda ni lo haga diferente».

**How to apply:** script generador (`gen_spec.py`) que escribe la sección del artifact y SPEC.md; fija en código las variantes
elegidas y retira sus mandos. Las normas externas (p. ej. Apple 3.1.2) van como dependencia en la card que tocan.
