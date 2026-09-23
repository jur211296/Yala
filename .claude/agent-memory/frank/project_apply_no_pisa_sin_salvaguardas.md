---
name: project_apply_no_pisa_sin_salvaguardas
description: PR del 22-sep (apply-overwrites-…): en el apply «no pude leer» ya no es «no hay nada»; tres residuales con ticket.
metadata:
  type: project
---

Cerrado sin device-QA. Lo que queda abierto y por qué no entró:
- `dangling-ref-repair-is-lost-when-its-row-cannot-be-read` (very-high): pase final, fuera de `applyPage`.
- `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read` (high): bloqueado por el `catch` sin rollback de `drainOnce`.
- `a-local-read-failure-in-the-migration-apply-reads-as-network` (low): falta un case local en `PullApplyOutcome`.

**Why:** los tres son la misma familia pero con otro camino de error.
**How to apply:** el dangler es el siguiente candidato natural de la cola A. Relacionado: [[feedback_el_gemelo_vive_en_el_mismo_save]].
