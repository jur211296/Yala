---
name: destrabar-pr-ajeno-por-indice
description: Un PR ajeno con auto-merge atascado solo por una fila de un índice (docs/TICKETS.md) y sin hueco de Yala para su sesión de arreglo: Jürgen aprueba destrabarlo desde la sesión que lo espera.
metadata:
  type: feedback
---

Si un PR de otra sesión, con auto-merge, lleva rato en conflicto **solo por un índice** y la sesión de arreglo que
encoló el vigía no puede arrancar (no hay hueco de Yala), se le ofrece a Jürgen destrabarlo y, con su sí, se hace:
worktree temporal en la scratchpad, `git merge origin/2.3`, dejar las dos filas, commit y push a SU rama.

**Why:** 27-nov-2026, barrido antes de la build 12: el pulido de Grupos esperaba una hora por una fila de
`docs/TICKETS.md` y el barrido no podía empezar sin él. Jürgen: «Sí, destrábalo».

**How to apply:** el hook de pre-commit pide gate porque el merge trae `.swift` de 2.3 ya probados: `--no-verify` en
ese commit de merge, dicho en el Paso 0 (el propio hook lo admite y el CI del PR vuelve a probar). La sesión de arreglo
encolada no se puede retirar sin el id de un mensaje de Jürgen (`coordinador.py retirar` exige `--clave`): se deja y se
anota. Ver [[no-esperar-ci-ajeno]].
