---
name: auto-merge-en-2-2-no-espera-al-ci
description: 2.2 exige hoy tests, coverage-index Y gateway; un PR en cola con uno rojo se queda atascado sin avisar — mide el ruleset, no lo recuerdes
metadata:
  type: feedback
---

**Medido el 2026-10-26:** el ruleset de `2.2` exige `tests`, `coverage-index` **y `gateway`**
(`gh api repos/jur211296/Yala/rules/branches/2.2`). El PR #634 quedó en cola de auto-merge desde las 06:02 y no entró en
todo el día: `coverage-index` (falso positivo del check de aislamiento) y `gateway` (el bench de Insights replica el
prompt del Swift por posición y #634 añadió una rama delante) estaban rojos. Nadie lo vio hasta la sesión siguiente.

Antes (2026-10-14) era al revés: `gh pr merge --auto` contra 2.2 fusionaba en el acto porque 2.2 no exigía checks.

**Why:** «en cola» no es «entrará». Un check obligatorio rojo deja el PR `OPEN` con `autoMergeRequest` puesto para
siempre, y la card ya decía `done`.

**How to apply:**
- Al abrir sesión con una card en `done` cuyo PR va en cola, `gh pr view <n> --json state` antes de darla por entrada.
- Antes de dejar un PR en cola, mide los checks obligatorios del ruleset y corre en local los que tu diff puede tocar:
  un cambio en el prompt de Yala IA (`Yala/Services/*LLM*`, `InsightsViewModel`) rompe `gateway` aunque no toques
  `gateway/` (`cd gateway && npm run typecheck && npm test`).
