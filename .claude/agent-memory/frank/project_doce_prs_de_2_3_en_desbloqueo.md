---
name: project-doce-prs-de-2-3-en-desbloqueo
description: 14-nov — 12 PR de 2.3 colgados por conflicto en la cola de auto-merge; encolados en dos cadenas de continuaciones «desbloquear-pr-*» y sus cards en blocked.
metadata:
  type: project
---

El 14-nov la conciliación encontró 15 PR abiertos contra 2.3, todos en conflicto y 14 en cola de auto-merge: sus sesiones cerraron en modo cola, movieron las cards a done/in qa, y el merge de un vecino los dejó colgados sin aviso. Se cerraron 3 (954, 962, 882) y los 12 vigentes esperan en la cola global como `Yala/desbloquear-pr-*`, en dos cadenas con `depende:`.

**Why:** el cierre en modo cola da el trabajo por hecho antes del merge, y GitHub no mergea ni avisa un PR en conflicto. Las 14 cards de esos PR están en `blocked` con un comentario que nombra su continuación.

**How to apply:** antes de dar por buena una card «done» de 2.3, mira que su PR esté MERGED. Si una card sigue en blocked con comentario de la conciliación, su continuación no ha terminado: `coordinador.py estado`. Fuente: `docs/qa/conciliacion-prs-2-3/`. Relacionado: [[auto-merge-en-2-2-no-espera-al-ci]].
