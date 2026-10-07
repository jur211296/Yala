---
name: esperar-un-pr-ajeno-mira-si-puede-entrar
description: Cuando un encargo pide esperar a que otro PR entre en 2.1 antes de rebasar, el CI verde no basta — un PR en conflicto (DIRTY) no entra solo y la espera no termina nunca.
metadata:
  type: feedback
---

**Al esperar a que el PR de otra sesión entre en `2.1`, vigila `mergeStateStatus`, no solo sus checks.** Con
`DIRTY` (en conflicto con `2.1`) la cola de auto-merge no lo mete aunque `tests` salga verde: hace falta que su
sesión rebase, y eso puede no pasar hoy.

**Why:** el 2026-10-07 el encargo del soltar en iPad pedía esperar a #384 y #385 antes del gate. #384 entró; esperé
~45 min a #385 vigilando solo `statusCheckRollup`, y cuando su CI terminó en verde seguía `OPEN`: había quedado
`DIRTY` en cuanto entró #384. La espera no tenía final.

**How to apply:** en la primera mirada pide también `gh pr view <n> --json mergeStateStatus`. Si sale `DIRTY`, trátalo
como la rama «si ese CI falla» del encargo: rebasa con lo que haya y sigue, y dilo en el cierre.
