---
name: regresion-se-mide-contra-lo-publicado
description: Un fallo grave en un barrido se mide contra la versión publicada antes de preguntar si entra: Jürgen cambió de B a A al saber que era regresión.
metadata:
  type: feedback
---

Cuando un barrido encuentra algo grave, **compila la versión publicada (`origin/1.0`, `git archive` a la scratchpad) y
pasa la misma receta antes de pedir la decisión**, o en cuanto se pueda. El 2026-11-05 el Panel del iPad se quedaba en
esqueleto; Jürgen eligió B (card aparte) y, al saber que la 2.1 publicada no lo tenía, pasó a A (entra en el PR del
barrido).

**Why:** «¿regresión o de siempre?» es lo que decide si bloquea la subida; sin el dato, la decisión se toma dos veces.

**How to apply:** la pregunta lleva ya el resultado contra lo publicado; si aún compila, dilo y recomienda condicionado
(«A si es nuevo, B si ya venía»). Relacionado: [[regresion-aparente-se-mide-contra-la-base]].
