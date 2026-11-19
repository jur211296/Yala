---
name: pr-huerfano-en-cola-se-rebasa
description: Un PR en cola de auto-merge cuya sesión ya cerró y que choca (p. ej. en docs/TICKETS.md) se arregla con rebase + push --force-with-lease, no con merge de 2.3.
metadata:
  type: feedback
---

Si tu encargo depende de otro PR que está en cola de auto-merge, `DIRTY`, y su sesión ya no existe (sin worktree),
nadie lo va a desatascar: arréglalo tú si el choque es menor (una fila de `docs/TICKETS.md`). Rebase sobre
`origin/2.3` en un worktree aparte, resolver, banco del PR, `git push --force-with-lease=<rama>:origin/<rama>`. El
auto-merge sigue armado y pasa a `MERGEABLE` en segundos.

**Why:** 2026-11-17, PR de la checklist de confiabilidad (P4) del que dependía la poda (P5). El merge de `2.3` en su
rama metía en staging todo el Swift de 2.3 y el pre-commit del gate lo bloqueaba (no hay sello); el rebase solo
replaya sus commits, que no tenían Swift, y no pasa por ese hook.

**How to apply:** va a «Decidido sin consultar» del cierre. Si el choque es de código, no es menor: pregunta.
Mientras corre su CI (el job `tests` tarda ~65 min), avanza lo tuyo y rebasa una vez cuando mergee.
